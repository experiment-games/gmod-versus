local UNIT = UNIT
local g_Player = player

UNIT.notifyClassStyles = UNIT.notifyClassStyles or {}

UNIT.backgroundColor = color_background
UNIT.unselectedColor = Color(255, 255, 255, 100)
UNIT.selectedColor = color_white

CreateClientConVar("versus_chatbox_world", "0", true, true)
CreateClientConVar("versus_chatbox_joinleave", "0", true, true)
CreateClientConVar("versus_chatbox_input_history", "15", true, false,
  "How many times your input is saved before older input is cleared.", 0, 30)

UNIT.maximumChatLength = UNIT.maximumChatLength or 126
UNIT.maximumLines = UNIT.maximumLines or 8
UNIT.joinSpam = UNIT.joinSpam or {}

UNIT.notifications = {}
UNIT.messages = UNIT.messages or {}

UNIT.history = UNIT.history or {}
UNIT.history.messages = UNIT.history.messages or {}
UNIT.history.position = UNIT.history.position or 0
UNIT.inputHistory = UNIT.inputHistory or {}

UNIT.chatboxWidth = math.Clamp(700, 576, ScrW() * .5)

function UNIT:createNotificationStack()
  if IsValid(UNIT.notificationStack) then
    UNIT.notificationStack:Remove()
  end

  UNIT.notificationStack = vgui.Create("versus_NotificationStack")
  UNIT.notificationStack:SetPaintedManually(true)
end

function UNIT.lookupBinding(bind)
  local binding = input.LookupBinding(bind)

  if (not binding) then
    return ("<" .. bind .. " not set!>"):upper(), false
  end

  binding = binding:upper()

  -- Hard-coded translations
  if (binding == "MOUSE1") then
    binding = "LEFT MOUSE BUTTON"
  elseif (binding == "MOUSE2") then
    binding = "RIGHT MOUSE BUTTON"
  end

  return binding, true
end

-- Get the position of notifications
function UNIT.getNotificationPosition(message, lastY, numMessages)
  local startX, startY = ScrW() * .5, 25

  return startX, lastY or startY, true, 1
end

-- Get the position of the chat area.
function UNIT.getChatPosition()
  local x, y = GAMEMODE.SPACING, ScrH() - (ScrH() / 4)

  -- Check if we have a custom chat area position set.
  if (UNIT.position) then
    x = UNIT.position.x
    y = UNIT.position.y
  end

  return x, y
end

-- Get the x position of the chat area.
function UNIT.getX()
  local x, y = UNIT.getChatPosition()

  return x
end

-- Get the y position of the chat area.
function UNIT.getY()
  local x, y = UNIT.getChatPosition()

  return y
end

-- Get the line height for a message
function UNIT.getLineHeight()
  surface.SetFont("versus_Chatbox_MainText")
  local textWidth, textHeight = surface.GetTextSize("A")
  return textHeight
end

-- Return a table of wrapped text (thanks to SamuraiMushroom for this function).
function UNIT.wrapText(text, font, width, overhead, base)
  surface.SetFont(font)

  -- Save the original width for the next line and take the overhead from the width.
  local original = width
  width = width - (overhead or 0)

  -- Check to see if the width of the text is greater than the width we specified.
  if (surface.GetTextSize(string.gsub(text, "&", "U")) > width) then
    local length = 0
    local exploded = {}
    local seperator = ""

    -- Check if the text has any spaces in it.
    if (string.find(text, " ", nil, false)) then
      exploded = string.Explode(" ", text)
      seperator = " "
    else
      exploded = string.ToTable(text)
      seperator = ""
    end

    -- Create a variable to store the current position of the text.
    local i = 1

    -- Count how many characters the length of the text is which is still smaller than our specified width.
    while (length < width) do
      local block = table.concat(exploded, seperator, 1, i)

      -- Set the length to be the length of this block of text.
      length = surface.GetTextSize(string.gsub(block, "&", "U"))

      -- Increase the iterator so that we can move on to the next block of text.
      i = i + 1
    end

    -- Make sure that the text is cut, otherwise we get a stack overflow
    -- from this function recursively calling itself on something that has
    -- _just the right width_ to cause that problem
    if (i == 2) then i = 3 end

    local cutText = table.concat(exploded, seperator, 1, i - 2)
    table.insert(base, cutText)

    -- Get the second line of the text which we may need to wrap again.
    text = table.concat(exploded, seperator, i - 1)

    -- Check to see if the size of the second line is greater than our
    -- specified width.
    if (surface.GetTextSize(string.gsub(text, "&", "U")) > original) then
      UNIT.wrapText(text, font, original, nil, base)
    else
      table.insert(base, text)
    end
  else
    table.insert(base, text)
  end
end

-- Create all the derma panels.
function UNIT.createChatboxPanel()
  if (IsValid(UNIT.chatboxPanel)) then
    UNIT.chatboxPanel:Remove()
  end

  UNIT.chatboxPanel = vgui.Create("versus_Chatbox")

  UNIT.chatboxPanel:Hide()
end

function UNIT.showChat()
  if (IsValid(UNIT.chatboxPanel)) then
    UNIT.chatboxPanel:Show()
  end
end

function UNIT.hideChat()
  if (IsValid(UNIT.chatboxPanel)) then
    UNIT.chatboxPanel:Hide()
  end
end

function UNIT.setChatText(text)
  if (IsValid(UNIT.chatboxPanel)) then
    UNIT.chatboxPanel.textEntry:SetText(text)
    UNIT.chatboxPanel.textEntry:SetCaretPos(string.len(text))
  end
end

-- Add a new message to the message queue.
function UNIT.messageAdd(title, name, text, filtered, icon, noSound)
  local message = {}

  if (title) then
    message.title = {}
    message.title.text = title[1]
    message.title.color = title[2] or color_white
  end

  if (name) then
    message.name = {}
    message.name.text = name[1]
    message.name.color = name[2] or color_white
  end

  message.timeStart = CurTime()
  message.timeFade = message.timeStart + 10
  message.timeFinish = message.timeFade + 1
  message.spacing = 0
  message.blocks = {}
  message.color = text[2] or color_white
  message.alpha = 255
  message.lines = 1
  message.text = text[1]
  message.icon = icon

  UNIT.extractClasses(message, UNIT.chatboxWidth)
  UNIT.printConsole(message)

  -- Check if the message is filtered.
  if (filtered) then
    return
  end

  -- Check the position of the history to see if it's the latest one.
  if (UNIT.history.position == #UNIT.history.messages) then
    UNIT.history.position = #UNIT.history.messages + 1
  end

  -- Check if we've reached the maximum lines.
  if (#UNIT.messages == UNIT.maximumLines) then
    table.remove(UNIT.messages, UNIT.maximumLines)
  end

  -- Get a copy of the message for the history.
  local copy = table.Copy(message)

  -- Insert the message into both the messages table and the history table.
  table.insert(UNIT.messages, 1, message)
  table.insert(UNIT.history.messages, copy)

  if (not noSound) then
    -- Play a sound to let us know we've got a new message.
    surface.PlaySound("common/talk.wav")
  end

  return message
end

function UNIT.getNotifyClass(classID)
  return UNIT.notifyClassStyles[classID]
end

function UNIT.notify(text, classID)
  classID = classID or 0
  local class = UNIT.getNotifyClass(classID)

  if (not class) then
    classID = NOTIFY_INFORMATION
    class = UNIT.getNotifyClass(NOTIFY_INFORMATION)
  end

  if (class.sound) then
    if (istable(class.sound)) then
      sound.Play(class.sound.path, LocalPlayer():EyePos(), 75, class.sound.pitch or 100, class.sound.volume or 1)
    else
      surface.PlaySound(class.sound)
    end
  end

  local message

  if (class.getPosition and class.getPosition ~= UNIT.getChatPosition) then
    -- New VGUI notification system
    message = {
      text = text,
      class = classID,
      playSound = false, -- Sound already played above
      timeStart = CurTime()
    }

    UNIT.printConsole(message)

    UNIT.notificationStack:ShowNotification(message)
  else
    message = UNIT.messageAdd(nil, nil, { text, class.color }, nil, { class.icon, class.iconText }, true)
  end

  return message
end

-- Print the message to the console.
function UNIT.printConsole(message)
  local total = ""

  -- Check if we have an icon specified.
  if (message.icon) then total = total .. "(" .. message.icon[2] .. ") " end
  if (message.title) then total = total .. message.title.text .. " " end
  if (message.name) then total = total .. message.name.text .. ": " end

  if (message.blocks) then
    for index, messageBlock in pairs(message.blocks) do
      local space = " "

      -- Check if we're at the last key, if we're breaking, and if we're a text type.
      if (index == #message.blocks) then
        space = ""
      end
      if (messageBlock.newline) then
        space = ""
      end
      if (messageBlock.class == "Text") then
        total = total .. messageBlock.text .. space
      end

      if (messageBlock.newline) then
        print(total)

        -- Reset the string so we can do the next line.
        total = ""
      end
    end
  else
    total = total .. message.text
  end

  if (total ~= "") then
    print(total)
  end
end

-- Extract classes.
function UNIT.extractClasses(message, wrapWidth)
  local width = 0

  surface.SetFont("versus_Chatbox_MainText")

  -- Check if we have an icon specified.
  if (message.icon) then
    width = width + 16 + surface.GetTextSize(" ")
  end
  if (message.title) then
    width = width + surface.GetTextSize(string.gsub(message.title.text .. " ", "&", "U"))
  end
  if (message.name) then
    width = width + surface.GetTextSize(string.gsub(message.name.text .. " ", "&", "U"))
  end

  -- Create a table to store the wrapped text and then get the wrapped text.
  local wrapped = {}

  -- Wrap the text into our table.
  UNIT.wrapText(message.text, "versus_Chatbox_MainText", wrapWidth, width, wrapped)

  for index, text in pairs(wrapped) do
    if (text ~= "") then
      if (index == #wrapped) then
        table.insert(message.blocks, { class = "Text", text = text })
      else
        table.insert(message.blocks, { class = "Text", text = text, newline = true })

        -- Increase the number of lines.
        message.lines = message.lines + 1
      end
    end
  end

  for index, messageBlock in pairs(message.blocks) do
    if (messageBlock.newline) then
      if (not message.blocks[index + 1]) then
        message.blocks[index].newline = false

        -- Reduce the number of lines.
        message.lines = message.lines - 1
      end
    end
  end
end

-- Explode a string by tags.
function UNIT.explodeByTags(variable, seperator, open, close)
  local results = {}
  local current = ""
  local tag = false

  for i = 1, string.len(variable) do
    local character = string.sub(variable, i, i)

    -- Check to see if we're currently handling a tag.
    if (not tag) then
      if (character == open) then
        current = current .. character
        tag = true
      elseif (character == seperator) then
        results[#results + 1] = current
        current = ""
      else
        current = current .. character
      end
    else
      current = current .. character

      -- Check to see if this character is the close tag.
      if (character == close) then
        tag = false
      end
    end
  end

  -- Check to see if the current current is not an empty string.
  if (current ~= "") then
    results[#results + 1] = current
  end

  return results
end

-- Called when a player says something or a message is received from the server.
function UNIT.chatText(index, name, text, filter, translatableWords)
  local class = filter
  local filtered = false

  -- Check if it is a valid filter.
  if (
        filter == "yell" or filter == "whisper" or filter == "me"
        or filter == "radio" or filter == "pm" or filter == "notify"
      ) then
    filter = "local"
  elseif (filter == "world") then
    filter = "world"
  end

  if (ConVarExists("versus_chatbox_" .. filter) and GetConVar("versus_chatbox_" .. filter):GetInt() == 1) then
    filtered = true
  end

  local player = index and g_Player.GetByID(index)

  -- Fix Valve's errors
  text = string.Replace(text, " ' ", "'")

  if (translatableWords ~= nil and #translatableWords > 0) then
    local translations = {}

    for _, translatableWord in pairs(translatableWords) do
      translations[#translations + 1] = language.GetPhrase(translatableWord)
    end

    PrintTable(translations)
    text = string.format(text, unpack(translations))
  end

  local message

  if (IsValid(player)) then
    local teamIndex = player:Team()
    local teamColor = team.GetColor(teamIndex)
    local icon = nil

    -- Check if the player is a super admin.
    if (player:IsSuperAdmin()) then
      icon = { Material("icon16/shield.png"), "^" }
    elseif (player:IsAdmin()) then
      icon = { Material("icon16/star.png"), "*" }
    elseif (player:GetNWBool("versus_Moderator")) then
      icon = { Material("icon16/emoticon_smile.png"), ":)" }
    else
      icon = hook.Run("GetPlayerIcon", player)
    end

    -- Check if the class is valid.
    if (class == "chat") then
      message = UNIT.messageAdd(nil, { name, teamColor }, { text }, filtered)
    elseif (class == "local") then
      message = UNIT.messageAdd(nil, nil, { name .. ": " .. text, Color(255, 255, 150, 255) }, filtered)
    elseif (class == "me") then
      message = UNIT.messageAdd(nil, nil, { "*** " .. name .. " " .. text, Color(255, 255, 150, 255) }, filtered)
    elseif (class == "yell") then
      message = UNIT.messageAdd({ "(Yell)" }, nil, { name .. ": " .. text, Color(255, 255, 150, 255) }, filtered)
    elseif (class == "whisper") then
      message = UNIT.messageAdd({ "(Whisper)" }, nil, { name .. ": " .. text, Color(255, 255, 150, 255) }, filtered)
    elseif (class == "radio") then
      message = UNIT.messageAdd({ "(Radio)" }, nil, { name .. ": " .. text, Color(150, 225, 75, 255) }, filtered)
    elseif (class == "pm") then
      message = UNIT.messageAdd({ "(PM)" }, nil, { name .. ": " .. text, Color(255, 150, 125, 255) }, filtered)
    elseif (class == "world") then
      message = UNIT.messageAdd({ "(World)", Color(255, 75, 75, 255) }, { name, teamColor }, { text }, filtered, icon)
    end
  else
    if (name == "Console" and class == "chat") then
      message = UNIT.messageAdd({ "(World)" }, { "Console", color_lightgray }, { text }, filtered)
    elseif (class == "radio") then
      message = UNIT.messageAdd({ "(Radio)" }, nil, { text, Color(150, 225, 75, 255) }, filtered)
    elseif (class == "joinleave") then
      text = text .. "."

      -- Check if we find brackets in the text.
      if (string.find(text, "%(", nil, false) and string.find(text, "%)", nil, false)) then
        text = string.gsub(text, "Kicked by Console :", "Kicked by Console:", 1)
        text = string.gsub(text, "%.%)", ")")

        -- Add the edited message.
        message = UNIT.messageAdd(nil, nil, { text, Color(255, 75, 75, 255) }, filtered)
      else
        if (not UNIT.joinSpam[text] or CurTime() > UNIT.joinSpam[text]) then
          message = UNIT.messageAdd(nil, nil, { text, Color(175, 255, 125, 255) }, filtered)

          -- Set the next available join for this player to be 5 seconds from now.
          UNIT.joinSpam[text] = CurTime() + 5
        end
      end
    elseif (class == "notify") then
      message = UNIT.messageAdd(nil, nil, { text, Color(255, 100, 200, 255) }, filtered)
    else
      message = UNIT.messageAdd(nil, nil, { text, Color(255, 255, 150, 255) }, filtered)
    end
  end

  return message
end

function UNIT.drawMessage(message, x, y, box, isCentered, hasBackground, forceDraw)
  local messageX = x
  local messageY = y
  local curTime = CurTime()
  local messageHeight = UNIT.getLineHeight()
  local space = surface.GetTextSize(" ")
  local xAlign = isCentered and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT
  box = box or { width = 0, height = 0 }

  -- We need to queue the drawing, because we don't know the size until
  -- we've processed the whole message. We need the size of the message
  -- to draw a background behind it.
  local drawQueue = setmetatable({}, FindMetaTable("VersusDrawQueue")):init()

  if (forceDraw) then
    message.alpha = 255
  elseif (curTime >= message.timeFade) then
    local fadeTime = message.timeFinish - message.timeFade
    local timeLeft = message.timeFinish - curTime
    local alpha = math.Clamp((255 / fadeTime) * timeLeft, 0, 255)

    if (alpha == 0) then
      return false
    else
      message.alpha = alpha
    end
  end

  if (message.icon) then
    if (not isCentered) then
      drawQueue:add(function(x, y, width, height)
        surface.SetMaterial(message.icon[1])
        surface.SetDrawColor(255, 255, 255, message.alpha)
        surface.DrawTexturedRect(x, y + 6, width, height)
      end, messageX, messageY, 16, 16)
    end

    messageX = messageX + 16 + surface.GetTextSize(" ")
  end

  -- Check if we have a title specified.
  if (message.title) then
    local width = surface.GetTextSize(string.gsub(message.title.text, "&", "U"))

    -- Get the title color for our text.
    local titleColor = Color(message.title.color.r, message.title.color.g, message.title.color.b, message.alpha)

    drawQueue:add(function(x, y)
      draw.SimpleText(message.title.text, "versus_Chatbox_MainText", x + 1, y + 1, Color(0, 0, 0, message.alpha), xAlign,
        0)
      draw.SimpleText(message.title.text, "versus_Chatbox_MainText", x, y, titleColor, xAlign, 0)
    end, messageX, messageY)

    -- Increase our x position with our space size.
    messageX = messageX + width + space
  end

  -- Check if we have a name specified.
  if (message.name) then
    local width = surface.GetTextSize(string.gsub(message.name.text, "&", "U"))

    -- Get the color of the name.
    local nameColor = Color(message.name.color.r, message.name.color.g, message.name.color.b, message.alpha)

    drawQueue:add(function(x, y, width, height)
      draw.SimpleText(message.name.text, "versus_Chatbox_MainText", x + 1, y + 1, Color(0, 0, 0, message.alpha), xAlign,
        0)
      draw.SimpleText(message.name.text, "versus_Chatbox_MainText", x, y, nameColor, xAlign, 0)
    end, messageX, messageY)

    -- Increase our x position with our width.
    messageX = messageX + width

    -- Get the width of a colon with this font.
    local width = surface.GetTextSize(":")

    drawQueue:add(function(x, y, width, height)
      draw.SimpleText(":", "versus_Chatbox_MainText", x + 1, y + 1, Color(0, 0, 0, message.alpha), xAlign, 0)
      draw.SimpleText(":", "versus_Chatbox_MainText", x, y, Color(255, 255, 255, message.alpha), xAlign, 0)
    end, messageX, messageY)

    -- Increase our x position with our space size.
    messageX = messageX + width + space
  end

  -- Get the text color.
  local textColor = Color(message.color.r, message.color.g, message.color.b, message.alpha)

  for k2, v2 in pairs(message.blocks) do
    if (v2.class == "Text") then
      local width = surface.GetTextSize(string.gsub(v2.text, "&", "U"))

      drawQueue:add(function(x, y, width, height)
        draw.SimpleText(v2.text, "versus_Chatbox_MainText", x + 1, y + 1, Color(0, 0, 0, message.alpha), xAlign, 0)
        draw.SimpleText(v2.text, "versus_Chatbox_MainText", x, y, textColor, xAlign, 0)
      end, messageX, messageY)

      -- Increase our x position with our space size.
      messageX = messageX + width + space
    end

    if (messageX - x > box.width) then
      box.width = messageX - x
    end

    if (UNIT.getY() - y > box.height) then
      box.height = UNIT.getY() - y
    end

    -- Check if we need to create a new line here.
    if (v2.newline) then
      messageY = messageY + UNIT.getLineHeight() + message.spacing
      messageX = x
      messageHeight = messageHeight + UNIT.getLineHeight()
    end
  end

  if (message.icon and isCentered) then
    drawQueue:add(function(x, y, width, height)
      surface.SetMaterial(message.icon[1])
      surface.SetDrawColor(255, 255, 255, message.alpha)
      surface.DrawTexturedRect(x, y, width, height)
    end, x - (box.width * .5), y, 16, 16)
  end

  if (hasBackground) then
    GAMEMODE:DrawBackgroundBox(x - (box.width * .5) - 4, y - 2, box.width + 12, messageHeight,
      Color(0, 0, 0, message.alpha / 255 * 100))
  end

  drawQueue:process()
end

function UNIT.getMessageAtPosition(screenX, screenY)
  local chatX, chatY = UNIT.getChatPosition()
  local x, y = chatX, chatY

  surface.SetFont("versus_Chatbox_MainText")

  local isVisible = UNIT.chatboxPanel:IsVisible()
  local messages

  if (isVisible) then
    messages = {}

    for i = 0, (UNIT.maximumLines - 1) do
      table.insert(messages, UNIT.history.messages[UNIT.history.position - i])
    end
  else
    messages = UNIT.messages
  end

  for index, message in pairs(messages) do
    if (not message) then continue end

    if (messages[index - 1]) then y = y - messages[index - 1].spacing end

    if (not isVisible and index == 1) then
      y = y - ((UNIT.getLineHeight() + message.spacing) * (message.lines - 1)) + 14
    else
      if (index == 1) then
        y = y + 2
      end

      y = y - ((UNIT.getLineHeight() + message.spacing) * message.lines)
    end

    local messageHeight = UNIT.getLineHeight() * message.lines

    if (screenX >= x and screenX <= x + UNIT.chatboxWidth
          and screenY >= y and screenY <= y + messageHeight) then
      return message
    end
  end

  return nil
end
