local PLUGIN = PLUGIN

PLUGIN._cachedData = PLUGIN._cachedData or {}

net.Receive("versus.smuggler.syncData", function()
  PLUGIN._cachedData = net.ReadTable()
  PLUGIN._cachedData._receivedAt = RealTime()

  if (IsValid(PLUGIN._mapPanel)) then
    PLUGIN._mapPanel:Refresh()
  end
end)

net.Receive("versus.smuggler.openMapUI", function()
  if (IsValid(PLUGIN._mapPanel)) then
    PLUGIN._mapPanel:Remove()
  end

  surface.PlaySound("buttons/button14.wav")

  PLUGIN._mapPanel = vgui.Create("versus_SmugglerMap")
  PLUGIN._mapPanel:MakePopup()
  PLUGIN._mapPanel:Refresh()
end)

net.Receive("versus.smuggler.showResult", function()
  local outcome = net.ReadString()
  local routeName = net.ReadString()
  local runnerName = net.ReadString()
  local cashReward = net.ReadUInt(32)
  local itemCount = math.min(net.ReadUInt(8), 20)
  local itemKeys = {}

  for _ = 1, itemCount do
    table.insert(itemKeys, net.ReadUInt(versus.inventory.bitSizeItemKeys))
  end

  local panel = vgui.Create("versus_RunResult")
  panel:SetResult(outcome, routeName, runnerName, cashReward, itemKeys)
  panel:MakePopup()
end)
