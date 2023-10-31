package blockchain

import (
	"errors"
	"fmt"
	"reflect"

	"github.com/meshplus/hyperbench/base"
	fcom "github.com/meshplus/hyperbench/common"
	"github.com/meshplus/hyperbench/plugins/blockchain/eth"
	"github.com/op/go-logging"
)

var log *logging.Logger

// NewBlockchain create blockchain with different client type.
func NewBlockchain(clientConfig base.ClientConfig) (client fcom.Blockchain, err error) {
	clientBase := base.NewBlockchainBase(clientConfig)

	Client, err := eth.New(clientBase)
	if err != nil {
		return nil, err
	}
	client, ok := Client.(fcom.Blockchain)
	if !ok {
		return nil, errors.New(fmt.Sprint(reflect.TypeOf(client)) + " is not blockchain.Blockchain")
	}
	return
}
