local case = testcase.new()
local contractTable = {}
local from = "71bE63f3384f5fb98995898A86B02Fb2426c5788"
local transferValueEveryRun = "100000000000000000000"

-- Attention: this is called in master vm
-- DeployContract only called once before run lua vm
function case:DeployContract()
end

-- Attention: this is called in local worker vm
-- BeforeRun called only once for every lua vm, all lua vm need to call the function before runing
function case:BeforeRun()
end

-- Attention: this is called in local worker vm
-- Run more time called by lua vm, this is controled by config
function case:Run()
    if self.index.Accounts < 2 then
        print("Accounts number must be at least 2")
        return
    end

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

    local chainID = self.blockchain:GetChainID()
    daiAddr, err = self.blockchain:DeployContract(fromAddr, "dai", chainID)
    if daiAddr == "" then
        print("deploy dai contract failed:" .. err)
    end
    self.blockchain:Confirm({["uid"] = daiAddr})

    usdcAddr, err = self.blockchain:DeployContract(fromAddr, "usdc")
    if usdcAddr == "" then
        print("deploy usdc contract failed:" .. err)
    end
    self.blockchain:Confirm({["uid"] = usdcAddr})

    usdtAddr, err = self.blockchain:DeployContract(fromAddr, "usdt")
    if usdtAddr == "" then
        print("deploy usdt contract failed:" .. err)
    end
    self.blockchain:Confirm({["uid"] = usdtAddr})

    crvAddr, err = self.blockchain:DeployContract(fromAddr, "3crv", "3crv", "CRV", "18", "10000000000000000")
    if crvAddr == "" then
        print("deploy 3crv contract failed:" .. err)
    end
    self.blockchain:Confirm({["uid"] = crvAddr})

    poolAddr, err = self.blockchain:DeployContract(fromAddr, "3pool", fromAddr, {daiAddr, usdcAddr, usdtAddr}, crvAddr, "10", "10", "10")
    if poolAddr == "" then
        print("deploy 3pool contract failed:" .. err)
    end
    self.blockchain:Confirm({["uid"] = poolAddr})

    -- liquidity for coin1, coin2 and coin3
    local amount1 = self.toolkit.RandInt(1, 100)
    local amount2 = self.toolkit.RandInt(1, 100)
    local amount3 = self.toolkit.RandInt(1, 100)
    -- lp token amount for mint and burn
    local lpTokenAmount = self.toolkit.RandInt(1, 100)
    -- add liquidity for 3 coins
    res = self.blockchain:Invoke({
        caller = fromAddr,
        contract = "3pool",
        func = "add_liquidity",
        args = {
            amount1, amount2, amount3, lpTokenAmount
        },
    })
    self.blockchain:Confirm(res)
    -- calculate amount of burn lp token before remove liquidity
    res = self.blockchain.Invoke({
        caller = fromAddr,
        contract = "3pool",
        func = "calc_token_amount",
        args = {
            amount1, amount2, amount3, false,
        },
    })
    self.blockchain:Confirm(res)
    -- remove liquidity for 3 coins
    res=self.blockchain.Invoke({
        caller = fromAddr,
        contract = "3pool",
        func = "remove_liquidity",
        args = {
            lpTokenAmount, amount1, amount2, amount3
        },
    })
    self.blockchain:Confirm(res)
    return res
end
return case