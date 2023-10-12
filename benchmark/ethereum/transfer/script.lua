local case = testcase.new()

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function case:BeforeRun()
    -- transfer token
    local accountNum = self.index.Accounts
    --print("accounts num:" .. self.index.Accounts)
    local from = "f39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    local result
    for i=1,accountNum do
        local toAddr = self.blockchain:GetAccount(i-1)
        if toAddr ~= from then
            result = self.blockchain:Transfer({
                from = from,
                to = toAddr,
                amount = 100,
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
    fromAddr = self.blockchain:GetRandomAccountByGroup()
    toAddr = self.blockchain:GetRandomAccount(fromAddr)
    --print("from addr:" .. fromAddr .. "to addr:" .. toAddr)
    value = self.toolkit.RandInt(1, 100)
    local ret = self.blockchain:Transfer({
        from = fromAddr, --"14dC79964da2C08b23698B3D3cc7Ca32193d9955",
        to = toAddr, --"90f79bf6eb2c4f870365e785982e1f101e93b906",
        amount = value * 0.01,
        extra = "11",
    })
    --print(ret)
    return ret
end

return case
