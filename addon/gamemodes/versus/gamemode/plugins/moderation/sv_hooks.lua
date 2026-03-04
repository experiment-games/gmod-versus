local PLUGIN = PLUGIN

function PLUGIN.hook:CanPlayerSay(player, text, filter)
  if not IsValid(player) then
    return
  end

  if (versus.util.throttled("player_chat", 1, player)) then
    versus.message.notify(
      player,
      "You are sending messages too quickly. Please wait a moment before chatting again.",
      NOTIFY_ERROR
    )
    return
  end

  -- Block the message outright while the player is muted.
  local muted, remaining = PLUGIN.getPlayerMuteStatus(player)

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
  if PLUGIN.apiKeyConvar:GetString() == "" then
    return
  end

  -- Enqueue the message so every chat line is checked, even during a pending API call.
  player._VersusModerationQueue = player._VersusModerationQueue or {}
  table.insert(player._VersusModerationQueue, text)

  PLUGIN.processMessageQueue(player)
end
