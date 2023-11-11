local case = testcase.new()
local contractTable = {}
local maxDeployContractNum = 1
local faucet = "a0Ee7A142d267C1f36714E4a8F75612F20a79720"
local receive = "264e23168e80f15e9311F2B88b4D7abeAba47E54"
local transferMaxValue = "1000000000000000000000000"
local transferValueEveryRun = "100000000000000000000"

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function case:BeforeRun()
    if self.index.Accounts < 2 then
        error("Accounts number must be at least 2")
    end

    for i = 1, maxDeployContractNum do
        local table = {}
        uniswapV2FactoryAddr = self.blockchain:DeployContract(faucet, "UniswapV2Factory", receive)
        if uniswapV2FactoryAddr ~= "" then
            table["UniswapV2Factory"] = uniswapV2FactoryAddr
        end
        wETH9Addr = self.blockchain:DeployContract(faucet, "WETH9")
        if wETH9Addr ~= "" then
            table["WETH9"] = wETH9Addr
        end
        uniswapV2Router02Addr = self.blockchain:DeployContract(faucet, "UniswapV2Router02", uniswapV2FactoryAddr, wETH9Addr)
        if uniswapV2Router02Addr ~= "" then
            table["UniswapV2Router02"] = uniswapV2Router02Addr
        end
        multicallForUniAddr = self.blockchain:DeployContract(faucet, "MulticallForUni")
        if multicallForUniAddr ~= "" then
            table["MultiCall"] = multicallForUniAddr
        end
        axiomL7Addr = self.blockchain:DeployContract(faucet, "AxiomOne", "AxiomL7", "L7", receive)
        if axiomL7Addr ~= "" then
            table["AxiomL7"] = axiomL7Addr
        end
        axiomL8Addr = self.blockchain:DeployContract(faucet, "AxiomOne", "AxiomL8", "L8", receive)
        if axiomL8Addr ~= "" then
            table["AxiomL8"] = axiomL8Addr
        end

        contractTable[#contractTable + 1] = table
    end

    local accountNum = math.min(self.index.Accounts, 200)
    local result
    for i=1, accountNum do
        local toAddr = self.blockchain:GetAccount(i-1)
        if toAddr ~= faucet then
            result = self.blockchain:Transfer({
                from = faucet,
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

function case:Run()
    -- get random contract
    local randomContractIndex = self.toolkit.RandInt(0, #contractTable)
    local contract = contractTable[randomContractIndex + 1] -- start index is 1
    local routerAddr = contract["UniswapV2Router02"]
    local L7Addr = contract["AxiomL7"]
    local L8Addr = contract["AxiomL8"]

    local accountNum = math.min(self.index.Accounts, 200)
    local randomFaucet = self.toolkit.RandInt(0, accountNum)
    local faucet = self.blockchain:GetAccount(randomFaucet)
    local sender = self.blockchain:GetRandomAccount(faucet)
    local result = self.blockchain:Transfer({
        from = faucet,
        to = sender,
        amount = transferValueEveryRun,
        extra = "uniswap transfer",
    })
    self.blockchain:Confirm(result)
    local amount = 1000000000000000000000     -- 1000枚代币
    local min = 0    -- 0.001 枚代币   可以设置为0
    local token1Addr = L7Addr -- erc20 合约地址
    local token2Addr = L8Addr -- erc20 合约地址
    local deadline = 1728283719 -- 截止时间，添加流动性时的入参
    local approveTokenA = self.blockchain:Invoke({
        caller = sender,
        contract = "AxiomOne",
        contract_addr = L7Addr,
        func = "approve",
        args = { routerAddr, amount }
    })
    self.blockchain:Confirm(approveTokenA)
    --print("approveTokenA:", approveTokenA.UID)
    local approveTokenB = self.blockchain:Invoke({
        caller = sender,
        contract = "AxiomOne",
        contract_addr = L8Addr,
        func = "approve",
        args = { routerAddr, amount }
    })
    self.blockchain:Confirm(approveTokenB)
    --print("approveTokenB:", approveTokenB.UID)
    random = self.toolkit.RandInt(0, 2)
    if random == 0 then
        --r=0 add addLiquidity
        local mintResult = self.blockchain:Invoke({
            caller = sender,
            contract = "AxiomOne",
            contract_addr = L7Addr,
            func = "mint",
            args = { sender, amount },
        })
        self.blockchain:Confirm(mintResult)
        --print("r=0,mintResult:", mintResult.UID)
        local mintResult2 = self.blockchain:Invoke({
            caller = sender,
            contract = "AxiomOne",
            contract_addr = L8Addr,
            func = "mint",
            args = { sender, amount * 0.5 },
        })
        self.blockchain:Confirm(mintResult2)
--         print("r=0,mintResult2:", mintResult2.UID)
        local addLiquidity = self.blockchain:Invoke({
            caller = sender,
            contract = "UniswapV2Router02",
            contract_addr = routerAddr,
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
        local choice = self.toolkit.RandInt(0, 2)
        local inputToken
        local outputToken
        if choice == 0 then
            inputToken = L7Addr
            outputToken = L8Addr
        else
            inputToken = L8Addr
            outputToken = L7Addr
        end
        local swapResult = self.blockchain:Invoke({
            caller = sender,
            contract = "UniswapV2Router02",
            contract_addr = routerAddr,
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