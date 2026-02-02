local UNIT = UNIT
local PANEL = {}

function PANEL:Init()
  self:SetTall(48)

  self.textEntry = vgui.Create("DTextEntry", self)
  self.textEntry:SetFont("VersusDefault")
  self.textEntry:SetTextColor(Color(220, 230, 240))
  self.textEntry:SetCursorColor(Color(80, 140, 220))
  self.textEntry:SetDrawLanguageID(false)
  self.textEntry.Paint = function(slf, w, h)
    -- Custom paint - no background, handled by parent
    slf:DrawTextEntryText(slf:GetTextColor(), slf:GetHighlightColor(), slf:GetCursorColor())
  end

  self.textEntry.OnValueChange = function(slf, val)
    self:OnValueChange(val)
  end

  self.textEntry.OnEnter = function(slf, value)
    self:OnEnter(value)
  end

  self.textEntry.OnKeyCode = function(slf, keyCode)
    self:OnKeyCode(keyCode)
  end

  self.textEntry.OnGetFocus = function()
    self.focused = true
  end

  self.textEntry.OnLoseFocus = function()
    self.focused = false
  end

  self.focused = false
  self.animProgress = 0

  self.bgColor = Color(20, 28, 40, 180)
  self.focusColor = Color(25, 35, 50, 220)
  self.accentColor = Color(80, 140, 220, 255)
end

function PANEL:SetText(text)
  self.textEntry:SetText(text or "")
end

function PANEL:GetText()
  return self.textEntry:GetText()
end

function PANEL:SetValue(text)
  self:SetText(text)
end

function PANEL:GetValue()
  return self:GetText()
end

function PANEL:RequestFocus()
  self.textEntry:RequestFocus()
end

function PANEL:SetPlaceholderText(text)
  self.textEntry:SetPlaceholderText(text or "")
end

function PANEL:SetUpdateOnType(enabled)
  self.textEntry:SetUpdateOnType(enabled)
end

function PANEL:SetTabbingDisabled(disabled)
  self.textEntry:SetTabbingDisabled(disabled)
end

function PANEL:OnValueChange(val)
  -- Override this function
end

function PANEL:OnEnter(value)
  -- Override this function
end

function PANEL:OnKeyCode(keyCode)
  -- Override this function
end

function PANEL:SetCaretPos(pos)
  self.textEntry:SetCaretPos(pos)
end

function PANEL:GetCaretPos()
  return self.textEntry:GetCaretPos()
end

function PANEL:Think()
  local target = (self.textEntry:HasFocus() and 1) or 0
  self.animProgress = Lerp(FrameTime() * 6, self.animProgress, target)
end

function PANEL:Paint(w, h)
  -- Background
  local currentBg = self.bgColor
  if self.textEntry:HasFocus() then
    currentBg = self.focusColor
  end

  draw.RoundedBox(0, 0, 0, w, h, currentBg)

  local placeholderText = self.textEntry:GetPlaceholderText()

  if (placeholderText and placeholderText ~= "" and self:GetText() == "") then
    surface.SetFont("VersusDefault")
    local textW, textH = surface.GetTextSize(placeholderText)

    surface.SetTextColor(100, 120, 140, 150 + (self.animProgress * 105))
    surface.SetTextPos(16, (h * .5) - (textH * .5))
    surface.DrawText(placeholderText)
  end

  -- Bottom accent line
  local lineAlpha = 30 + (self.animProgress * 195)
  surface.SetDrawColor(self.accentColor.r, self.accentColor.g, self.accentColor.b, lineAlpha)
  surface.DrawRect(0, h - 2, w, 2)

  return true
end

function PANEL:PerformLayout(w, h)
  self.textEntry:SetPos(16, 0)
  self.textEntry:SetSize(w - 32, h)
end

vgui.Register("versus_TextEntry", PANEL, "EditablePanel")
