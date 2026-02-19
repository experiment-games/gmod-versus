local PLUGIN = PLUGIN

--- Opens the leaderboard panel. If it is already open, closes it instead.
function PLUGIN.openLeaderboard()
  if IsValid(PLUGIN.leaderboardPanel) then
    PLUGIN.leaderboardPanel:Close()
    return
  end

  PLUGIN.leaderboardPanel = vgui.Create("versus_Leaderboard")
end

--[[
  Net Messages
--]]

-- Triggered by the leaderboard corkboard entity on the server
net.Receive("versus.leaderboard.open", function()
  PLUGIN.openLeaderboard()
end)

-- Incoming page data from the server; forwarded to the open panel
net.Receive("versus.leaderboard.pageData", function()
  local sortBy  = net.ReadString()
  local page    = net.ReadUInt(16)
  local total   = net.ReadUInt(32)
  local count   = net.ReadUInt(8)

  local entries = {}

  for i = 1, count do
    table.insert(entries, {
      steamID = net.ReadString(),
      name    = net.ReadString(),
      money   = net.ReadUInt(32),
      xp      = net.ReadUInt(32),
      level   = net.ReadUInt(16),
    })
  end

  if IsValid(PLUGIN.leaderboardPanel) then
    PLUGIN.leaderboardPanel:OnPageData(sortBy, page, total, entries)
  end
end)

-- Server reply to a "find me" request; forwarded to the open panel
net.Receive("versus.leaderboard.findPlayerResult", function()
  local sortBy = net.ReadString()
  local rank   = net.ReadUInt(32)

  if IsValid(PLUGIN.leaderboardPanel) then
    PLUGIN.leaderboardPanel:OnFindMeResult(sortBy, rank)
  end
end)
