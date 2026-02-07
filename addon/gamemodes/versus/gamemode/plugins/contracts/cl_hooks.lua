local PLUGIN = PLUGIN

--[[
  Net Messages
--]]

net.Receive("versus.contracts.receiveContracts", function()
  local contractCount = net.ReadUInt(PLUGIN.bitCountContractAmount)
  local contracts = {}

  for i = 1, contractCount do
    local name = net.ReadString()
    local enabled = net.ReadBool()
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
