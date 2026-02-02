local UNIT = UNIT
local PANEL = {}
local PADDING = 50

function PANEL:Init()
  self:SetCursor("hand")
  self:SetTall(48)

  self.hovered = false
  self.pressed = false
  self.text = ""
  self.textColor = Color(200, 220, 240, 255)
  self.bgColor = Color(25, 35, 50, 200)
  self.hoverColor = Color(35, 50, 75, 220)
  self.pressColor = Color(20, 30, 45, 255)
  self.accentColor = Color(80, 140, 220, 255)

  self.animProgress = 0
end

function PANEL:SetText(text)
  self.text = text or ""
end

function PANEL:GetText()
  return self.text
end

function PANEL:SetTextColor(color)
  self.textColor = color
end

function PANEL:DoClick()
  -- Override this function
end

function PANEL:OnCursorEntered()
  self.hovered = true
end

function PANEL:OnCursorExited()
  self.hovered = false
end

function PANEL:OnMousePressed()
  self.pressed = true
end

function PANEL:OnMouseReleased()
  if self.pressed and self.hovered then
    self:DoClick()
  end
  self.pressed = false
end

function PANEL:Think()
  local target = (self.hovered and 1) or 0
  self.animProgress = Lerp(FrameTime() * 8, self.animProgress, target)
end

function PANEL:SizeToContents()
  surface.SetFont("VersusButton")
  local textW, textH = surface.GetTextSize(self.text)
  self:SetWide(textW + PADDING)
end

function PANEL:Paint(w, h)
  -- Background
  local currentBg = self.bgColor
  if self.pressed and self.hovered then
    currentBg = self.pressColor
  elseif self.hovered then
    currentBg = self.hoverColor
  end

  draw.RoundedBox(0, 0, 0, w, h, currentBg)

  -- Left accent line
  local accentWidth = 3 + (self.animProgress * 2)
  draw.RoundedBox(0, 0, 0, accentWidth, h, self.accentColor)

  draw.SimpleText(self.text, "VersusButton", w / 2, h / 2, self.textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

  return true
end

vgui.Register("versus_Button", PANEL, "EditablePanel")
