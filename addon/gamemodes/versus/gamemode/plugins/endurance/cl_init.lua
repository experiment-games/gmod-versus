local PLUGIN = PLUGIN

-- State received from the server.
PLUGIN.squadState = PLUGIN.squadState or nil
PLUGIN.pendingInvites = PLUGIN.pendingInvites or {}

--[[
  Net message receivers (client-side)
--]]

net.Receive("versus.endurance.syncSquadState", function()
  local leaderSteamID = net.ReadString()
  local memberCount   = net.ReadUInt(4)
  local members       = {}

  for i = 1, memberCount do
    local steamID = net.ReadString()
    local name    = net.ReadString()
    local isReady = net.ReadBool()
    table.insert(members, { steamID = steamID, name = name, isReady = isReady })
  end

  local pendingInviteCount = net.ReadUInt(4)

  PLUGIN.squadState = {
    leader             = leaderSteamID,
    members            = members,
    pendingInviteCount = pendingInviteCount,
  }
end)

net.Receive("versus.endurance.invitePlayer", function()
  local leaderSteamID = net.ReadString()
  local leaderName    = net.ReadString()

  if table.HasValue(PLUGIN.pendingInvites, leaderSteamID) then return end

  table.insert(PLUGIN.pendingInvites, leaderSteamID)

  local notification = vgui.Create("versus_EnduranceInviteNotification")
  notification:SetInviteData(leaderSteamID, leaderName)
end)

net.Receive("versus.endurance.matchmakingResult", function()
  local success = net.ReadBool()
  local message = net.ReadString()

  if success then
    -- Ask the player to connect to the endurance server.
    permissions.AskToConnect(message)
    chat.AddText(Color(120, 200, 120), "[Endurance] ", Color(220, 230, 240),
      "Match found! Connecting to " .. message .. "…")
  else
    chat.AddText(Color(220, 80, 80), "[Endurance] ", Color(220, 230, 240), "Matchmaking failed: " .. message)
  end
end)

net.Receive("versus.endurance.arenaRedirect", function()
  local serverAddress = net.ReadString()

  permissions.AskToConnect(serverAddress)
  chat.AddText(Color(120, 200, 120), "[Endurance] ", Color(220, 230, 240),
    "Game over! Return to the hideout at " .. serverAddress .. "…")
end)

net.Receive("versus.endurance.matchmakingScheduled", function()
  local serverAddress  = net.ReadString()
  local secsUntilOpen  = net.ReadUInt(16)

  chat.AddText(Color(120, 200, 120), "[Endurance] ", Color(220, 230, 240),
    "Match found! You will be connected to " .. serverAddress ..
    " in ~" .. secsUntilOpen .. " second(s)…")
end)

--[[
  Console command to open the matchmaking panel
--]]

concommand.Add("versus_endurance_matchmaking", function()
  if not GetGlobalBool("VersusHideoutMap", false) then
    chat.AddText(Color(220, 80, 80), "[Endurance] ", Color(220, 230, 240),
      "You can only queue for Endurance from the hideout.")
    return
  end

  -- If not yet in a squad, form one first.
  if not PLUGIN.squadState then
    net.Start("versus.endurance.formSquad")
    net.SendToServer()
  end

  local existing = vgui.GetWorldPanel():Find("versus_EnduranceMatchmakingPanel")

  if not IsValid(existing) then
    vgui.Create("versus_EnduranceMatchmakingPanel")
  end
end)
