local PLUGIN = PLUGIN

versus.includePrefixed("sv_hooks.lua")

util.AddNetworkString("versus.hitStatistics.requestPlayerStats")
util.AddNetworkString("versus.hitStatistics.requestSuspiciousPlayers")
util.AddNetworkString("versus.hitStatistics.requestPlayersOverview")

-- In-memory storage for pending stats updates (will get committed to db in saveData)
PLUGIN.pendingStats = PLUGIN.pendingStats or {}

function PLUGIN.initializePendingStats(steamID)
  if (not PLUGIN.pendingStats[steamID]) then
    PLUGIN.pendingStats[steamID] = {
      player_hits = {},
      npc_hits = {}
    }
  end
end

function PLUGIN.incrementPendingStat(client, statType, value)
  local steamID = client:SteamID64()

  if (not steamID) then
    return
  end

  PLUGIN.initializePendingStats(steamID)

  if (not PLUGIN.pendingStats[steamID][statType]) then
    PLUGIN.pendingStats[steamID][statType] = 0
  end

  PLUGIN.pendingStats[steamID][statType] = PLUGIN.pendingStats[steamID][statType] + value
end

function PLUGIN.incrementPendingHit(client, hitgroup, targetType)
  local steamID = client:SteamID64()

  if (not steamID) then
    return
  end

  PLUGIN.initializePendingStats(steamID)

  local hitsKey = (targetType == "npc") and "npc_hits" or "player_hits"

  if (not PLUGIN.pendingStats[steamID][hitsKey][hitgroup]) then
    PLUGIN.pendingStats[steamID][hitsKey][hitgroup] = 0
  end

  PLUGIN.pendingStats[steamID][hitsKey][hitgroup] = PLUGIN.pendingStats[steamID][hitsKey][hitgroup] + 1
end

-- Helper function to get pending stats for a specific player by steam ID
function PLUGIN.getPendingStatsBySteamID(steamID)
  return PLUGIN.pendingStats[steamID]
end

-- Helper function to merge pending stats into database results
function PLUGIN.mergePendingStats(dbStats, pendingStats)
  if (not pendingStats) then
    return dbStats
  end

  -- Merge basic stats
  if (pendingStats.shots_fired) then
    dbStats.total_shots = (dbStats.total_shots or 0) + pendingStats.shots_fired
  end

  if (pendingStats.kills) then
    dbStats.kills = (dbStats.kills or 0) + pendingStats.kills
  end

  if (pendingStats.deaths) then
    dbStats.deaths = (dbStats.deaths or 0) + pendingStats.deaths
  end

  if (pendingStats.headshot_kills) then
    dbStats.headshot_kills = (dbStats.headshot_kills or 0) + pendingStats.headshot_kills
  end

  if (pendingStats.npc_kills) then
    dbStats.npc_kills = (dbStats.npc_kills or 0) + pendingStats.npc_kills
  end

  -- Merge player hitgroup stats
  if (pendingStats.player_hits) then
    for hitgroupID, count in pairs(pendingStats.player_hits) do
      local hitgroupName = PLUGIN.hitgroupNames[hitgroupID]

      if (hitgroupName) then
        local columnName = "player_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))
        dbStats[columnName] = (dbStats[columnName] or 0) + count
      end
    end
  end

  -- Merge NPC hitgroup stats
  if (pendingStats.npc_hits) then
    for hitgroupID, count in pairs(pendingStats.npc_hits) do
      local hitgroupName = PLUGIN.hitgroupNames[hitgroupID]

      if (hitgroupName) then
        local columnName = "npc_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))
        dbStats[columnName] = (dbStats[columnName] or 0) + count
      end
    end
  end

  return dbStats
end

--- Helper function to convert stats to array format for chunking
function PLUGIN.convertStatsToArray(stats)
  local statsArray = {}

  -- Add basic stats
  table.insert(statsArray, {
    type = "totals",
    data = stats.totals or {}
  })

  table.insert(statsArray, {
    type = "accuracy",
    data = stats.accuracy or {}
  })

  -- Add player hitgroup data
  for hitgroup, data in pairs(stats.hitgroups or {}) do
    table.insert(statsArray, {
      type = "hitgroup",
      hitgroup = hitgroup,
      data = data
    })
  end

  -- Add NPC hitgroup data
  for hitgroup, data in pairs(stats.npc_hitgroups or {}) do
    table.insert(statsArray, {
      type = "npc_hitgroup",
      hitgroup = hitgroup,
      data = data
    })
  end

  return statsArray
end

function PLUGIN.hook:Think()
  if (versus.util.throttled("hitStatsSave", 300)) then
    return
  end

  PLUGIN.saveData()
end

-- Get player statistics for admin review
function PLUGIN.getPlayerStats(steamID, callback)
  local query = [[
		SELECT
			ps.steam_id,
			ps.total_shots,
			ps.player_hits_generic,
			ps.player_hits_head,
			ps.player_hits_chest,
			ps.player_hits_stomach,
			ps.player_hits_leftarm,
			ps.player_hits_rightarm,
			ps.player_hits_leftleg,
			ps.player_hits_rightleg,
			ps.player_hits_gear,
			ps.npc_hits_generic,
			ps.npc_hits_head,
			ps.npc_hits_chest,
			ps.npc_hits_stomach,
			ps.npc_hits_leftarm,
			ps.npc_hits_rightarm,
			ps.npc_hits_leftleg,
			ps.npc_hits_rightleg,
			ps.npc_hits_gear,
			ps.kills,
			ps.deaths,
			ps.headshot_kills,
			ps.npc_kills
		FROM player_hit_stats ps
		WHERE ps.steam_id = ']] .. steamID .. [['
	]]

  versus.database.query(query, function(result)
    local dbRow = {}

    if (result and #result > 0) then
      dbRow = result[1]
    end

    -- Get pending stats for this player
    local pendingStats = PLUGIN.getPendingStatsBySteamID(steamID)

    -- Merge pending stats with database stats
    local mergedRow = PLUGIN.mergePendingStats(dbRow, pendingStats)

    -- Calculate player hit totals
    local totalShots = tonumber(mergedRow.total_shots) or 0
    local playerTotalHits = 0
    local playerHeadshotHits = tonumber(mergedRow.player_hits_head) or 0
    local npcTotalHits = 0
    local npcHeadshotHits = tonumber(mergedRow.npc_hits_head) or 0
    local kills = tonumber(mergedRow.kills) or 0
    local deaths = tonumber(mergedRow.deaths) or 0
    local headshotKills = tonumber(mergedRow.headshot_kills) or 0
    local npcKills = tonumber(mergedRow.npc_kills) or 0

    -- Sum all hitgroup hits
    local playerHitgroups = {}
    local npcHitgroups = {}
    for hitgroupID, hitgroupName in pairs(PLUGIN.hitgroupNames) do
      local playerCol  = "player_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))
      local npcCol     = "npc_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))

      local playerHits = tonumber(mergedRow[playerCol]) or 0
      local npcHits    = tonumber(mergedRow[npcCol]) or 0

      playerTotalHits  = playerTotalHits + playerHits
      npcTotalHits     = npcTotalHits + npcHits

      if (playerHits > 0) then
        playerHitgroups[hitgroupName] = {
          hits = playerHits,
          avg_damage = 0,
          avg_distance = 0
        }
      end

      if (npcHits > 0) then
        npcHitgroups[hitgroupName] = {
          hits = npcHits,
          avg_damage = 0,
          avg_distance = 0
        }
      end
    end

    -- Calculate accuracy percentages (vs players only, used for suspicion)
    local hitRate = totalShots > 0 and (playerTotalHits / totalShots) * 100 or 0
    local headshotRate = playerTotalHits > 0 and (playerHeadshotHits / playerTotalHits) * 100 or 0
    local npcHitRate = totalShots > 0 and (npcTotalHits / totalShots) * 100 or 0
    local npcHeadshotRate = npcTotalHits > 0 and (npcHeadshotHits / npcTotalHits) * 100 or 0
    local kdRatio = deaths > 0 and (kills / deaths) or kills

    local stats = {
      accuracy = {
        hit_rate = hitRate,
        headshot_rate = headshotRate,
        npc_hit_rate = npcHitRate,
        npc_headshot_rate = npcHeadshotRate
      },
      hitgroups = playerHitgroups,
      npc_hitgroups = npcHitgroups,
      totals = {
        shots_fired = totalShots,
        total_hits = playerTotalHits,
        headshot_hits = playerHeadshotHits,
        total_npc_hits = npcTotalHits,
        headshot_npc_hits = npcHeadshotHits,
        kills = kills,
        deaths = deaths,
        headshot_kills = headshotKills,
        npc_kills = npcKills,
        kd_ratio = kdRatio
      }
    }

    callback(stats)
  end)

  return true
end

-- Get suspicious players based on configurable thresholds
function PLUGIN.getSuspiciousPlayers(callback, thresholds, page, pageSize)
  page = page or 1
  pageSize = pageSize or PLUGIN.paginationLimit
  thresholds = thresholds or {}
  thresholds.min_shots = thresholds.min_shots or 100
  thresholds.max_accuracy = thresholds.max_accuracy or 85
  thresholds.max_headshot_rate = thresholds.max_headshot_rate or 60

  local query = [[
		SELECT
			ps.steam_id,
			p.last_name as steam_name,
			ps.total_shots,
			(ps.player_hits_generic + ps.player_hits_head + ps.player_hits_chest + ps.player_hits_stomach +
			 ps.player_hits_leftarm + ps.player_hits_rightarm + ps.player_hits_leftleg + ps.player_hits_rightleg + ps.player_hits_gear) as player_total_hits,
			ps.player_hits_head as player_headshot_hits
		FROM player_hit_stats ps
		LEFT JOIN `]] .. versus.config["MySQL Player Table"] .. [[` p ON ps.steam_id = p.steamid
		WHERE ps.total_shots >= 0
		ORDER BY (player_total_hits * 100.0 / GREATEST(ps.total_shots, 1)) DESC
	]]

  versus.database.query(query, function(result)
    if (not result) then
      ErrorNoHaltWithStack("Failed to get suspicious players.")
      callback({})
      return
    end

    local suspiciousPlayers = {}

    -- Process database results
    for _, row in ipairs(result) do
      local steamID = row.steam_id
      local pendingStats = PLUGIN.getPendingStatsBySteamID(steamID)
      local mergedRow = PLUGIN.mergePendingStats(row, pendingStats)

      local totalShots = tonumber(mergedRow.total_shots) or 0
      local totalHits = tonumber(mergedRow.player_total_hits) or 0
      local headshotHits = tonumber(mergedRow.player_headshot_hits) or 0

      -- Recalculate total hits from individual hitgroups to account for pending stats
      if (pendingStats and pendingStats.player_hits) then
        totalHits = 0
        for hitgroupID, hitgroupName in pairs(PLUGIN.hitgroupNames) do
          local columnName = "player_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))
          local hits = tonumber(mergedRow[columnName]) or 0
          totalHits = totalHits + hits
        end
        headshotHits = tonumber(mergedRow.player_hits_head) or 0
      end

      if (totalShots >= thresholds.min_shots) then
        local accuracy = (totalHits / totalShots) * 100
        local headshotRate = totalHits > 0 and (headshotHits / totalHits) * 100 or 0

        local suspicionReasons = {}

        if (accuracy > thresholds.max_accuracy) then
          table.insert(suspicionReasons, string.format("High accuracy: %.1f%%", accuracy))
        end

        if (headshotRate > thresholds.max_headshot_rate) then
          table.insert(suspicionReasons, string.format("High headshot rate: %.1f%%", headshotRate))
        end

        if (#suspicionReasons > 0) then
          table.insert(suspiciousPlayers, {
            steam_id = steamID,
            steam_name = row.steam_name or "Unknown",
            accuracy = accuracy,
            headshot_rate = headshotRate,
            total_shots = totalShots,
            total_hits = totalHits,
            reasons = suspicionReasons
          })
        end
      end
    end

    -- Also check players who only have pending stats (no database records yet)
    for steamID, pendingStats in pairs(PLUGIN.pendingStats) do
      -- Skip if this player was already processed from database
      local foundInDb = false
      for _, row in ipairs(result) do
        if (row.steam_id == steamID) then
          foundInDb = true
          break
        end
      end

      if (not foundInDb) then
        local playerName = "Unknown"
        for _, ply in ipairs(player.GetAll()) do
          if (ply:SteamID64() == steamID) then
            playerName = ply:Name()
            break
          end
        end

        local totalShots = pendingStats.shots_fired or 0
        local totalHits = 0
        local headshotHits = 0

        if (pendingStats.player_hits) then
          for hitgroupID, hits in pairs(pendingStats.player_hits) do
            totalHits = totalHits + hits
            if (hitgroupID == HITGROUP_HEAD) then
              headshotHits = hits
            end
          end
        end

        if (totalShots >= thresholds.min_shots) then
          local accuracy = (totalHits / totalShots) * 100
          local headshotRate = totalHits > 0 and (headshotHits / totalHits) * 100 or 0

          local suspicionReasons = {}

          if (accuracy > thresholds.max_accuracy) then
            table.insert(suspicionReasons, string.format("High accuracy: %.1f%%", accuracy))
          end

          if (headshotRate > thresholds.max_headshot_rate) then
            table.insert(suspicionReasons, string.format("High headshot rate: %.1f%%", headshotRate))
          end

          if (#suspicionReasons > 0) then
            table.insert(suspiciousPlayers, {
              steam_id = steamID,
              steam_name = playerName,
              accuracy = accuracy,
              headshot_rate = headshotRate,
              total_shots = totalShots,
              total_hits = totalHits,
              reasons = suspicionReasons
            })
          end
        end
      end
    end

    -- Paginate results
    local totalCount = #suspiciousPlayers
    local totalPages = math.max(1, math.ceil(totalCount / pageSize))
    page = math.Clamp(page, 1, totalPages)

    local startIdx = (page - 1) * pageSize + 1
    local endIdx = math.min(page * pageSize, totalCount)
    local pageSlice = {}
    for i = startIdx, endIdx do
      table.insert(pageSlice, suspiciousPlayers[i])
    end

    callback({
      players = pageSlice,
      page = page,
      totalPages = totalPages,
      totalCount = totalCount
    })
  end)

  return true
end

-- Get basic overview stats for all players
function PLUGIN.getPlayersOverview(callback, page, pageSize, searchText)
  page = page or 1
  pageSize = pageSize or PLUGIN.paginationLimit
  searchText = searchText or ""
  local query = [[
		SELECT
			ps.steam_id,
			p.last_name as steam_name,
			ps.total_shots,
			(ps.player_hits_generic + ps.player_hits_head + ps.player_hits_chest + ps.player_hits_stomach +
			 ps.player_hits_leftarm + ps.player_hits_rightarm + ps.player_hits_leftleg + ps.player_hits_rightleg + ps.player_hits_gear) as player_total_hits,
			(ps.npc_hits_generic + ps.npc_hits_head + ps.npc_hits_chest + ps.npc_hits_stomach +
			 ps.npc_hits_leftarm + ps.npc_hits_rightarm + ps.npc_hits_leftleg + ps.npc_hits_rightleg + ps.npc_hits_gear) as npc_total_hits,
			ps.player_hits_head as player_headshot_hits,
			ps.npc_hits_head as npc_headshot_hits,
			ps.kills,
			ps.deaths,
			ps.headshot_kills,
			ps.npc_kills
		FROM player_hit_stats ps
		LEFT JOIN `]] .. versus.config["MySQL Player Table"] .. [[` p ON ps.steam_id = p.steamid
		WHERE ps.total_shots >= 0
		ORDER BY ps.total_shots DESC
	]]

  versus.database.query(query, function(result)
    if (not result) then
      ErrorNoHaltWithStack("Failed to get players overview.")
      callback({})
      return
    end

    local playersStats = {}

    -- Process database results
    for _, row in ipairs(result) do
      local steamID = row.steam_id
      local pendingStats = PLUGIN.getPendingStatsBySteamID(steamID)
      local mergedRow = PLUGIN.mergePendingStats(row, pendingStats)

      local totalShots = tonumber(mergedRow.total_shots) or 0
      local totalHits = tonumber(mergedRow.player_total_hits) or 0
      local headshotHits = tonumber(mergedRow.player_headshot_hits) or 0
      local npcTotalHits = tonumber(mergedRow.npc_total_hits) or 0
      local npcHeadshotHits = tonumber(mergedRow.npc_headshot_hits) or 0
      local kills = tonumber(mergedRow.kills) or 0
      local deaths = tonumber(mergedRow.deaths) or 0
      local headshotKills = tonumber(mergedRow.headshot_kills) or 0
      local npcKills = tonumber(mergedRow.npc_kills) or 0

      -- Recalculate player hit totals from per-hitgroup columns when pending stats exist
      if (pendingStats and pendingStats.player_hits) then
        totalHits = 0
        headshotHits = 0
        for hitgroupID, hitgroupName in pairs(PLUGIN.hitgroupNames) do
          local columnName = "player_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))
          local hits = tonumber(mergedRow[columnName]) or 0
          totalHits = totalHits + hits
          if (hitgroupID == HITGROUP_HEAD) then
            headshotHits = hits
          end
        end
      end

      -- Recalculate NPC hit totals from per-hitgroup columns when pending stats exist
      if (pendingStats and pendingStats.npc_hits) then
        npcTotalHits = 0
        npcHeadshotHits = 0
        for hitgroupID, hitgroupName in pairs(PLUGIN.hitgroupNames) do
          local columnName = "npc_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))
          local hits = tonumber(mergedRow[columnName]) or 0
          npcTotalHits = npcTotalHits + hits
          if (hitgroupID == HITGROUP_HEAD) then
            npcHeadshotHits = hits
          end
        end
      end

      local accuracy = totalShots > 0 and (totalHits / totalShots) * 100 or 0
      local headshotRate = totalHits > 0 and (headshotHits / totalHits) * 100 or 0
      local kdRatio = deaths > 0 and (kills / deaths) or kills

      if (totalShots > 0) then -- Only include players with shots`
        table.insert(playersStats, {
          steam_id = steamID,
          steam_name = row.steam_name or "Unknown",
          total_shots = totalShots,
          total_hits = totalHits,
          headshot_hits = headshotHits,
          total_npc_hits = npcTotalHits,
          headshot_npc_hits = npcHeadshotHits,
          kills = kills,
          deaths = deaths,
          headshot_kills = headshotKills,
          npc_kills = npcKills,
          accuracy = accuracy,
          headshot_rate = headshotRate,
          kd_ratio = kdRatio
        })
      end
    end

    -- Also include players who only have pending stats (no database records yet)
    for steamID, pendingStats in pairs(PLUGIN.pendingStats) do
      -- Skip if this player was already processed from database
      local foundInDb = false
      for _, playerStat in ipairs(playersStats) do
        if (playerStat.steam_id == steamID) then
          foundInDb = true
          break
        end
      end

      if (not foundInDb) then
        local playerName = "Unknown"
        for _, ply in ipairs(player.GetAll()) do
          if (ply:SteamID64() == steamID) then
            playerName = ply:Name()
            break
          end
        end

        local totalShots = pendingStats.shots_fired or 0
        local totalHits = 0
        local headshotHits = 0
        local npcTotalHits = 0
        local npcHeadshotHits = 0
        local kills = pendingStats.kills or 0
        local deaths = pendingStats.deaths or 0
        local headshotKills = pendingStats.headshot_kills or 0
        local npcKills = pendingStats.npc_kills or 0

        if (pendingStats.player_hits) then
          for hitgroupID, hits in pairs(pendingStats.player_hits) do
            totalHits = totalHits + hits
            if (hitgroupID == HITGROUP_HEAD) then
              headshotHits = hits
            end
          end
        end

        if (pendingStats.npc_hits) then
          for hitgroupID, hits in pairs(pendingStats.npc_hits) do
            npcTotalHits = npcTotalHits + hits
            if (hitgroupID == HITGROUP_HEAD) then
              npcHeadshotHits = hits
            end
          end
        end

        local accuracy = totalShots > 0 and (totalHits / totalShots) * 100 or 0
        local headshotRate = totalHits > 0 and (headshotHits / totalHits) * 100 or 0
        local kdRatio = deaths > 0 and (kills / deaths) or kills

        if (totalShots > 0) then -- Only include players with shots
          table.insert(playersStats, {
            steam_id = steamID,
            steam_name = playerName,
            total_shots = totalShots,
            total_hits = totalHits,
            headshot_hits = headshotHits,
            total_npc_hits = npcTotalHits,
            headshot_npc_hits = npcHeadshotHits,
            kills = kills,
            deaths = deaths,
            headshot_kills = headshotKills,
            npc_kills = npcKills,
            accuracy = accuracy,
            headshot_rate = headshotRate,
            kd_ratio = kdRatio
          })
        end
      end
    end

    -- Sort by total shots descending
    table.sort(playersStats, function(a, b)
      return a.total_shots > b.total_shots
    end)

    -- Apply search filter
    if (searchText ~= "") then
      local lowerSearch = string.lower(searchText)
      local filtered = {}
      for _, playerStat in ipairs(playersStats) do
        local name = string.lower(playerStat.steam_name or "")
        local sid = string.lower(playerStat.steam_id or "")
        if (string.find(name, lowerSearch, 1, true) or string.find(sid, lowerSearch, 1, true)) then
          table.insert(filtered, playerStat)
        end
      end
      playersStats = filtered
    end

    -- Paginate results
    local totalCount = #playersStats
    local totalPages = math.max(1, math.ceil(totalCount / pageSize))
    page = math.Clamp(page, 1, totalPages)

    local startIdx = (page - 1) * pageSize + 1
    local endIdx = math.min(page * pageSize, totalCount)
    local pageSlice = {}
    for i = startIdx, endIdx do
      table.insert(pageSlice, playersStats[i])
    end

    callback({
      players = pageSlice,
      page = page,
      totalPages = totalPages,
      totalCount = totalCount
    })
  end)

  return true
end

net.Receive("versus.hitStatistics.requestPlayerStats", function(len, client)
  local steamID = net.ReadString()

  if (not client:IsAdmin()) then
    return
  end

  if (not steamID or steamID == "") then
    return
  end

  PLUGIN.getPlayerStats(steamID, function(stats)
    local statsArray = PLUGIN.convertStatsToArray(stats)
    local response = versus.network.startUnboundedMessage("PlayerHitStats")
    response:writeTable(statsArray)
    response:writeString(steamID)
    response:send(client)
  end)
end)

net.Receive("versus.hitStatistics.requestSuspiciousPlayers", function(len, client)
  local thresholds = net.ReadTable()
  local page = net.ReadUInt(16)

  if (not client:IsAdmin()) then
    return
  end

  PLUGIN.getSuspiciousPlayers(function(data)
    local response = versus.network.startUnboundedMessage("SuspiciousPlayers")
    response:writeTable(data)
    response:send(client)
  end, thresholds, page)
end)

net.Receive("versus.hitStatistics.requestPlayersOverview", function(len, client)
  if (not client:IsAdmin()) then
    return
  end

  local page = net.ReadUInt(16)
  local searchText = net.ReadString()

  PLUGIN.getPlayersOverview(function(data)
    local response = versus.network.startUnboundedMessage("PlayersOverview")
    response:writeTable(data)
    response:send(client)
  end, page, nil, searchText)
end)
