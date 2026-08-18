local PLUGIN = PLUGIN

--[[
  Database table creation
--]]

function PLUGIN.hook:VersusBuildCreateTablesQueries(queries)
  -- Stores a row for each versus_squad_spawn entity registered by the endurance server.
  -- The endurance server populates this table on map load; the hideout server reads it
  -- to find free spawn slots during matchmaking.
  -- The `map` column tracks which map each spawn belongs to so that spawn records from
  -- previous maps are not accidentally offered as free slots on the current map.
  table.insert(queries, [[
		CREATE TABLE IF NOT EXISTS `endurance_squad_spawns` (
			`id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			`spawn_id` varchar(255) NOT NULL,
			`map` varchar(255) NOT NULL DEFAULT '',
			UNIQUE KEY `spawn_map_unique` (`spawn_id`, `map`),
			`squad_id` int(11) UNSIGNED NULL DEFAULT NULL
		);
	]])

  -- Stores one row per squad that has been matched into an endurance arena.
  table.insert(queries, [[
		CREATE TABLE IF NOT EXISTS `endurance_squads` (
			`id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			`members` longtext NOT NULL,
			`status` varchar(64) NOT NULL DEFAULT 'pending',
			`connect_at` DATETIME NULL DEFAULT NULL,
			`created_at` TIMESTAMP NOT NULL DEFAULT NOW()
		);
	]])
end

-- Players cannot try again after death on endurance maps.
function PLUGIN.hook:CanPlayerRespawnInTime(player, attacker)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  return false
end

-- We stop the player from spawning if they already played through the endurance mode
-- and died.
function PLUGIN.hook:PlayerDeathThink(player)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  if player._VersusEndurancePlayed then
    return false
  end
end

function PLUGIN.hook:InitPostEntity()
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  -- In endurance mode we need the server to think so it will setup the timer and query the database in-time to know
  -- who is allowed to connect.
  RunConsoleCommand("sv_hibernate_think", "1")

  -- We set a random password, so that players can't just connect directly without going through matchmaking to reserve a slot.
  local passwordConVar = GetConVar("sv_password")
  local currentPassword = passwordConVar and passwordConVar:GetString() or ""

  if currentPassword == "" then
    local randomPassword = tostring(math.random(10000, 999999999999999999999999999))
    RunConsoleCommand("sv_password", randomPassword)
    print("[Endurance] Set random server password to " .. randomPassword .. " to prevent non-matchmaking connections.")
  else
    print(
      "[Endurance] Warning: sv_password is not empty. Endurance mode relies on a random password to prevent non-matchmaking connections, so make sure to clear sv_password before starting the server."
    )
  end

  -- Register all versus_squad_spawn entities present in the map into the
  -- database so the hideout server can query available slots.
  -- Also clear any stale squad reservations left from a previous session so
  -- all spawns are immediately free to join after a restart.
  local currentMap = game.GetMap()

  -- Remove spawn records and rebuild them so we always have non-reserved spawns and
  -- only spawns for the current map in the database.
  versus.database.query(
    "DELETE FROM `endurance_squad_spawns`",
    function()
      for _, spawnEntity in ipairs(ents.FindByClass("versus_squad_spawn")) do
        local spawnID = spawnEntity:GetSpawnID()

        if spawnID == "" then continue end

        versus.database.queryPrepared(
          "INSERT IGNORE INTO `endurance_squad_spawns` (`spawn_id`, `map`) VALUES (?, ?)",
          {
            versus.player.getValueTypeDefinition(spawnID),
            versus.player.getValueTypeDefinition(currentMap),
          }
        )
      end
    end
  )

  -- Start the clock-aligned poller that refreshes the CheckPassword allowlist.
  PLUGIN.startConnectWindowPolling()

  -- Start the automatic map rotation timer (fires every MAP_ROTATION_INTERVAL seconds).
  PLUGIN.startMapRotationTimer()
end

--- Blocks connections from players who are not in the current connect-window allowlist.
--- Only active when VersusEnduranceMap is true. SteamIDs configured in
--- versus.config["Endurance Testing SteamIDs"] bypass the check (if their name ends with "*")
--- so developers can still connect for testing without going through matchmaking.
function PLUGIN.hook:CheckPassword(steamID64, ipAddress, svPassword, clPassword, name)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  local expireTime = PLUGIN.allowedSteamIDs[steamID64]

  if expireTime and expireTime >= os.time() then
    -- Allow: player is in the current connect window.
    -- We explicitly return true to prevent the base gamemode from actually checking the password (which we don't care about
    -- since the player is allowed based on their SteamID64)
    return true
  end

  -- Allow configured testing SteamIDs through if their name ends with a marker (for testing
  -- purposes where they might not have a reserved slot). See sv_configuration.lua.example.
  if (versus.config["Endurance Testing SteamIDs"] or {})[steamID64] and string.EndsWith(name, "*") then
    -- We explicitly return true to prevent the base gamemode from actually checking the password
    return true
  end

  return false,
      "Slot not reserved for you. You must join through matchmaking in our Hideout server."
end

function PLUGIN.hook:PlayerInitialized(player)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  -- Look up which spawn this player belongs to and teleport them there.
  PLUGIN.getReservedSpawnForPlayer(player:SteamID64(), function(spawnID)
    if not spawnID then
      -- Superadmins may connect without a reserved spawn for testing purposes.
      -- They can use "versus_endurance_test_start" in the server console to start waves manually.
      if player:IsSuperAdmin() then
        local firstSpawn = ents.FindByClass("versus_squad_spawn")[1]

        if IsValid(firstSpawn) then
          player:SetPos(firstSpawn:GetSpawnPosition())
          player:SetAngles(firstSpawn:GetSpawnAngles())
          player._VersusEndurancePlayed = true
        end

        versus.message.notify(player,
          "Connected as superadmin (no reserved spawn). " ..
          "Use 'versus_endurance_test_start' in the server console to start waves.",
          NOTIFY_CHAT_LIGHTBULB
        )
        return
      end

      -- Kick the player if they somehow got here without a reserved spawn (shouldn't be possible through normal means).
      player:Kick("You must connect through matchmaking in our Hideout server to play Endurance mode.")
      return
    end

    for _, spawnEntity in ipairs(ents.FindByClass("versus_squad_spawn")) do
      if spawnEntity:GetSpawnID() == spawnID then
        player:SetPos(spawnEntity:GetPos() + Vector(0, 0, 10))
        player:SetAngles(spawnEntity:GetAngles())
        player._VersusEndurancePlayed = true

        -- Once all squad members for this spawn have joined, start waves.
        PLUGIN.checkAndStartWaves(spawnID)
        return
      end
    end
  end)
end

--- Checks whether all expected squad members have joined for the given arena.
--- If so, starts the wave system.
--- @param spawnID string
function PLUGIN.checkAndStartWaves(spawnID)
  -- Avoid starting waves multiple times for the same arena.
  if PLUGIN.activeSquads[spawnID] then
    return
  end

  -- Find the spawn entity.
  local spawnEntity = nil

  for _, ent in ipairs(ents.FindByClass("versus_squad_spawn")) do
    if ent:GetSpawnID() == spawnID then
      spawnEntity = ent
      break
    end
  end

  if not IsValid(spawnEntity) then return end

  -- Look up the squad members from the DB.
  versus.database.queryPrepared(
    "SELECT es.`members` FROM `endurance_squads` es " ..
    "INNER JOIN `endurance_squad_spawns` esp ON esp.`squad_id` = es.`id` " ..
    "WHERE esp.`spawn_id` = ? AND es.`status` = 'matchmade' LIMIT 1",
    {
      versus.player.getValueTypeDefinition(spawnID),
    },
    function(rows)
      if not rows or #rows == 0 then return end

      local memberSteamIDs = util.JSONToTable(rows[1].members) or {}
      local allJoined      = true

      for _, steamID in ipairs(memberSteamIDs) do
        if not IsValid(PLUGIN.findPlayerBySteamID(steamID)) then
          allJoined = false
          break
        end
      end

      if allJoined then
        PLUGIN.startWavesForArena(spawnEntity, memberSteamIDs)
      end
    end
  )
end

function PLUGIN.hook:OnNPCKilled(npc, attacker, inflictor)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  PLUGIN.onEnduranceNPCKilled(npc)
end

function PLUGIN.hook:PlayerSaveDisconnect(player)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  hook.Run("PlayerFailedVersus", player)
end

function PLUGIN.hook:PlayerDeath(player, inflictor, attacker, ragdoll)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  hook.Run("PlayerFailedVersus", player)

  -- Check if all players assigned to this arena have been wiped out.
  for spawnID, state in pairs(PLUGIN.activeSquads) do
    if not table.HasValue(state.members, player:SteamID64()) then
      continue
    end

    -- Show the endurance reward screen to the dying player.
    local currentXP    = versus.rewards.getPlayerXP(player)
    local startXP      = player._VersusEnduranceStartXP or currentXP
    local xpGained     = currentXP - startXP
    local currentLevel = versus.rewards.getPlayerLevel(player)
    local xpToNext     = versus.rewards.getXPToNextLevel(player)
    local startLevel   = versus.rewards.getLevelFromXP(startXP)

    versus.rewards.showRewardScreen(
      player,
      "Endurance Over",
      "You survived to wave " .. state.wave,
      {},
      xpGained,
      currentLevel,
      xpToNext,
      currentXP,
      startLevel,
      startXP
    )

    local anyAlive = false

    for _, memberSteamID in ipairs(state.members) do
      local ply = PLUGIN.findPlayerBySteamID(memberSteamID)

      -- Exclude the dying player and any players who are already in a spectating
      -- session (they were respawned as spectators after dying, so Alive() returns
      -- true even though they are out of the game).
      local isSpectating = versus.spectating and versus.spectating.spectatorSessions[memberSteamID]

      if IsValid(ply) and ply:Alive() and ply:SteamID64() ~= player:SteamID64() and not isSpectating then
        anyAlive = true
        break
      end
    end

    -- Let the dead player spectate their remaining squad members while they wait for
    -- the squad-wipe redirect.  We pass every member; the spectating plugin skips over
    -- anyone who is already dead and auto-advances when further deaths occur.
    if anyAlive and versus.spectating then
      local membersWithoutSelf = {}

      for _, memberSteamID in ipairs(state.members) do
        if memberSteamID ~= player:SteamID64() then
          table.insert(membersWithoutSelf, memberSteamID)
        end
      end

      -- The player needs to be spawned in order to see anything and have control
      -- We slightly delay, since I have no idea if we can just call Spawn in PlayerDeath
      -- (because PostPlayerDeath is still called and might interfere if a player is alive again?)
      -- setSpectator must be called AFTER Spawn() so that the spectate state is not reset
      -- by the spawn (which would leave the player with their hands out).
      timer.Simple(0.1, function()
        if IsValid(player) then
          player:Spawn()
          versus.spectating.setSpectator(player, membersWithoutSelf)
        end
      end)
    end

    if not anyAlive then
      PLUGIN.onSquadWiped(spawnID)
    end

    break
  end
end

--[[
  Hideout-side net message receivers
--]]

net.Receive("versus.endurance.formSquad", function(len, player)
  local success, message = PLUGIN.formSquad(player)

  if not success then
    versus.message.notify(player, message or "Failed to form squad", NOTIFY_ERROR)
  end
end)

net.Receive("versus.endurance.invitePlayer", function(len, player)
  local targetSteamID = net.ReadString()
  local target        = PLUGIN.findPlayerBySteamID(targetSteamID)

  if not IsValid(target) then
    versus.message.notify(player, "Player not found", NOTIFY_ERROR)
    return
  end

  local success, message = PLUGIN.inviteToSquad(player, target)

  if not success then
    versus.message.notify(player, message or "Failed to invite player", NOTIFY_ERROR)
  end
end)

net.Receive("versus.endurance.acceptInvite", function(len, player)
  local leaderSteamID = net.ReadString()
  local success, message = PLUGIN.acceptInvite(player, leaderSteamID)

  if not success then
    versus.message.notify(player, message or "Failed to accept invite", NOTIFY_ERROR)
  end
end)

net.Receive("versus.endurance.declineInvite", function(len, player)
  local leaderSteamID = net.ReadString()
  PLUGIN.declineInvite(player, leaderSteamID)
end)

net.Receive("versus.endurance.readyUp", function(len, player)
  local success, message = PLUGIN.readyUp(player)

  if not success then
    versus.message.notify(player, message or "Failed to ready up", NOTIFY_ERROR)
  end
end)

net.Receive("versus.endurance.disbandSquad", function(len, player)
  PLUGIN.disbandSquad(player)
end)

net.Receive("versus.endurance.leaveSquad", function(len, player)
  PLUGIN.leaveSquad(player)
end)

--- When a squad leader disconnects, automatically disband their pending squad so members
--- are freed and can join or form a new one.  Non-leader members are removed from the squad.
--- On endurance maps, checks whether the disconnect leaves an active arena with no remaining
--- alive members and triggers a squad wipe if so.
function PLUGIN.hook:PlayerDisconnected(player)
  if GetGlobalBool("VersusEnduranceMap", false) then
    local steamID = player:SteamID64()

    for spawnID, state in pairs(PLUGIN.activeSquads) do
      if not table.HasValue(state.members, steamID) then continue end

      local anyAlive = false

      for _, memberSteamID in ipairs(state.members) do
        if memberSteamID == steamID then continue end

        local ply = PLUGIN.findPlayerBySteamID(memberSteamID)
        local isSpectating = versus.spectating and versus.spectating.spectatorSessions[memberSteamID]

        if IsValid(ply) and ply:Alive() and not isSpectating then
          anyAlive = true
          break
        end
      end

      if not anyAlive then
        PLUGIN.onSquadWiped(spawnID)
      end

      break
    end

    return
  end

  if not GetGlobalBool("VersusHideoutMap", false) then
    return
  end

  local steamID = player:SteamID64()

  if PLUGIN.pendingSquads[steamID] then
    PLUGIN.disbandSquad(player)
  else
    PLUGIN.leaveSquad(player)
  end

  -- Remove the disconnecting player from any squad's pending invite list.
  -- leaveSquad only handles accepted members; an invited-but-not-yet-accepted
  -- player would otherwise leave a stale "pending" count for the squad leader.
  for leaderSteamID, squad in pairs(PLUGIN.pendingSquads) do
    if table.RemoveByValue(squad.pendingInvites, steamID) then
      PLUGIN.syncSquadStateToAll(leaderSteamID)
    end
  end
end
