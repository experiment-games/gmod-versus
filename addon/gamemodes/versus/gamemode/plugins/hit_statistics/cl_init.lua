local PLUGIN = PLUGIN

-- Helper function to convert array back to stats format
function PLUGIN.convertArrayToStats(statsArray)
  local stats = {
    totals = {},
    accuracy = {},
    hitgroups = {},
    npc_hitgroups = {},
  }

  for _, entry in ipairs(statsArray) do
    if (entry.type == "totals") then
      stats.totals = entry.data
    elseif (entry.type == "accuracy") then
      stats.accuracy = entry.data
    elseif (entry.type == "hitgroup") then
      stats.hitgroups[entry.hitgroup] = entry.data
    elseif (entry.type == "npc_hitgroup") then
      stats.npc_hitgroups[entry.hitgroup] = entry.data
    end
  end

  return stats
end

function PLUGIN.showHitStatsPanel()
  if (not LocalPlayer():IsAdmin()) then
    LocalPlayer():Notify("You don't have permission to access this panel.")
    return
  end

  if (IsValid(PLUGIN.hitStatsPanel)) then
    PLUGIN.hitStatsPanel:Close()
  end

  PLUGIN.hitStatsPanel = vgui.Create("versus_AdminHitStats")
  PLUGIN.hitStatsPanel:MakePopup()

  -- Request initial data
  net.Start("versus.hitStatistics.requestPlayersOverview")
  net.SendToServer()
end

versus.network.receiveUnbounded("PlayersOverview", function(message, client)
  local playersStats = message:readTable()

  if (IsValid(PLUGIN.hitStatsPanel)) then
    PLUGIN.hitStatsPanel:DisplayPlayersOverview(playersStats)
  end
end)

versus.network.receiveUnbounded("PlayerHitStats", function(message, client)
  local statsArray = message:readTable()
  local steamID = message:readString()
  local stats = PLUGIN.convertArrayToStats(statsArray)

  if (IsValid(PLUGIN.hitStatsPanel)) then
    PLUGIN.hitStatsPanel:DisplayPlayerStats(stats, steamID)
  end
end)

versus.network.receiveUnbounded("SuspiciousPlayers", function(message, client)
  local suspiciousPlayers = message:readTable()

  if (IsValid(PLUGIN.hitStatsPanel)) then
    PLUGIN.hitStatsPanel:DisplaySuspiciousPlayers(suspiciousPlayers)
  end
end)

concommand.Add("versus_hitstats_panel", function()
  if (not LocalPlayer():IsAdmin()) then
    LocalPlayer():Notify("You don't have permission to access this panel.")
    return
  end

  PLUGIN.showHitStatsPanel()
end)
