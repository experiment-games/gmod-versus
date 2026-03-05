local PLUGIN = PLUGIN

local playerGetAll = player.GetAll
local playerGetBySteamID64 = player.GetBySteamID64

-- Maps spectator SteamID64 -> { targets = {SteamID64, ...}, index = number }
PLUGIN.spectatorSessions = PLUGIN.spectatorSessions or {}

util.AddNetworkString("versus.spectating.state")
util.AddNetworkString("versus.spectating.cycle")
util.AddNetworkString("versus.spectating.end")

--- Puts `player` into spectator mode, cycling through the players identified by `targetSteamIDs`.
--- The spectator will automatically track the first live target.  If a watched player dies or
--- disconnects the system cycles to the next available target automatically.
---
--- Call `versus.spectating.clearSpectator(player)` when spectating should end (e.g. the whole
--- squad has been wiped and there is nobody left to watch).
---
--- @param player       Player    The dead/spectating player.
--- @param targetSteamIDs string[]  Ordered list of SteamID64 strings the player may spectate.
function PLUGIN.setSpectator(player, targetSteamIDs)
  local steamID = player:SteamID64()
  PLUGIN.spectatorSessions[steamID] = { targets = targetSteamIDs, index = 1 }
  PLUGIN.applySpectateTarget(player)
end

--- Removes a player's spectating session and notifies their client to hide the spectating HUD.
--- @param player Player
function PLUGIN.clearSpectator(player)
  local steamID = player:SteamID64()

  if not PLUGIN.spectatorSessions[steamID] then return end

  PLUGIN.spectatorSessions[steamID] = nil

  player:UnSpectate()
  player:SetNoDraw(false)
  player:DrawShadow(true)
  player:SetTeam(TEAM_PLAYERS)
  player:Spawn()

  net.Start("versus.spectating.end")
  net.Send(player)
end

--[[
  Internal helpers
--]]

--- Sends the current spectating state to the spectating player's client.
--- @param player  Player
--- @param session table   The spectator's session entry.
--- @param target  Player  The entity currently being spectated (may be NULL).
function PLUGIN.syncState(player, session, target)
  net.Start("versus.spectating.state")

  if IsValid(target) then
    net.WriteBool(true)
    net.WriteString(target:Nick())
    net.WriteUInt(session.index, 4) -- 1-based, max 15 targets
    net.WriteUInt(#session.targets, 4)
  else
    net.WriteBool(false)
    net.WriteString("")
    net.WriteUInt(0, 4)
    net.WriteUInt(#session.targets, 4)
  end

  net.Send(player)
end

--- Finds the next live target starting at `session.index` and spectates it.
--- If no live target exists the player's client is told there is nothing to watch.
--- @param player  Player
function PLUGIN.applySpectateTarget(player)
  local session = PLUGIN.spectatorSessions[player:SteamID64()]

  if not session or #session.targets == 0 then return end

  local count      = #session.targets
  local startIndex = session.index

  local target     = NULL
  local foundIndex = startIndex

  for i = 0, count - 1 do
    local idx = ((startIndex - 1 + i) % count) + 1
    local candidate = playerGetBySteamID64(session.targets[idx])

    if candidate and candidate:Alive() then
      target     = candidate
      foundIndex = idx
      break
    end
  end

  session.index = foundIndex

  if IsValid(target) then
    player:StripWeapons()
    player:SetTeam(TEAM_SPECTATOR)
    player:Spectate(OBS_MODE_CHASE)
    player:SpectateEntity(target)
    player:SetNoDraw(true)
    player:DrawShadow(false)
  end

  PLUGIN.syncState(player, session, target)
end

--- Advances (or rewinds) the current spectate target by `direction` steps (+1 / -1).
--- @param player    Player
--- @param direction number
function PLUGIN.cycleTarget(player, direction)
  local session = PLUGIN.spectatorSessions[player:SteamID64()]

  if not session or #session.targets == 0 then return end

  local count = #session.targets
  session.index = ((session.index - 1 + direction) % count) + 1

  PLUGIN.applySpectateTarget(player)
end

--[[
  Hooks
--]]

--- When a spectated player dies, automatically move any spectators watching them to the next target.
function PLUGIN.hook:PlayerDeath(player)
  local deadSteamID = player:SteamID64()

  for spectatorSteamID, session in pairs(PLUGIN.spectatorSessions) do
    if not table.HasValue(session.targets, deadSteamID) then continue end

    -- Only auto-cycle if this player is the one currently on screen.
    if session.targets[session.index] ~= deadSteamID then continue end

    local spectator = playerGetBySteamID64(spectatorSteamID)

    if spectator then
      -- Step forward one so applySpectateTarget searches from the next slot.
      session.index = (session.index % #session.targets) + 1
      PLUGIN.applySpectateTarget(spectator)
    end
  end
end

--- Clean up sessions when a tracked player disconnects.
function PLUGIN.hook:PlayerDisconnected(player)
  local disconnectedSteamID = player:SteamID64()

  -- Remove as spectator.
  PLUGIN.spectatorSessions[disconnectedSteamID] = nil

  -- If this player was a target, advance any spectators watching them.
  for spectatorSteamID, session in pairs(PLUGIN.spectatorSessions) do
    if not table.HasValue(session.targets, disconnectedSteamID) then continue end

    -- Remove from the target list.
    for i = #session.targets, 1, -1 do
      if session.targets[i] == disconnectedSteamID then
        table.remove(session.targets, i)

        -- Keep the index in range.
        if session.index > #session.targets then
          session.index = math.max(1, #session.targets)
        end

        break
      end
    end

    local spectator = playerGetBySteamID64(spectatorSteamID)

    if #session.targets == 0 then
      -- No live targets remain; just notify the client.
      if spectator then
        PLUGIN.syncState(spectator, session, NULL)
      end
    else
      if spectator then
        PLUGIN.applySpectateTarget(spectator)
      end
    end
  end
end

-- Players cannot perform inventory actions while spectating.
function PLUGIN.hook:PlayerCanUseItem(player, item)
  local session = PLUGIN.spectatorSessions[player:SteamID64()]

  if session then
    versus.message.notify(player, "You cannot use items while spectating.", NOTIFY_ERROR)
    return false
  end
end

function PLUGIN.hook:PlayerCanDropItem(player, item)
  local session = PLUGIN.spectatorSessions[player:SteamID64()]

  if session then
    versus.message.notify(player, "You cannot drop items while spectating.", NOTIFY_ERROR)
    return false
  end
end

function PLUGIN.hook:PlayerCanUnequipItem(player, slot)
  local session = PLUGIN.spectatorSessions[player:SteamID64()]

  if session then
    versus.message.notify(player, "You cannot unequip items while spectating.", NOTIFY_ERROR)
    return false
  end
end

--[[
  Net messages
--]]

net.Receive("versus.spectating.cycle", function(_, player)
  local direction = net.ReadInt(4) -- +1 or -1
  PLUGIN.cycleTarget(player, direction)
end)

--[[
  Console commands
--]]

-- Tool for admin to become a spectator of everyone online.
concommand.Add("versus_spectate_all", function(player, command, args)
  if not IsValid(player) or not player:IsAdmin() then return end

  local steamIDs = {}

  for _, ply in ipairs(playerGetAll()) do
    if (ply ~= player) then
      table.insert(steamIDs, ply:SteamID64())
    end
  end

  PLUGIN.setSpectator(player, steamIDs)
end, nil, "Become a spectator of all players currently online (admin only).")
