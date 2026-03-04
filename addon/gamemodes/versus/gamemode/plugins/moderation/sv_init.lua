local PLUGIN = PLUGIN

versus.includePrefixed("sv_hooks.lua")

-- API key is stored in a protected convar so it never leaks to clients.
PLUGIN.apiKeyConvar = CreateConVar(
  "versus_moderation_openai_key",
  "",
  FCVAR_PROTECTED,
  "OpenAI API key used by the chat moderation plugin."
)

-- System prompt loaded from the companion file (returns a string literal).
local systemPrompt = include(PLUGIN.fullPath .. "/prompts/system_chat.lua")
local moderationOutputSchema = file.Read(PLUGIN.fullPath .. "/prompts/system_chat_output.json", "LUA")

--- Processes the next queued message for a player, serialising API calls so they
--- fire one-at-a-time while still checking every message.
--- @param player Player
function PLUGIN.processMessageQueue(player)
  -- Another call is already in flight for this player.
  if player._VersusModerationPending then
    return
  end

  local queue = player._VersusModerationQueue
  if not queue or #queue == 0 then
    return
  end

  -- Dequeue the oldest message.
  local message = table.remove(queue, 1)

  player._VersusModerationPending = true

  local history = player._VersusModerationHistory or {}
  local data = PLUGIN.getModerationData(player)
  local warnings = data.moderationWarnings

  PLUGIN.callModerationAPI(message, warnings, history, function(result)
    -- Guard: player may have left while the request was in-flight.
    if not IsValid(player) then
      return
    end

    player._VersusModerationPending = nil

    local actioned = false
    if result then
      actioned = PLUGIN.applyModerationResult(player, result)
    end

    PLUGIN.addToHistory(player, message, actioned)

    -- Continue draining the queue.
    PLUGIN.processMessageQueue(player)
  end)
end

--- Records a sent message into the player's history, keeping the last 4 entries.
--- @param player Player
--- @param message string
--- @param actioned boolean Whether the message received a warning or mute
function PLUGIN.addToHistory(player, message, actioned)
  local history = player._VersusModerationHistory or {}
  table.insert(history, { message = message, actioned = actioned })

  -- Retain only the 9 most recent entries (the current message will be the 10th context item).
  while #history > 9 do
    table.remove(history, 1)
  end

  player._VersusModerationHistory = history
end

--- Returns the data sub-table for the player, ensuring moderation fields exist.
--- @param player Player
--- @return table
function PLUGIN.getModerationData(player)
  local data = player:getCharacter("data")
  data.moderationWarnings = data.moderationWarnings or 0
  data.moderationMutedUntil = data.moderationMutedUntil or 0
  return data
end

--- Returns whether the player is currently muted and, if so, how many seconds remain.
--- @param player Player
--- @return boolean isMuted
--- @return number secondsRemaining
function PLUGIN.getPlayerMuteStatus(player)
  local data = PLUGIN.getModerationData(player)
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
--- @param history table Array of previous {message, actioned} entries for this player
--- @param callback fun(result: table|nil)
function PLUGIN.callModerationAPI(message, warnings, history, callback)
  local apiKey = PLUGIN.apiKeyConvar:GetString()
  if apiKey == "" then
    callback(nil)
    return
  end

  local userContent = util.TableToJSON({
    message  = message,
    warnings = warnings,
    history  = history,
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

--- Applies a moderation verdict to a player (warning or mute).
--- A nil .response on the result table means the message was clean — no action taken.
--- Returns true if any action (warning or mute) was applied, false otherwise.
--- @param player Player
--- @param result table Full result table (with a .response sub-table or nil)
--- @return boolean actioned
function PLUGIN.applyModerationResult(player, result)
  if not IsValid(player) then return false end

  local response = result.response

  -- nil response means the message was clean — nothing to do.
  if response == nil then
    print("[Moderation] Message is clean, no action taken.\n")
    return false
  end

  local playerData = PLUGIN.getModerationData(player)

  if response.warning then
    -- Mild offense: issue a visible warning and persist the incremented count.
    playerData.moderationWarnings = playerData.moderationWarnings + 1

    versus.message.notifyAll(
      string.format(
        "[Moderation] '%s' received a warning: %s",
        player:Nick(),
        response.warning
      ),
      NOTIFY_ERROR
    )

    return true
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

    return true
  end

  return false
end
