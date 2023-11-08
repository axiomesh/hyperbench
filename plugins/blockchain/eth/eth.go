package eth

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"fmt"
	"math/big"
	"math/rand"
	"os"
	"path"
	"reflect"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/meshplus/hyperbench/base"
	fcom "github.com/meshplus/hyperbench/common"
	"github.com/spf13/cast"
	"github.com/spf13/viper"
)

const (
	maxGasPrice = 10000000000000
	gasLimit    = 300000
	sep         = "\n"
)

// Contract contains the abi and bin files of contract
type Contract struct {
	Name      string
	ABI       string
	BIN       string
	parsedAbi abi.ABI
}

type option struct {
	gas    *big.Int
	setGas bool
	noSend bool
}

type NonceMgr struct {
	nonceMap map[string]uint64
	lock     sync.RWMutex
}

func (nm *NonceMgr) getNonceAndAdd(client *ethclient.Client, addr common.Address) (uint64, error) {
	nm.lock.Lock()
	defer nm.lock.Unlock()

	if nonce, ok := nm.nonceMap[addr.String()]; ok {
		nonce++
		nm.nonceMap[addr.String()] = nonce
		return nonce, nil
	}

	nonce, err := client.PendingNonceAt(context.Background(), addr)
	if err != nil {
		return 0, err
	}
	nm.nonceMap[addr.String()] = nonce
	return nonce, nil
}

func (nm *NonceMgr) subNonce(addr common.Address) {
	nm.lock.Lock()
	defer nm.lock.Unlock()

	if nonce, ok := nm.nonceMap[addr.String()]; ok {
		nonce--
		nm.nonceMap[addr.String()] = nonce
	}
}

// ETH the client of eth
type ETH struct {
	*base.BlockchainBase
	ethClient  *ethclient.Client
	startBlock uint64
	endBlock   uint64
	chainID    *big.Int
	gasPrice   *big.Int
	engineCap  uint64
	workerNum  uint64
	wkIdx      uint64
	vmIdx      uint64
	op         option
}

// Msg contains message of context
type Msg struct {
	ContractName string `json:"contract_name"`
	ContractAddr string `json:"contract_addr"`
}

var (
	accounts        map[string]*ecdsa.PrivateKey
	accountAddrList []string
	contracts       map[string]Contract
	nonceMgr        NonceMgr
	accountCount    uint64
)

func InitEth() {
	nonceMgr.nonceMap = make(map[string]uint64)

	log := fcom.GetLogger("eth")
	configPath := viper.GetString(fcom.ClientConfigPath)
	options := viper.GetStringMap(fcom.ClientOptionPath)
	accountCount = viper.GetUint64(fcom.EngineAccountsPath)
	files, err := os.ReadDir(configPath + "/keystore")
	if err != nil {
		log.Errorf("access keystore failed:%v", err)
	}

	accounts = make(map[string]*ecdsa.PrivateKey)
	for _, file := range files {
		fileName := file.Name()
		accountAddrList, accounts, err = KeystoreToPrivateKey(configPath+"/keystore/"+fileName, cast.ToString(options["keypassword"]))
		if err != nil {
			log.Errorf("access account file failed: %v", err)
			return
		}
	}

	contractPath := viper.GetString(fcom.ClientContractPath)
	if contractPath != "" {
		contracts, err = newContract(contractPath)
		if err != nil {
			log.Errorf("initiate contract failed: %v", err)
			return
		}

		for name, contract := range contracts {
			parsed, err := abi.JSON(strings.NewReader(contract.ABI))
			if err != nil {
				log.Errorf("decode abi of contract failed: %v", err)
				return
			}
			contract.parsedAbi = parsed
			// update contract
			contracts[name] = contract
		}
	}
}

// New use given blockchainBase create ETH.
func New(blockchainBase *base.BlockchainBase) (client interface{}, err error) {
	log := fcom.GetLogger("eth")
	ethConfig, err := os.Open(blockchainBase.ConfigPath + "/eth.toml")
	if err != nil {
		log.Errorf("load eth configuration fialed: %v", err)
		return nil, err
	}
	viper.MergeConfig(ethConfig)
	ethClient, err := ethclient.Dial(viper.GetString("rpc.node") + ":" + viper.GetString("rpc.port"))
	if err != nil {
		log.Errorf("ethClient initiate fialed: %v", err)
		return nil, err
	}

	gasPrice := big.NewInt(maxGasPrice)

	chainID, err := ethClient.NetworkID(context.Background())
	if err != nil {
		log.Errorf("get chainID failed: %v", err)
		return nil, err
	}

	workerNum := uint64(len(viper.GetStringSlice(fcom.EngineURLsPath)))
	if workerNum == 0 {
		workerNum = 1
	}
	vmIdx := uint64(blockchainBase.Options["vmIdx"].(int64))
	wkIdx := uint64(blockchainBase.Options["wkIdx"].(int64))

	client = &ETH{
		BlockchainBase: blockchainBase,
		ethClient:      ethClient,
		chainID:        chainID,
		gasPrice:       gasPrice,
		engineCap:      viper.GetUint64(fcom.EngineCapPath),
		workerNum:      workerNum,
		vmIdx:          vmIdx,
		wkIdx:          wkIdx,
		op: option{
			setGas: false,
			noSend: false,
		},
	}
	return
}
func (e *ETH) DeployContract(addr, contractName string, args ...any) (string, error) {
	// convert args
	deployArgs := e.convertArgs(args)
	e.Logger.Infof("deploy args: %+v", deployArgs)

	// deploy contract
	deployContract, ok := contracts[contractName]
	if !ok {
		e.Logger.Errorf("deploy contract: %s not found", contractName)
		return "", fmt.Errorf("contract name: %s not found in contract directory", contractName)
	}

	account, ok := accounts[addr]
	if !ok {
		e.Logger.Errorf("deploy contract error, the account %s not exist", addr)
		return "", fmt.Errorf("deploy contract %s error", contractName)
	}

	auth, err := bind.NewKeyedTransactorWithChainID(account, e.chainID)
	if err != nil {
		e.Logger.Errorf("generate transaction options failed: %v", err)
		return "", err
	}
	auth.Value = big.NewInt(0)       // in wei
	auth.GasLimit = uint64(gasLimit) // in units
	auth.GasPrice = e.gasPrice

	accountAddr := common.HexToAddress(addr)
	nonce, err := nonceMgr.getNonceAndAdd(e.ethClient, accountAddr)
	if err != nil {
		e.Logger.Errorf("get nonce failed: %v", err)
		return "", err
	}
	auth.Nonce = big.NewInt(int64(nonce))

	contractAddress, _, _, err := bind.DeployContract(auth, deployContract.parsedAbi, common.FromHex(deployContract.BIN), e.ethClient, deployArgs...)
	if err != nil {
		e.Logger.Errorf("deploycontract failed: %v", err)
		nonceMgr.subNonce(accountAddr)
		return "", err
	}

	e.Logger.Infof("deploy contract: %s success, address: %s", contractName, contractAddress)

	return contractAddress.String(), nil
}

// Invoke invoke contract with funcName and args in eth network
func (e *ETH) Invoke(invoke fcom.Invoke, ops ...fcom.Option) *fcom.Result {
	contract, ok := contracts[invoke.Contract]
	if !ok {
		e.Logger.Errorf("invoke error, no this contract: %s", invoke.Contract)
		return e.handleErr()
	}

	contractAddress := common.HexToAddress(invoke.ContractAddr)

	instance := bind.NewBoundContract(contractAddress, contract.parsedAbi, e.ethClient, e.ethClient, e.ethClient)

	priKey, ok := accounts[invoke.Caller]
	if !ok {
		e.Logger.Errorf("invoke error, not found this account: %s", invoke.Caller)
		return e.handleErr()
	}
	auth, err := bind.NewKeyedTransactorWithChainID(priKey, e.chainID)
	if err != nil {
		e.Logger.Errorf("generate transaction options failed: %v", err)
		return e.handleErr()
	}

	from := common.HexToAddress(invoke.Caller)
	nonce, err := nonceMgr.getNonceAndAdd(e.ethClient, from)
	if err != nil {
		e.Logger.Errorf("invoke: pending nonce failed: %v", err)
		return e.handleErr()
	}
	auth.Nonce = big.NewInt(int64(nonce))
	auth.Value = big.NewInt(0)              // in wei
	auth.GasLimit = uint64(gasLimit)        // in units
	auth.GasPrice = big.NewInt(maxGasPrice) // max_gas_price

	if e.op.setGas {
		auth.GasPrice = e.op.gas
	}
	auth.NoSend = e.op.noSend
	buildTime := time.Now().UnixNano()

	args := e.convertArgs(invoke.Args)

	tx, err := instance.Transact(auth, invoke.Func, args...)
	sendTime := time.Now().UnixNano()
	if err != nil {
		e.Logger.Errorf("invoke error: %v", err)
		nonceMgr.subNonce(from)
		return &fcom.Result{
			Label:     invoke.Func,
			UID:       fcom.InvalidUID,
			Ret:       []interface{}{},
			Status:    fcom.Failure,
			BuildTime: buildTime,
			SendTime:  sendTime,
		}
	}
	ret := &fcom.Result{
		Label:     invoke.Func,
		UID:       tx.Hash().String(),
		Ret:       []interface{}{tx.Data()},
		Status:    fcom.Success,
		BuildTime: buildTime,
		SendTime:  sendTime,
	}

	return ret

}

func (e *ETH) convertArgs(args []interface{}) []interface{} {
	var dstArgs []interface{}
	for _, arg := range args {
		switch reflect.TypeOf(arg).Kind() {
		case reflect.Float64:
			argFloat := arg.(float64)
			dstArgs = append(dstArgs, big.NewInt(int64(argFloat)))
		case reflect.String:
			argStr := arg.(string)
			str := strings.TrimPrefix(argStr, "0x")
			if len(str) == common.AddressLength*2 {
				addr := common.HexToAddress(argStr)
				dstArgs = append(dstArgs, addr)
			} else if len(str) == common.HashLength*2 {
				addr := common.Hex2BytesFixed(str, 32)
				data := [32]byte{}
				copy(data[:], addr)
				dstArgs = append(dstArgs, data)
			} else {
				dstArgs = append(dstArgs, arg)
			}
		case reflect.Slice:
			argSlice := arg.([]interface{})
			// Create an array of appropriate length.
			isAddressArray := true
			for _, item := range argSlice {
				// Check if the item can be a valid address, and set the flag false if not.
				if addrStr, ok := item.(string); ok {
					str := strings.TrimPrefix(addrStr, "0x")
					if len(str) != common.AddressLength*2 {
						isAddressArray = false
						break
					}
				} else {
					isAddressArray = false
					break
				}
			}

			// If all items can be valid addresses, create an address array.
			if isAddressArray {
				addrArray := make([]common.Address, len(argSlice))
				for i, item := range argSlice {
					addrArray[i] = common.HexToAddress(item.(string))
				}
				dstArgs = append(dstArgs, addrArray)
			} else {
				dstArgs = append(dstArgs, arg) // or handle non-address slices as needed
			}
		default:
			dstArgs = append(dstArgs, arg)
		}
	}
	return dstArgs
}

// Confirm check the result of `Invoke` or `Transfer`
func (e *ETH) Confirm(result *fcom.Result, ops ...fcom.Option) *fcom.Result {
	if result.UID == "" ||
		result.UID == fcom.InvalidUID ||
		result.Status != fcom.Success ||
		result.Label == fcom.InvalidLabel {
		return result
	}
	var errors []error
	for i := 1; i <= 5; i++ {
		tx, err := e.ethClient.TransactionReceipt(context.Background(), common.HexToHash(result.UID))
		result.ConfirmTime = time.Now().UnixNano()
		if err != nil || tx == nil {
			errors = append(errors, err)
			result.Status = fcom.Unknown
			time.Sleep(500 * time.Millisecond)
			continue
		}
		result.Status = fcom.Confirm
		break
	}

	if result.Status == fcom.Failure || result.Status == fcom.Unknown {
		e.Logger.Errorf("Confirm error: %+v", errors)
	}

	return result
}

// Transfer transfer a amount of money from a account to the other one
func (e *ETH) Transfer(args fcom.Transfer, ops ...fcom.Option) (result *fcom.Result) {
	from := common.HexToAddress(args.From)
	nonce, err := nonceMgr.getNonceAndAdd(e.ethClient, from)
	if err != nil {
		e.Logger.Errorf("transfer: pending nonce failed: %v", err)
		return e.handleErr()
	}

	value, ok := new(big.Int).SetString(args.Amount, 10)
	if !ok {
		e.Logger.Error("value format error, can't convert to big.Int")
		return e.handleErr()
	}

	toAddress := common.HexToAddress(args.To)
	data := []byte(args.Extra)
	if e.op.setGas {
		e.gasPrice = e.op.gas
	}
	tx := types.NewTransaction(nonce, toAddress, value, gasLimit, e.gasPrice, data)
	buildTime := time.Now().UnixNano()

	account, ok := accounts[args.From]
	if !ok {
		e.Logger.Errorf("get account error: from: %s", args.From)
		nonceMgr.subNonce(from)
		return e.handleErr()
	}
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(e.chainID), account)
	if err != nil {
		nonceMgr.subNonce(from)
		return &fcom.Result{
			Label:     fcom.BuiltinTransferLabel,
			UID:       fcom.InvalidUID,
			Ret:       []interface{}{},
			Status:    fcom.Failure,
			BuildTime: buildTime,
		}
	}

	err = e.ethClient.SendTransaction(context.Background(), signedTx)
	sendTime := time.Now().UnixNano()
	if err != nil {
		e.Logger.Errorf("transfer error: %v", err)
		nonceMgr.subNonce(from)
		return &fcom.Result{
			Label:     fcom.BuiltinTransferLabel,
			UID:       fcom.InvalidUID,
			Ret:       []interface{}{},
			Status:    fcom.Failure,
			BuildTime: buildTime,
			SendTime:  sendTime,
		}
	}

	ret := &fcom.Result{
		Label:     fcom.BuiltinTransferLabel,
		UID:       signedTx.Hash().String(),
		Ret:       []interface{}{tx.Data()},
		Status:    fcom.Success,
		BuildTime: buildTime,
		SendTime:  sendTime,
	}

	return ret
}

// SetContext set test group context in go client
func (e *ETH) SetContext(context string) error {
	return nil
}

// ResetContext reset test group context in go client
func (e *ETH) ResetContext() error {
	return nil
}

// GetContext generate TxContext
func (e *ETH) GetContext() (string, error) {

	// msg := &Msg{
	// 	Contract: e.contract,
	// }

	// bytes, err := json.Marshal(msg)

	// return string(bytes), err
	return "", nil
}

// Statistic statistic remote node performance
func (e *ETH) Statistic(statistic fcom.Statistic) (*fcom.RemoteStatistic, error) {

	from, to := statistic.From, statistic.To

	statisticData, err := GetTPS(e, from, to)
	if err != nil {
		e.Logger.Errorf("getTPS failed: %v", err)
		return nil, err
	}
	return statisticData, nil
}

// LogStartStatus records start blockheight and time
func (e *ETH) LogStartStatus() (start int64, err error) {
	blockInfo, err := e.ethClient.HeaderByNumber(context.Background(), nil)
	if err != nil {
		return 0, err
	}
	e.startBlock = blockInfo.Number.Uint64()
	e.Logger.Infof("Log start block number: %d", e.startBlock)
	start = time.Now().UnixNano()
	return start, err
}

// LogEndStatus records end blockheight and time
func (e *ETH) LogEndStatus() (end int64, err error) {
	blockInfo, err := e.ethClient.HeaderByNumber(context.Background(), nil)
	if err != nil {
		return 0, err
	}
	e.endBlock = blockInfo.Number.Uint64()
	e.Logger.Infof("Log end block number: %d", e.endBlock)
	end = time.Now().UnixNano()
	return end, err
}

// GetRandomAccount get random account except addr
func (e *ETH) GetRandomAccount(addr string) string {
	accountAddr := strings.TrimPrefix(addr, "0x")
	randomNumber := rand.Int63n(int64(accountCount))

	account := accountAddrList[randomNumber]
	if account == accountAddr {
		index := (randomNumber + 1) % int64(accountCount)
		return accountAddrList[index]
	}
	return account
}

func (e *ETH) GetAccount(index uint64) string {
	return accountAddrList[index]
}

// GetRandomAccountByGroup get random account by group
func (e *ETH) GetRandomAccountByGroup() string {
	// total group
	totalGroup := e.workerNum * e.engineCap
	// my group
	group := e.wkIdx*e.engineCap + e.vmIdx

	accountNumOneGroup := accountCount / totalGroup

	if accountNumOneGroup < 1 {
		accountNumOneGroup = 1
	}

	randomNumber := rand.Int63n(int64(accountNumOneGroup))
	accIndex := randomNumber + int64(group*accountNumOneGroup)
	if accIndex >= int64(len(accountAddrList)) {
		accIndex = int64(len(accountAddrList) - 1)
	}

	return accountAddrList[accIndex]
}

// Option ethereum receive options to change the config to client.
// Supported Options:
//  1. key: gas
//     valueType: int
//     effect: set gas will set gasprice used for transaction
//     not set gas will let client use gas which initiate when client created
//     default: default setGas is false, gas is what initiate when client created
//  2. key: nosend
//     valueType: bool
//     effect: set nosend true will let client do not send transaction to node when invoking contract
//     set nosend false will let client send transaction to node when invoking contract
//     default: default nosend is false, gas is what initiate when client created
func (e *ETH) Option(options fcom.Option) error {
	for key, value := range options {
		switch key {
		case "gas":
			if gas, ok := value.(float64); ok {
				e.op.setGas = true
				e.op.gas = big.NewInt(int64(gas))
			} else {
				return errors.New("option `gas` type error: " + reflect.TypeOf(value).Name())
			}
		case "nosend":
			if nosend, ok := value.(bool); ok {
				e.op.noSend = nosend
			} else {
				return errors.New("option `nosend` type error: " + reflect.TypeOf(value).Name())
			}
		}
	}
	return nil
}

// GetContractAddrByName get contract addr by name
func (e *ETH) GetContractAddrByName(contractName string) string {
	return ""
}

func (e *ETH) handleErr() *fcom.Result {
	return &fcom.Result{
		UID:    fcom.InvalidUID,
		Ret:    []interface{}{},
		Status: fcom.Failure,
	}
}

func KeystoreToPrivateKey(privateKeyFile, password string) ([]string, map[string]*ecdsa.PrivateKey, error) {
	log := fcom.GetLogger("eth")
	keyjson, err := os.ReadFile(privateKeyFile)
	if err != nil {
		log.Errorf("read keyjson file failed: %v", err)
		return nil, nil, err
	}

	// TODO: use password to decrypt

	dstAddrList := make([]string, 0)
	dstKeyMap := make(map[string]*ecdsa.PrivateKey)
	keys := strings.Split(string(keyjson), sep)

	if accountCount > uint64(len(keys)) {
		return nil, nil, fmt.Errorf("expected account count %d is bigger than importing account count: %d", accountCount, len(keys))
	}

	for _, key := range keys[:accountCount] {
		sk, err := crypto.HexToECDSA(strings.TrimPrefix(key, "0x"))
		if err != nil {
			return nil, nil, err
		}

		addr := crypto.PubkeyToAddress(sk.PublicKey)
		dstAddr := strings.TrimPrefix(addr.String(), "0x")
		dstAddrList = append(dstAddrList, dstAddr)
		dstKeyMap[dstAddr] = sk
	}

	return dstAddrList, dstKeyMap, nil
}

// GetTPS calculates txnum and blocknum of pressure test
func GetTPS(e *ETH, beginTime, endTime int64) (*fcom.RemoteStatistic, error) {
	blockCounter, txCounter := 0, 0

	for i := e.startBlock; i < e.endBlock; i++ {
		block, err := e.ethClient.BlockByNumber(context.Background(), new(big.Int).SetUint64(i))
		if err != nil {
			return nil, err
		}
		txCounter += len(block.Transactions())
		blockCounter++
	}

	statistic := &fcom.RemoteStatistic{
		Start:    beginTime,
		End:      endTime,
		BlockNum: blockCounter,
		TxNum:    txCounter,
		CTps:     float64(txCounter) * 1e9 / float64(endTime-beginTime),
		Bps:      float64(blockCounter) * 1e9 / float64(endTime-beginTime),
	}
	return statistic, nil
}

// newContract initiates abi and bin files of contract
func newContract(contractPath string) (contracts map[string]Contract, err error) {
	files, err := os.ReadDir(contractPath)
	abiDataMap := make(map[string][]byte)
	binDataMap := make(map[string][]byte)
	if err != nil {
		return nil, err
	}
	for _, file := range files {
		fileExt := path.Ext(file.Name())
		name := strings.TrimSuffix(file.Name(), fileExt)
		if fileExt == ".abi" {
			abiData, err := os.ReadFile(contractPath + "/" + file.Name())
			if err != nil {
				return nil, err
			}
			abiDataMap[name] = abiData
		}
		if fileExt == ".bin" {
			binData, err := os.ReadFile(contractPath + "/" + file.Name())
			if err != nil {
				return nil, err
			}
			binDataMap[name] = binData
		}
	}

	dstContract := make(map[string]Contract)
	for name, abiData := range abiDataMap {
		binData, ok := binDataMap[name]
		if !ok {
			return nil, fmt.Errorf("no bin data for file: %s", name)
		}
		dstContract[name] = Contract{
			Name: name,
			BIN:  string(binData),
			ABI:  string(abiData),
		}
	}

	return dstContract, nil
}
