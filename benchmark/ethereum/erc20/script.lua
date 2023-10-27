local case = testcase.new()

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function case:BeforeRun()
    --print("accounts num:" .. self.index.Accounts)
    local from = "9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
    if self.index.Accounts < 2 then
        print("Accounts number must be at least 2")
        return
    end
    local accountNum = math.min(self.index.Accounts, 200)
--     print("accounts num:" .. accountNum)
    local result
    for i=1, accountNum do
        local toAddr = self.blockchain:GetAccount(i-1)
        if toAddr ~= from then
            result = self.blockchain:Transfer({
                from = from,
                to = toAddr,
                amount = '1000000000000000000000000',
                extra = "11",
            })
            sleep(0.1)
        end
    end

    -- wait token confirm
    self.blockchain:Confirm(result)

    -- mint erc20
    for i=1, accountNum do
        local fromAddr = self.blockchain:GetAccount(i-1)
        result = self.blockchain:Invoke({
            caller = fromAddr,
            contract = "ERC20", -- contract name is the contract file name under directory invoke/contract
            func = "mint",
            args = {10000000000},
        })
        sleep(0.1)
    end

    -- wait token confirm
    self.blockchain:Confirm(result)

    -- set contract address
    --self.blockchain:SetContext('{"contract_name": "ERC20", "contract_addr": "0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E"}')
end

function case:Run()
    -- invoke erc20 contract
    local accountNum = math.min(self.index.Accounts, 200)
    local randomFaucet = self.toolkit.RandInt(0, accountNum)
    local fromAddr = self.blockchain:GetAccount(randomFaucet)
    local toAddr = self.blockchain:GetRandomAccount(fromAddr)
    --print("to addr:" .. toAddr)
    local random = self.toolkit.RandInt(0, 2)
    local value = self.toolkit.RandInt(1, 100)
    local result
    if random == 0 then
        result = self.blockchain:Invoke({
            caller = fromAddr,
            contract = "ERC20",
            func = "transfer",
            args = {toAddr, value},
        })
    else
        -- make sure that randomFaucet is not equal to randomFaucet2
        randomFaucet2 = (randomFaucet + self.toolkit.RandInt(1, accountNum+1)) % accountNum
        fromAddr2 = self.blockchain:GetAccount(randomFaucet2)
        result = self.blockchain:Invoke({
            caller = fromAddr,
            contract = "ERC20",
            func = "approve",
            args = {fromAddr2, value},
        })
        result = self.blockchain:Invoke({
            caller = fromAddr2,
            contract = "ERC20",
            func = "transferFrom",
            args = {fromAddr, toAddr, value},
        })
    end

    --print("call result:" .. result.UID)
    --self.blockchain:Confirm(result)
    return result
end
return case