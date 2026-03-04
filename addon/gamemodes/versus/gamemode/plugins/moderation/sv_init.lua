local PLUGIN = PLUGIN

-- API key is stored in a protected convar so it never leaks to clients.
local apiKeyConvar = CreateConVar(
  "versus_moderation_openai_key",
  "",
  FCVAR_PROTECTED,
  "OpenAI API key used by the chat moderation plugin."
)

-- System prompt loaded from the companion file (returns a string literal).
local systemPrompt = include(PLUGIN.fullPath .. "/prompts/system_chat.lua")
local moderationOutputSchema = file.Read(PLUGIN.fullPath .. "/prompts/system_chat_output.json", "LUA")

--- Returns the data sub-table for the player, ensuring moderation fields exist.
--- @param ply Player
--- @return table
local function getModerationData(ply)
  local data = ply:getCharacter("data")
  data.moderationWarnings = data.moderationWarnings or 0
  data.moderationMutedUntil = data.moderationMutedUntil or 0
  return data
end

--- Returns whether the player is currently muted and, if so, how many seconds remain.
--- @param ply Player
--- @return boolean isMuted
--- @return number secondsRemaining
local function getPlayerMuteStatus(ply)
  local data = getModerationData(ply)
  local remaining = (data.moderationMutedUntil or 0) - os.time()
  if remaining > 0 then
    return true, remaining
  end
  return false, 0
end

--- Calls the OpenAI responses API to evaluate a chat message.
--- The callback receives the decoded response table on success, or nil on failure.
--- @param message string
--- @param warnings number Current warning count sent as context to the AI
--- @param callback fun(result: table|nil)
function PLUGIN.callModerationAPI(message, warnings, callback)
  local apiKey = apiKeyConvar:GetString()
  if apiKey == "" then
    callback(nil)
    return
  end

  local userContent = util.TableToJSON({
    message = message,
    warnings = warnings,
  })

  local body = util.TableToJSON({
    model = "gpt-5-nano",
    input = {
      { role = "system", content = systemPrompt },
      { role = "user",   content = userContent },
    },
    text = {
      format = util.JSONToTable(moderationOutputSchema),
    },
  })

  local hasMadeRequest = HTTP({
    url = "https://api.openai.com/v1/responses",
    method = "POST",
    headers = {
      ["Authorization"] = "Bearer " .. apiKey,
    },
    body = body,
    type = "application/json",

    success = function(code, responseBody)
      if code ~= 200 then
        ErrorNoHalt(string.format("[Moderation] API returned HTTP %d: %s\n", code, responseBody))
        callback(nil)
        return
      end

      local response = util.JSONToTable(responseBody)
      if not response or response.error then
        ErrorNoHalt(string.format("[Moderation] Failed to parse API response: %s\n", responseBody))
        callback(nil)
        return
      end

      -- Navigate the responses-API envelope: find the message output item.
      -- When reasoning is enabled the output array may contain a leading
      -- reasoning item (type="reasoning") before the actual message item.
      local output

      if response.output then
        for _, item in ipairs(response.output) do
          if item.type == "message" then
            output = item
            break
          end
        end
      end

      if not output or output.status ~= "completed" then
        PrintTable(response)
        ErrorNoHalt("[Moderation] Unexpected output status in API response.\n")
        callback(nil)
        return
      end

      local content = output.content and output.content[1]
      if not content or content.type ~= "output_text" then
        ErrorNoHalt("[Moderation] Unexpected content type in API response.\n")
        callback(nil)
        return
      end

      local parsed = util.JSONToTable(content.text)
      if not parsed then
        ErrorNoHalt(string.format("[Moderation] Failed to parse structured JSON payload: %s\n", content.text))
        callback(nil)
        return
      end

      callback(parsed)
    end,

    failed = function(reason)
      ErrorNoHalt(string.format("[Moderation] HTTP request failed: %s\n", reason))
      callback(nil)
    end,
  })

  if not hasMadeRequest then
    ErrorNoHalt("[Moderation] Failed to initiate HTTP request to OpenAI.\n")
    callback(nil)
  end
end

-- Per-player flag to avoid flooding the API while a check is already in flight.
local pendingCheck = {}

function PLUGIN.hook:CanPlayerSay(player, text, filter)
  if not IsValid(player) then
    return
  end

  -- Block the message outright while the player is muted.
  local muted, remaining = getPlayerMuteStatus(player)

  if muted then
    local minutes = math.ceil(remaining / 60)

    versus.message.notify(
      player,
      string.format("[Moderation] You are currently muted for %d more minute(s).", minutes),
      NOTIFY_ERROR
    )

    return false
  end

  -- Skip moderation if no API key is configured.
  if apiKeyConvar:GetString() == "" then
    return
  end

  -- When a check is already in-flight, let the message through but skip a second call.
  if pendingCheck[player] then
    return
  end

  pendingCheck[player] = true

  local data = getModerationData(player)
  local warnings = data.moderationWarnings

  self.callModerationAPI(text, warnings, function(result)
    pendingCheck[player] = nil

    if not IsValid(player) or not result then
      return
    end

    local response = result.response

    -- nil response means the message was fine — nothing to do.
    if response == nil then
      return
    end

    local playerData = getModerationData(player)

    if response.warning then
      -- Mild offense: issue a visible warning and persist the incremented count.
      playerData.moderationWarnings = playerData.moderationWarnings + 1

      versus.message.notifyAll(
        string.format(
          "[Moderation] '%s' received a warning (total warnings: %d): %s",
          player:Nick(),
          playerData.moderationWarnings,
          response.warning
        ),
        NOTIFY_ERROR
      )
    elseif response.duration_minutes then
      -- Serious offense: apply a timed mute.
      local durationSecs              = response.duration_minutes * 60
      playerData.moderationMutedUntil = os.time() + durationSecs

      local hours                     = math.floor(response.duration_minutes / 60)
      local displayTime               = hours >= 1
          and string.format("%d hour(s)", hours)
          or string.format("%d minute(s)", response.duration_minutes)

      versus.message.notifyAll(
        string.format(
          "[Moderation] '%s' has been muted for %s: %s",
          player:Nick(),
          displayTime,
          response.reason
        ),
        NOTIFY_ERROR
      )
    end
  end)
end
