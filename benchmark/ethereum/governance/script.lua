local case = testcase.new()
local councilManagerContractAddr = "0x0000000000000000000000000000000000001002"
local outOfDateBlockNumber = 1
local proposalID = 1

local councilElect = 0
local pass = 0
local reject = 1

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
end

-- Attention: this is called in local worker vm
-- Run more time called by lua vm, this is controled by config
function case:Run()
    local randomFaucet = self.toolkit.RandInt(0, self.index.Accounts)
    local fromAddr = self.blockchain:GetAccount(randomFaucet)

    local blockNumber = self.blockchain:LatestBlockNumber()
    print("block number" .. blockNumber)

    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "governance",
        contract_addr = councilManagerContractAddr,
        func = "propose",
        args = {"=uint8=" .. councilElect, "test title", "test desc", "=uint64=" .. (blockNumber+outOfDateBlockNumber), {Candidates = {{Address = "0xc7F999b83Af6DF9e67d0a37Ee7e900bF38b3D013" , Weight = 100, Name = "test1"}, {Address = "0x79a1215469FaB6f9c63c1816b45183AD3624bE34" , Weight = 100, Name = "test2"}, {Address = "0x97c8B516D19edBf575D72a172Af7F418BE498C37" , Weight = 100, Name = "test3"}, {Address = "0xc0Ff2e0b3189132D815b8eb325bE17285AC898f8" , Weight = 100, Name = "test4"}}}},
    })
   
    local anotherAddr = self.blockchain:GetRandomAccount(fromAddr)
    result = self.blockchain:Invoke({
        caller = anotherAddr,
        contract = "governance",
        contract_addr = councilManagerContractAddr,
        func = "vote",
        args = {"=uint64=" .. proposalID, "=uint8=" .. pass, "=bytes="},
    })

    local anotherAddr2 = self.blockchain:GetRandomAccount(anotherAddr)
    result = self.blockchain:Invoke({
        caller = anotherAddr2,
        contract = "governance",
        contract_addr = councilManagerContractAddr,
        func = "vote",
        args = {"=uint64=" .. proposalID, "=uint8=" .. reject, "=bytes="},
    })

    proposalID = proposalID + 1

    --print("call result:" .. result.UID)
    --self.blockchain:Confirm(result)
    return result
end
return case