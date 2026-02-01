local UNIT = UNIT

do
  local COMMAND = versus.command.define("sanctions")
  COMMAND.description = "See all available sanctions"
  COMMAND.requiredFlags = "a"

  function COMMAND:onRun(player, target, sanctionKey, duration)
    local sanctions = UNIT.all()
    local sanctionsString = ""
    local seperator = ", "

    for sanctionKey, sanction in pairs(sanctions) do
      sanctionsString = sanctionsString .. seperator .. sanctionKey
    end

    player:notify(sanctionsString:sub(seperator:len() + 1), NOTIFY_INFORMATION)
  end
end

do
  local COMMAND = versus.command.define("addsanction")
  COMMAND.description = "Add a sanction for a player."
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(Player, "Target", "The player to receive the sanction")
  COMMAND:addRequiredParameter(tostring, "Sanction", "The sanction to apply")
  COMMAND:addRequiredParameter(tonumber, "Duration", "How long the sanction should last in seconds")
  COMMAND:addRequiredParameter(tostring, "Reason", "Why the player is receiving the sanction")
  COMMAND:addParameter(tostring, "Data", "Additional data to provide to the sanction")

  function COMMAND:onRun(player, target, sanctionKey, duration, reason, data)
    local sanction = UNIT.get(sanctionKey)

    if (not sanction) then
      player:notify("The sanction you provided is invalid! Use /sanctions to see a list of valid sanctions.",
        NOTIFY_ERROR)
      return
    end

    if (duration <= 0) then
      player:notify("The duration you provided is too low! Pick a time in seconds higher than 0.", NOTIFY_ERROR)
      return
    end

    UNIT.addSanction(target, sanction, duration, reason, player, data)
  end
end

do
  local COMMAND = versus.command.define("removesanction")
  COMMAND.description = "Remove a sanction from a player."
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(Player, "Target", "The player who's sanction should expire early")
  COMMAND:addRequiredParameter(tostring, "Sanction", "The sanction to remove")

  function COMMAND:onRun(player, target, sanctionKey)
    local sanction = UNIT.get(sanctionKey)

    if (not sanction) then
      player:notify("The sanction you provided is invalid! Use /sanctions to see a list of valid sanctions.",
        NOTIFY_ERROR)
      return
    end

    UNIT.expireSanction(target, sanction)
  end
end

do
  local COMMAND = versus.command.define("fetchsanctions")
  COMMAND.description = "Ensure the latest sanctions are retrieved from the database"
  COMMAND.requiredFlags = "a"

  function COMMAND:onRun(player, target, sanctionKey, duration)
    UNIT.processNotExpired()

    player:notify("Sanctions updated!", NOTIFY_INFORMATION)
  end
end
