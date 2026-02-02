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

-- TODO: Extract this to the chatbox, it shouldn't be in the hint panel
function PANEL:FillSuggestions(partial)
  local alreadySuggesting = false

  if (partial:StartWith(versus.config["Command Prefix"])) then
    local matches = versus.command.find(partial:sub(2))

    if (#self.sortedHintNames ~= #matches) then
      self:ClearTooltip()
    end

    self.sortedHintNames = {}

    if (#matches > 0) then
      for index, command in pairs(matches) do
        if (versus.player.hasFlags(LocalPlayer(), command.requiredFlags)) then
          local hintText = versus.config["Command Prefix"] .. command.command .. " "

          table.insert(self.sortedHintNames, command.command)
          self:CreateHintLabel(index, command.command, hintText, command.parameterDescription, command.description)
        end
      end

      alreadySuggesting = true
    else
      self:ClearTooltip()
    end
  end

  if (not alreadySuggesting) then
    local matches = {}

    -- Add all non-exact matches to autocomplete
    for _, oldInput in pairs(UNIT.inputHistory) do
      if (oldInput:find(partial, 1, true)
            and oldInput ~= partial) then
        table.insert(matches, oldInput)
      end
    end

    if (#self.sortedHintNames ~= #matches) then
      self:ClearTooltip()
    end

    self.sortedHintNames = {}

    if (#matches > 0) then
      for index, oldInput in pairs(matches) do
        table.insert(self.sortedHintNames, oldInput)
        self:CreateHintLabel(index, oldInput, oldInput)
      end
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

-- Create a derma hint label parented to the hint panel.
function PANEL:CreateHintLabel(order, name, label, labelSuffix, selectedTip)
  if (not IsValid(self.hintLabels[name])) then
    local hintLabel = vgui.Create("DLabel", self)
    hintLabel:SetZPos(order)
    hintLabel:Dock(TOP)
    hintLabel:DockMargin(4, 0, 0, 0)
    hintLabel:SetFont("ChatFont")
    hintLabel._label = label
    hintLabel:SetText(label .. (labelSuffix and labelSuffix or ""))
    hintLabel:InvalidateLayout(true)
    hintLabel:InvalidateParent(true)
    hintLabel._toolTip = selectedTip or false
    hintLabel:SetMouseInputEnabled(true)

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
    self.hintLabels[name]:SetZPos(order)
  end

  if (not self.selectedHintName
        or self.selectedHintName == name) then
    self:SelectHint(name)
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
