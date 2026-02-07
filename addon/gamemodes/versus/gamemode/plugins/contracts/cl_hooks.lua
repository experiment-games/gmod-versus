local PLUGIN = PLUGIN

-- We show the contract selection on spawn
function PLUGIN.hook:LocalPlayerInitialized()
  PLUGIN.contractSelectionPanel = vgui.Create("versus_ContractSelection")

  -- Load existing contracts if we already have them, which can happen if this
  -- hook runs after we've already received contracts from the server
  hook.Run("PlayerReceivedContracts", self:getLocalContracts() or {})
end

function PLUGIN.hook:PlayerSelectedContract(contract, contractID)
  if (IsValid(PLUGIN.contractSelectionPanel)) then
    PLUGIN.contractSelectionPanel:Remove()
    PLUGIN.contractSelectionPanel = nil
  end
end

function PLUGIN.hook:PlayerReceivedContracts(contracts)
  if (IsValid(PLUGIN.contractSelectionPanel)) then
    PLUGIN.contractSelectionPanel:SetContracts(contracts)
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.contracts.receiveContracts", function()
  local contractCount = net.ReadUInt(PLUGIN.bitCountContractAmount)
  local contracts = {}

  for i = 1, contractCount do
    local id = net.ReadUInt(PLUGIN.bitCountContractID)
    local enabled = net.ReadBool()
    local unavailableReason = not enabled and net.ReadString() or nil
    local name = net.ReadString()
    local contractType = net.ReadString()
    local extractionPoint = net.ReadEntity()
    local spawnPoint = net.ReadEntity()
    local difficulty = net.ReadString()
    local reward = net.ReadString()
    local pvpMode = net.ReadString()

    contracts[id] = {
      id = id,
      name = name,
      enabled = enabled,
      unavailableReason = unavailableReason,
      type = contractType,
      extractionPoint = extractionPoint,
      spawnPoint = spawnPoint,
      difficulty = difficulty,
      reward = reward,
      pvpMode = pvpMode,
    }
  end

  PLUGIN:receiveContracts(contracts)
end)

net.Receive("versus.contracts.selectedContract", function()
  local contractID = net.ReadUInt(PLUGIN.bitCountContractID)
  local contract = PLUGIN:getLocalContract(contractID)

  hook.Run("PlayerSelectedContract", contract, contractID)
end)

net.Receive("versus.contracts.forceReselectContract", function()
  PLUGIN.contractSelectionPanel = vgui.Create("versus_ContractSelection")
  hook.Run("PlayerReceivedContracts", PLUGIN:getLocalContracts() or {})
end)
