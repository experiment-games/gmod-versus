local UNIT = UNIT

do
  local COMMAND = versus.command.define("pm")
  COMMAND.description = "Privately message a player."
  COMMAND.requiredFlags = "c"

  COMMAND:addRequiredParameter(Player, "Receiving Player", "The player to send a private message to")
  COMMAND:addRequiredParameter(tostring, "Message", "Your message to the player")

  function COMMAND:onRun(player, target, message)
    if (player == target) then
      versus.message.notify(player, "You cannot send a private message to yourself!", NOTIFY_ERROR)
      return
    end

    versus.message.addChat(player, player, "pm", message)
    versus.message.addChat(target, player, "pm", message)
  end
end

do
  local COMMAND = versus.command.define("y")
  COMMAND.description = "Yell to players at shouting distance"
  COMMAND.requiredFlags = "c"

  COMMAND:addRequiredParameter(tostring, "Message", "What you want to yell")

  function COMMAND:onRun(player, message)
    versus.message.addChatInRadius(player, "yell", message, player:GetPos(), versus.config["Talk Radius"] * 2)
  end
end

do
  local COMMAND = versus.command.define("me")
  COMMAND.description = "Describe an action you perform, e.g: \"<Your name> checks their pockets and shrugs\"."
  COMMAND.requiredFlags = "c"

  COMMAND:addRequiredParameter(tostring, "Action Description", "This text is placed behind your name in chat")

  function COMMAND:onRun(player, action)
    player:chatMe(action)
  end
end

do
  local COMMAND = versus.command.define("w")
  COMMAND.description = "Whisper to players really close to you."
  COMMAND.requiredFlags = "c"

  COMMAND:addRequiredParameter(tostring, "Message", "What you want to whisper")

  function COMMAND:onRun(player, message)
    versus.message.addChatInRadius(player, "whisper", message, player:GetPos(), versus.config["Talk Radius"] / 2)
  end
end

do
  local COMMAND = versus.command.define("radio")
  COMMAND.description = "Send a message to all players on the same frequency (TODO)."
  COMMAND.requiredFlags = "c"

  COMMAND:addRequiredParameter(tostring, "Message", "What you want to broadcast on your radio frequency")

  function COMMAND:onRun(player, text)
    -- TODO: Radio frequencies
    versus.player.sayRadio(player, text)
  end
end
