local PLUGIN = PLUGIN

-- Squad state table: maps squadID -> { members = {steamid, ...}, spawnID = string, wave = number, alive = bool }
PLUGIN.activeSquads = PLUGIN.activeSquads or {}

-- Pending squad invitations on the hideout server: maps leaderSteamID -> { members = {}, pendingInvites = {}, readied = {} }
PLUGIN.pendingSquads = PLUGIN.pendingSquads or {}

-- Endurance-server connect-window allowlist: maps steamID64 -> expiry unix timestamp.
-- Populated by the clock-aligned DB poll; checked in CheckPassword.
PLUGIN.allowedSteamIDs = PLUGIN.allowedSteamIDs or {}

-- How many seconds beyond connect_at a player is still permitted to join.
PLUGIN.CONNECT_WINDOW_GRACE = 300

-- Minimum seconds of lead time required before the next clock minute.
-- If fewer than this many seconds remain, we bump to the minute after next.
PLUGIN.CONNECT_WINDOW_MIN_LEAD = 10

util.AddNetworkString("versus.endurance.formSquad")
util.AddNetworkString("versus.endurance.invitePlayer")
util.AddNetworkString("versus.endurance.acceptInvite")
util.AddNetworkString("versus.endurance.declineInvite")
util.AddNetworkString("versus.endurance.readyUp")
util.AddNetworkString("versus.endurance.disbandSquad")
util.AddNetworkString("versus.endurance.leaveSquad")
util.AddNetworkString("versus.endurance.syncSquadState")
util.AddNetworkString("versus.endurance.matchmakingResult")
util.AddNetworkString("versus.endurance.arenaRedirect")
util.AddNetworkString("versus.endurance.matchmakingScheduled")

versus.includePrefixed("sv_hooks.lua")
versus.includePrefixed("sv_test.lua")

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
--- @param connectAt number  Unix timestamp of the clock-minute players may connect
--- @param callback fun(squadID: number, spawnID: string)
--- @param errorCallback? fun(err: string)
function PLUGIN.registerSquadInDatabase(memberSteamIDs, connectAt, callback, errorCallback)
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

          local spawnRow   = rows[1]
          local spawnRowID = spawnRow.id
          local spawnID    = spawnRow.spawn_id

          -- Reserve the spawn for this squad.
          versus.database.queryPrepared(
            "UPDATE `endurance_squad_spawns` SET `squad_id` = ? WHERE `id` = ?",
            { dbNum(squadID), dbNum(spawnRowID) },
            function()
              -- Mark the squad as matchmade (spawn reserved) and record the connect window.
              versus.database.queryPrepared(
                "UPDATE `endurance_squads` SET `status` = 'matchmade', `connect_at` = FROM_UNIXTIME(?) WHERE `id` = ?",
                { dbNum(connectAt), dbNum(squadID) },
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
  local steamID = leader:SteamID64()

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
  local leaderSteamID = leader:SteamID64()
  local squad         = PLUGIN.pendingSquads[leaderSteamID]

  if not squad then
    return false, "You are not leading a squad"
  end

  if #squad.members >= PLUGIN.SQUAD_MAX_SIZE then
    return false, "Squad is already full (" .. PLUGIN.SQUAD_MAX_SIZE .. " players maximum)"
  end

  local targetSteamID = target:SteamID64()

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

  local steamID = player:SteamID64()

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

  table.RemoveByValue(squad.pendingInvites, player:SteamID64())
  PLUGIN.syncSquadStateToAll(leaderSteamID)
end

--- Called when `player` marks themselves as ready.
--- Once all members are ready and the squad meets the minimum size, matchmaking begins.
--- @param player Player
--- @return boolean, string?
function PLUGIN.readyUp(player)
  local steamID = player:SteamID64()
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
  local leaderSteamID = leader:SteamID64()
  local squad         = PLUGIN.pendingSquads[leaderSteamID]

  if not squad then return end

  -- Notify all members.
  for _, memberSteamID in ipairs(squad.members) do
    local ply = PLUGIN.findPlayerBySteamID(memberSteamID)

    if IsValid(ply) and ply:SteamID64() ~= leaderSteamID then
      net.Start("versus.endurance.matchmakingResult")
      net.WriteBool(false)
      net.WriteString("The squad was disbanded by the leader")
      net.Send(ply)
    end
  end

  PLUGIN.pendingSquads[leaderSteamID] = nil
end

--- Removes `member` from the pending squad they belong to (non-leader leave).
--- If the caller is the squad leader, this is a no-op (use disbandSquad instead).
--- @param member Player
function PLUGIN.leaveSquad(member)
  local steamID = member:SteamID64()
  local squad   = PLUGIN.getSquadForPlayer(steamID)

  if not squad then return end

  -- Leaders must disband, not leave.
  if squad.leader == steamID then return end

  table.RemoveByValue(squad.members, steamID)
  table.RemoveByValue(squad.readied, steamID)

  -- Inform the departing member that they have left.
  net.Start("versus.endurance.matchmakingResult")
  net.WriteBool(false)
  net.WriteString("You have left the squad")
  net.Send(member)

  -- Sync updated state to remaining members.
  PLUGIN.syncSquadStateToAll(squad.leader)
end

--- Polls the endurance server every second until it has at least `squadSize` free
--- player slots, then calls `callback()`.  Gives up after `maxWait` seconds and
--- calls `failCallback(reason)` instead.
--- @param serverAddress string  "ip:port" string
--- @param squadSize number
--- @param callback fun()
--- @param failCallback fun(reason: string)
--- @param maxWait? number  Maximum seconds to wait (default 240)
function PLUGIN.waitForSlots(serverAddress, squadSize, callback, failCallback, maxWait)
  local ip, port = serverAddress:match("([^:]+):(%d+)")

  if not ip or not port then
    failCallback("Could not parse server address: " .. serverAddress)
    return
  end

  port = tonumber(port)
  maxWait = maxWait or 240

  local elapsed = 0
  local timerName = "endurance_wait_slots_" .. serverAddress .. "_" .. tostring(SysTime())

  timer.Create(timerName, 1, 0, function()
    elapsed = elapsed + 1

    if elapsed > maxWait then
      timer.Remove(timerName)
      failCallback("Timed out waiting for free slots on " .. serverAddress)
      return
    end

    -- As we are the server, we always want the freshest possible data from the endurance server about how many players are currently connected.
    local bypassCache = true

    versus.serverInfo.getInfo(ip, port, function(success, data)
      if not success then return end -- retry on next tick

      local freeSlots = (data.max_players or 0) - (data.players or 0)

      if freeSlots >= squadSize then
        timer.Remove(timerName)
        callback()
      end
    end, bypassCache)
  end)
end

--- Starts the matchmaking process: writes the squad to the database, then sends
--- `permissions.AskToConnect` to all members once the connect window opens.
--- @param squad table
function PLUGIN.beginMatchmaking(squad)
  local enduranceServer = PLUGIN.convarEnduranceServer:GetString()

  if enduranceServer == "" then
    PLUGIN.notifySquad(squad, false, "No endurance server is configured")
    return
  end

  -- Calculate the next clock-minute boundary at which players may connect.
  -- This gives the endurance server's polling timer time to cache their SteamIDs.
  local now = os.time()
  local secsLeft = 60 - (now % 60)

  if secsLeft < PLUGIN.CONNECT_WINDOW_MIN_LEAD then
    -- Too close to the boundary — bump to the minute after next.
    secsLeft = secsLeft + 60
  end

  local connectAt = now + secsLeft

  -- Capture the squad data before we clear pendingSquads.
  local capturedSquad = squad
  local leaderSteamID = squad.leader

  PLUGIN.registerSquadInDatabase(squad.members, connectAt, function(squadID, spawnID)
    -- Remove from pending immediately so the leader can't double-queue.
    PLUGIN.pendingSquads[leaderSteamID] = nil

    -- Tell each member that matchmaking succeeded and when to expect the connection prompt.
    for _, memberSteamID in ipairs(capturedSquad.members) do
      local ply = PLUGIN.findPlayerBySteamID(memberSteamID)

      if not IsValid(ply) then continue end

      net.Start("versus.endurance.matchmakingScheduled")
      net.WriteString(enduranceServer)
      net.WriteUInt(secsLeft, 16)
      net.Send(ply)
    end

    -- Wait until the connect window opens, then wait for enough free slots before
    -- sending the actual AskToConnect prompt.
    local delay = connectAt - os.time()

    timer.Simple(math.max(0, delay), function()
      PLUGIN.waitForSlots(enduranceServer, #capturedSquad.members, function()
        PLUGIN.notifySquad(capturedSquad, true, enduranceServer, spawnID)
      end, function(reason)
        PLUGIN.notifySquad(capturedSquad, false, "Could not connect: endurance server is full. " .. reason)
      end)
    end)
  end, function(err)
    PLUGIN.notifySquad(capturedSquad, false, "Matchmaking failed: " .. tostring(err))
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

--- Queries the database for squads whose connect window has opened and adds their
--- members to `PLUGIN.allowedSteamIDs`.  Also prunes expired entries.
--- Called every clock minute on the endurance server.
function PLUGIN.refreshAllowedSteamIDsFromDB()
  local now = os.time()

  -- Prune expired cache entries.
  for steamID64, expireTime in pairs(PLUGIN.allowedSteamIDs) do
    if expireTime < now then
      PLUGIN.allowedSteamIDs[steamID64] = nil
    end
  end

  -- Prune squads whose connect window has fully expired (players never connected).
  -- Free their reserved spawns and delete the squad records so the slots can be reused.
  local expiryCutoff = now - PLUGIN.CONNECT_WINDOW_GRACE

  versus.database.queryPrepared(
    "SELECT es.`id`, esp.`spawn_id` FROM `endurance_squads` es " ..
    "LEFT JOIN `endurance_squad_spawns` esp ON esp.`squad_id` = es.`id` " ..
    "WHERE es.`status` = 'matchmade' AND es.`connect_at` IS NOT NULL " ..
    "AND es.`connect_at` <= FROM_UNIXTIME(?)",
    { dbNum(expiryCutoff) },
    function(rows)
      if not rows then return end

      for _, row in ipairs(rows) do
        local squadID = row.id
        local spawnID = row.spawn_id

        -- Don't prune a squad whose arena is currently running waves.
        if spawnID and PLUGIN.activeSquads[spawnID] then continue end

        -- Free the reserved spawn first so the slot is available even if the
        -- squad delete below is interrupted.
        versus.database.queryPrepared(
          "UPDATE `endurance_squad_spawns` SET `squad_id` = NULL WHERE `squad_id` = ?",
          { dbNum(squadID) }
        )

        -- Delete the squad record.
        versus.database.queryPrepared(
          "DELETE FROM `endurance_squads` WHERE `id` = ?",
          { dbNum(squadID) }
        )

        print(string.format("[Endurance] Pruned expired squad (id %d): connect window elapsed with no active run.", squadID))
      end
    end
  )

  -- Fetch all matchmade squads whose connect window has arrived.
  versus.database.queryPrepared(
    "SELECT `members` FROM `endurance_squads` " ..
    "WHERE `status` = 'matchmade' AND `connect_at` IS NOT NULL AND `connect_at` <= FROM_UNIXTIME(?)",
    { dbNum(now) },
    function(rows)
      if not rows then return end

      local expireTime = now + PLUGIN.CONNECT_WINDOW_GRACE

      for _, row in ipairs(rows) do
        local members = util.JSONToTable(row.members) or {}

        for _, steamID64 in ipairs(members) do
          PLUGIN.allowedSteamIDs[steamID64] = expireTime
        end
      end
    end
  )
end

--- Starts the clock-aligned repeating timer that keeps `PLUGIN.allowedSteamIDs` fresh.
--- Fires at the top of the next minute, then every 30 seconds thereafter.
--- Must only be called on the endurance server (VersusEnduranceMap = true).
function PLUGIN.startConnectWindowPolling()
  local delay = 60 - (os.time() % 60)

  timer.Simple(delay, function()
    PLUGIN.refreshAllowedSteamIDsFromDB()

    timer.Create("versus_endurance_connect_window_poll", 30, 0, function()
      PLUGIN.refreshAllowedSteamIDsFromDB()
    end)
  end)

  print(string.format("[Endurance] Connect-window polling starts in %d second(s) (aligned to clock minute).", delay))
end

--- Returns the connected player with the given steam ID, or an invalid entity.
--- @param steamID string
--- @return Player
function PLUGIN.findPlayerBySteamID(steamID)
  for _, ply in player.Iterator() do
    if ply:SteamID64() == steamID then
      return ply
    end
  end

  return NULL
end

--[[
  Endurance-server-side wave system
--]]

--- Returns all versus_npc_spawn_point entities whose ArenaID matches `arenaID`.
--- These are the only spawn points the wave system will use for that arena.
--- @param arenaID string  Matches the SpawnID of the arena's versus_squad_spawn entity
--- @return Entity[]
function PLUGIN.getArenaSpawnPoints(arenaID)
  local result = {}

  for _, ent in ipairs(ents.FindByClass("versus_npc_spawn_point")) do
    if IsValid(ent) and ent:GetArenaID() == arenaID then
      table.insert(result, ent)
    end
  end

  return result
end

--- Picks the best spawn point from `spawnPoints`, preferring one that no player
--- can currently see.  Falls back to a random point if all are observed.
--- @param spawnPoints Entity[]
--- @return Entity?
function PLUGIN.pickBestArenaSpawnPoint(spawnPoints)
  if #spawnPoints == 0 then return nil end

  local unobserved = {}

  for _, ent in ipairs(spawnPoints) do
    if IsValid(ent) and not versus.npc.canAnyPlayerSeeEntity(ent) then
      table.insert(unobserved, ent)
    end
  end

  if #unobserved > 0 then
    return unobserved[math.random(#unobserved)]
  end

  return spawnPoints[math.random(#spawnPoints)]
end

--- Returns the active WAVE_CONFIG tier for `waveNumber`.
--- Finds the tier with the highest `fromWave` that is still <= `waveNumber`.
--- @param waveNumber number
--- @return table  Active tier table from PLUGIN.WAVE_CONFIG
function PLUGIN.resolveWaveTier(waveNumber)
  local activeTier = PLUGIN.WAVE_CONFIG[1]

  for _, tier in ipairs(PLUGIN.WAVE_CONFIG) do
    if tier.fromWave <= waveNumber then
      activeTier = tier
    end
  end

  return activeTier
end

--- Grants XP to all alive squad members for surviving a wave.
--- XP scales linearly with wave number: XP_PER_WAVE * waveNumber.
--- @param spawnID string
--- @param waveNumber number
function PLUGIN.grantWaveXP(spawnID, waveNumber)
  local state = PLUGIN.activeSquads[spawnID]

  if not state then return end

  local xpAmount = PLUGIN.XP_PER_WAVE * waveNumber

  for _, steamID in ipairs(state.members) do
    local ply = PLUGIN.findPlayerBySteamID(steamID)

    if IsValid(ply) and ply:Alive() then
      versus.rewards.addXP(ply, xpAmount)
    end
  end

  print(string.format("[Endurance] Arena '%s': granted %d XP to surviving members (wave %d).",
    spawnID, xpAmount, waveNumber))
end

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

  -- Record each member's XP at the start so we can show earned XP on the reward screen.
  for _, steamID in ipairs(steamIDs) do
    local ply = PLUGIN.findPlayerBySteamID(steamID)

    if IsValid(ply) then
      ply._VersusEnduranceStartXP = versus.rewards.getPlayerXP(ply)
    end
  end

  PLUGIN.spawnNextWave(spawnID)
end

--- Spawns the next wave for the arena identified by `spawnID`.
--- Uses PLUGIN.WAVE_CONFIG to determine which NPC classes, counts,
--- health values, models, and loot tables apply to the current wave.
--- NPCs are spawned via the NPC library at arena-tagged versus_npc_spawn_point
--- entities and immediately set to swarm all alive squad members.
--- @param spawnID string
function PLUGIN.spawnNextWave(spawnID)
  local state = PLUGIN.activeSquads[spawnID]

  if not state then return end

  state.wave        = state.wave + 1

  local waveNumber  = state.wave
  local tier        = PLUGIN.resolveWaveTier(waveNumber)
  local spawnPoints = PLUGIN.getArenaSpawnPoints(spawnID)
  local fallbackPos = IsValid(state.spawnEntity) and state.spawnEntity:GetPos() or Vector(0, 0, 0)

  -- Collect alive squad members to use as chase targets.
  local targets     = {}

  for _, steamID in ipairs(state.members) do
    local ply = PLUGIN.findPlayerBySteamID(steamID)

    if IsValid(ply) and ply:Alive() then
      table.insert(targets, ply)
    end
  end

  local allSpawned = {}
  local totalNPCs  = 0

  for _, npcEntry in ipairs(tier.npcs) do
    -- Count: base + optional per-wave increase.
    local waveOffset    = waveNumber - tier.fromWave
    local count         = npcEntry.count + math.floor(waveOffset * (npcEntry.countIncreasePerWave or 0))

    -- Health: base × healthIncreasePerWave^(waves since tier start).
    local health        = math.floor(npcEntry.baseHealth * (npcEntry.healthIncreasePerWave ^ waveOffset))

    -- Choose a spawn point for this group.
    local spawnEnt      = PLUGIN.pickBestArenaSpawnPoint(spawnPoints)
    local spawnPos      = spawnEnt and spawnEnt:GetPos() or fallbackPos

    -- Primary chase target (first alive member, if any).
    local primaryTarget = targets[1]

    print(string.format("[Endurance] Arena '%s': wave %d — %d × %s  hp %d",
      spawnID, waveNumber, count, npcEntry.class, health))

    local npcs = versus.npc.spawnNPCsAtPoint(
      npcEntry.class, spawnPos, count, npcEntry.weapons or {}, primaryTarget)

    for _, npc in ipairs(npcs) do
      -- Apply configured health.
      npc:SetHealth(health)
      npc:SetMaxHealth(health)

      -- Apply custom model (visual override; set post-spawn which is safe for NPC hull-based collision).
      if npcEntry.model then
        npc:SetModel(npcEntry.model)
      end

      -- Apply model scale.
      if npcEntry.modelScale and npcEntry.modelScale ~= 1.0 then
        npc:SetModelScale(npcEntry.modelScale, 0)
      end

      -- Chase ALL alive squad members: primary via setChase, rest via relationship.
      if IsValid(primaryTarget) then
        versus.npc.setChase(npc, primaryTarget)
      end

      for i = 2, #targets do
        if IsValid(targets[i]) then
          npc:AddEntityRelationship(targets[i], D_HT, 99)
        end
      end

      -- Attach loot spawner if configured.
      if npcEntry.loot then
        versus.npc.attachLootSpawner(npc, npcEntry.loot)
      end

      -- Tag the NPC so kill events can route back to this arena.
      npc._VersusEnduranceSpawnID = spawnID

      table.insert(allSpawned, npc)
    end

    totalNPCs = totalNPCs + #npcs
  end

  state.spawnedNPCs = allSpawned
  state.totalNPCs   = totalNPCs
  state.killedNPCs  = 0

  print(string.format("[Endurance] Arena '%s': wave %d started (%d NPCs total).",
    spawnID, waveNumber, totalNPCs))
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

  -- Grant XP to all alive members for completing this wave.
  PLUGIN.grantWaveXP(spawnID, state.wave)

  timer.Simple(PLUGIN.WAVE_INTERVAL, function()
    if PLUGIN.activeSquads[spawnID] then
      PLUGIN.spawnNextWave(spawnID)
    end
  end)
end

--- Called when all members of an arena's squad have died.
--- Frees the spawn reservation, then after a short delay redirects all members
--- to the hideout server and kicks anyone who hasn't connected within the kick window.
--- @param spawnID string
function PLUGIN.onSquadWiped(spawnID)
  local state   = PLUGIN.activeSquads[spawnID]
  local wave    = state and state.wave or 0
  local members = state and table.Copy(state.members) or {}

  print(string.format("[Endurance] Arena '%s': squad wiped out on wave %d.", spawnID, wave))

  -- All members are now dead; clear any active spectating sessions for this squad so the
  -- spectating HUD is dismissed before the redirect countdown begins.
  if versus.spectating then
    for _, steamID in ipairs(members) do
      local ply = PLUGIN.findPlayerBySteamID(steamID)

      if IsValid(ply) then
        versus.spectating.clearSpectator(ply)
      end
    end
  end

  PLUGIN.freeSquadSpawn(spawnID)
  PLUGIN.activeSquads[spawnID] = nil

  -- Wait for the last player to finish viewing their XP screen, then redirect everyone.
  timer.Simple(PLUGIN.SQUAD_WIPE_REDIRECT_DELAY, function()
    local hideoutServer = GetConVar("versus_hideout_server"):GetString()

    if hideoutServer == "" then
      print("[Endurance] No hideout server configured (versus_hideout_server); skipping redirect.")
      return
    end

    for _, steamID in ipairs(members) do
      local ply = PLUGIN.findPlayerBySteamID(steamID)

      if not IsValid(ply) then continue end

      net.Start("versus.endurance.arenaRedirect")
      net.WriteString(hideoutServer)
      net.Send(ply)
    end

    -- Kick anyone still on the endurance server after the kick window.
    timer.Simple(PLUGIN.SQUAD_WIPE_KICK_DELAY, function()
      for _, steamID in ipairs(members) do
        local ply = PLUGIN.findPlayerBySteamID(steamID)

        if IsValid(ply) then
          ply:Kick("Please reconnect to the hideout server to play again: " .. hideoutServer)
        end
      end
    end)
  end)
end
