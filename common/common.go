package common

// Invoke define need filed for invoke contract.
type Invoke struct {
	Caller       string        `mapstructure:"caller"`
	Contract     string        `mapstructure:"contract"`
	ContractAddr string        `mapstructure:"contract_addr"`
	Func         string        `mapstructure:"func"`
	Args         []interface{} `mapstructure:"args"`
}

// Transfer define need filed for transfer.
type Transfer struct {
	From   string `mapstructure:"from"`
	To     string `mapstructure:"to"`
	Amount string `mapstructure:"amount"`
	Extra  string `mapstructure:"extra"`
}

// Query define need filed for query info.
type Query struct {
	Func string        `mapstructure:"func"`
	Args []interface{} `mapstructure:"args"`
}

// Option for receive options.
type Option map[string]interface{}

// Context the context in vm.
type Context string

// Statistic contains statistic time.
type Statistic struct {
	From int64 `mapstructure:"from"`
	To   int64 `mapstructure:"to"`
}
