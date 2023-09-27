local case = testcase.new()

function case:BeforeRun()
    -- set contract addresses
    self.blockchain.SetContext('{"contract_name": "3pool", "contract_addr": "0x34737E9A2606B34707e4E66a1ccFfb3aDB759f58"}')
end

function case:Run()
    -- invoke erc20 contract to approve
    local fromAddr = self.blockchain:GetAccount(0)
    local amount1 = self.toolkit.RandInt(1, 100)
    local amount2 = self.toolkit.RandInt(1, 100)
    local amount3 = self.toolkit.RandInt(1, 100)
    local lpToken = self.toolkit.RandInt(1, 100)
    -- add liquidity for 3 coins
    self.blockchain:Invoke({
        caller = fromAddr,
        contract = "3pool",
        func = "add_liquidity",
        args = {
            amount1, amount2, amount3, lpToken
        },
    })
    -- calculate amount of burn lp token before remove liquidity
    tokenAmount = self.blockchain.Invoke({
        caller = fromAddr,
        contract = "3pool",
        func = "calc_token_amount",
        args = {
            amount1, amount2, amount3, false,
        },
    })
    -- remove liquidity for 3 coins
    self.blockchain.Invoke({
        caller = fromAddr,
        contract = "3pool",
        func = "remove_liquidity",
        args = {
            lpToken, amount1, amount2, amount3
        },
    })
    return 0
end
return case