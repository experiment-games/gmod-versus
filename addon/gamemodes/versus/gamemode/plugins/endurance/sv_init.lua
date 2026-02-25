local PLUGIN = PLUGIN

-- Squad state table: maps squadID -> { members = {steamid, ...}, spawnID = string, wave = number, alive = bool }
PLUGIN.activeSquads = PLUGIN.activeSquads or {}

-- Pending squad invitations on the hideout server: maps leaderSteamID -> { members = {}, pendingInvites = {}, readied = {} }
PLUGIN.pendingSquads = PLUGIN.pendingSquads or {}

util.AddNetworkString("versus.endurance.formSquad")
util.AddNetworkString("versus.endurance.invitePlayer")
util.AddNetworkString("versus.endurance.acceptInvite")
util.AddNetworkString("versus.endurance.declineInvite")
util.AddNetworkString("versus.endurance.readyUp")
util.AddNetworkString("versus.endurance.disbandSquad")
util.AddNetworkString("versus.endurance.syncSquadState")
util.AddNetworkString("versus.endurance.matchmakingResult")

versus.includePrefixed("sv_hooks.lua")

--[[
  Database helpers
--]]

--- Returns a `TYPE_STRING` value table for use with `versus.database.queryPrepared`.
--- @param value string
--- @return table
local function dbStr(value)
  return { databaseType = TYPE_STRING, value = tostring(value) }
end

--- Returns a `TYPE_NUMBER` value table for use with `versus.database.queryPrepared`.
--- @param value number
--- @return table
local function dbNum(value)
  return { databaseType = TYPE_NUMBER, value = tonumber(value) }
end

--- Registers a squad in the database and reserves a free squad spawn.
--- Calls `callback(squadID, spawnID)` on success or `errorCallback(err)` on failure.
--- @param memberSteamIDs table  List of steam ID strings (leader first)
--- @param callback fun(squadID: number, spawnID: string)
--- @param errorCallback? fun(err: string)
function PLUGIN.registerSquadInDatabase(memberSteamIDs, callback, errorCallback)
  local membersJSON = util.TableToJSON(memberSteamIDs)

  -- Insert the squad row first, then reserve a free spawn.
  versus.database.queryPrepared(
    "INSERT INTO `endurance_squads` (`members`, `status`) VALUES (?, 'pending')",
    { dbStr(membersJSON) },
    function(_, squadID)
      if not squadID then
        if errorCallback then errorCallback("No insert ID returned for squad") end
        return
      end

      -- Find a free squad spawn slot and reserve it.
      versus.database.query(
        "SELECT `id`, `spawn_id` FROM `endurance_squad_spawns` WHERE `squad_id` IS NULL LIMIT 1",
        function(rows)
          if not rows or #rows == 0 then
            -- No free spawn available; update squad to reflect this.
            versus.database.queryPrepared(
              "UPDATE `endurance_squads` SET `status` = 'waiting' WHERE `id` = ?",
              { dbNum(squadID) }
            )

            if errorCallback then errorCallback("No free squad spawn available") end
            return
          end

          local spawnRow = rows[1]
          local spawnRowID = spawnRow.id
          local spawnID    = spawnRow.spawn_id

          -- Reserve the spawn for this squad.
          versus.database.queryPrepared(
            "UPDATE `endurance_squad_spawns` SET `squad_id` = ? WHERE `id` = ?",
            { dbNum(squadID), dbNum(spawnRowID) },
            function()
              -- Mark the squad as matchmade (spawn reserved).
              versus.database.queryPrepared(
                "UPDATE `endurance_squads` SET `status` = 'matchmade' WHERE `id` = ?",
                { dbNum(squadID) },
                function()
                  callback(squadID, spawnID)
                end,
                errorCallback
              )
            end,
            errorCallback
          )
        end,
        errorCallback
      )
    end,
    errorCallback,
    true -- returnLastInsert
  )
end

--- Marks a squad spawn as free (squad was wiped out or disbanded).
--- @param spawnID string  The spawn_id value of the spawn to free
function PLUGIN.freeSquadSpawn(spawnID)
  -- First retrieve the squad_id so we can delete the squad row.
  versus.database.queryPrepared(
    "SELECT `squad_id` FROM `endurance_squad_spawns` WHERE `spawn_id` = ?",
    { dbStr(spawnID) },
    function(rows)
      -- Clear the reservation.
      versus.database.queryPrepared(
        "UPDATE `endurance_squad_spawns` SET `squad_id` = NULL WHERE `spawn_id` = ?",
        { dbStr(spawnID) }
      )

      if not rows or #rows == 0 or not rows[1].squad_id then
        return
      end

      -- Delete the squad record.
      versus.database.queryPrepared(
        "DELETE FROM `endurance_squads` WHERE `id` = ?",
        { dbNum(rows[1].squad_id) }
      )
    end
  )
end

--- Looks up the squad spawn reserved for the given steam ID.
--- Calls `callback(spawnID)` if found, or `callback(nil)` otherwise.
--- @param steamID string
--- @param callback fun(spawnID: string?)
function PLUGIN.getReservedSpawnForPlayer(steamID, callback)
  versus.database.queryPrepared(
    "SELECT esp.`spawn_id` FROM `endurance_squad_spawns` esp " ..
      "INNER JOIN `endurance_squads` es ON es.`id` = esp.`squad_id` " ..
      "WHERE es.`members` LIKE ? AND es.`status` = 'matchmade' LIMIT 1",
    { dbStr("%" .. steamID .. "%") },
    function(rows)
      if rows and #rows > 0 then
        callback(rows[1].spawn_id)
      else
        callback(nil)
      end
    end
  )
end

--[[
  Hideout-side squad management
--]]

--- Creates a new pending squad with `leader` as the sole member.
--- Returns false (with a message) if the player is already in a squad.
--- @param leader Player
--- @return boolean, string?
function PLUGIN.formSquad(leader)
  local steamID = leader:SteamID()

  if PLUGIN.getSquadForPlayer(steamID) then
    return false, "You are already in a squad"
  end

  PLUGIN.pendingSquads[steamID] = {
    leader         = steamID,
    members        = { steamID },
    pendingInvites = {},
    readied        = {},
  }

  PLUGIN.syncSquadStateToLeader(steamID)
  return true
end

--- Returns the pending squad table for a given steam ID (as leader or member), or nil.
--- @param steamID string
--- @return table?
function PLUGIN.getSquadForPlayer(steamID)
  -- Check if this player is a leader.
  if PLUGIN.pendingSquads[steamID] then
    return PLUGIN.pendingSquads[steamID]
  end

  -- Check if this player is a member of someone else's squad.
  for _, squad in pairs(PLUGIN.pendingSquads) do
    if table.HasValue(squad.members, steamID) then
      return squad
    end
  end

  return nil
end

--- Invites `target` to the squad led by `leader`.
--- @param leader Player
--- @param target Player
--- @return boolean, string?
function PLUGIN.inviteToSquad(leader, target)
  local leaderSteamID = leader:SteamID()
  local squad         = PLUGIN.pendingSquads[leaderSteamID]

  if not squad then
    return false, "You are not leading a squad"
  end

  if #squad.members >= PLUGIN.SQUAD_MAX_SIZE then
    return false, "Squad is already full (" .. PLUGIN.SQUAD_MAX_SIZE .. " players maximum)"
  end

  local targetSteamID = target:SteamID()

  if table.HasValue(squad.members, targetSteamID) then
    return false, target:Nick() .. " is already in your squad"
  end

  if table.HasValue(squad.pendingInvites, targetSteamID) then
    return false, target:Nick() .. " has already been invited"
  end

  if PLUGIN.getSquadForPlayer(targetSteamID) then
    return false, target:Nick() .. " is already in another squad"
  end

  table.insert(squad.pendingInvites, targetSteamID)

  -- Notify the invited player.
  net.Start("versus.endurance.invitePlayer")
  net.WriteString(leaderSteamID)
  net.WriteString(leader:Nick())
  net.Send(target)

  PLUGIN.syncSquadStateToLeader(leaderSteamID)
  return true
end

--- Called when `player` accepts an invitation from the squad led by `leaderSteamID`.
--- @param player Player
--- @param leaderSteamID string
--- @return boolean, string?
function PLUGIN.acceptInvite(player, leaderSteamID)
  local squad = PLUGIN.pendingSquads[leaderSteamID]

  if not squad then
    return false, "Squad no longer exists"
  end

  local steamID = player:SteamID()

  if not table.HasValue(squad.pendingInvites, steamID) then
    return false, "You have not been invited to this squad"
  end

  if #squad.members >= PLUGIN.SQUAD_MAX_SIZE then
    return false, "Squad is already full"
  end

  -- Remove from pending invites and add to members.
  table.RemoveByValue(squad.pendingInvites, steamID)
  table.insert(squad.members, steamID)

  PLUGIN.syncSquadStateToAll(leaderSteamID)
  return true
end

--- Called when `player` declines an invitation.
--- @param player Player
--- @param leaderSteamID string
function PLUGIN.declineInvite(player, leaderSteamID)
  local squad = PLUGIN.pendingSquads[leaderSteamID]

  if not squad then return end

  table.RemoveByValue(squad.pendingInvites, player:SteamID())
  PLUGIN.syncSquadStateToAll(leaderSteamID)
end

--- Called when `player` marks themselves as ready.
--- Once all members are ready and the squad meets the minimum size, matchmaking begins.
--- @param player Player
--- @return boolean, string?
function PLUGIN.readyUp(player)
  local steamID = player:SteamID()
  local squad   = PLUGIN.getSquadForPlayer(steamID)

  if not squad then
    return false, "You are not in a squad"
  end

  if table.HasValue(squad.readied, steamID) then
    return false, "You are already marked as ready"
  end

  table.insert(squad.readied, steamID)
  PLUGIN.syncSquadStateToAll(squad.leader)

  -- Check if all members are ready.
  if #squad.readied < #squad.members then
    return true
  end

  -- Minimum size check.
  if #squad.members < PLUGIN.SQUAD_MIN_SIZE then
    return false, "You need at least " .. PLUGIN.SQUAD_MIN_SIZE .. " players to start"
  end

  -- All ready — begin matchmaking.
  PLUGIN.beginMatchmaking(squad)
  return true
end

--- Disbands the pending squad led by `leader`.
--- @param leader Player
function PLUGIN.disbandSquad(leader)
  local leaderSteamID = leader:SteamID()
  local squad         = PLUGIN.pendingSquads[leaderSteamID]

  if not squad then return end

  -- Notify all members.
  for _, memberSteamID in ipairs(squad.members) do
    local ply = PLUGIN.findPlayerBySteamID(memberSteamID)

    if IsValid(ply) and ply:SteamID() ~= leaderSteamID then
      net.Start("versus.endurance.matchmakingResult")
      net.WriteBool(false)
      net.WriteString("The squad was disbanded by the leader")
      net.Send(ply)
    end
  end

  PLUGIN.pendingSquads[leaderSteamID] = nil
end

--- Starts the matchmaking process: writes the squad to the database and sends
--- `permissions.AskToConnect` to all members.
--- @param squad table
function PLUGIN.beginMatchmaking(squad)
  local enduranceServer = PLUGIN.convarEnduranceServer:GetString()

  if enduranceServer == "" then
    PLUGIN.notifySquad(squad, false, "No endurance server is configured")
    return
  end

  PLUGIN.registerSquadInDatabase(squad.members, function(squadID, spawnID)
    PLUGIN.notifySquad(squad, true, enduranceServer, spawnID)
    PLUGIN.pendingSquads[squad.leader] = nil
  end, function(err)
    PLUGIN.notifySquad(squad, false, "Matchmaking failed: " .. tostring(err))
  end)
end

--- Notifies every member of a squad about the matchmaking result.
--- When `success` is true, `data` is the server address and `spawnID` is included.
--- When `success` is false, `data` is an error message.
--- @param squad table
--- @param success boolean
--- @param data string
--- @param spawnID? string
function PLUGIN.notifySquad(squad, success, data, spawnID)
  for _, memberSteamID in ipairs(squad.members) do
    local ply = PLUGIN.findPlayerBySteamID(memberSteamID)

    if not IsValid(ply) then continue end

    net.Start("versus.endurance.matchmakingResult")
    net.WriteBool(success)
    net.WriteString(data)
    net.Send(ply)
  end
end

--- Sends the current squad state to all online members of the squad led by `leaderSteamID`.
--- @param leaderSteamID string
function PLUGIN.syncSquadStateToAll(leaderSteamID)
  local squad = PLUGIN.pendingSquads[leaderSteamID]

  if not squad then return end

  for _, memberSteamID in ipairs(squad.members) do
    local ply = PLUGIN.findPlayerBySteamID(memberSteamID)

    if IsValid(ply) then
      PLUGIN.sendSquadState(ply, squad)
    end
  end
end

--- Sends the squad state to the leader only (e.g. after forming or inviting).
--- @param leaderSteamID string
function PLUGIN.syncSquadStateToLeader(leaderSteamID)
  local squad = PLUGIN.pendingSquads[leaderSteamID]

  if not squad then return end

  local leader = PLUGIN.findPlayerBySteamID(leaderSteamID)

  if IsValid(leader) then
    PLUGIN.sendSquadState(leader, squad)
  end
end

--- Writes the squad state net message to `player`.
--- @param player Player
--- @param squad table
function PLUGIN.sendSquadState(player, squad)
  local memberNames = {}

  for _, memberSteamID in ipairs(squad.members) do
    local ply = PLUGIN.findPlayerBySteamID(memberSteamID)
    table.insert(memberNames, {
      steamID = memberSteamID,
      name    = IsValid(ply) and ply:Nick() or memberSteamID,
      isReady = table.HasValue(squad.readied, memberSteamID),
    })
  end

  net.Start("versus.endurance.syncSquadState")
  net.WriteString(squad.leader)
  net.WriteUInt(#memberNames, 4)

  for _, entry in ipairs(memberNames) do
    net.WriteString(entry.steamID)
    net.WriteString(entry.name)
    net.WriteBool(entry.isReady)
  end

  net.WriteUInt(#squad.pendingInvites, 4)
  net.Send(player)
end

--- Returns the connected player with the given steam ID, or an invalid entity.
--- @param steamID string
--- @return Player
function PLUGIN.findPlayerBySteamID(steamID)
  for _, ply in player.Iterator() do
    if ply:SteamID() == steamID then
      return ply
    end
  end

  return NULL
end

--[[
  Endurance-server-side wave system
--]]

--- Sets up the wave system for one squad arena identified by `spawnEntity`.
--- @param spawnEntity Entity  The versus_squad_spawn entity for this arena
--- @param steamIDs table  List of member steam ID strings (used to track alive players)
function PLUGIN.startWavesForArena(spawnEntity, steamIDs)
  local spawnID = spawnEntity:GetSpawnID()

  PLUGIN.activeSquads[spawnID] = {
    spawnEntity = spawnEntity,
    members     = steamIDs,
    wave        = 0,
    spawnedNPCs = {},
  }

  PLUGIN.spawnNextWave(spawnID)
end

--- Spawns the next wave for the arena identified by `spawnID`.
--- @param spawnID string
function PLUGIN.spawnNextWave(spawnID)
  local state = PLUGIN.activeSquads[spawnID]

  if not state then return end

  state.wave = state.wave + 1

  local waveNumber    = state.wave
  local spawnEntity   = state.spawnEntity
  local origin        = IsValid(spawnEntity) and spawnEntity:GetPos() or Vector(0, 0, 0)
  local healthScale   = 1 + PLUGIN.WAVE_HEALTH_SCALE * (waveNumber - 1)
  local speedScale    = 1 + PLUGIN.WAVE_SPEED_SCALE  * (waveNumber - 1)
  local enemyCount    = 3 + waveNumber  -- 4 on wave 1, 5 on wave 2, etc.

  print(string.format("[Endurance] Arena '%s': starting wave %d (%d enemies, %.1fx hp, %.1fx speed)",
    spawnID, waveNumber, enemyCount, healthScale, speedScale))

  for i = 1, enemyCount do
    local angle     = math.rad((i / enemyCount) * 360)
    local offset    = Vector(math.cos(angle) * 150, math.sin(angle) * 150, 0)
    local spawnPos  = origin + offset

    local npc = ents.Create("npc_zombie")

    if not IsValid(npc) then continue end

    npc:SetPos(spawnPos)
    npc:SetAngles(Angle(0, math.random(0, 360), 0))
    npc:Spawn()
    npc:Activate()

    local baseHealth = 50
    local health     = math.floor(baseHealth * healthScale)
    npc:SetHealth(health)
    npc:SetMaxHealth(health)

    -- Increase movement speed via the NPC's schedule / runspeed.
    local baseSpeed = 80
    npc:SetSchedule(SCHED_MOVE_AWAY_FAILSAFE) -- reset; actual speed handled below
    npc:SetMovementActivity(ACT_RUN)
    npc:GetPhysicsObject() -- ensure physics is ready
    -- Store scale on the NPC so the hook can read it.
    npc._VersusEnduranceSpeedScale = speedScale

    npc._VersusEnduranceSpawnID = spawnID
    table.insert(state.spawnedNPCs, npc)
  end

  -- Track how many must die before the next wave begins.
  state.totalNPCs  = enemyCount
  state.killedNPCs = 0
end

--- Called when an endurance NPC is killed.  If all NPCs in the wave are dead,
--- schedules the next wave after WAVE_INTERVAL seconds.
--- @param npc Entity
function PLUGIN.onEnduranceNPCKilled(npc)
  local spawnID = npc._VersusEnduranceSpawnID

  if not spawnID then return end

  local state = PLUGIN.activeSquads[spawnID]

  if not state then return end

  state.killedNPCs = state.killedNPCs + 1

  if state.killedNPCs < state.totalNPCs then
    return
  end

  print(string.format("[Endurance] Arena '%s': wave %d cleared.  Next wave in %d seconds.",
    spawnID, state.wave, PLUGIN.WAVE_INTERVAL))

  timer.Simple(PLUGIN.WAVE_INTERVAL, function()
    if PLUGIN.activeSquads[spawnID] then
      PLUGIN.spawnNextWave(spawnID)
    end
  end)
end

--- Called when all members of an arena's squad have died.
--- Frees the spawn reservation and removes the arena state.
--- @param spawnID string
function PLUGIN.onSquadWiped(spawnID)
  print(string.format("[Endurance] Arena '%s': squad wiped out on wave %d.", spawnID,
    PLUGIN.activeSquads[spawnID] and PLUGIN.activeSquads[spawnID].wave or 0))

  PLUGIN.freeSquadSpawn(spawnID)
  PLUGIN.activeSquads[spawnID] = nil
end
