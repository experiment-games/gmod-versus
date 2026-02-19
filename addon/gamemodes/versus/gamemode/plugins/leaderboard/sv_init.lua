local PLUGIN = PLUGIN

util.AddNetworkString("versus.leaderboard.open")
util.AddNetworkString("versus.leaderboard.requestPage")
util.AddNetworkString("versus.leaderboard.pageData")
util.AddNetworkString("versus.leaderboard.findPlayer")
util.AddNetworkString("versus.leaderboard.findPlayerResult")

--- Per-player in-flight guard.
--- Only one leaderboard DB query is allowed at a time per player.
--- Any additional requests that arrive while a query is already running are
--- silently dropped
PLUGIN._requestInFlight = PLUGIN._requestInFlight or {}

--- "Find Me" — looks up the rank of the requesting player for a given sort
--- column and replies with the 1-based rank (or 0 when the player has no row).
PLUGIN._findInFlight = PLUGIN._findInFlight or {}

-- Only these column names are permitted in ORDER BY to prevent SQL injection
local VALID_SORT_COLUMNS = {
  xp    = "xp",
  money = "money",
}

--- Fetch one page of leaderboard data from the database.
--- Runs a COUNT(*) first, then the paginated SELECT, and calls back with both.
---
--- @param sortBy  string   "xp" or "money"
--- @param page    number   1-based page index
--- @param callback function Called as callback(totalRows, entries) where entries is an
---                          array of tables: { last_name, money, xp, level }
function PLUGIN.fetchLeaderboardPage(sortBy, page, callback)
  local column    = VALID_SORT_COLUMNS[sortBy] or "xp"
  local tableName = versus.config["MySQL Player Table"]
  local offset    = (page - 1) * PLUGIN.PAGE_SIZE

  local countSQL  = string.format(
    "SELECT COUNT(*) AS `total` FROM `%s`",
    tableName
  )

  local dataSQL   = string.format(
    "SELECT `steamID`, `last_name`, `money`, `xp`, `level` FROM `%s` ORDER BY `%s` DESC LIMIT %d OFFSET %d",
    tableName, column, PLUGIN.PAGE_SIZE, offset
  )

  versus.database.query(countSQL, function(countResult)
    local total = countResult and countResult[1] and tonumber(countResult[1].total) or 0

    versus.database.query(dataSQL, function(dataResult)
      callback(total, dataResult or {})
    end, function(err)
      ErrorNoHalt("[Leaderboard] Data query error: " .. tostring(err) .. "\n")
      callback(0, {})
    end)
  end, function(err)
    ErrorNoHalt("[Leaderboard] Count query error: " .. tostring(err) .. "\n")
    callback(0, {})
  end)
end

--[[
  Net Messages
--]]

net.Receive("versus.leaderboard.requestPage", function(len, player)
  local sortBy = net.ReadString()
  local page   = net.ReadUInt(16)

  -- Sanitise inputs
  if not VALID_SORT_COLUMNS[sortBy] then
    sortBy = "xp"
  end

  page = math.max(1, page)

  local steamID = player:SteamID64()

  -- If a query is already running for this player, silently drop the request.
  -- The client's own inflight guard means legitimate UI should never reach this
  -- branch; it exists as a server-side safety net.
  if PLUGIN._requestInFlight[steamID] then
    return
  end

  PLUGIN._requestInFlight[steamID] = true

  PLUGIN.fetchLeaderboardPage(sortBy, page, function(total, entries)
    -- Always clear the flag first so the player can make a new request even if
    -- something goes wrong sending the response.
    PLUGIN._requestInFlight[steamID] = nil

    if not IsValid(player) then return end

    net.Start("versus.leaderboard.pageData")
    net.WriteString(sortBy)
    net.WriteUInt(page, 16)
    net.WriteUInt(total, 32)
    net.WriteUInt(#entries, 8)

    for _, entry in ipairs(entries) do
      net.WriteString(tostring(entry.steamID or ""))
      net.WriteString(tostring(entry.last_name or "Unknown"))
      net.WriteUInt(tonumber(entry.money) or 0, 32)
      net.WriteUInt(tonumber(entry.xp) or 0, 32)
      net.WriteUInt(tonumber(entry.level) or 1, 16)
    end
    net.Send(player)
  end)
end)

net.Receive("versus.leaderboard.findPlayer", function(len, player)
  local sortBy = net.ReadString()

  if not VALID_SORT_COLUMNS[sortBy] then
    sortBy = "xp"
  end

  local steamID = player:SteamID64()

  if PLUGIN._findInFlight[steamID] then
    return
  end
  PLUGIN._findInFlight[steamID] = true

  local column = VALID_SORT_COLUMNS[sortBy]
  local tableName = versus.config["MySQL Player Table"]

  -- Step 1: fetch the player's own score for the chosen column.
  local scoreSQL = string.format(
    "SELECT `%s` FROM `%s` WHERE `steamid` = ?",
    column, tableName
  )

  local values = {
    versus.player.getValueTypeDefinition(steamID),
  }

  local function sendResult(rank)
    PLUGIN._findInFlight[steamID] = nil
    if not IsValid(player) then return end

    net.Start("versus.leaderboard.findPlayerResult")
    net.WriteString(sortBy)
    net.WriteUInt(rank, 32)
    net.Send(player)
  end

  versus.database.queryPrepared(scoreSQL, values, function(scoreResult)
    if not scoreResult or not scoreResult[1] then
      -- Player has no database row yet.
      sendResult(0)
      return
    end

    local playerScore = tonumber(scoreResult[1][column]) or 0

    -- Step 2: count how many players have a strictly higher score.
    -- Rank = that count + 1.
    local rankSQL = string.format(
      "SELECT COUNT(*) AS `rank` FROM `%s` WHERE `%s` > ?",
      tableName, column
    )

    local values = {
      versus.player.getValueTypeDefinition(playerScore),
    }

    versus.database.queryPrepared(rankSQL, values, function(rankResult)
      local rank = rankResult and rankResult[1] and (tonumber(rankResult[1].rank) + 1) or 1
      sendResult(rank)
    end, function(err)
      ErrorNoHalt("[Leaderboard] Find-me rank query error: " .. tostring(err) .. "\n")
      sendResult(0)
    end)
  end, function(err)
    ErrorNoHalt("[Leaderboard] Find-me score query error: " .. tostring(err) .. "\n")
    sendResult(0)
  end)
end)
