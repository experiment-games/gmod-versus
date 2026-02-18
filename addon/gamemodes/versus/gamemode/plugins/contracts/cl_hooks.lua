local PLUGIN = PLUGIN

-- We show the contract selection on spawn
function PLUGIN.hook:LocalPlayerInitialized()
  if (hook.Run("PlayerShouldSelectContract") == false) then
    return
  end

  self.contractSelectionPanel = vgui.Create("versus_ContractSelection")

  -- Load existing contracts if we already have them, which can happen if this
  -- hook runs after we've already received contracts from the server
  hook.Run("PlayerReceivedContracts", self.getLocalContracts() or {})
end

function PLUGIN.hook:PlayerSelectedContract(contract, contractID)
  if (IsValid(self.contractSelectionPanel)) then
    self.contractSelectionPanel:Remove()
    self.contractSelectionPanel = nil
  end
end

function PLUGIN.hook:PlayerReceivedContracts(contracts)
  if (IsValid(self.contractSelectionPanel)) then
    self.contractSelectionPanel:SetContracts(contracts)
  end
end

function PLUGIN.hook:PlayerContractAvailabilityUpdated(updates)
  if IsValid(self.contractSelectionPanel) and IsValid(self.contractSelectionPanel.contractsPanel) then
    self.contractSelectionPanel.contractsPanel:UpdateContractAvailability(updates)
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.contracts.closeSelectionPanel", function()
  if (IsValid(PLUGIN.contractSelectionPanel)) then
    PLUGIN.contractSelectionPanel:Remove()
    PLUGIN.contractSelectionPanel = nil
  end
end)

net.Receive("versus.contracts.receiveContracts", function()
  local contractCount = net.ReadUInt(PLUGIN.bitCountContractAmount)
  local contracts = {}

  for i = 1, contractCount do
    local id = net.ReadUInt(PLUGIN.bitCountContractID)
    local enabled = net.ReadBool()
    local unavailableReason = not enabled and net.ReadString() or nil
    local name = net.ReadString()
    local difficulty = net.ReadUInt(3)
    local reward = net.ReadUInt(3)
    local combatStyle = net.ReadUInt(3)

    -- Receive all non-hidden locations
    local locationCount = net.ReadUInt(8)
    local locations = {}

    for j = 1, locationCount do
      local key = net.ReadString()
      local entity = net.ReadEntity()
      local displayName = net.ReadString()
      local class = net.ReadString()

      locations[key] = {
        entity = entity,
        displayName = displayName,
        class = class
      }
    end

    -- Convert numeric difficulty to string for UI
    local difficultyText = "MEDIUM"
    if difficulty == PLUGIN.DIFFICULTY_EASY then
      difficultyText = "EASY"
    elseif difficulty == PLUGIN.DIFFICULTY_HARD then
      difficultyText = "HARD"
    end

    -- Convert numeric reward to string for UI
    local rewardText = "LOW"
    if reward == PLUGIN.REWARD_MEDIUM then
      rewardText = "MEDIUM"
    elseif reward == PLUGIN.REWARD_HIGH then
      rewardText = "HIGH"
    end

    -- Convert combat style to pvpMode string for UI
    local pvpModeText = "PvE"
    if combatStyle == PLUGIN.COMBAT_STYLE_PVP then
      pvpModeText = "PvP"
    elseif combatStyle == PLUGIN.COMBAT_STYLE_MIXED then
      pvpModeText = "BOTH"
    end

    contracts[id] = {
      id = id,
      name = name,
      enabled = enabled,
      unavailableReason = unavailableReason,
      locations = locations,
      difficulty = difficultyText,
      reward = rewardText,
      pvpMode = pvpModeText,
    }
  end

  PLUGIN.receiveContracts(contracts)
end)

net.Receive("versus.contracts.selectedContract", function()
  local contractID = net.ReadUInt(PLUGIN.bitCountContractID)
  local contract = PLUGIN.getLocalContract(contractID)

  hook.Run("PlayerSelectedContract", contract, contractID)
end)

net.Receive("versus.contracts.forceReselectContract", function()
  if (hook.Run("PlayerShouldSelectContract") == false) then
    return
  end

  PLUGIN.contractSelectionPanel = vgui.Create("versus_ContractSelection")
  hook.Run("PlayerReceivedContracts", PLUGIN.getLocalContracts() or {})
end)

net.Receive("versus.contracts.playerEliminated", function()
  -- Create elimination screen
  local eliminationScreen = vgui.Create("versus_EliminationScreen")

  -- Set subtitle based on who killed the player
  local subtitle = ""
  local hasAttacker = net.ReadBool()

  if hasAttacker then
    local isPlayer = net.ReadBool()

    if isPlayer then
      local attackerName = net.ReadString()
      subtitle = "Eliminated by " .. attackerName
    else
      local isNPC = net.ReadBool()

      if isNPC then
        subtitle = "Eliminated by hostile forces"
      end
    end
  end

  eliminationScreen:SetSubtitle(subtitle)
end)

net.Receive("versus.contracts.updateContractAvailability", function()
  local contractCount = net.ReadUInt(8)
  local updates = {}

  for i = 1, contractCount do
    local contractID = net.ReadUInt(PLUGIN.bitCountContractID)
    local enabled = net.ReadBool()
    local unavailableReason = not enabled and net.ReadString() or nil

    table.insert(updates, {
      id = contractID,
      enabled = enabled,
      unavailableReason = unavailableReason
    })
  end

  -- Update local contract data
  local localContracts = PLUGIN.getLocalContracts()
  if localContracts then
    for _, update in ipairs(updates) do
      if localContracts[update.id] then
        localContracts[update.id].enabled = update.enabled
        localContracts[update.id].unavailableReason = update.unavailableReason
      end
    end
  end

  -- Update UI if contract selection panel is open
  if IsValid(PLUGIN.contractSelectionPanel) then
    hook.Run("PlayerContractAvailabilityUpdated", updates)
  end
end)

concommand.Add("versus_test_fail_contract", function()
  local eliminationScreen = vgui.Create("versus_EliminationScreen")
  eliminationScreen:SetSubtitle("Elimination Screen Test")
end)
