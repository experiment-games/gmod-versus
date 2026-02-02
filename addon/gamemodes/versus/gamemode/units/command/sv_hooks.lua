local UNIT = UNIT

-- Called when attempts to use a command.
function UNIT.hook:PlayerCanUseCommand(player, command, parameters)
  if (command.command == "sleep" and player:Alive() and player._Sleeping) then
    return true
  end

  if ((not player:Alive() and not command.allowWhileDead) or player._KnockedOut) then
    versus.message.notify(player, "You cannot do that because you are unconcious!", NOTIFY_ERROR)

    return false
  end
end

-- Called when a player says something in chat
function UNIT.hook:PlayerCanSayLocal(player, text)
  if (not player._Initialized) then
    return
  end

  if (string.sub(text, 1, 1) ~= versus.config["Command Prefix"]) then
    return
  end

  text = string.sub(text, versus.config["Command Prefix"]:len() + 1)

  local arguments = UNIT.parseCommand(text)

  UNIT.runPlayerCommand(player, arguments)

  return false
end
