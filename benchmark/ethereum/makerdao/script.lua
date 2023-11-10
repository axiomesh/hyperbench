local case = testcase.new()
local contractTable = {}
local maxDeployContractNum = 10
local from = "70997970C51812dc3A010C7d01b50e0d17dc79C8"
local transferMaxValue = "10000000000000000000000"
local transferValueEveryRun = "10000000000000000000"

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

    local chainID = self.blockchain:GetChainID()
    for i = 1, maxDeployContractNum do
        local table = {}
        daiAddr = self.blockchain:DeployContract(from, "Dai", chainID, from)
        if daiAddr ~= "" then
            table["Dai"] = daiAddr
        end
        erc20Addr = self.blockchain:DeployContract(from, "ERC20", from, "1000000000000000000000")
        if erc20Addr ~= "" then
            table["ERC20"] = erc20Addr
        end
        vatAddr = self.blockchain:DeployContract(from, "Vat", from)
        if vatAddr ~= "" then
            table["Vat"] = vatAddr
        end
        daiJoinAddr = self.blockchain:DeployContract(from, "DaiJoin", from, vatAddr, daiAddr)
        if daiJoinAddr ~= "" then
            table["DaiJoin"] = daiJoinAddr
        end
        gemJoinAddr = self.blockchain:DeployContract(from, "GemJoin", from, vatAddr, "0x0000000000000000000000000000000000000000000000000000000000000000", erc20Addr)
        if gemJoinAddr ~= "" then
            table["GemJoin"] = gemJoinAddr
        end

        contractTable[#contractTable + 1] = table
    end

    local accountNum = math.min(self.index.Accounts, 200)
    local result
    for i=1, accountNum do
        local toAddr = self.blockchain:GetAccount(i-1)
        if toAddr ~= from then
            result = self.blockchain:Transfer({
                from = from,
                to = toAddr,
                amount = transferMaxValue,
                extra = "11",
            })
            sleep(0.1)
        end
    end
    -- wait token confirm
    self.blockchain:Confirm(result)
end

-- Attention: this is called in local worker vm
-- Run more time called by lua vm, this is controled by config
function case:Run()
    -- get random contract
    local randomContractIndex = self.toolkit.RandInt(0, #contractTable)
    local contract = contractTable[randomContractIndex + 1]
    local daiAddr = contract["Dai"]
    local erc20Addr = contract["ERC20"]
    local vatAddr = contract["Vat"]
    local daiJoinAddr = contract["DaiJoin"]
    local gemJoinAddr = contract["GemJoin"]

    -- invoke erc20 contract
    local accountNum = math.min(self.index.Accounts, 200)
    local randomFaucet = self.toolkit.RandInt(0, accountNum)
    local faucet = self.blockchain:GetAccount(randomFaucet)
    local fromAddr = self.blockchain:GetRandomAccount(faucet)
    local result = self.blockchain:Transfer({
            from = faucet,
            to = fromAddr,
            amount = '100000000000000000000',
            extra = "transfer",
        })
    --print("i. ERC20 mint result:" .. result.UID)
    self.blockchain:Confirm(result)

    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "ERC20", -- contract name is the contract file name under directory invoke/contract
        contract_addr = erc20Addr,
        func = "mint",
        args = {100000000},
    })
--     print("ii. ERC20 mint result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "ERC20",
        contract_addr = erc20Addr,
        func = "approve",
        args = {"0x7eC62F11970b96E2010F665B15174A47Dd3179B5", 1000},
    })
--     print("iii. ERC20 call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "GemJoin",
        contract_addr = gemJoinAddr,
        func = "join",
        args = {fromAddr, 1000},
    })
--     print("iv. GemJoin call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "Vat",
        contract_addr = vatAddr,
        func = "frob",
        args = {"0x5444535300000000000000000000000000000000000000000000000000000000", fromAddr, fromAddr, fromAddr, 100, 1},
    })
--     print("v. Vat call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "Vat",
        contract_addr = vatAddr,
        func = "hope",
        args = {"0x4c335ac75D0610D9D03926a751A0698d29782f0a"},
    })
--     print("vi. Vat call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "DaiJoin",
        contract_addr = daiJoinAddr,
        func = "exit",
        args = {fromAddr, 1},
    })
--     print("vii. DaiJoin call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "Dai",
        contract_addr = daiAddr,
        func = "approve",
        args = {"0x4c335ac75D0610D9D03926a751A0698d29782f0a", 1},
    })
--     print("viii. Dai call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "DaiJoin",
        contract_addr = daiJoinAddr,
        func = "join",
        args = {fromAddr, 1},
    })
--     print("ix. DaiJoin call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "Vat",
        contract_addr = vatAddr,
        func = "frob",
        args = {"0x5444535300000000000000000000000000000000000000000000000000000000", fromAddr, fromAddr, fromAddr, -100, -1},
    })
--     print("x. Vat call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "GemJoin",
        contract_addr = gemJoinAddr,
        func = "exit",
        args = {fromAddr, 1000},
    })
--     print("xi. GemJoin call result:" .. result.UID)
    self.blockchain:Confirm(result)

    --print("call result:" .. result.UID)
    --self.blockchain:Confirm(result)
    return result
end
return case