local PLUGIN = PLUGIN

util.AddNetworkString("versus.bounty_board.open")
util.AddNetworkString("versus.bounty_board.data")
util.AddNetworkString("versus.bounty_board.pickUp")
util.AddNetworkString("versus.bounty_board.turnIn")
util.AddNetworkString("versus.bounty_board.notification")

-- Cached active bounties for this server (loaded from DB on start-up)
PLUGIN.activeBounties = PLUGIN.activeBounties or {}

-- Per-player in-memory progress: [steamID][bountyDBID] = { progress, completed_at, turned_in }
-- A key only exists once the player has picked up the bounty.
PLUGIN.playerBounties = PLUGIN.playerBounties or {}

--[[
  Helpers
--]]

--- Returns the Unix timestamp for the next midnight UTC after now.
--- @return number
local function nextMidnightUTC()
  local now   = os.time()
  local today = math.floor(now / PLUGIN.SECONDS_PER_DAY) * PLUGIN.SECONDS_PER_DAY
  return today + PLUGIN.SECONDS_PER_DAY
end

--- Returns true if the NPC class matches a kill_npc bounty definition.
--- @param definition table  Bounty definition
--- @param class      string NPC class string
--- @return boolean
local function npcMatchesBounty(definition, class)
  if definition.npcClass then
    return definition.npcClass == class
  elseif definition.npcClasses then
    for _, c in ipairs(definition.npcClasses) do
      if c == class then return true end
    end
  end
  return false
end

--- Returns the in-memory progress entry for a player/bounty, creating it if necessary.
--- Only call this when the player has already picked up the bounty.
--- Does NOT write to the database.
--- @param steamID    string
--- @param bountyDBID number  Row id from the bounties table
--- @return table  { progress, completed_at, turned_in }
local function getOrCreatePlayerBounty(steamID, bountyDBID)
  PLUGIN.playerBounties[steamID] = PLUGIN.playerBounties[steamID] or {}

  if not PLUGIN.playerBounties[steamID][bountyDBID] then
    PLUGIN.playerBounties[steamID][bountyDBID] = {
      progress     = 0,
      completed_at = nil,
      turned_in    = false,
    }
  end

  return PLUGIN.playerBounties[steamID][bountyDBID]
end

--[[
  Database helpers
--]]

--- Upserts a player_bounties row (creates or updates progress).
--- @param steamID    string
--- @param bountyDBID number
--- @param progress   number
--- @param completedAt number|nil  Unix timestamp or nil
--- @param turnedIn   boolean
local function savePlayerBounty(steamID, bountyDBID, progress, completedAt, turnedIn)
  local completedAtSQL = completedAt and tostring(completedAt) or "NULL"
  local turnedInVal    = turnedIn and 1 or 0

  local sql            = string.format(
    "INSERT INTO `player_bounties` (`steam_id`, `bounty_id`, `progress`, `completed_at`, `turned_in`)" ..
    " VALUES (?, %d, %d, %s, %d)" ..
    " ON DUPLICATE KEY UPDATE `progress` = %d, `completed_at` = %s, `turned_in` = %d",
    bountyDBID, progress, completedAtSQL, turnedInVal,
    progress, completedAtSQL, turnedInVal
  )

  local values         = { versus.player.getValueTypeDefinition(steamID) }

  versus.database.queryPrepared(sql, values, nil, function(err)
    ErrorNoHalt("[BountyBoard] Failed to save player bounty: " .. tostring(err) .. "\n")
  end)
end

--- Increments a player's progress on a bounty by `amount` and marks complete if target reached.
--- Writes to DB and returns the updated entry.
--- @param player     Player
--- @param bountyRow  table  Entry from PLUGIN.activeBounties: { id, key, target_count, scale, reward, expires_at }
--- @param amount     number
--- @return table  Updated in-memory entry
local function incrementProgress(player, bountyRow, amount)
  local definition = PLUGIN.definitions[bountyRow.key]
  if not definition then return end

  local steamID = player:SteamID()
  local entry   = getOrCreatePlayerBounty(steamID, bountyRow.id)

  if entry.turned_in or entry.completed_at then
    return entry -- already done
  end

  entry.progress = entry.progress + amount

  local completed = false
  if entry.progress >= bountyRow.target_count then
    entry.progress     = bountyRow.target_count
    entry.completed_at = os.time()
    completed          = true
  end

  savePlayerBounty(steamID, bountyRow.id, entry.progress, entry.completed_at, entry.turned_in)

  if completed then
    versus.message.notify(
      player,
      string.format('Bounty complete: "%s"! Return to the Bounty Board to collect your reward.', definition.name),
      NOTIFY_HINT
    )
  end

  return entry
end

--[[
  Daily bounty management
--]]

--- Picks DAILY_BOUNTY_COUNT random definitions and inserts them into the bounties table.
--- For each definition a random target count is rolled (in steps between randomMin and
--- randomMax). A 0-1 scale is derived from that step for display/debugging.
---
--- Reward model:
--- - baseReward is the reward at randomMin.
--- - Reward then scales linearly with the rolled target count up to randomMax.
--- Calls callback(insertedRows) where each row has .id, .key, .target_count, .scale, .reward, .expires_at.
--- @param expiresAt number  Unix timestamp
--- @param callback  function
local function generateDailyBounties(expiresAt, callback)
  local allKeys = table.GetKeys(PLUGIN.definitions)
  table.Shuffle(allKeys)

  local count    = math.min(PLUGIN.DAILY_BOUNTY_COUNT, #allKeys)
  local selected = {}

  for i = 1, count do
    table.insert(selected, allKeys[i])
  end

  local inserted = {}
  local pending  = #selected

  if pending == 0 then
    callback(inserted)
    return
  end

  for _, key in ipairs(selected) do
    local def         = PLUGIN.definitions[key]

    -- Roll a random step index between 0 and stepCount (inclusive).
    -- Guard against misconfigured definitions (randomStep must be positive).
    local safeStep    = math.max(1, def.randomStep)
    local stepCount   = math.max(0, math.floor((def.randomMax - def.randomMin) / safeStep))
    local stepIdx     = math.random(0, stepCount)
    local targetCount = def.randomMin + stepIdx * safeStep
    local scale       = stepCount > 0 and (stepIdx / stepCount) or 1.0

    -- baseReward is the payout for randomMin; scale reward directly with rolled target count.
    local safeMin     = math.max(1, def.randomMin)
    local reward      = math.max(1, math.Round(def.baseReward * (targetCount / safeMin)))

    local sql         =
    "INSERT INTO `bounties` (`bounty_key`, `target_count`, `scale`, `reward`, `created_at`, `expires_at`) VALUES (?, ?, ?, ?, ?, ?)"
    local values      = {
      versus.player.getValueTypeDefinition(key),
      versus.player.getValueTypeDefinition(targetCount),
      versus.player.getValueTypeDefinition(scale),
      versus.player.getValueTypeDefinition(reward),
      versus.player.getValueTypeDefinition(os.time()),
      versus.player.getValueTypeDefinition(expiresAt),
    }

    versus.database.queryPrepared(sql, values, function(_, lastInsert)
      table.insert(inserted, {
        id           = lastInsert,
        key          = key,
        target_count = targetCount,
        scale        = scale,
        reward       = reward,
        expires_at   = expiresAt,
      })
      pending = pending - 1
      if pending == 0 then
        callback(inserted)
      end
    end, function(err)
      ErrorNoHalt("[BountyBoard] Failed to insert bounty: " .. tostring(err) .. "\n")
      pending = pending - 1
      if pending == 0 then
        callback(inserted)
      end
    end, true)
  end
end

--- Loads today's active bounties from the database, generating them if none exist yet.
--- @param callback function  Called with an array of {id, key, target_count, scale, reward, expires_at} tables
local function loadOrGenerateDailyBounties(callback)
  local now = os.time()

  local sql = string.format(
    "SELECT `id`, `bounty_key`, `target_count`, `scale`, `reward`, `expires_at` FROM `bounties` WHERE `expires_at` > %d",
    now
  )

  versus.database.query(sql, function(result)
    if result and #result > 0 then
      local bounties = {}
      for _, row in ipairs(result) do
        table.insert(bounties, {
          id           = tonumber(row.id),
          key          = row.bounty_key,
          target_count = tonumber(row.target_count),
          scale        = tonumber(row.scale),
          reward       = tonumber(row.reward),
          expires_at   = tonumber(row.expires_at),
        })
      end
      callback(bounties)
    else
      -- No active bounties – generate a fresh set for today
      generateDailyBounties(nextMidnightUTC(), function(inserted)
        callback(inserted)
      end)
    end
  end, function(err)
    ErrorNoHalt("[BountyBoard] Failed to query bounties: " .. tostring(err) .. "\n")
    callback({})
  end)
end

--- Loads a player's progress for the current active bounties from the DB.
--- Stale (expired) rows are collected, the player is notified, and those rows are deleted.
--- @param player   Player
--- @param callback function  Called when loading is complete
function PLUGIN.loadPlayerBounties(player, callback)
  if player:IsBot() then
    if callback then callback() end
    return
  end

  local steamID = player:SteamID()

  -- Collect active bounty IDs to build an IN clause
  local activeIDs = {}
  for _, b in ipairs(PLUGIN.activeBounties) do
    table.insert(activeIDs, tostring(b.id))
  end

  -- Step 1: find expired, unturned-in entries to notify the player
  local expiredSQL = string.format(
    "SELECT pb.`bounty_id`, b.`bounty_key` " ..
    " FROM `player_bounties` pb" ..
    " JOIN `bounties` b ON b.`id` = pb.`bounty_id`" ..
    " WHERE pb.`steam_id` = ? AND b.`expires_at` <= %d AND pb.`turned_in` = 0",
    os.time()
  )

  local values = { versus.player.getValueTypeDefinition(steamID) }

  versus.database.queryPrepared(expiredSQL, values, function(expiredResult)
    if not IsValid(player) then
      if callback then callback() end
      return
    end

    -- Notify player about any expired, unturned-in bounties
    if expiredResult and #expiredResult > 0 then
      local names = {}
      local expiredIDs = {}

      for _, row in ipairs(expiredResult) do
        local def = PLUGIN.definitions[row.bounty_key]
        if def then
          table.insert(names, '"' .. def.name .. '"')
        end
        table.insert(expiredIDs, tostring(row.bounty_id))
      end

      if #names > 0 then
        versus.message.notify(
          player,
          "The following bounties have expired: " .. table.concat(names, ", ") .. ".",
          NOTIFY_HINT
        )
      end

      -- Delete stale rows
      local deleteSQL = string.format(
        "DELETE FROM `player_bounties` WHERE `steam_id` = ? AND `bounty_id` IN (%s)",
        table.concat(expiredIDs, ", ")
      )

      versus.database.queryPrepared(deleteSQL, values, nil, function(err)
        ErrorNoHalt("[BountyBoard] Failed to delete expired player bounties: " .. tostring(err) .. "\n")
      end)
    end

    -- Step 2: load current progress for active bounties
    if #activeIDs == 0 then
      PLUGIN.playerBounties[steamID] = {}
      if callback then callback() end
      return
    end

    local progressSQL = string.format(
      "SELECT `bounty_id`, `progress`, `completed_at`, `turned_in` " ..
      " FROM `player_bounties`" ..
      " WHERE `steam_id` = ? AND `bounty_id` IN (%s)",
      table.concat(activeIDs, ", ")
    )

    versus.database.queryPrepared(progressSQL, values, function(progressResult)
      if not IsValid(player) then
        if callback then callback() end
        return
      end

      PLUGIN.playerBounties[steamID] = {}

      if progressResult then
        for _, row in ipairs(progressResult) do
          local bid = tonumber(row.bounty_id)
          PLUGIN.playerBounties[steamID][bid] = {
            progress     = tonumber(row.progress) or 0,
            completed_at = tonumber(row.completed_at) or nil,
            turned_in    = row.turned_in == "1" or row.turned_in == 1,
          }
        end
      end

      if callback then callback() end
    end, function(err)
      ErrorNoHalt("[BountyBoard] Failed to load player bounties: " .. tostring(err) .. "\n")
      PLUGIN.playerBounties[steamID] = {}
      if callback then callback() end
    end)
  end, function(err)
    ErrorNoHalt("[BountyBoard] Failed to query expired bounties: " .. tostring(err) .. "\n")
    PLUGIN.playerBounties[steamID] = {}
    if callback then callback() end
  end)
end

--- Sends the current active bounties and the player's progress to the player's client.
--- @param player Player
function PLUGIN.sendBountiesTo(player)
  if not IsValid(player) or player:IsBot() then return end

  local steamID = player:SteamID()
  local entries = PLUGIN.activeBounties
  local now     = os.time()

  net.Start("versus.bounty_board.data")
  net.WriteUInt(#entries, PLUGIN.BIT_BOUNTY_DB_ID)
  net.WriteUInt(now, 32)

  for _, bountyRow in ipairs(entries) do
    local def          = PLUGIN.definitions[bountyRow.key]
    local entry        = PLUGIN.playerBounties[steamID] and PLUGIN.playerBounties[steamID][bountyRow.id]

    local progress     = entry and entry.progress or 0
    local completed_at = entry and entry.completed_at or 0
    local turned_in    = entry and entry.turned_in or false
    -- A row in player_bounties only exists once the bounty is picked up
    local picked_up    = entry ~= nil

    net.WriteUInt(bountyRow.id, PLUGIN.BIT_BOUNTY_DB_ID)
    net.WriteString(bountyRow.key)
    net.WriteUInt(bountyRow.expires_at, 32)
    -- definition fields – description is formatted with the rolled count
    local description = def and string.format(def.description, bountyRow.target_count) or ""
    net.WriteString(def and def.name or bountyRow.key)
    net.WriteString(description)
    net.WriteUInt(bountyRow.target_count, PLUGIN.BIT_PROGRESS)
    net.WriteUInt(bountyRow.reward, PLUGIN.BIT_REWARD)
    -- player progress
    net.WriteUInt(progress, PLUGIN.BIT_PROGRESS)
    net.WriteUInt(completed_at, 32)
    net.WriteBool(turned_in)
    net.WriteBool(picked_up)
  end

  net.Send(player)
end

--[[
  NPC kill tracking
--]]

--- Called on each NPC kill to advance matching bounties for the killer.
--- @param npc      Entity
--- @param attacker Entity  Expected to be a Player
function PLUGIN.onNPCKilled(npc, attacker)
  if not IsValid(attacker) or not attacker:IsPlayer() then return end
  if #PLUGIN.activeBounties == 0 then return end

  local isEndurance = GetGlobalBool("VersusEnduranceMap", false)
  local npcClass    = npc:GetClass()
  local steamID     = attacker:SteamID()
  local now         = os.time()

  for _, bountyRow in ipairs(PLUGIN.activeBounties) do
    if bountyRow.expires_at <= now then continue end

    local def = PLUGIN.definitions[bountyRow.key]
    if not def or def.type ~= "kill_npc" then continue end
    if def.requireEndurance and not isEndurance then continue end
    if not npcMatchesBounty(def, npcClass) then continue end

    local entry = PLUGIN.playerBounties[steamID] and PLUGIN.playerBounties[steamID][bountyRow.id]
    if not entry or entry.turned_in or entry.completed_at then continue end

    incrementProgress(attacker, bountyRow, 1)
  end
end

--[[
  Encounter camp clear tracking
--]]

--- Called when a monster camp is fully cleared (hook fired from encounters plugin).
--- @param campID   string  Encounter type ID (e.g. "combine_checkpoint")
--- @param instance table   Active camp instance
--- @param attacker Entity  Player who killed the last NPC (may be invalid)
function PLUGIN.onEncounterCampCleared(campID, instance, attacker)
  if not IsValid(attacker) or not attacker:IsPlayer() then return end
  if #PLUGIN.activeBounties == 0 then return end

  local now     = os.time()
  local steamID = attacker:SteamID()

  for _, bountyRow in ipairs(PLUGIN.activeBounties) do
    if bountyRow.expires_at <= now then continue end

    local def = PLUGIN.definitions[bountyRow.key]
    if not def or def.type ~= "clear_encounter" then continue end
    if def.encounterID ~= campID then continue end

    local entry = PLUGIN.playerBounties[steamID] and PLUGIN.playerBounties[steamID][bountyRow.id]
    if not entry or entry.turned_in or entry.completed_at then continue end

    incrementProgress(attacker, bountyRow, 1)
  end
end

--[[
  Turn-in
--]]

--- Gives the cash reward for a turned-in bounty and shows a notification.
--- @param player     Player
--- @param bountyRow  table   Active bounty row {id, key, target_count, scale, reward, expires_at}
local function grantBountyReward(player, bountyRow)
  local def = PLUGIN.definitions[bountyRow.key]
  if not def then return end

  versus.finance.giveMoney(player, bountyRow.reward, "Bounty reward: " .. def.name)

  versus.message.notify(
    player,
    string.format('Bounty "%s" turned in! You received $%d.', def.name, bountyRow.reward),
    NOTIFY_HINT
  )
end

net.Receive("versus.bounty_board.turnIn", function(len, player)
  if not IsValid(player) then return end

  local bountyDBID = net.ReadUInt(PLUGIN.BIT_BOUNTY_DB_ID)
  local now        = os.time()
  local steamID    = player:SteamID()

  -- Find the bounty in the active set
  local bountyRow  = nil
  for _, b in ipairs(PLUGIN.activeBounties) do
    if b.id == bountyDBID then
      bountyRow = b
      break
    end
  end

  if not bountyRow then
    versus.message.notify(player, "That bounty is no longer active.", NOTIFY_ERROR)
    return
  end

  if bountyRow.expires_at <= now then
    versus.message.notify(player, "That bounty has expired.", NOTIFY_ERROR)
    return
  end

  local entry = PLUGIN.playerBounties[steamID] and PLUGIN.playerBounties[steamID][bountyDBID]

  if not entry or not entry.completed_at then
    versus.message.notify(player, "You haven't completed that bounty yet.", NOTIFY_ERROR)
    return
  end

  if entry.turned_in then
    versus.message.notify(player, "You have already turned in that bounty.", NOTIFY_ERROR)
    return
  end

  -- Mark as turned in
  entry.turned_in = true
  savePlayerBounty(steamID, bountyDBID, entry.progress, entry.completed_at, true)

  grantBountyReward(player, bountyRow)

  -- Re-send updated data so the client UI reflects the change
  PLUGIN.sendBountiesTo(player)
end)

net.Receive("versus.bounty_board.pickUp", function(len, player)
  if not IsValid(player) then return end

  local bountyDBID = net.ReadUInt(PLUGIN.BIT_BOUNTY_DB_ID)
  local now        = os.time()
  local steamID    = player:SteamID()

  -- Find the bounty in the active set
  local bountyRow  = nil
  for _, b in ipairs(PLUGIN.activeBounties) do
    if b.id == bountyDBID then
      bountyRow = b
      break
    end
  end

  if not bountyRow then
    versus.message.notify(player, "That bounty is no longer active.", NOTIFY_ERROR)
    return
  end

  if bountyRow.expires_at <= now then
    versus.message.notify(player, "That bounty has expired.", NOTIFY_ERROR)
    return
  end

  local entry = PLUGIN.playerBounties[steamID] and PLUGIN.playerBounties[steamID][bountyDBID]

  if entry then
    return -- silently ignore double pick-up
  end

  -- Create the in-memory entry and persist it; its existence signals "picked up"
  getOrCreatePlayerBounty(steamID, bountyDBID)
  savePlayerBounty(steamID, bountyDBID, 0, nil, false)

  local def = PLUGIN.definitions[bountyRow.key]
  versus.message.notify(
    player,
    string.format('Bounty "%s" picked up! Start working on it to collect the reward.',
      def and def.name or "Unknown Bounty"),
    NOTIFY_HINT
  )

  -- Re-send updated data so the client UI reflects the picked-up state
  PLUGIN.sendBountiesTo(player)
end)

net.Receive("versus.bounty_board.open", function(len, player)
  -- Client is requesting a data refresh (sent when the board entity is used)
  PLUGIN.sendBountiesTo(player)
end)

--[[
  Hooks that require access to local functions defined in this file
--]]

--- Load (or generate) daily bounties once the database connection is ready.
function PLUGIN.hook:DatabaseConnected()
  loadOrGenerateDailyBounties(function(bounties)
    PLUGIN.activeBounties = bounties
    print(string.format("[BountyBoard] Loaded %d active bounties.", #bounties))
  end)
end

--- Load a player's bounty progress from the DB during initialisation.
--- Blocks spawning until the async query completes.
function PLUGIN.hook:PlayerInitializing(player, blockingCallbacks)
  if player:IsBot() then return end

  local done = false

  table.insert(blockingCallbacks, function()
    return done
  end)

  PLUGIN.loadPlayerBounties(player, function()
    done = true
  end)
end
