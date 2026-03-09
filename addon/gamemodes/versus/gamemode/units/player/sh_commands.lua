local UNIT = UNIT

local maximumNameLength = 48

do
  local COMMAND = versus.command.define("giveflags")
  COMMAND.description = "Give access flags to a player."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Target Player", "The player to give access to something")
  COMMAND:addRequiredParameter(tostring, "Access Flags", "The flag(s) to give")

  function COMMAND:onRun(player, target, flags)
    if (string.find(flags, "a", nil, true) or string.find(flags, "s", nil, true)) then
      versus.message.notify(player, "You cannot give 'a' or 's' access! Add that player in settings/users.txt instead.",
        NOTIFY_ERROR)

      return
    end

    UNIT.giveFlags(target, flags)

    versus.message.notifyAll(player:getCombinedName() .. " gave " .. target:getCombinedName() .. " '" ..
      flags .. "' access.")
  end
end

do
  local COMMAND = versus.command.define("takeaccess")
  COMMAND.description = "Take access from a player."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Target Player", "The player to take access to something")
  COMMAND:addRequiredParameter(tostring, "Access Flags", "The flag(s) to take")

  function COMMAND:onRun(player, target, flags)
    if (string.find(flags, "a", nil, true) or string.find(flags, "s", nil, true)) then
      versus.message.notify(player, "You cannot take 'a' or 's' access!", NOTIFY_ERROR)

      return
    end

    UNIT.takeFlags(target, flags)

    versus.message.notifyAll(player:getCombinedName() .. " took '" ..
      flags .. "' access from " .. target:getCombinedName() .. ".")
  end
end

do
  local COMMAND = versus.command.define("name")
  COMMAND.description = "Change your character name."
  COMMAND.requiredFlags = "b"
  COMMAND.allowWhileDead = true

  COMMAND:addRequiredParameter(tostring, "Character name", "The name of your character")

  function COMMAND:onRun(player, name)
    if (string.len(name) > maximumNameLength) then
      versus.message.notify(player, string.format("Your name can be a maximum of %u characters!", maximumNameLength),
        NOTIFY_ERROR)
      return
    end

    player:getCharacter("data").name = name

    versus.message.printMessage(player, "Your name will be '" .. name .. "' next time you spawn.")
  end
end
