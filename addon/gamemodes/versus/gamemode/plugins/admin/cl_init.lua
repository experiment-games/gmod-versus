local PLUGIN = PLUGIN

-- Register the Admin tab in the main menu (visible to admins only).
function PLUGIN.hook:BuildMainMenuTabs(tabs)
  if not LocalPlayer():IsAdmin() then return end

  tabs:addTab("Admin", vgui.Create("versus_AdminPanel"), 10)
end

-- Receive online players list from server.
net.Receive("versus.admin.onlinePlayers", function()
  local players = net.ReadTable()

  if IsValid(PLUGIN.adminPanel) then
    PLUGIN.adminPanel:DisplayOnlinePlayers(players)
  end
end)

-- Receive banned players list from server.
net.Receive("versus.admin.bannedPlayers", function()
  local bans = net.ReadTable()

  if IsValid(PLUGIN.adminPanel) then
    PLUGIN.adminPanel:DisplayBannedPlayers(bans)
  end
end)
