package common

// Blockchain define the service need provided in blockchain.
type Blockchain interface {
	// GetChainID get chain id
	GetChainID() uint64

	// GetLatestBlockNumber get laste block number
	GetLatestBlockNumber() (uint64, error)

	// DeployContract should deploy contract with config file
	DeployContract(addr, contractName string, args ...any) (string, error)

	// DeployBigContract should deploy contract with config file
	DeployBigContract(addr, contractName string, gasLimit uint64, args ...any) (string, error)

	// Invoke just invoke the contract
	Invoke(Invoke, ...Option) *Result

	// Transfer a amount of money from a account to the other one
	Transfer(Transfer, ...Option) *Result

	// Confirm check the result of `Invoke` or `Transfer`
	Confirm(*Result, ...Option) *Result

	// Query do some query
	Query(Query, ...Option) interface{}

	// Option pass the options to affect the action of client
	Option(Option) error

	// GetContext Generate TxContext based on New/Init/DeployContract
	// GetContext will only be run in master
	// return the information how to invoke the contract, maybe include
	// contract address, abi or so.
	// the return value will be send to worker to tell them how to invoke the contract
	GetContext() (string, error)

	// SetContext set test context into go client
	// SetContext will be run once per worker
	SetContext(ctx string) error

	// ResetContext reset test group context in go client
	ResetContext() error

	// Statistic query the statistics information in the time interval defined by
	// nanosecond-level timestamps `from` and `to`
	Statistic(statistic Statistic) (*RemoteStatistic, error)

	// LogStartStatus records start blockheight and time
	LogStartStatus() (int64, error)

	// LogEndStatus records end blockheight and time
	LogEndStatus() (int64, error)

	// LogContractTable records deployed contracts
	LogContractTable() error

	// InitContractAddress load contract table from config file
	InitContractAddress() *Result

	// GetRandomAccount get random account except addr
	GetRandomAccount(addr string) string

	// GetAccount get account of index
	GetAccount(index uint64) string

	// GetRandomAccountByGroup get random account by group
	GetRandomAccountByGroup() string

	// GetContractAddrByName get contract address by contract name
	GetContractAddrByName(contractName string) string
}
