local PLUGIN = PLUGIN

PLUGIN.libraryKey = "serverInfo"

PLUGIN.convarApiEndpoint = CreateConVar(
  "versus_server_info_api_endpoint",
  "https://experiment.games/server-info-mhSShrvoxY/",
  { FCVAR_REPLICATED, FCVAR_ARCHIVE },
  "The API endpoint to query for server information. This should point to a server running the server info API included with this plugin."
)

PLUGIN.cache = PLUGIN.cache or {}
PLUGIN.cacheTimeToLiveSeconds = 20

PLUGIN.supportedQueryTypes = {
  "info", -- Basic server info (name, map, player count, etc.)
  -- Unsupported atm:
  -- "players", -- List of players with names, scores, durations
  -- "rules"    -- Server rules (key-value pairs defined by the server)
}

--- Generate cache key
--- @param ip string Server IP address
--- @param port number Server port
--- @param queryType string Type of query
--- @return string # Cache key
local function getCacheKey(ip, port, queryType)
  return string.format("%s:%d:%s", ip, port, queryType or "info")
end

--- Check if cached data is still valid
--- @param cacheEntry table Cache entry with data and timestamp
--- @return boolean # True if cache is valid
local function isCacheValid(cacheEntry)
  if not cacheEntry then
    return false
  end

  return (CurTime() - cacheEntry.timestamp) < PLUGIN.cacheTimeToLiveSeconds
end

--- Get data from cache
--- @param ip string Server IP address
--- @param port number Server port
--- @param queryType string Type of query
--- @return table? # Cached data or nil
local function getFromCache(ip, port, queryType)
  local key = getCacheKey(ip, port, queryType)
  local entry = PLUGIN.cache[key]

  if isCacheValid(entry) then
    return entry.data
  end

  return nil
end

--- Store data in cache
--- @param ip string Server IP address
--- @param port number Server port
--- @param queryType string Type of query
--- @param data table Data to cache
local function storeInCache(ip, port, queryType, data)
  local key = getCacheKey(ip, port, queryType)
  PLUGIN.cache[key] = {
    data = data,
    timestamp = CurTime()
  }
end

--- Clear cache for specific server and query type
--- @param ip string Server IP address
--- @param port number Server port
--- @param queryType? string Type of query (nil to clear all types for this server)
function PLUGIN.clearCache(ip, port, queryType)
  if queryType then
    local key = getCacheKey(ip, port, queryType)
    PLUGIN.cache[key] = nil
  else
    -- Clear all query types for this server
    for _, qType in ipairs(PLUGIN.supportedQueryTypes) do
      local key = getCacheKey(ip, port, qType)
      PLUGIN.cache[key] = nil
    end
  end
end

--- Clear all cache entries
function PLUGIN.clearAllCache()
  PLUGIN.cache = {}
end

--- Query server info (name, map, players, etc.)
--- @param ip string Server IP address
--- @param port number Server port
--- @param callback fun(success, data) Callback function
--- @param bypassCache? boolean Set to true to bypass cache
function PLUGIN.getInfo(ip, port, callback, bypassCache)
  PLUGIN.query(ip, port, "info", callback, bypassCache)
end

--- Internal query function
--- @param ip string Server IP address
--- @param port number Server port
--- @param queryType string Type of query
--- @param callback fun(success: boolean, data: table) Callback function
--- @param bypassCache? boolean Set to true to bypass cache
function PLUGIN.query(ip, port, queryType, callback, bypassCache)
  if not isstring(ip) or not isnumber(port) then
    if callback then
      callback(false, { error = "Invalid IP or port" })
    end

    return
  end

  if not bypassCache then
    local cachedData = getFromCache(ip, port, queryType)
    if cachedData then
      if callback then
        callback(true, cachedData)
      end

      return
    end
  end

  local apiEndpoint = PLUGIN.convarApiEndpoint:GetString()
  local url = apiEndpoint ..
      "?ip=" .. ip ..
      "&port=" .. port ..
      "&type=" .. (queryType or "info")

  HTTP({
    url = url,
    method = "GET",
    success = function(code, body, headers)
      local data = util.JSONToTable(body)

      if not data then
        if callback then
          callback(false, { error = "Failed to parse JSON response from: " .. body })
        end

        return
      end

      if data.success then
        storeInCache(ip, port, queryType, data.data)

        if callback then
          callback(true, data.data)
        end
      else
        if callback then
          callback(false, { error = data.error or "Unknown error" })
        end
      end
    end,
    failed = function(reason)
      if callback then
        callback(false, { error = "HTTP request failed: " .. reason })
      end
    end
  })
end

--- Get info about the current server the player is on
--- @param callback fun(success: boolean, data: table) Callback function
--- @param bypassCache? boolean Set to true to bypass cache
function PLUGIN.getCurrentServer(callback, bypassCache)
  local ip = game.GetIPAddress()

  -- Parse IP:PORT
  local serverIP, serverPort = ip:match("([^:]+):(%d+)")

  if not serverIP or not serverPort then
    if callback then
      callback(false, { error = "Failed to parse current server address" })
    end

    return
  end

  PLUGIN.getInfo(serverIP, tonumber(serverPort), callback, bypassCache)
end

--- Helper function to format player duration
--- @param seconds number Duration in seconds
--- @return string # Formatted duration
function PLUGIN.formatDuration(seconds)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = math.floor(seconds % 60)

  if hours > 0 then
    return string.format("%dh %dm %ds", hours, minutes, secs)
  elseif minutes > 0 then
    return string.format("%dm %ds", minutes, secs)
  end

  return string.format("%ds", secs)
end
