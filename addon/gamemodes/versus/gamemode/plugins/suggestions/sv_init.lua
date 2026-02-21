local PLUGIN = PLUGIN

util.AddNetworkString("versus.suggestions.open")
util.AddNetworkString("versus.suggestions.submit")
util.AddNetworkString("versus.suggestions.submitResult")
util.AddNetworkString("versus.suggestions.adminList")
util.AddNetworkString("versus.suggestions.adminListResult")
util.AddNetworkString("versus.suggestions.adminLoad")

-- Ensure the suggestions directories exist
file.CreateDir("versus/suggestions")
file.CreateDir("versus/suggestions/feature")
file.CreateDir("versus/suggestions/contract")

--- Build a safe filename from a steamid and timestamp.
local function buildFilename(steamID, timestamp)
  -- Replace characters that are invalid in filenames
  local safe = tostring(timestamp) .. "_" .. steamID:gsub("[^%w]", "_")
  return safe .. ".json"
end

--- Save a suggestion to disk.
--- @param suggestionType string  "feature" or "contract"
--- @param player Player
--- @param data table
local function saveSuggestion(suggestionType, player, data)
  local timestamp = os.time()
  local steamID = player:SteamID64()
  local filename = buildFilename(steamID, timestamp)
  local path = "versus/suggestions/" .. suggestionType .. "/" .. filename

  local record = {
    playerName = player:Nick(),
    steamID = steamID,
    timestamp = timestamp,
    type = suggestionType,
    data = data,
  }

  file.Write(path, util.TableToJSON(record, false))
end

--[[
  Net Messages
--]]

-- A player submits a suggestion (feature or contract)
net.Receive("versus.suggestions.submit", function(len, player)
  local suggestionType = net.ReadString()
  local jsonData = net.ReadString()

  local function sendResult(ok, message)
    if not IsValid(player) then return end

    net.Start("versus.suggestions.submitResult")
    net.WriteBool(ok)
    net.WriteString(message or "")
    net.Send(player)
  end

  -- Sanity check type
  if suggestionType ~= "feature" and suggestionType ~= "contract" then
    sendResult(false, "Unknown suggestion type.")
    return
  end

  -- Reject oversized payloads (defence-in-depth; client also checks)
  if #jsonData > PLUGIN.MAX_SUGGESTION_SIZE then
    sendResult(false, "Suggestion data exceeds the 60 KB limit.")
    return
  end

  local data = util.JSONToTable(jsonData)

  if not data then
    sendResult(false, "Malformed suggestion data.")
    return
  end

  -- Run shared validation
  local ok, err

  if suggestionType == "feature" then
    ok, err = PLUGIN.validateFeatureSuggestion(data)
  else
    ok, err = PLUGIN.validateContractSuggestion(data)
  end

  if not ok then
    sendResult(false, err)
    return
  end

  saveSuggestion(suggestionType, player, data)
  sendResult(true, "Thank you! Your suggestion has been submitted.")
end)

-- An admin requests the list of saved suggestions
net.Receive("versus.suggestions.adminList", function(len, player)
  if not player:IsAdmin() then return end

  local suggestions = {}

  for _, suggestionType in ipairs({ "feature", "contract" }) do
    local files = file.Find("versus/suggestions/" .. suggestionType .. "/*.json", "DATA")

    for _, filename in ipairs(files) do
      local path    = "versus/suggestions/" .. suggestionType .. "/" .. filename
      local content = file.Read(path, "DATA")

      if content then
        local record = util.JSONToTable(content)

        if record then
          table.insert(suggestions, {
            filename       = filename,
            suggestionType = suggestionType,
            playerName     = tostring(record.playerName or "Unknown"),
            steamID        = tostring(record.steamID or ""),
            timestamp      = tonumber(record.timestamp) or 0,
          })
        end
      end
    end
  end

  -- Sort by timestamp descending (newest first)
  table.sort(suggestions, function(a, b) return a.timestamp > b.timestamp end)

  net.Start("versus.suggestions.adminListResult")
  net.WriteUInt(#suggestions, 16)

  for _, entry in ipairs(suggestions) do
    net.WriteString(entry.filename)
    net.WriteString(entry.suggestionType)
    net.WriteString(entry.playerName)
    net.WriteString(entry.steamID)
    net.WriteUInt(entry.timestamp, 32)
  end

  net.Send(player)
end)

-- An admin requests the full content of a specific suggestion
net.Receive("versus.suggestions.adminLoad", function(len, player)
  if not player:IsAdmin() then return end

  local suggestionType = net.ReadString()
  local filename = net.ReadString()

  -- Sanitise: prevent path traversal
  filename = filename:match("^[%w_%-%.]+$")

  if not filename or (suggestionType ~= "feature" and suggestionType ~= "contract") then
    return
  end

  local path = "versus/suggestions/" .. suggestionType .. "/" .. filename
  local content = file.Read(path, "DATA")

  if not content then return end

  -- Use unbounded messaging so large suggestions (up to 64 KB) are delivered reliably
  local message = versus.network.startUnboundedMessage("versus.suggestions.adminLoadResult")
  message:writeString(content)
  message:send(player)
end)
