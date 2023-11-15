local case = testcase.new()
local contractTable = {}
local maxDeployContractNum = 1
local from = "70997970C51812dc3A010C7d01b50e0d17dc79C8"
local transferValueEveryRun = "41000000000000000000"

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
        self.blockchain:Confirm({["uid"] = daiAddr})
        erc20Addr = self.blockchain:DeployContract(from, "ERC20", from, "1000000000000000000000")
        if erc20Addr ~= "" then
            table["ERC20"] = erc20Addr
        end
        self.blockchain:Confirm({["uid"] = erc20Addr})
        vatAddr = self.blockchain:DeployContract(from, "Vat", from)
        if vatAddr ~= "" then
            table["Vat"] = vatAddr
        end
        self.blockchain:Confirm({["uid"] = vatAddr})
        daiJoinAddr = self.blockchain:DeployContract(from, "DaiJoin", from, vatAddr, daiAddr)
        if daiJoinAddr ~= "" then
            table["DaiJoin"] = daiJoinAddr
        end
        self.blockchain:Confirm({["uid"] = daiJoinAddr})
        gemJoinAddr = self.blockchain:DeployContract(from, "GemJoin", from, vatAddr, "0x5444535300000000000000000000000000000000000000000000000000000000", erc20Addr)
        if gemJoinAddr ~= "" then
            table["GemJoin"] = gemJoinAddr
        end
        self.blockchain:Confirm({["uid"] = gemJoinAddr})


        result = self.blockchain:Invoke({
            caller = from,
            contract = "Dai", -- contract name is the contract file name under directory invoke/contract
            contract_addr = daiAddr,
            func = "rely",
            args = {daiJoinAddr},
        })
        self.blockchain:Confirm(result)
        result = self.blockchain:Invoke({
            caller = from,
            contract = "Vat", -- contract name is the contract file name under directory invoke/contract
            contract_addr = vatAddr,
            func = "init",
            args = {"0x5444535300000000000000000000000000000000000000000000000000000000"},
        })
        self.blockchain:Confirm(result)
        result = self.blockchain:Invoke({
            caller = from,
            contract = "Vat", -- contract name is the contract file name under directory invoke/contract
            contract_addr = vatAddr,
            func = "file1",
            args = {"0x4c696e6500000000000000000000000000000000000000000000000000000000", "100000000000000000000000000000000000000000000000000000000000000"},
        })
        self.blockchain:Confirm(result)
        result = self.blockchain:Invoke({
            caller = from,
            contract = "Vat", -- contract name is the contract file name under directory invoke/contract
            contract_addr = vatAddr,
            func = "file",
            args = {"0x5444535300000000000000000000000000000000000000000000000000000000", "0x6c696e6500000000000000000000000000000000000000000000000000000000", "100000000000000000000000000000000000000000000000000000000000000"},
        })
        self.blockchain:Confirm(result)
        result = self.blockchain:Invoke({
            caller = from,
            contract = "Vat", -- contract name is the contract file name under directory invoke/contract
            contract_addr = vatAddr,
            func = "file",
            args = {"0x5444535300000000000000000000000000000000000000000000000000000000", "0x73706f7400000000000000000000000000000000000000000000000000000000", "100000000000000000000000000000000000000000000000000000000000000"},
        })
        self.blockchain:Confirm(result)
        result = self.blockchain:Invoke({
            caller = from,
            contract = "Vat", -- contract name is the contract file name under directory invoke/contract
            contract_addr = vatAddr,
            func = "rely",
            args = {gemJoinAddr},
        })
        self.blockchain:Confirm(result)
        result = self.blockchain:Invoke({
            caller = from,
            contract = "Vat", -- contract name is the contract file name under directory invoke/contract
            contract_addr = vatAddr,
            func = "rely",
            args = {daiJoinAddr},
        })
        self.blockchain:Confirm(result)
        contractTable[#contractTable + 1] = table
    end
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

    -- transfer token
    local fromAddr = self.blockchain:GetRandomAccount(from)
    local result = self.blockchain:Transfer({
            from = from,
            to = fromAddr,
            amount = transferValueEveryRun,
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
        args = {gemJoinAddr, 1000},
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
        args = {daiJoinAddr},
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
        args = {daiJoinAddr, 1},
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