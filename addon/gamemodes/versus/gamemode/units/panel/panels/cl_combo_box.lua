local UNIT = UNIT
local PANEL = {}

function PANEL:Init()
  self:SetTall(48)
  self:SetCursor("hand")

  -- Internal state
  self.hovered = false
  self.pressed = false
  self.animProgress = 0
  self.arrowAnim = 0

  -- Colors matching the versus UI style
  self.bgColor = Color(20, 28, 40, 180)
  self.focusColor = Color(25, 35, 50, 220)
  self.accentColor = Color(80, 140, 220, 255)
  self.textColor = Color(220, 230, 240, 255)
  self.placeholderColor = Color(100, 120, 140, 150)

  -- Selected value display
  self.selectedText = ""
  self.placeholderText = "Select an option..."

  -- Choices storage
  self.Choices = {}
  self.Data = {}
  self.ChoiceIcons = {}
  self.Spacers = {}
  self.selected = nil
  self.m_bDoSort = true
end

function PANEL:Clear()
  self.selectedText = ""
  self.Choices = {}
  self.Data = {}
  self.ChoiceIcons = {}
  self.Spacers = {}
  self.selected = nil
  self:CloseMenu()
end

function PANEL:AddChoice(value, data, select, icon)
  local index = table.insert(self.Choices, value)

  if data then
    self.Data[index] = data
  end

  if icon then
    self.ChoiceIcons[index] = icon
  end

  if select then
    self:ChooseOption(value, index)
  end

  return index
end

function PANEL:RemoveChoice(index)
  if not isnumber(index) then return end
  local text = table.remove(self.Choices, index)
  local data = table.remove(self.Data, index)
  return text, data
end

function PANEL:AddSpacer()
  self.Spacers[#self.Choices] = true
end

function PANEL:GetOptionText(index)
  return self.Choices[index]
end

function PANEL:GetOptionData(index)
  return self.Data[index]
end

function PANEL:GetOptionTextByData(data)
  for id, dat in pairs(self.Data) do
    if dat == data then
      return self:GetOptionText(id)
    end
  end

  for id, dat in pairs(self.Data) do
    if dat == tonumber(data) then
      return self:GetOptionText(id)
    end
  end

  return data
end

function PANEL:GetSelectedID()
  return self.selected
end

function PANEL:GetSelected()
  if not self.selected then return end
  return self:GetOptionText(self.selected), self:GetOptionData(self.selected)
end

function PANEL:SetValue(strValue)
  self.selectedText = strValue or ""
end

function PANEL:GetValue()
  return self.selectedText
end

function PANEL:SetPlaceholderText(text)
  self.placeholderText = text or "Select an option..."
end

function PANEL:SetSortItems(bool)
  self.m_bDoSort = bool
end

function PANEL:GetSortItems()
  return self.m_bDoSort
end

function PANEL:ChooseOption(value, index)
  self:CloseMenu()
  self.selectedText = value or ""
  self.selected = index
  self:OnSelect(index, value, self.Data[index])
end

function PANEL:ChooseOptionID(index)
  local value = self:GetOptionText(index)
  self:ChooseOption(value, index)
end

function PANEL:OnSelect(index, value, data)
  -- Override this
end

function PANEL:OnMenuOpened(menu)
  -- Override this
end

function PANEL:IsMenuOpen()
  return IsValid(self.Menu) and self.Menu:IsVisible()
end

function PANEL:OpenMenu(pControlOpener)
  if #self.Choices == 0 then return end

  self:CloseMenu()

  local parent = self
  while IsValid(parent) and not parent:IsModal() do
    parent = parent:GetParent()
  end
  if not IsValid(parent) then parent = self end

  self.Menu = DermaMenu(false, parent)

  -- Style the menu to match versus aesthetic
  self.Menu.Paint = function(slf, w, h)
    draw.RoundedBox(0, 0, 0, w, h, Color(20, 28, 40, 240))
    -- Top accent line
    surface.SetDrawColor(80, 140, 220, 180)
    surface.DrawRect(0, 0, w, 2)
  end

  local buildMenu = function(choices)
    for k, v in ipairs(choices) do
      local origId = v.id or k
      local label = v.data or v

      local option = self.Menu:AddOption(label, function()
        self:ChooseOption(label, origId)
      end)

      -- Style menu items
      option:SetFont("VersusDefault")
      option:SetTextColor(Color(220, 230, 240, 255))
      option.Paint = function(slf, w, h)
        if slf:IsHovered() then
          draw.RoundedBox(0, 0, 0, w, h, Color(25, 35, 50, 220))
          surface.SetDrawColor(80, 140, 220, 200)
          surface.DrawRect(0, h - 1, w, 1)
        end
      end

      if self.ChoiceIcons[origId] then
        option:SetIcon(self.ChoiceIcons[origId])
      end

      if self.Spacers[origId] then
        self.Menu:AddSpacer()
      end
    end
  end

  if self:GetSortItems() then
    local sorted = {}
    for k, v in pairs(self.Choices) do
      local val = tostring(v)
      if string.len(val) > 1 and not tonumber(val) and val:StartsWith("#") then
        val = language.GetPhrase(val:sub(2))
      end
      table.insert(sorted, { id = k, data = v, label = val })
    end
    table.sort(sorted, function(a, b) return a.label < b.label end)
    buildMenu(sorted)
  else
    local plain = {}
    for k, v in ipairs(self.Choices) do
      table.insert(plain, { id = k, data = v, label = v })
    end
    buildMenu(plain)
  end

  local x, y = self:LocalToScreen(0, self:GetTall())

  self.Menu:SetMinimumWidth(self:GetWide())
  self.Menu:Open(x, y, false, self)

  self:OnMenuOpened(self.Menu)
end

function PANEL:CloseMenu()
  if IsValid(self.Menu) then
    self.Menu:Remove()
  end
  self.Menu = nil
end

function PANEL:OnCursorEntered()
  if not self:IsEnabled() then return end
  self.hovered = true
  surface.PlaySound("versus/ui_hover2.wav")
end

function PANEL:OnCursorExited()
  self.hovered = false
end

function PANEL:OnMousePressed()
  if not self:IsEnabled() then return end
  self.pressed = true
  surface.PlaySound("versus/ui_click1.wav")
end

function PANEL:OnMouseReleased()
  if self.pressed and self.hovered then
    if self:IsMenuOpen() then
      self:CloseMenu()
    else
      self:OpenMenu()
    end
  end
  surface.PlaySound("versus/ui_click2.wav")
  self.pressed = false
end

function PANEL:CheckConVarChanges()
  if not self.m_strConVar then return end

  local strValue = GetConVarString(self.m_strConVar)
  if self.m_strConVarValue == strValue then return end

  self.m_strConVarValue = strValue
  self:SetValue(self:GetOptionTextByData(self.m_strConVarValue))
end

function PANEL:Think()
  self:CheckConVarChanges()

  local isOpen = self:IsMenuOpen()
  local target = ((self.hovered or isOpen) and 1) or 0
  self.animProgress = Lerp(FrameTime() * 8, self.animProgress, target)

  -- Arrow rotation: 0 = down, 1 = up (menu open)
  local arrowTarget = isOpen and 1 or 0
  self.arrowAnim = Lerp(FrameTime() * 10, self.arrowAnim, arrowTarget)
end

function PANEL:Paint(w, h)
  local isOpen = self:IsMenuOpen()
  local currentBg = (self.pressed or isOpen) and self.focusColor
      or (self.hovered and Color(25, 35, 50, 200))
      or self.bgColor

  if not self:IsEnabled() then
    currentBg = ColorAlpha(currentBg, 50)
  end

  draw.RoundedBox(0, 0, 0, w, h, currentBg)

  -- Selected text or placeholder
  surface.SetFont("VersusDefault")
  local displayText = (self.selectedText ~= "") and self.selectedText or self.placeholderText
  local isPlaceholder = self.selectedText == ""

  local _, textH = surface.GetTextSize(displayText)

  if isPlaceholder then
    local alpha = not self:IsEnabled() and 60 or (80 + self.animProgress * 70)
    surface.SetTextColor(ColorAlpha(Color(100, 120, 140), alpha))
  else
    local alpha = not self:IsEnabled() and 80 or 255
    surface.SetTextColor(ColorAlpha(self.textColor, alpha))
  end

  surface.SetTextPos(12, (h - textH) * 0.5)
  surface.DrawText(displayText)

  -- Arrow chevron
  local arrowSize = 8
  local arrowX = w - 20
  local arrowY = h * 0.5

  local arrowAlpha = not self:IsEnabled() and 60 or (120 + self.animProgress * 135)
  surface.SetDrawColor(self.accentColor.r, self.accentColor.g, self.accentColor.b, arrowAlpha)

  -- Rotate arrow based on menu open state (lerped)
  -- Draw a simple chevron: two lines forming a "V" or "^"
  local flip = self.arrowAnim -- 0 = V (down), 1 = ^ (up)
  local dir = 1 - (flip * 2)  -- 1 = down, -1 = up

  surface.DrawLine(
    arrowX - arrowSize, arrowY - (dir * arrowSize * 0.4),
    arrowX, arrowY + (dir * arrowSize * 0.4)
  )
  surface.DrawLine(
    arrowX, arrowY + (dir * arrowSize * 0.4),
    arrowX + arrowSize, arrowY - (dir * arrowSize * 0.4)
  )

  -- Bottom accent line
  local lineAlpha = 30 + (self.animProgress * 195)
  surface.SetDrawColor(self.accentColor.r, self.accentColor.g, self.accentColor.b, lineAlpha)
  surface.DrawRect(0, h - 2, w, 2)

  return true
end

-- Sizes to the largest option text, plus padding and arrow
function PANEL:SizeToContents()
  local maxWidth = 0
  surface.SetFont("VersusDefault")

  for _, choice in ipairs(self.Choices) do
    local text = tostring(choice)
    local textWidth, _ = surface.GetTextSize(text)
    if textWidth > maxWidth then
      maxWidth = textWidth
    end
  end

  -- Add padding and space for arrow
  self:SetWide(12 + maxWidth + 6 + 16 + 12)
end

function PANEL:PerformLayout(w, h)
  -- No child panels needed; all drawing is done in Paint
end

vgui.Register("versus_ComboBox", PANEL, "EditablePanel")
