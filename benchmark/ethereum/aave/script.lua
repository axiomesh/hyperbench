local case = testcase.new()
local contractTable = {}
local maxDeployContractNum = 1
local from = "8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"
local transferValueEveryRun = "41000000000000000000"

-- Attention: this is called in master vm
-- DeployContract only called once before run lua vm
function case:DeployContract()
end

-- Attention: this is called in local worker vm
-- BeforeRun called only once for every lua vm, all lua vm need to call the function before runing
function case:BeforeRun()
    --print("accounts num:" .. self.index.Accounts)
    if self.index.Accounts < 2 then
        print("Accounts number must be at least 2")
        return
    end

    -- set aries contract addresses
    --self.blockchain.SetContext('{"contract_name": "aave", "contract_addr": "0x8811817d4982fC4Ea24ecAA7e7Ec502069b0a353"}')
    --self.blockchain.SetContext('{"contract_name": "lendingpool", "contract_addr": "0xC6E282fbeC6aFe4EAC7a6A41369b519E7a9209cd"}')
    -- set dev contract addresses
    self.blockchain.SetContext('{"contract_name": "aave", "contract_addr": "0x67BF81C7c894ae013882Fec620EF03838dCdB5F3"}')
    self.blockchain.SetContext('{"contract_name": "lendingpool", "contract_addr": "0xbB908283Edb0dec9Ff512aE87a3a3A46D607486A"}')
end

-- Attention: this is called in local worker vm
-- Run more time called by lua vm, this is controled by config
function case:Run()
    -- invoke erc20 contract to approve
    local fromAddr = self.blockchain:GetAccount(0)
    local anotherAddr = self.blockchain:GetAccount(1)
    local lendingPoolAddr = self.blockchain:GetContractAddrByName("lendingpool")
    print("to addr:" .. lendingPoolAddr)
    local value = self.toolkit.RandInt(1, 100)
    local approveRes = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "aave",
        func = "approve",
        args = {lendingPoolAddr, value},
    })
    --print("approve aave result:" .. approveRes.UID)

    -- deposit some aave to lendingPool
    local aaveAddr = self.blockchain:GetContractAddrByName("aave")
    local depositRes = self.blockchain.Invoke({
        caller = fromAddr,
        contract = "lendingpool",
        func = "deposit",
        args = {aaveAddr, value, fromAddr, 0},
    })
    --print("deposit aave result:" .. depositRes.UID)

    -- withdraw some aave to another account
    local withdrawRes = self.blockchain.Invoke({
        caller = fromAddr,
        contract = "lendingpool",
        func = "withdraw",
        args = {aaveAddr, value, anotherAddr},
    })
    --print("withdraw aave result:" .. withdrawRes.UID)
    return withdrawRes
end
return case