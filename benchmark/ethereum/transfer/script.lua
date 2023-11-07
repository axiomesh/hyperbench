local case = testcase.new()

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function case:BeforeRun()
    --print("accounts num:" .. self.index.Accounts)
    local from = "f39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    if self.index.Accounts < 2 then
        print("Accounts number must be at least 2")
        return
    end
    local accountNum = math.min(self.index.Accounts, 200)
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
end

function case:Run()
    --print("----start lua vm-----")
    local accountNum = math.min(self.index.Accounts, 200)
    randomFaucet = self.toolkit.RandInt(0, accountNum)
    fromAddr = self.blockchain:GetAccount(randomFaucet)
    toAddr = self.blockchain:GetRandomAccount(fromAddr)
    --print("from addr:" .. fromAddr .. "to addr:" .. toAddr)
    local ret = self.blockchain:Transfer({
        from = fromAddr, --"14dC79964da2C08b23698B3D3cc7Ca32193d9955",
        to = toAddr, --"90f79bf6eb2c4f870365e785982e1f101e93b906",
        amount = '1000000000000000000',
        extra = "11",
    })
    --print(ret)
    return ret
end

return case
