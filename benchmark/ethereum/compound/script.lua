local case = testcase.new()
local contractTable = {}
local maxDeployContractNum = 10
local from = "dD2FD4581271e230360230F9337D5c0430Bf44C0"
local transferValueEveryRun = "400000000000000000000"

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
   if self.index.Accounts < 2 then
      print("Accounts number must be at least 2")
      return
   end

   local chainID = self.blockchain:GetChainID()
   for i = 1, maxDeployContractNum do
      local table = {}
      local uniAddr = self.blockchain:DeployContract(from, "UNI", "UNI", "UNI")
      if uniAddr ~= "" then
         table["UNI"] = uniAddr
      end
      local usdcAddr = self.blockchain:DeployContract(from, "USDC", "USDC", "USDC")
      if usdcAddr ~= "" then
         table["USDC"] = usdcAddr
      end
      local comptrollerAddr = self.blockchain:DeployBigContract(from, "Comptroller", 10000000, from)
      if comptrollerAddr ~= "" then
         table["Comptroller"] = comptrollerAddr
      end
      local simplePriceOracleAddr = self.blockchain:DeployContract(from, "SimplePriceOracle")
      if simplePriceOracleAddr ~= "" then
         table["SimplePriceOracle"] = simplePriceOracleAddr
      end
      -- JumpRateModelV2
      local jumpRateModelV2SAddr = self.blockchain:DeployContract(from, "JumpRateModelV2", "20000000000000000","180000000000000000","4000000000000000000","800000000000000000", from)
      if jumpRateModelV2SAddr ~= "" then
         table["JumpRateModelV2"] = jumpRateModelV2SAddr
      end
      -- LegacyJumpRateModelV2
      local legacyJumpRateModelV2Addr = self.blockchain:DeployContract(from, "LegacyJumpRateModelV2","0","40000000000000000","1090000000000000000","800000000000000000", from)
      if legacyJumpRateModelV2Addr ~= "" then
         table["LegacyJumpRateModelV2"] = legacyJumpRateModelV2Addr
      end
      local cUNIAddr = self.blockchain:DeployBigContract(from, "CUNI", 10000000, uniAddr, comptrollerAddr, jumpRateModelV2SAddr, "200000000000000000000000000", "cUNI", "cUNI", "8", from)
      if cUNIAddr ~= "" then
         table["CUNI"] = cUNIAddr
      end
      local cUSDCAddr = self.blockchain:DeployBigContract(from, "CUSDC", 10000000, usdcAddr, comptrollerAddr, legacyJumpRateModelV2Addr, "200000000000000", "cUSDC", "cUSDC", "8", from)
      if cUSDCAddr ~= "" then
         table["CUSDC"] = cUSDCAddr
      end

      -- initialize contract
      self.blockchain:Invoke({
         caller = from,
         contract = "Comptroller",
         contract_addr = comptrollerAddr,
         func = "_setPriceOracle",
         args = {simplePriceOracleAddr},
      })
      self.blockchain:Invoke({
         caller = from,
         contract = "Comptroller",
         contract_addr = comptrollerAddr,
         func = "_supportMarket",
         args = {cUNIAddr},
      })
      self.blockchain:Invoke({
         caller = from,
         contract = "Comptroller",
         contract_addr = comptrollerAddr,
         func = "_supportMarket",
         args = {cUSDCAddr},
      })
      self.blockchain:Invoke({
         caller = from,
         contract = "SimplePriceOracle",
         contract_addr = simplePriceOracleAddr,
         func = "setUnderlyingPrice",
         args = {cUNIAddr, "25022748000000000000"},
      })
      self.blockchain:Invoke({
         caller = from,
         contract = "SimplePriceOracle",
         contract_addr = simplePriceOracleAddr,
         func = "setUnderlyingPrice",
         args = {cUSDCAddr, "35721743800000000000000"},
      })
      self.blockchain:Invoke({
         caller = from,
         contract = "Comptroller",
         contract_addr = comptrollerAddr,
         func = "_setCollateralFactor",
         args = {cUNIAddr, "800000000000000000"},
      })
      self.blockchain:Invoke({
         caller = from,
         contract = "Comptroller",
         contract_addr = comptrollerAddr,
         func = "_setCollateralFactor",
         args = {cUSDCAddr, "600000000000000000"},
      })

      contractTable[#contractTable + 1] = table
   end

end

-- Attention: this is called in local worker vm
-- Run more time called by lua vm, this is controled by config
function case:Run()
   -- get random contract
   local randomContractIndex = self.toolkit.RandInt(0, #contractTable)
   local contract = contractTable[randomContractIndex + 1]
   local fromAddr = self.blockchain:GetRandomAccount(from)
   print("from addr:" .. fromAddr)

   -- transfer token
   local result = self.blockchain:Transfer({
           from = from,
           to = fromAddr,
           amount = transferValueEveryRun,
           extra = "transfer",
       })
   --print("i. ERC20 mint result:" .. result.UID)
   self.blockchain:Confirm(result)

   local uniMint=10000000
   local usdcMint=100000000
   local cUNIAddr = contract["CUNI"]
   local cUSDCAddr = contract["CUSDC"]
   local comptrollerAddr = contract["Comptroller"]
   local uniAddr = contract["UNI"]
   local usdcAddr = contract["USDC"]

   self.blockchain:Invoke({
    caller = fromAddr,
    contract = "UNI",
    contract_addr = uniAddr,
    func = "mint",
    args = {fromAddr, uniMint},
   })

   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "UNI",
      contract_addr = uniAddr,
      func = "approve",
      args = {cUNIAddr, uniMint},
   })

   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "USDC",
      contract_addr = usdcAddr,
      func = "mint",
      args = {fromAddr, usdcMint},
   })

   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "USDC",
      contract_addr = usdcAddr,
      func = "approve",
      args = {cUSDCAddr, usdcMint},
   })
   
   self.blockchain:Invoke({
    caller = fromAddr,
    contract = "Comptroller",
    contract_addr = comptrollerAddr,
    func = "enterOneMarkets",
    args = {cUSDCAddr},
   })
   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "Comptroller",
      contract_addr = comptrollerAddr,
      func = "enterOneMarkets",
      args = {cUNIAddr},
   })

   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "CUNI",
      contract_addr = cUNIAddr,
      func = "mint",
      args = {uniMint},
   })

   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "CUSDC",
      contract_addr = cUSDCAddr,
      func = "mint",
      args = {usdcMint},
   })

   local uniMint=10000000
   local mintNum=100000

   -- self.blockchain:Invoke({
   --    caller = fromAddr,
   --    contract = "Comptroller",
   --    contract_addr = comptrollerAddr,
   --    func = "enterOneMarkets",
   --    args = {cUSDCAddr},
   -- })

   -- self.blockchain:Invoke({
   --    caller = fromAddr,
   --    contract = "Comptroller",
   --    contract_addr = comptrollerAddr,
   --    func = "enterOneMarkets",
   --    args = {cUNIAddr},
   -- })

   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "UNI",
      contract_addr = uniAddr,
      func = "mint",
      args = {fromAddr, uniMint},
   })


   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "UNI",
      contract_addr = uniAddr,
      func = "approve",
      args = {cUNIAddr, mintNum},
   })

   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "CUNI",
      contract_addr = cUNIAddr,
      func = "mint",
      args = {mintNum},
   })

   borrowNum=self.toolkit.RandInt(100, 1000)
   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "CUNI",
      contract_addr = cUNIAddr,
      func = "borrow",
      args = {borrowNum},
   })


   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "UNI",
      contract_addr = uniAddr,
      func = "approve",
      args = {cUNIAddr,borrowNum},
   })

   self.blockchain:Invoke({
      caller = fromAddr,
      contract = "CUNI",
      contract_addr = cUNIAddr,
      func = "repayBorrow",
      args = {borrowNum},
   })

end
return case
