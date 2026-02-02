local UNIT = UNIT

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self:SetSize(UNIT.chatboxWidth, 42)

  self:CreateScrollPanel()
  self:CreateFiltersPanel()
  self:CreateDermaButtons()
  self:CreateTextEntry()
  self:CreateHintPanel()
end

function PANEL:CreateHintPanel()
  self.hintPanel = vgui.Create("versus_Hint_Panel")
end

-- Create the derma buttons.
function PANEL:CreateDermaButtons()
  self.buttons = {}

  -- Create a derma button to scroll up the chat box.
  self:CreateButton("Up", "▲", self:GetTall(), "Scroll up the message area.", function()
    UNIT.history.position = UNIT.history.position - 1
  end, function(self)
    if (UNIT.history.messages[UNIT.history.position - UNIT.maximumLines]) then
      self:SetEnabled(true)
      self:SetAlpha(255)
    else
      self:SetEnabled(false)
      self:SetAlpha(50)
    end
  end)

  -- Create a derma button to scroll down the chat box.
  self:CreateButton("Down", "▼", self:GetTall(), "Scroll down the message area.", function()
    UNIT.history.position = UNIT.history.position + 1
  end, function(self)
    if (UNIT.history.messages[UNIT.history.position + 1]) then
      self:SetEnabled(true)
      self:SetAlpha(255)
    else
      self:SetEnabled(false)
      self:SetAlpha(50)
    end
  end)

  -- Create a derma button to go to the bottom of the chat box.
  self:CreateButton("Bottom", "⇊", self:GetTall(), "Goto the bottom of the message area.", function()
    UNIT.history.position = #UNIT.history.messages
  end, function(self)
    if (UNIT.history.position < #UNIT.history.messages) then
      self:SetEnabled(true)
      self:SetAlpha(255)
    else
      self:SetEnabled(false)
      self:SetAlpha(50)
    end
  end)

  -- Create a derma button for the filters.
  self:CreateButton("Filters", "Filters", 79, "Enable or disable message filters.", function()
    local IsVisible = self.filters:IsVisible()

    -- Check Is Visible.
    if (IsVisible) then
      self.filters:SetVisible(false)
    else
      self.filters:SetVisible(true)
    end
  end)
end

-- Create a derma button parented to the chat panel.
function PANEL:CreateButton(name, text, width, toolTip, doClick, think)
  self.buttons[name] = vgui.Create("versus_Button", self)
  self.buttons[name]:SetText(text)
  self.buttons[name]:SetWide(width)
  self.buttons[name]:Dock(RIGHT)
  self.buttons[name]:SetToolTip(toolTip)
  self.buttons[name].DoClick = doClick
  self.buttons[name].Think = think

  self.buttons[name]:DockMargin(4, 4, 4, 4)
  self.buttons[name]:MoveToBack()

  versus.panel.initPanelSkin(self.buttons[name])
end

function PANEL:CreateTextEntry()
  self.textEntry = vgui.Create("versus_Chatbox_TextEntry", self)
  self.textEntry:Dock(FILL)
  self.textEntry:DockMargin(4, 4, 4, 4)
  self.textEntry.chatbox = self

  versus.panel.initPanelSkin(self.textEntry)
end

function PANEL:CreateScrollPanel()
  self.scroll = vgui.Create("Panel")
  self.scroll:SetPos(0, 0)
  self.scroll:SetSize(0, 0)

  function self.scroll:OnMouseWheeled(delta)
    local isVisible = self:IsVisible()

    if (isVisible) then
      if (delta > 0) then
        if (UNIT.history.messages[UNIT.history.position - UNIT.maximumLines]) then
          UNIT.history.position = UNIT.history.position - 1
        end
      else
        if (UNIT.history.messages[UNIT.history.position + 1]) then
          UNIT.history.position = UNIT.history.position + 1
        end
      end
    end
  end
end

function PANEL:CreateFiltersPanel()
  self.filters = vgui.Create("versus_Chatbox_Filters")
end

function PANEL:Show()
  self:SetKeyboardInputEnabled(true)
  self:SetMouseInputEnabled(true)

  -- Set all panels connected to this one to be visible.
  self.scroll:SetVisible(true)
  self:SetVisible(true)
  self.hintPanel:SetVisible(true)
  self:MakePopup()

  -- Set the history position to the latest.
  UNIT.history.position = #UNIT.history.messages

  -- Request focus so that we can type into the text entry panel directly.
  self.textEntry:RequestFocus()

  self.hintPanel:ClearTooltip()

  -- Call a hook so plugins can get when the chat box is opened.
  hook.Run("OpenChatBox")
end

-- A function to hide the chat panel.
function PANEL:Hide()
  self:SetKeyboardInputEnabled(false)
  self:SetMouseInputEnabled(false)

  for _, hintLabel in pairs(self.hintPanel.hintLabels) do
    hintLabel:SetMouseInputEnabled(false)
  end

  -- Set the text of the text entry to an empty string to reset it.
  self.textEntry:SetText("")

  -- Set the panels connected to this to be invisible.
  self:SetVisible(false)
  self.scroll:SetVisible(false)
  self.filters:SetVisible(false)
  self.hintPanel:SetVisible(false)

  UNIT.selectedHintName = nil
  self.hintPanel:ClearTooltip()

  -- Call a hook so plugins can get when the chat box is closed.
  hook.Run("CloseChatBox")
end

function PANEL:SetTextEntry(text)
  self.textEntry:SetText(text)
  self.textEntry:SetCaretPos(text:len())
  self.textEntry:RequestFocus()
end

function PANEL:SetScrollPanelRect(x, y, width, height)
  local _, chatY = UNIT.getChatPosition()
  height = math.max(height, 100)

  self.scroll:SetPos(x, math.min(y, chatY - height))
  self.scroll:SetSize(width, height)
end

function PANEL:Paint()
  local titleColor = color_green
  local textColor = color_white

  -- Draw a rounded box for the text entry to go on.
  GAMEMODE:DrawBackgroundBox(0, 0, self:GetWide(), self:GetTall(), UNIT.backgroundColor)

  -- Set the font of the text.
  surface.SetFont("versus_Chatbox_MainText")

  -- Get the width of the text.
  local width = surface.GetTextSize("Say")
  local textHeight

  -- Check if we're sending a message to our team.
  if (UNIT.sayTeam) then
    -- Draw text to tell us that we're sending a message to our team.
    width, textHeight = draw.SimpleText("Say Team", "versus_Chatbox_MainText", 5, self:GetTall() * .5 + 1, color_black,
      TEXT_ALIGN_LEFT,
      TEXT_ALIGN_CENTER)
    draw.SimpleText("Say Team", "versus_Chatbox_MainText", 4, self:GetTall() * .5, titleColor, TEXT_ALIGN_LEFT,
      TEXT_ALIGN_CENTER)
  else
    width = draw.SimpleText("Say", "versus_Chatbox_MainText", 5, self:GetTall() * .5 + 1, color_black, TEXT_ALIGN_LEFT,
      TEXT_ALIGN_CENTER)
    draw.SimpleText("Say", "versus_Chatbox_MainText", 4, self:GetTall() * .5, titleColor, TEXT_ALIGN_LEFT,
      TEXT_ALIGN_CENTER)
  end

  self.textEntry:DockMargin(width + 16, 4, 4, 4)

  -- Draw a colon after the chat prefix.
  draw.SimpleText(":", "versus_Chatbox_MainText", 5 + width, self:GetTall() * .5 + 1, color_black, TEXT_ALIGN_LEFT,
    TEXT_ALIGN_CENTER)
  draw.SimpleText(":", "versus_Chatbox_MainText", 4 + width, self:GetTall() * .5, textColor, TEXT_ALIGN_LEFT,
    TEXT_ALIGN_CENTER)
end

-- Called eveyr frame.
function PANEL:Think()
  local x, y = UNIT.getChatPosition()

  -- Set the position of the chat panel.
  self:SetPos(x, y + 6)
  self.hintPanel:SetWide(self:GetWide() - self.textEntry:GetPos())
  self.hintPanel:SetPos(self.textEntry:GetPos() + 4, y - self.hintPanel:GetTall())

  local filtersButton = self.buttons["Filters"]
  self.filters:SetPos(self:LocalToScreen(filtersButton.x, filtersButton.y - self.filters:GetTall() - 8))

  -- Check if the main panel is visible.
  if (self:IsVisible() and input.IsKeyDown(KEY_ESCAPE)) then
    self:Hide()
  end
end

vgui.Register("versus_Chatbox", PANEL, "EditablePanel")

-- The text entry definition for the chatbox
local PANEL = {}

function PANEL:Init()
  self:SetTabbingDisabled(true)
  self:SetPos(34, 4)
  self:SetSize(396, 16)
end

function PANEL:OnEnter()
  local message = self:GetValue():Trim()

  -- Check if the message is valid.
  if (message and message ~= "") then
    UNIT.history.position = #UNIT.history.messages

    if (string.len(message) > UNIT.maximumChatLength) then
      message = string.sub(message, 1, UNIT.maximumChatLength)
    end

    RunConsoleCommand("say", string.Replace(message, "\"", "$q"))

    self:SetText("")

    -- Add to history and remove older historic messages so we
    -- don't clutter the auto completion with too many options
    if (not table.HasValue(UNIT.inputHistory, message)) then
      table.insert(UNIT.inputHistory, 1, message)
    end

    for i = #UNIT.inputHistory, GetConVar("versus_chatbox_input_history"):GetInt(), -1 do
      table.remove(UNIT.inputHistory, i)
    end
  end

  self.chatbox:Hide()
end

function PANEL:OnKeyCode(keyCode)
  if (keyCode == KEY_PAGEUP or keyCode == KEY_UP) then
    self.chatbox.hintPanel:SelectPreviousHint()
  elseif (keyCode == KEY_PAGEDOWN or keyCode == KEY_DOWN) then
    self.chatbox.hintPanel:SelectNextHint()
  end

  if (keyCode == KEY_RIGHT or keyCode == KEY_TAB) then
    self.chatbox.hintPanel:CompleteSelected()
  end
end

function PANEL:Think()
  local message = self:GetValue()
  local length = utf8.len(message)

  -- Check if the length of the message is greater than the maximum allowed.
  if (length > UNIT.maximumChatLength) then
    self:SetText(string.sub(message, 1, UNIT.maximumChatLength))
    self:SetCaretPos(UNIT.maximumChatLength)

    -- Play a sound to alert the player that they're over the character limit.
    surface.PlaySound("common/talk.wav")
  elseif (length > 0) then
    self.chatbox.hintPanel:FillSuggestions(message)
  else
    self.chatbox.hintPanel:PruneDermaHintLabel()
  end
end

vgui.Register("versus_Chatbox_TextEntry", PANEL, "versus_TextEntry")

-- The definition for chatbox filters
local PANEL = {}

function PANEL:Init()
  self.checkBoxes = {}

  self:SetSize(120, 50)

  self:CreateCheckBox("World", "versus_chatbox_world", 8, "Filter out-of-character messages.", "Filter World", 8)
  self:CreateCheckBox("Join/Leave", "versus_chatbox_joinleave", 8, "Filter join/leave messages.", "Filter Join/Leave",
    28)
end

function PANEL:CreateCheckBox(name, conVar, x, toolTip, label, y)
  y = y or 4

  -- Check if a label was defined.
  if (label) then
    self.checkBoxes[name] = vgui.Create("DCheckBoxLabel", self)
    self.checkBoxes[name]:SetText(label)
  else
    self.checkBoxes[name] = vgui.Create("DCheckBox", self)
  end

  -- Set the position and other settings of the check box.
  self.checkBoxes[name]:SetPos(x, y)
  self.checkBoxes[name]:SetToolTip(toolTip)
  self.checkBoxes[name]:SetConVar(conVar)

  -- Check if a label was defined.
  if (label) then
    self.checkBoxes[name]:SizeToContents()
  else
    self.checkBoxes[name]:SetSize(16, 16)
  end

  versus.panel.initPanelSkin(self.checkBoxes[name])
end

-- Called every time the panel should be painted.
function PANEL:Paint()
  GAMEMODE:DrawBackgroundBox(0, 0, self:GetWide(), self:GetTall(), UNIT.backgroundColor)
end

vgui.Register("versus_Chatbox_Filters", PANEL, "EditablePanel")
