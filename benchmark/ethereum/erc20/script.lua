local case = testcase.new()

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function case:BeforeRun()
    -- transfer token
    local accountNum = self.index.Accounts
    --print("accounts num:" .. self.index.Accounts)
    local from = "9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
    local result
    for i=1,accountNum do
        local toAddr = self.blockchain:GetAccount(i-1)
        if toAddr ~= from then
            result = self.blockchain:Transfer({
                from = from,
                to = toAddr,
                amount = 80,
                extra = "11",
            })
            sleep(0.1)
        end
    end

    -- wait token confirm
    self.blockchain:Confirm(result)

    -- mint erc20
    for i=1,accountNum do
        local fromAddr = self.blockchain:GetAccount(i-1)
        result = self.blockchain:Invoke({
            caller = fromAddr,
            contract = "ERC20", -- contract name is the contract file name under directory invoke/contract
            func = "mint",
            args = {100000000},
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
    local fromAddr = self.blockchain:GetRandomAccountByGroup()
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
        result = self.blockchain:Invoke({
            caller = fromAddr,
            contract = "ERC20",
            func = "approve",
            args = {toAddr, value},
        })

        recvAddr = self.blockchain:GetRandomAccount(fromAddr)
        result = self.blockchain:Invoke({
            caller = toAddr,
            contract = "ERC20",
            func = "transferFrom",
            args = {fromAddr, recvAddr, value},
        })
    end

    --print("call result:" .. result.UID)
    --self.blockchain:Confirm(result)
    return result
end
return case