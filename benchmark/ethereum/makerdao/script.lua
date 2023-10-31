local case = testcase.new()

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function case:BeforeRun()
    self.blockchain:SetContext('{"contract_name": "Vat", "contract_addr": "0xac9766576143a129fe779d6d43971E3236F9B747"}')
    self.blockchain:SetContext('{"contract_name": "ERC20", "contract_addr": "0x14d493c0b0213a8Cf33186b6C535152cECb3a17b"}')
    self.blockchain:SetContext('{"contract_name": "Dai", "contract_addr": "0x847C5302e34997c11fc3C2d4b1dbDcaA83577E8f"}')
    self.blockchain:SetContext('{"contract_name": "DaiJoin", "contract_addr": "0x1B5D2dB0A94968a07d69590165D58BeFB511a4f3"}')
    self.blockchain:SetContext('{"contract_name": "GemJoin", "contract_addr": "0x6F6BB85b8aaAccC27d11492bEb21817DA49D5642"}')
    
    -- transfer token
    local accountNum = self.index.Accounts
    --print("accounts num:" .. self.index.Accounts)
    local from = "70997970C51812dc3A010C7d01b50e0d17dc79C8"
    local result
    for i=1,accountNum do
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
end

function case:Run()
    -- invoke erc20 contract
    local fromAddr = self.blockchain:GetRandomAccountByGroup()
    local toAddr = self.blockchain:GetRandomAccount(fromAddr)
    --print("from addr:" .. fromAddr)
    local result

    --print("First Call")
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "ERC20",
        func = "approve",
        args = {"0x7eC62F11970b96E2010F665B15174A47Dd3179B5", 1000},
    })
    --print("ERC20 call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "GemJoin",
        func = "join",
        args = {fromAddr, 1000},
    })
    --print("GemJoin call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "Vat",
        func = "frob",
        args = {"0x5444535300000000000000000000000000000000000000000000000000000000", fromAddr, fromAddr, fromAddr, 100, 1},
    })
    --print("Vat call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "Vat",
        func = "hope",
        args = {"0x4c335ac75D0610D9D03926a751A0698d29782f0a"},
    })
    --print("Vat call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "DaiJoin",
        func = "exit",
        args = {fromAddr, 1},
    })
    --print("DaiJoin call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "Dai",
        func = "approve",
        args = {"0x4c335ac75D0610D9D03926a751A0698d29782f0a", 1},
    })
    --print("Dai call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "DaiJoin",
        func = "join",
        args = {fromAddr, 1},
    })
    --print("DaiJoin call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "Vat",
        func = "frob",
        args = {"0x5444535300000000000000000000000000000000000000000000000000000000", fromAddr, fromAddr, fromAddr, -100, -1},
    })
    --print("Vat call result:" .. result.UID)
    self.blockchain:Confirm(result)
    result = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "GemJoin",
        func = "exit",
        args = {fromAddr, 1000},
    })
    --print("GemJoin call result:" .. result.UID)
    self.blockchain:Confirm(result)

    --print("call result:" .. result.UID)
    --self.blockchain:Confirm(result)
    return result
end
return case