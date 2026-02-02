local UNIT = UNIT

-- Called when a player says something.
function UNIT.hook:PlayerSay(player, text, public)
  text = string.Replace(text, "$q", '"')
  text = string.Replace(text, " ' ", "'")
  text = string.Replace(text, " : ", ":")

  -- Check if we're speaking in world chat.
  if (string.sub(text, 1, 2) == "//") then
    if (string.Trim(string.sub(text, 3)) ~= "") then
      if (hook.Run("PlayerCanSayWorld", player, text) ~= false) then
        UNIT.addChat(nil, player, "world", string.Trim(string.sub(text, 3)))
      end
    end
  elseif (hook.Run("PlayerCanSayLocal", player, text) ~= false) then
    UNIT.addChatInRadius(player, "local", text, player:GetPos(), versus.config["Talk Radius"])
  end

  -- Return an empty string so the text doesn't show.
  return ""
end

-- Called when a player attempts to say something in-character.
function UNIT.hook:PlayerCanSayLocal(player, text)
  if (not player:Alive() or player._KnockedOut) then
    versus.message.notify(player, "You cannot talk because you are unconscious!", NOTIFY_ERROR)

    return false
  end
end

-- Called when a player attempts to say something in World Chat.
function UNIT.hook:PlayerCanSayWorld(player, text)
  if (player:IsAdmin() or GetConVar("versus_world"):GetInt() == 1) then
    return true
  else
    versus.message.notify(player, "Talking in World Chat has been disabled!",
      NOTIFY_ERROR)

    return false
  end
end
