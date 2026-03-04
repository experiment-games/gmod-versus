local UNIT = UNIT
local g_Player = player

CreateConVar("versus_world", 1)

util.AddNetworkString("versus.message.notification")
util.AddNetworkString("versus.message.playerChat")
util.AddNetworkString("versus.message.chat")

-- Notifies a player.
function UNIT.notify(player, message, class)
  if (class == nil) then
    versus.message.addChat(player, nil, "notify", message)
  else
    net.Start("versus.message.notification")
    net.WriteString(message)
    net.WriteUInt(class, 16)
    net.Send(player)
  end
end

-- Notifies every player using Garry's hint messages.
function UNIT.notifyAll(message, class)
  for _, player in ipairs(g_Player.GetAll()) do
    UNIT.notify(player, message, class)
  end

  if (not GAMEMODE:IsListenServer()) then
    print(message)
  end
end

-- Prints a message to every player's chat area and console.
function UNIT.printMessageAll(message)
  for _, player in ipairs(g_Player.GetAll()) do
    UNIT.printMessage(player, message)
  end

  -- Check to see if we're not running a listen server.
  if (not GAMEMODE:IsListenServer()) then
    print(message)
  end
end

-- Prints a message to a player's chat area and console.
function UNIT.printMessage(player, message) player:PrintMessage(3, message) end

-- Prints a message to players within a radius of a specified position.
function UNIT.printMessageInRadius(message, position, radius)
  for _, player in ipairs(g_Player.GetAll()) do
    if (position:Distance(player:GetPos()) <= radius) then
      UNIT.printMessage(player, message)
    end
  end
end

-- Add a new line.
function UNIT.addChat(recipientFilter, player, filter, text, translatableWords)
  if (hook.Run("CanPlayerSay", player, text, filter) == false) then
    return
  end

  if (recipientFilter == nil) then
    recipientFilter = g_Player.GetAll()
  end

  local function writeTranslatableWords()
    if (not istable(translatableWords)) then
      net.WriteUInt(0, UNIT.bitSizeTranslatedWords)
      return
    end

    net.WriteUInt(#translatableWords, UNIT.bitSizeTranslatedWords)
    for _, word in ipairs(translatableWords) do
      net.WriteString(word)
    end
  end

  if (player) then
    net.Start("versus.message.playerChat")
    net.WriteEntity(player)
    net.WriteString(filter)
    net.WriteString(text)
    writeTranslatableWords()
    net.Send(recipientFilter)
  else
    net.Start("versus.message.chat")
    net.WriteString(filter)
    net.WriteString(text)
    writeTranslatableWords()
    net.Send(recipientFilter)
  end
end

-- Add a new line to players within the radius of a position.
function UNIT.addChatInRadius(player, filter, text, position, radius, translatableWords)
  local listeners = {}

  for _, listener in ipairs(g_Player.GetAll()) do
    if (versus.entity.isNearPosition(listener, position, radius)) then
      table.insert(listeners, listener)
    end
  end

  UNIT.addChat(listeners, player, filter, text, translatableWords)
end
