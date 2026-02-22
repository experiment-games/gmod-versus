local PLUGIN = PLUGIN

PLUGIN.campPositions = PLUGIN.campPositions or {}

--[[
  Hooks
--]]

function PLUGIN.hook:ContractSelectionPanelPaint(selectionPanel, w, h, mx, my, mapOverview)
  local iconSize = 8

  for _, campPos in ipairs(PLUGIN.campPositions) do
    local panelX, panelY = mapOverview:WorldToPanel(campPos)
    local screenX = mx + panelX
    local screenY = my + panelY

    draw.NoTexture()
    surface.SetDrawColor(255, 100, 100, 50)
    GAMEMODE:DrawCircle(screenX, screenY, iconSize * .25)

    GAMEMODE:DrawOutlinedCircle(screenX, screenY, iconSize / 2 + 2, 2)
  end
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
end)
