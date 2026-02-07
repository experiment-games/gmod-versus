local PLUGIN = PLUGIN

-- We show the contract selection on spawn
function PLUGIN.hook:LocalPlayerInitialized()
  PLUGIN.contractSelectionPanel = vgui.Create("versus_ContractSelection")

  -- Load existing contracts if we already have them, which can happen if this
  -- hook runs after we've already received contracts from the server
  hook.Run("PlayerReceivedContracts", self:getLocalContracts())
end

--[[
  Net Messages
--]]

net.Receive("versus.contracts.receiveContracts", function()
  local contractCount = net.ReadUInt(PLUGIN.bitCountContractAmount)
  local contracts = {}

  for i = 1, contractCount do
    local enabled = net.ReadBool()
    local name = net.ReadString()
    local contractType = net.ReadString()
    local extractionPoint = net.ReadEntity()
    local spawnPoint = net.ReadEntity()
    local difficulty = net.ReadString()
    local reward = net.ReadString()
    local pvpMode = net.ReadString()

    table.insert(contracts, {
      name = name,
      enabled = enabled,
      type = contractType,
      extractionPoint = extractionPoint,
      spawnPoint = spawnPoint,
      difficulty = difficulty,
      reward = reward,
      pvpMode = pvpMode,
    })
  end

  PLUGIN:receiveContracts(contracts)
end)
