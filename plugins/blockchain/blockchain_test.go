package blockchain

import (
	"testing"

	"github.com/meshplus/hyperbench/base"
	"github.com/stretchr/testify/assert"
)

func TestNewBlockchain(t *testing.T) {
	t.Skip()
	bk, err := NewBlockchain(base.ClientConfig{})
	assert.NotNil(t, bk)
	assert.NoError(t, err)

	bk, err = NewBlockchain(base.ClientConfig{
		ClientType: "eth",
	})
	assert.Nil(t, bk)
	assert.Error(t, err)

	defer func() {
		if err := recover(); err != nil {
			return
		}
	}()
	bk, err = NewBlockchain(base.ClientConfig{
		ClientType: "fabric",
	})
	assert.Nil(t, bk)
	assert.Error(t, err)

	bk, err = NewBlockchain(base.ClientConfig{
		ClientType: "xuperchain",
	})
	assert.Nil(t, bk)
	assert.Error(t, err)
}

func TestNewHyperchain(t *testing.T) {
	defer func() {
		if err := recover(); err != nil {
			return
		}
	}()
	bk, err := NewBlockchain(base.ClientConfig{
		ClientType: "flato",
	})
	assert.Nil(t, bk)
	assert.Error(t, err)
}
