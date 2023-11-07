local case = testcase.new()

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function case:BeforeRun()
    self.blockchain:SetContext('{"contract_name": "UniswapV2Router02", "contract_addr": "0x0cA404feA82e87eC4e0A1c3E6F558124b327fE1c"}')
    local faucet = "a0Ee7A142d267C1f36714E4a8F75612F20a79720"
    if self.index.Accounts < 2 then
        error("Accounts number must be at least 2")
    end
    local accountNum = math.min(self.index.Accounts, 200)
    local result
    for i=1, accountNum do
        local toAddr = self.blockchain:GetAccount(i-1)
        if toAddr ~= faucet then
            result = self.blockchain:Transfer({
                from = faucet,
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
    routerAddr = "0x0cA404feA82e87eC4e0A1c3E6F558124b327fE1c" -- 路由合约地址
    local accountNum = math.min(self.index.Accounts, 200)
    randomFaucet = self.toolkit.RandInt(0, accountNum)
    faucet = self.blockchain:GetAccount(randomFaucet)
    sender = self.blockchain:GetRandomAccount(faucet)
    result = self.blockchain:Transfer({
        from = faucet,
        to = sender,
        amount = '100000000000000000000',
        extra = "uniswap transfer",
    })
    self.blockchain:Confirm(result)
    amount = 1000000000000000000000     -- 1000枚代币
    min = 0    -- 0.001 枚代币   可以设置为0
    token1Addr = "0x6fD2623860Fa1986bb7DA35Dcb9fAcD692B22758" -- erc20 合约地址
    token2Addr = "0x4a3aFbdad0b43CDA2Af599583347e06ABBb65Da7" -- erc20 合约地址
    deadline = 1728283719 -- 截止时间，添加流动性时的入参
    self.blockchain:SetContext('{"contract_name": "AxiomOne", "contract_addr": "0x6fD2623860Fa1986bb7DA35Dcb9fAcD692B22758"}')
    local approveTokenA = self.blockchain:Invoke({
        caller = sender,
        contract = "AxiomOne",
        func = "approve",
        args = { routerAddr, amount }
    })
    self.blockchain:Confirm(approveTokenA)
    --print("approveTokenA:", approveTokenA.UID)
    self.blockchain:SetContext('{"contract_name": "AxiomOne", "contract_addr": "0x4a3aFbdad0b43CDA2Af599583347e06ABBb65Da7"}')
    local approveTokenB = self.blockchain:Invoke({
        caller = sender,
        contract = "AxiomOne",
        func = "approve",
        args = { routerAddr, amount }
    })
    self.blockchain:Confirm(approveTokenB)
    --print("approveTokenB:", approveTokenB.UID)
    random = self.toolkit.RandInt(0, 2)
    if random == 0 then
        --r=0 add addLiquidity
        self.blockchain:SetContext('{"contract_name": "AxiomOne", "contract_addr": "0x6fD2623860Fa1986bb7DA35Dcb9fAcD692B22758"}')
        local mintResult = self.blockchain:Invoke({
            caller = sender,
            contract = "AxiomOne",
            func = "mint",
            args = { sender, amount },
        })
        self.blockchain:Confirm(mintResult)
        --print("r=0,mintResult:", mintResult.UID)
        self.blockchain:SetContext('{"contract_name": "AxiomOne", "contract_addr": "0x4a3aFbdad0b43CDA2Af599583347e06ABBb65Da7"}')
        local mintResult2 = self.blockchain:Invoke({
            caller = sender,
            contract = "AxiomOne",
            func = "mint",
            args = { sender, amount * 0.5 },
        })
        self.blockchain:Confirm(mintResult2)
--         print("r=0,mintResult2:", mintResult2.UID)
        local addLiquidity = self.blockchain:Invoke({
            caller = sender,
            contract = "UniswapV2Router02",
            func = "addLiquidity",
            args = {
                token1Addr,
                token2Addr,
                amount * 0.8,
                amount * 0.4,
                min,
                min,
                sender,
                deadline,
            },
        })
        self.blockchain:Confirm(addLiquidity)
--         print("r=0,addLiquidity: ", addLiquidity.UID)
    else
        --r=1 swap token
        choice = self.toolkit.RandInt(0, 2)
        if choice == 0 then
            inputToken = token1Addr
            outputToken = token2Addr
        else
            inputToken = token2Addr
            outputToken = token1Addr
        end
        local swapResult = self.blockchain:Invoke({
            caller = sender,
            contract = "UniswapV2Router02",
            func = "swapExactTokensForTokensSupportingFeeOnTransferTokens",
            args = {
                amount * 0.005,
                min,
                { inputToken, outputToken },
                sender,
                deadline,
            },
        })
        self.blockchain:Confirm(swapResult)
--         print("r=1,swap: ", swapResult.UID)
    end
end
return case