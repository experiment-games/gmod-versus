local PLUGIN = PLUGIN

do
  local COMMAND = versus.command.define("warnings")
  COMMAND.description = "Check how many moderation warnings a player has."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Target Player", "The player to check warnings for")

  function COMMAND:onRun(player, target)
    local data = target:getCharacter("data")
    local warnings = data.moderationWarnings or 0

    versus.message.notify(player, string.format("%s has %d moderation warning(s).", target:Nick(), warnings))
  end
end

do
  local COMMAND = versus.command.define("warn")
  COMMAND.description = "Issue a moderation warning to a player."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Target Player", "The player to warn")
  COMMAND:addRequiredParameter(tostring, "Reason", "The reason for the warning")

  function COMMAND:onRun(player, target, reason)
    local data = target:getCharacter("data")
    data.moderationWarnings = (data.moderationWarnings or 0) + 1

    versus.message.notifyAll(player:Nick() .. " issued a warning to " .. target:Nick() .. ": " .. reason)
  end
end

do
  local COMMAND = versus.command.define("warningsclear")
  COMMAND.description = "Clear moderation warnings for a player."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Target Player", "The player to clear warnings for")

  function COMMAND:onRun(player, target)
    local data = target:getCharacter("data")
    data.moderationWarnings = 0

    versus.message.notifyAll(player:Nick() .. " cleared moderation warnings for " .. target:Nick() .. ".")
  end
end

do
  local COMMAND = versus.command.define("muted")
  COMMAND.description = "Check if a player is currently muted."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Target Player", "The player to check mute status for")

  function COMMAND:onRun(player, target)
    local data = target:getCharacter("data")
    local mutedUntil = data.moderationMutedUntil or 0
    local remaining = mutedUntil - os.time()
    local muted = remaining > 0

    if muted then
      local minutes = math.ceil(remaining / 60)
      versus.message.notify(player, string.format("%s is currently muted for %d more minute(s).", target:Nick(), minutes))
    else
      versus.message.notify(player, string.format("%s is not currently muted.", target:Nick()))
    end
  end
end

do
  local COMMAND = versus.command.define("mute")
  COMMAND.description = "Mute a player for a specified duration."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Target Player", "The player to mute")
  COMMAND:addRequiredParameter(tonumber, "Duration (minutes)", "The duration of the mute in minutes")
  COMMAND:addRequiredParameter(tostring, "Reason", "The reason for the mute")

  function COMMAND:onRun(player, target, durationMinutes, reason)
    local data = target:getCharacter("data")
    local durationSecs = durationMinutes * 60
    data.moderationMutedUntil = os.time() + durationSecs

    local displayTime = durationMinutes >= 60
        and string.format("%d hour(s)", math.ceil(durationMinutes / 60))
        or string.format("%d minute(s)", durationMinutes)

    versus.message.notifyAll(
      string.format(
        "[Moderation] '%s' has been muted for %s: %s",
        target:Nick(),
        displayTime,
        reason
      ),
      NOTIFY_ERROR
    )
  end
end

do
  local COMMAND = versus.command.define("unmute")
  COMMAND.description = "Unmute a player immediately."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Target Player", "The player to unmute")

  function COMMAND:onRun(player, target)
    local data = target:getCharacter("data")
    local mutedUntil = data.moderationMutedUntil or 0
    local remaining = mutedUntil - os.time()
    local muted = remaining > 0

    if not muted then
      versus.message.notify(player, string.format("%s is not currently muted.", target:Nick()), NOTIFY_ERROR)
      return
    end

    data.moderationMutedUntil = 0

    versus.message.notifyAll(player:Nick() .. " unmuted " .. target:Nick() .. ".")
  end
end
