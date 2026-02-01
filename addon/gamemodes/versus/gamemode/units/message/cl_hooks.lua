local UNIT = UNIT

function UNIT.hook:VersusInitialized()
  self.createChatboxPanel()
end

-- Called when a player presses a bind.
function UNIT.hook:PlayerBindPress(player, bind, press)
  if (bind == "toggleconsole") then
    UNIT.chatboxPanel:Hide()
    ErrorNoHalt("I don't believe this is ever called...")
  elseif ((bind == "messagemode" or bind == "messagemode2") and press) then
    UNIT.chatboxPanel:Show()

    return true
  end
end

local function drawChatMessages()
  local chatX, chatY = UNIT.getChatPosition()
  local decayedIndices = {}
  local x, y = chatX, chatY

  surface.SetFont("versus_Chatbox_MainText")

  local space = surface.GetTextSize(" ")
  local box = { width = 0, height = 0 }

  local messages = UNIT.messages
  local isVisible = UNIT.chatboxPanel:IsVisible()

  -- Check if our chat panel is visible.
  if (isVisible) then
    messages = {}

    for i = 0, (UNIT.maximumLines - 1) do
      table.insert(messages, UNIT.history.messages[UNIT.history.position - i])
    end
  else
    if (#UNIT.history.messages > 100) then
      local amount = #UNIT.history.messages - 100

      for i = 1, amount do
        table.remove(UNIT.history.messages, 1)
      end
    end
  end

  for index, message in pairs(messages) do
    if (messages[index - 1]) then y = y - messages[index - 1].spacing end

    local isVisible = UNIT.chatboxPanel:IsVisible()

    if (not isVisible and index == 1) then
      y = y - ((UNIT.getLineHeight() + message.spacing) * (message.lines - 1)) + 14
    else
      if (index == 1) then
        y = y + 2
      end

      y = y - ((UNIT.getLineHeight() + message.spacing) * message.lines)
    end

    if (UNIT.drawMessage(message, x, y, box, nil, nil, true) == false) then
      decayedIndices[index] = true
    end
  end

  for index in pairs(decayedIndices) do
    table.remove(messages, index)
  end

  UNIT.chatboxPanel:SetScrollPanelRect(x, chatY - box.height, UNIT.chatboxWidth, box.height)
end

local function drawNotifications()
  surface.SetFont("versus_Chatbox_MainText")

  for positionCallback, notifications in pairs(UNIT.notifications) do
    local decayedIndices = {}
    local x, y, isCentered = 0, nil
    local spacingMultiplier

    -- Get the size of a space with this font.
    local space = surface.GetTextSize(" ")

    for index, notification in ipairs(notifications) do
      x, y, isCentered, spacingMultiplier = positionCallback(notification, y, #notifications)
      spacingMultiplier = spacingMultiplier or -1

      if (notifications[index - 1]) then
        y = y + (spacingMultiplier * notifications[index - 1].spacing)
      end

      -- Increase y by our spacing multiplied by the lines we have.
      y = y + ((UNIT.getLineHeight() + notification.spacing) * notification.lines * spacingMultiplier)

      if (UNIT.drawMessage(notification, x, y, nil, isCentered, true) == false) then
        if (notification.onDecayed) then
          notification:onDecayed()
        end

        decayedIndices[index] = true
      end
    end

    for index in pairs(decayedIndices) do
      table.remove(notifications, index)
    end
  end
end

-- Called when the HUD should be painted.
function UNIT.hook:HUDPaint()
  drawChatMessages()

  local localPlayer = LocalPlayer()
  local entitiesInView = ents.FindInSphere(localPlayer:GetPos(), 512)

  for _, entity in pairs(entitiesInView) do
    if (entity:IsPlayer() and entity ~= localPlayer and entity.lastChatMessage ~= nil) then
      local pos
      local bone = entity:LookupBone("ValveBiped.Bip01_Head1")

      if (bone) then
        pos = entity:GetBonePosition(bone):ToScreen()
      else
        pos = (entity:GetPos() + entity:OBBCenter()):ToScreen()
      end

      UNIT.drawMessage(entity.lastChatMessage, pos.x, pos.y, nil, true, true)
    end
  end
end

-- Called after all other 2D draw hooks are called
function UNIT.hook:DrawOverlay()
  drawNotifications()
end

-- When a notification is received on the client
net.Receive("versus.message.notification", function(len)
  local message = net.ReadString()
  local class = net.ReadUInt(16)

  -- Add the notification using Garry's system.
  versus.message.notifyMessageAdd(message, class)
end)

-- Hook into when a player message is sent from the server.
net.Receive("versus.message.playerChat", function(len)
  local player = net.ReadEntity()
  local filter = net.ReadString()
  local text = net.ReadString()
  local translatableWordsCount = net.ReadUInt(UNIT.bitSizeTranslatedWords)
  local translatableWords = {}

  for _ = 1, translatableWordsCount do
    table.insert(translatableWords, net.ReadString())
  end

  -- Check to see if the player is a player.
  if (player:IsPlayer()) then
    player.lastChatMessage = UNIT.chatText(player:EntIndex(), player:getCombinedName(), text, filter, translatableWords)
  end
end)

-- Hook into when a message is sent from the server.
net.Receive("versus.message.chat", function(len)
  local filter = net.ReadString()
  local text = net.ReadString()
  local translatableWordsCount = net.ReadUInt(UNIT.bitSizeTranslatedWords)
  local translatableWords = {}

  for _ = 1, translatableWordsCount do
    table.insert(translatableWords, net.ReadString())
  end

  -- Chat Text.
  UNIT.chatText(nil, nil, text, filter, translatableWords)
end)
