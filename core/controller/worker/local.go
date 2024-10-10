package worker

import (
	"context"
	"sync"
	"sync/atomic"
	"time"

	fcom "github.com/meshplus/hyperbench/common"
	"github.com/op/go-logging"

	"github.com/meshplus/hyperbench/core/collector"
	"github.com/meshplus/hyperbench/core/engine"
	"github.com/meshplus/hyperbench/core/vmpool"
	"github.com/meshplus/hyperbench/vm"
)

// LocalWorker is the local Worker implement
type LocalWorker struct {
	logger    *logging.Logger
	conf      LocalWorkerConfig
	eg        engine.Engine
	pool      vmpool.Pool
	collector collector.Collector
	idx       fcom.TxIndex
	wg        sync.WaitGroup
	ctx       context.Context
	cancel    context.CancelFunc
	resultCh  chan *fcom.Result
	done      chan struct{}
	colRet    chan collector.Collector
	colReq    chan struct{}
}

// LocalWorkerConfig define the local worker need config.
type LocalWorkerConfig struct {
	Index    int64
	Cap      int64
	Rate     int64
	Duration time.Duration
	Accounts int64
	Alive    int64
}

// NewLocalWorker create LocalWorker.
func NewLocalWorker(config LocalWorkerConfig) (*LocalWorker, error) {
	localWorker := LocalWorker{
		logger:    fcom.GetLogger("worker"),
		collector: collector.NewTDigestSummaryCollector(),
		resultCh:  make(chan *fcom.Result, 1024),
		done:      make(chan struct{}),
		colReq:    make(chan struct{}),
		colRet:    make(chan collector.Collector),
	}
	// init engine
	eg := engine.NewEngine(engine.BaseEngineConfig{
		Rate:     config.Rate,
		Duration: config.Duration,
		Wg:       &localWorker.wg,
	})
	// init vm pool
	pool, err := vmpool.NewPoolImpl(config.Index, config.Cap, config.Accounts, config.Alive)
	if err != nil {
		return nil, err
	}

	// init index
	idx := fcom.TxIndex{
		TxIdx:   -1,
		MissIdx: 0,
	}
	ctx, cancel := context.WithCancel(context.Background())
	localWorker.conf = config
	localWorker.eg = eg
	localWorker.pool = pool
	localWorker.idx = idx
	localWorker.ctx = ctx
	localWorker.cancel = cancel

	return &localWorker, nil
}

// SetContext set the context of worker passed from Master
func (l *LocalWorker) SetContext(bs []byte) (err error) {
	l.pool.Walk(func(v vm.VM) bool {
		if err = v.BeforeSet(); err != nil {
			return true
		}
		if err = v.SetContext(bs); err != nil {
			return true
		}
		return false
	})
	return err
}

// BeforeRun call user hook
func (l *LocalWorker) BeforeRun() (err error) {
	wg := &sync.WaitGroup{}
	l.pool.Walk(func(v vm.VM) bool {
		wg.Add(1)
		go func() {
			if err = v.BeforeRun(); err != nil {
				l.logger.Errorf("Before run error: %s", err)
			}
			wg.Done()
		}()

		return false
	})
	wg.Wait()
	return err
}

// Do call the workers to running
func (l *LocalWorker) Do() error {

	go l.runEngine()

	go l.runCollector()

	return nil
}

// AfterRun call user hook
func (l *LocalWorker) AfterRun() (err error) {
	wg := &sync.WaitGroup{}
	l.pool.Walk(func(v vm.VM) bool {
		wg.Add(1)
		go func() {
			if err = v.AfterRun(); err != nil {
				l.logger.Errorf("After run error: %s", err)
			}
			wg.Done()
		}()

		return false
	})
	wg.Wait()
	return err
}

// Statistic get the number of sent and missed transactions
func (l *LocalWorker) Statistics() (int64, int64) {
	return l.idx.TxIdx + 1, l.idx.MissIdx
}

func (l *LocalWorker) runCollector() {

	defer func() {
		close(l.done)
		close(l.colRet)
	}()

	l.collector.Reset()
	for {
		select {
		case <-l.ctx.Done():
			return
		case result, valid := <-l.resultCh:
			if !valid {
				// engine stop
				l.colRet <- l.collector
				return
			}
			l.collector.Add(result)
		case l.colRet <- l.collector:
			l.collector = collector.NewTDigestSummaryCollector()
			l.collector.Reset()
		}
	}
}

func (l *LocalWorker) runEngine() {
	l.eg.Run(l.asyncJob)

	// close all engines while Do end to ensure all func has been done
	l.wg.Wait()
	close(l.resultCh)
}

func (l *LocalWorker) asyncJob() {
	v := l.pool.Pop()
	defer func() {
		if v != nil {
			l.pool.Push(v)
		}
		l.wg.Done()
	}()
	if v == nil {
		atomic.AddInt64(&l.idx.MissIdx, 1)
		// if worker can not get vm from pool, just shortcut
		return
	}

	res, err := v.Run(fcom.TxContext{
		Context: l.ctx,
		TxIndex: l.atomicAddIndex(),
	})
	if err != nil {
		return
	}
	l.resultCh <- res
}

func (l *LocalWorker) atomicAddIndex() (idx fcom.TxIndex) {
	idx.TxIdx = atomic.AddInt64(&l.idx.TxIdx, 1)
	return
}

// Teardown close the worker manually.
func (l *LocalWorker) Teardown() {
	l.eg.Close()
	l.cancel()
}

// CheckoutCollector checkout collector.
func (l *LocalWorker) CheckoutCollector() (collector.Collector, bool, error) {
	c, b := <-l.colRet
	return c, b, nil
}

// Done close the worker.
func (l *LocalWorker) Done() chan struct{} {
	return l.done
}
