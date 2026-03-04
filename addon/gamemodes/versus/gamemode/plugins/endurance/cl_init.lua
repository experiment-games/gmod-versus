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

  -- Show the invite in the matchmaking tab's notification bar.
  -- If the panel doesn't exist yet, just rely on ShowNextInvite when it opens.
  if IsValid(PLUGIN.matchmakingPanel) then
    PLUGIN.matchmakingPanel:ShowInvite(leaderSteamID, leaderName)
  end
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
    -- Squad was disbanded or matchmaking failed — clear local squad state.
    PLUGIN.squadState = nil
    PLUGIN.pendingInvites = {}

    if IsValid(PLUGIN.matchmakingPanel) then
      PLUGIN.matchmakingPanel:RebuildMemberList()
    end

    chat.AddText(Color(220, 80, 80), "[Endurance] ", Color(220, 230, 240), "Matchmaking failed: " .. message)
  end
end)

net.Receive("versus.endurance.arenaRedirect", function()
  local serverAddress = net.ReadString()

  -- Dismiss the wipe screen (if still showing) before the connect prompt.
  if IsValid(PLUGIN.wipeScreen) then
    PLUGIN.wipeScreen:Remove()
    PLUGIN.wipeScreen = nil
  end

  permissions.AskToConnect(serverAddress)
  chat.AddText(Color(120, 200, 120), "[Endurance] ", Color(220, 230, 240),
    "Game over! Return to the hideout at " .. serverAddress .. "…")
end)

net.Receive("versus.endurance.squadWiped", function()
  local wave = net.ReadUInt(16)
  local redirectDelay = net.ReadUInt(16)

  -- Remove any existing wipe screen before showing a fresh one.
  if IsValid(PLUGIN.wipeScreen) then
    PLUGIN.wipeScreen:Remove()
  end

  local panel = vgui.Create("versus_EnduranceWipeScreen")

  if IsValid(panel) then
    panel:SetWave(wave)
    panel:SetRedirectDelay(redirectDelay)
    PLUGIN.wipeScreen = panel
  end
end)

net.Receive("versus.endurance.matchmakingScheduled", function()
  local serverAddress = net.ReadString()
  local secsUntilOpen = net.ReadUInt(16)

  chat.AddText(Color(120, 200, 120), "[Endurance] ", Color(220, 230, 240),
    "Match found! You will be connected to " .. serverAddress ..
    " in ~" .. secsUntilOpen .. " second(s)…")
end)

-- Register the Endurance tab in the main menu
function PLUGIN.hook:BuildMainMenuTabs(tabs)
  tabs:addTab("Endurance Matchmaking", vgui.Create("versus_EnduranceMatchmakingPanel"), 4)
end
