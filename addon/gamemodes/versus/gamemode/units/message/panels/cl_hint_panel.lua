local UNIT = UNIT

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.selectedHintTooltip = nil
  self.selectedHintName = nil
  self.sortedHintNames = {}
  self.hintLabels = {}

  self:SetZPos(100)
  self:SetSize(UNIT.chatboxWidth, 0)
end

-- When the input starts with the command prefix and contains a space, returns (command, paramIndex)
-- where paramIndex is the 1-based index of the parameter currently being typed.
-- Returns (nil, 0) when still searching for a command name (no space yet) or command not found.
local function parseCommandFromInput(partial)
  local prefix = versus.config["Command Prefix"]
  local withoutPrefix = partial:sub(#prefix + 1)
  local spacePos = withoutPrefix:find(" ")

  if not spacePos then
    return nil, 0
  end

  local commandName = withoutPrefix:sub(1, spacePos - 1):lower()
  local command = versus.command.stored[commandName]

  if not command then
    return nil, 0
  end

  -- Count which 1-based parameter the user is currently typing
  local afterArgs = withoutPrefix:sub(spacePos + 1)
  local paramIndex = 0
  local inToken = false
  local inQuote = false

  for i = 1, #afterArgs do
    local c = afterArgs:sub(i, i)

    if c == '"' then
      inQuote = not inQuote

      if not inToken then
        paramIndex = paramIndex + 1
        inToken = true
      end
    elseif c == " " and not inQuote then
      inToken = false
    elseif not inToken then
      paramIndex = paramIndex + 1
      inToken = true
    end
  end

  -- When afterArgs is empty or ends with a space we are beginning the next parameter
  if afterArgs == "" or (afterArgs:sub(-1) == " " and not inQuote) then
    paramIndex = paramIndex + 1
  end

  return command, paramIndex
end

-- TODO: Extract this to the chatbox, it shouldn't be in the hint panel
function PANEL:FillSuggestions(partial)
  local alreadySuggesting = false
  local prefix = versus.config["Command Prefix"]

  if partial:StartWith(prefix) then
    local command, paramIndex = parseCommandFromInput(partial)

    if command and versus.player.hasFlags(LocalPlayer(), command.requiredFlags) then
      -- Exact command found and parameters are being typed: show only this command with active parameter highlighted
      if #self.sortedHintNames ~= 1 then
        self:ClearTooltip()
      end

      self.sortedHintNames = { command.command }

      local hintText = prefix .. command.command .. " "
      self:CreateHintLabel(1, command.command, hintText, command.parameterDescriptions, command.description, paramIndex)
      self:SelectHint(command.command)
      alreadySuggesting = true
    else
      -- Still typing the command name: show all matching commands
      local matches = versus.command.find(partial:sub(#prefix + 1))

      if #self.sortedHintNames ~= #matches then
        self:ClearTooltip()
      end

      self.sortedHintNames = {}

      if #matches > 0 then
        for index, cmd in pairs(matches) do
          if versus.player.hasFlags(LocalPlayer(), cmd.requiredFlags) then
            local hintText = prefix .. cmd.command .. " "

            table.insert(self.sortedHintNames, cmd.command)
            self:CreateHintLabel(index, cmd.command, hintText, cmd.parameterDescriptions, cmd.description)
          end
        end

        self:SelectFirstHint()
        alreadySuggesting = true
      else
        self:ClearTooltip()
      end
    end
  end

  if not alreadySuggesting then
    local matches = {}

    -- Add all non-exact matches to autocomplete
    for _, oldInput in pairs(UNIT.inputHistory) do
      if oldInput:find(partial, 1, true) and oldInput ~= partial then
        table.insert(matches, oldInput)
      end
    end

    if #self.sortedHintNames ~= #matches then
      self:ClearTooltip()
    end

    self.sortedHintNames = {}

    if #matches > 0 then
      for index, oldInput in pairs(matches) do
        table.insert(self.sortedHintNames, oldInput)
        self:CreateHintLabel(index, oldInput, oldInput)
      end

      self:SelectFirstHint()
    else
      self:ClearTooltip()
    end
  end

  self:PruneDermaHintLabel(self.sortedHintNames)
end

function PANEL:ClearTooltip()
  if (IsValid(self.selectedHintTooltip)) then
    self.selectedHintTooltip:Close()
    self.selectedHintTooltip:Remove()
  end
end

function PANEL:CreateTooltip(panel)
  local tooltip = vgui.Create("DTooltip")
  tooltip:SetText(panel._toolTip)
  tooltip:SizeToContents()

  -- Wait off-screen until the correct position is known
  tooltip:SetPos(ScrW(), ScrH())

  -- Override so the PositionTooltip isn't called (that moves the panel to the cursor)
  function tooltip:Paint(w, h)
    derma.SkinHook("Paint", "Tooltip", self, w, h)
  end

  -- Because the suggestions are docked their LocalToScreen may be incorrect
  timer.Simple(0.01, function()
    if (IsValid(panel) and IsValid(tooltip)) then
      local x, y = panel:GetParent():LocalToScreen(panel:GetPos())

      tooltip:SetPos(x + 64, y - panel:GetTall())
    end
  end)

  return tooltip
end

function PANEL:SelectHint(targetName)
  local newSelectedName

  self:ClearTooltip()

  for name, hintLabel in pairs(self.hintLabels) do
    if (IsValid(hintLabel)) then
      if (not targetName or targetName == name) then
        newSelectedName = name
      end

      if (self.selectedHintName and self.selectedHintName ~= newSelectedName) then
        hintLabel:SetTextColor(UNIT.unselectedColor)
      end
    end
  end

  local newSelected = self.hintLabels[newSelectedName]
  if (IsValid(newSelected)) then
    self.selectedHintName = newSelectedName
    newSelected:SetTextColor(UNIT.selectedColor)

    if (newSelected._toolTip) then
      self.selectedHintTooltip = self:CreateTooltip(newSelected)
    end
  end
end

function PANEL:SelectFirstHint()
  if (#self.sortedHintNames > 0) then
    self:SelectHint(self.sortedHintNames[1])
  end
end

function PANEL:SelectPreviousHint()
  for index, name in pairs(self.sortedHintNames) do
    if (self.selectedHintName == name) then
      self:SelectHint(self.sortedHintNames[math.max(1, index - 1)])
      break
    end
  end
end

function PANEL:SelectNextHint()
  for index, name in pairs(self.sortedHintNames) do
    if (self.selectedHintName == name) then
      self:SelectHint(self.sortedHintNames[math.min(#self.sortedHintNames, index + 1)])
      break
    end
  end
end

function PANEL:CompleteSelected()
  local selected = self.selectedHintName and self.hintLabels[self.selectedHintName] or nil
  if (IsValid(selected)) then
    UNIT.chatboxPanel:SetTextEntry(selected._label)
  end
end

-- Create a hint label parented to the hint panel.
-- For command hints, parameterDescriptions is a table of individual formatted parameter strings
-- (e.g. {"<player Target>", "<number Duration>"}). currentParamIndex (optional, 1-based) highlights
-- the parameter currently being typed, clamped to the last parameter when exceeded.
-- For plain history hints, parameterDescriptions is nil.
function PANEL:CreateHintLabel(order, name, label, parameterDescriptions, selectedTip, currentParamIndex)
  if (not IsValid(self.hintLabels[name])) then
    local hintLabel = vgui.Create("DLabel", self)
    hintLabel:SetZPos(order)
    hintLabel:Dock(TOP)
    hintLabel:DockMargin(4, 0, 0, 0)
    hintLabel:SetFont("VersusDefault")
    hintLabel._label = label
    hintLabel._toolTip = selectedTip or false
    hintLabel:SetMouseInputEnabled(true)

    if parameterDescriptions then
      -- Build the full text, size the label from it, then clear the text so the engine
      -- doesn't render it natively (DLabel extends the engine Label which draws text
      -- independently of the Lua Paint callback).
      local fullText = label
      for i, paramDesc in ipairs(parameterDescriptions) do
        fullText = fullText .. (i > 1 and " " or "") .. paramDesc
      end
      hintLabel:SetText(fullText)
      hintLabel:SizeToContents()
      hintLabel:SetText("")

      hintLabel._commandLabel = label
      hintLabel._parameterDescriptions = parameterDescriptions
      hintLabel._currentParamIndex = currentParamIndex

      -- Custom paint: draw the command prefix normally, then each parameter with
      -- the active one highlighted in gold and others dimmed.
      function hintLabel:Paint(w, h)
        surface.SetFont(self:GetFont())

        local _, textH = surface.GetTextSize("Ay")
        local y = math.floor((h - textH) / 2)
        local x = 0
        local baseColor = self:GetTextColor() or UNIT.unselectedColor

        -- Clamp active param index so multi-word last params stay highlighted
        local activeIndex = self._currentParamIndex
        if activeIndex and #self._parameterDescriptions > 0 then
          activeIndex = math.min(activeIndex, #self._parameterDescriptions)
        end

        -- Draw the command prefix (e.g. "/ban ")
        surface.SetTextColor(baseColor.r, baseColor.g, baseColor.b, baseColor.a)
        surface.SetTextPos(x, y)
        surface.DrawText(self._commandLabel)
        x = x + surface.GetTextSize(self._commandLabel)

        -- Draw each parameter, highlighting the active one in gold
        for i, paramDesc in ipairs(self._parameterDescriptions) do
          local isActive = activeIndex ~= nil and i == activeIndex

          -- Space separator between parameters (label already ends with a space)
          if i > 1 then
            surface.SetTextColor(baseColor.r, baseColor.g, baseColor.b, 80)
            surface.SetTextPos(x, y)
            surface.DrawText(" ")
            x = x + surface.GetTextSize(" ")
          end

          if isActive then
            surface.SetTextColor(255, 215, 50, 255)
          else
            surface.SetTextColor(baseColor.r, baseColor.g, baseColor.b, 80)
          end

          surface.SetTextPos(x, y)
          surface.DrawText(paramDesc)
          x = x + surface.GetTextSize(paramDesc)
        end
      end
    else
      hintLabel:SetText(label)
    end

    hintLabel:InvalidateLayout(true)
    hintLabel:InvalidateParent(true)

    local hintPanel = self

    function hintLabel:OnCursorMoved(cursorX, cursorY)
      hintPanel:SelectHint(name)
    end

    function hintLabel:OnMouseReleased(keyCode)
      if (keyCode == MOUSE_FIRST) then
        hintPanel:CompleteSelected()
      end
    end

    self.hintLabels[name] = hintLabel
    self:SizeToContentsY()
  else
    local existingLabel = self.hintLabels[name]
    existingLabel:SetZPos(order)

    -- Update the active parameter index so the highlight follows the cursor
    if currentParamIndex ~= nil then
      existingLabel._currentParamIndex = currentParamIndex
    end
  end
end

function PANEL:PruneDermaHintLabel(names)
  if (names == nil) then
    names = {}
  end

  for name, label in pairs(self.hintLabels) do
    if (not table.HasValue(names, name)) then
      label:Remove()

      if (self.selectedHintName == name) then
        self:SelectFirstHint()
      end

      self.hintLabels[name]:SetMouseInputEnabled(false)
      self.hintLabels[name] = nil
      self:InvalidateLayout(true)
      self:SizeToContentsY()
    end
  end
end

function PANEL:GetContentSize()
  local width = 0
  local height = 0

  for _, child in pairs(self:GetChildren()) do
    if (IsValid(child)) then
      height = height + child:GetTall()
      width = math.max(width, child:GetPos() + child:GetWide())
    end
  end

  return width, height
end

function PANEL:Paint(width, height)
  GAMEMODE:DrawBackgroundBox(0, 0, width, height, UNIT.backgroundColor)
end

vgui.Register("versus_Hint_Panel", PANEL, "Panel")
