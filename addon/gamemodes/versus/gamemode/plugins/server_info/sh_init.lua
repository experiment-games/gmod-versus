local PLUGIN = PLUGIN

PLUGIN.libraryKey = "serverInfo"

PLUGIN.convarApiEndpoint = CreateConVar(
  "versus_server_info_api_endpoint",
  "https://experiment.games/server-info-mhSShrvoxY/",
  { FCVAR_REPLICATED, FCVAR_ARCHIVE },
  "The API endpoint to query for server information. This should point to a server running the server info API included with this plugin."
)

--- Query server info (name, map, players, etc.)
--- @param ip string Server IP address
--- @param port number Server port
--- @param callback fun(success, data) Callback function
function PLUGIN.getInfo(ip, port, callback)
  PLUGIN.query(ip, port, "info", callback)
end

--- Query player list
--- @param ip string Server IP address
--- @param port number Server port
--- @param callback fun(success: boolean, data: table) Callback function
function PLUGIN.getPlayers(ip, port, callback)
  PLUGIN.query(ip, port, "players", callback)
end

--- Query server rules/cvars
--- @param ip string Server IP address
--- @param port number Server port
--- @param callback fun(success, data) Callback function
function PLUGIN.getRules(ip, port, callback)
  PLUGIN.query(ip, port, "rules", callback)
end

--- Internal query function
--- @param ip string Server IP address
--- @param port number Server port
--- @param queryType string Type of query (info, players, rules)
--- @param callback fun(success: boolean, data: table) Callback function
function PLUGIN.query(ip, port, queryType, callback)
  if not isstring(ip) or not isnumber(port) then
    if callback then
      callback(false, { error = "Invalid IP or port" })
    end

    return
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
function PLUGIN.getCurrentServer(callback)
  local ip = game.GetIPAddress()

  -- Parse IP:PORT
  local serverIP, serverPort = ip:match("([^:]+):(%d+)")

  if not serverIP or not serverPort then
    if callback then
      callback(false, { error = "Failed to parse current server address" })
    end

    return
  end

  PLUGIN.getInfo(serverIP, tonumber(serverPort), callback)
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
