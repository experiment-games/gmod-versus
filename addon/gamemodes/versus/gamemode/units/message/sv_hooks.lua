local UNIT = UNIT

-- Called when a player says something.
function UNIT.hook:PlayerSay(player, text, public)
  text = string.Replace(text, "$q", '"')
  text = string.Replace(text, " ' ", "'")
  text = string.Replace(text, " : ", ":")

  -- Check if we're speaking on OOC.
  if (string.sub(text, 1, 2) == "//") then
    if (string.Trim(string.sub(text, 3)) ~= "") then
      if (hook.Run("PlayerCanSayOOC", player, text) ~= false) then
        UNIT.addChat(nil, player, "ooc", string.Trim(string.sub(text, 3)))
      end
    end
  elseif (string.sub(text, 1, 3) == ".//") then
    if (string.Trim(string.sub(text, 4)) ~= "") then
      if (hook.Run("PlayerCanSayLOOC", player, text) ~= false) then
        UNIT.addChatInRadius(player, "looc", string.Trim(string.sub(text, 4)), player:GetPos(),
          versus.config["Talk Radius"])
      end
    end
  elseif (hook.Run("PlayerCanSayIC", player, text) ~= false) then
    UNIT.addChatInRadius(player, "ic", text, player:GetPos(), versus.config["Talk Radius"])
  end

  -- Return an empty string so the text doesn't show.
  return ""
end

-- Called when a player attempts to say something in-character.
function UNIT.hook:PlayerCanSayIC(player, text)
  if (not player:Alive() or player._KnockedOut) then
    versus.message.notify(player, "You cannot talk because you are unconcious!", NOTIFY_ERROR)

    return false
  end
end

-- Called when a player attempts to say something in OOC.
function UNIT.hook:PlayerCanSayOOC(player, text)
  if (player:IsAdmin() or GetConVarNumber("versus_ooc") == 1) then
    return true
  else
    versus.message.notify(player, "Talking in OOC has been disabled, if you talk OOC in advert you'll be permabanned!",
      NOTIFY_ERROR)

    return false
  end
end

-- Called when a player attempts to say something in local OOC.
function UNIT.hook:PlayerCanSayLOOC(player, text) end
