local PLUGIN = PLUGIN

--[[
  Database table creation
--]]

function PLUGIN.hook:VersusBuildCreateTablesQueries(queries)
  -- Stores a row for each versus_squad_spawn entity registered by the endurance server.
  -- The endurance server populates this table on map load; the hideout server reads it
  -- to find free spawn slots during matchmaking.
  table.insert(queries, [[
		CREATE TABLE IF NOT EXISTS `endurance_squad_spawns` (
			`id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			`spawn_id` varchar(255) NOT NULL UNIQUE,
			`squad_id` int(11) UNSIGNED NULL DEFAULT NULL
		);
	]])

  -- Stores one row per squad that has been matched into an endurance arena.
  table.insert(queries, [[
		CREATE TABLE IF NOT EXISTS `endurance_squads` (
			`id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			`members` longtext NOT NULL,
			`status` varchar(64) NOT NULL DEFAULT 'pending',
			`created_at` TIMESTAMP NOT NULL DEFAULT NOW()
		);
	]])
end

--[[
  Endurance-server-side hooks
--]]

function PLUGIN.hook:InitPostEntity()
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  -- Register all versus_squad_spawn entities present in the map into the
  -- database so the hideout server can query available slots.
  timer.Simple(3, function()
    for _, spawnEntity in ipairs(ents.FindByClass("versus_squad_spawn")) do
      local spawnID = spawnEntity:GetSpawnID()

      if spawnID == "" then continue end

      versus.database.queryPrepared(
        "INSERT IGNORE INTO `endurance_squad_spawns` (`spawn_id`) VALUES (?)",
        { { databaseType = TYPE_STRING, value = spawnID } }
      )
    end
  end)
end

function PLUGIN.hook:PlayerInitialized(player)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  -- Look up which spawn this player belongs to and teleport them there.
  PLUGIN.getReservedSpawnForPlayer(player:SteamID(), function(spawnID)
    if not spawnID then
      -- Superadmins may connect without a reserved spawn for testing purposes.
      -- They can use "versus_endurance_test_start" in the server console to start waves manually.
      if player:IsSuperAdmin() then
        local firstSpawn = ents.FindByClass("versus_squad_spawn")[1]

        if IsValid(firstSpawn) then
          player:SetPos(firstSpawn:GetSpawnPosition())
          player:SetAngles(firstSpawn:GetSpawnAngles())
        end

        versus.message.notify(player,
          "Connected as superadmin (no reserved spawn). " ..
          "Use 'versus_endurance_test_start' in the server console to start waves.",
          NOTIFY_HINT)
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

        -- Once all squad members for this spawn have joined, start waves.
        PLUGIN.checkAndStartWaves(spawnID)
        return
      end
    end
  end)
end

-- Commented, as we can't query fast enough to return a response before the player already connects.
-- Instead we'll kick them in PlayerInitialized if they don't have a reserved spawn, which should be just as effective at preventing random players from joining the endurance server.
-- -- When a player tries to connect to the endurance server, check if they have a reserved spawn. If not, reject the connection.
-- function PLUGIN.hook:CheckPassword(steamID64, ipAddress, svPassword, clPassword, name)
--   if not GetGlobalBool("VersusEnduranceMap", false) then
--     return
--   end
-- end

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
    { { databaseType = TYPE_STRING, value = spawnID } },
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

function PLUGIN.hook:PlayerDeath(player, inflictor, attacker, ragdoll)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  -- Check if all players assigned to this arena have been wiped out.
  for spawnID, state in pairs(PLUGIN.activeSquads) do
    if not table.HasValue(state.members, player:SteamID()) then
      continue
    end

    local anyAlive = false

    for _, memberSteamID in ipairs(state.members) do
      local ply = PLUGIN.findPlayerBySteamID(memberSteamID)

      if IsValid(ply) and ply:Alive() and ply:SteamID() ~= player:SteamID() then
        anyAlive = true
        break
      end
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
