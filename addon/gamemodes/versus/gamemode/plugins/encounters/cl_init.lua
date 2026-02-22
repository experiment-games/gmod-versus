local PLUGIN = PLUGIN

PLUGIN.campPositions = PLUGIN.campPositions or {}

--[[
  Hooks
--]]

function PLUGIN.hook:ContractSelectionPanelInitialized(selectionPanel)
  if not selectionPanel.mapOverview then
    return
  end

  -- Store the panel reference so Paint can draw on it
  selectionPanel._encounterCampPositions = PLUGIN.campPositions
end

--[[
  Net Messages
--]]

net.Receive("versus.encounters.sendCampPositions", function()
  local count = net.ReadUInt(8)
  local positions = {}

  for i = 1, count do
    positions[i] = net.ReadVector()
  end

  PLUGIN.campPositions = positions

  -- Update any open contract selection panel immediately
  local selectionPanel = versus.contracts.contractSelectionPanel
  if IsValid(selectionPanel) then
    selectionPanel._encounterCampPositions = PLUGIN.campPositions
  end
end)
