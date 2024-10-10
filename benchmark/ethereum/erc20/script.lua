local case = testcase.new()
local contractTable = {}
local maxDeployContractNum = 10
--local from = "9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
--local from = "83a81eb60fb2CE7C8db70D80Eb07e9d1E4655C62"
local from = "3bA3053a98396cea0EaDD1fCD0cdfd08dE71DC9e"
local transferValueEveryRun = "80000000000000000000"
local start_time = os.time()


function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

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

    for i = 1, maxDeployContractNum do
        contractAddr = self.blockchain:DeployContract(from, "ERC20")
        if contractAddr ~= "" then
            contractTable[#contractTable + 1] = contractAddr
        end
    end
end

-- Attention: this is called in local worker vm
-- Run more time called by lua vm, this is controled by config
function case:Run()
    local time_diff = os.difftime(os.time(), start_time)
    --local multiple = time_diff / (24 * 3600)
    local multiple = math.floor(time_diff / (60))
    local randomContractIndex = self.toolkit.RandInt(0, #contractTable)
    local contractAddr = contractTable[randomContractIndex + 1]

    -- transfer token
    local range = math.floor(self.index.Accounts / self.index.Alive)
    if multiple == 0 then
        randomFaucet = self.toolkit.RandInt(self.index.Alive * multiple, self.index.Alive * (multiple + 1))
    else
        randomFaucet = self.toolkit.RandInt(self.index.Alive * (multiple % range), self.index.Alive * (multiple % range + 1))
    end
    local fromNew = self.blockchain:GetAccount(randomFaucet)
    local fromAddr = self.blockchain:GetRandomAccount(fromNew)
    if fromAddr ~= fromNew then
        result = self.blockchain:Transfer({
            from = fromNew,
            to = fromAddr,
            amount = transferValueEveryRun,
            extra = "11",
        })
        -- wait token confirm
        --self.blockchain:Confirm(result)
    end

    -- mint erc20
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "ERC20", -- contract name is the contract file name under directory invoke/contract
        contract_addr = contractAddr,
        func = "mint",
        args = {100},
    })
    -- wait token confirm
    --self.blockchain:Confirm(result)

    -- invoke erc20 contract
    local toAddr = self.blockchain:GetRandomAccount(fromAddr)
    --print("to addr:" .. toAddr)
    local random = self.toolkit.RandInt(0, 2)
    local value = self.toolkit.RandInt(1, 100)
    local result
    if random == 0 then
        result = self.blockchain:Invoke({
            caller = fromAddr,
            contract = "ERC20",
            contract_addr = contractAddr,
            func = "transfer",
            args = {toAddr, value},
        })
    else
        -- make sure that randomFaucet is not equal to randomFaucet2
        fromAddr2 = self.blockchain:GetRandomAccount(fromAddr)
        result = self.blockchain:Invoke({
            caller = fromAddr,
            contract = "ERC20",
            contract_addr = contractAddr,
            func = "approve",
            args = {fromAddr2, value},
        })
        result = self.blockchain:Invoke({
            caller = fromAddr2,
            contract = "ERC20",
            contract_addr = contractAddr,
            func = "transferFrom",
            args = {fromAddr, toAddr, value},
        })
    end

    --print("call result:" .. result.UID)
    --self.blockchain:Confirm(result)
    return result
end
return case
