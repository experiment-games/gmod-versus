local UNIT = UNIT
local PADDING = 50

do
  local PANEL = {}

  function PANEL:Init()
    self:SetCursor("hand")
    self:SetTall(48)

    self.hovered = false
    self.pressed = false
    self.text = ""

    self:SetType("default")

    self.animProgress = 0
  end

  function PANEL:SetType(type)
    if type == "primary" then
      self.bgColor = Color(80, 140, 220, 200)
      self.hoverColor = Color(90, 160, 240, 230)
      self.pressColor = Color(70, 120, 200, 255)
      self.accentColor = Color(80, 140, 220, 255)
      self.textColor = Color(255, 255, 255, 255)
    else
      self.textColor = Color(200, 220, 240, 255)
      self.bgColor = Color(25, 35, 50, 200)
      self.hoverColor = Color(35, 50, 75, 220)
      self.accentColor = Color(80, 140, 220, 255)
      self.pressColor = Color(20, 30, 45, 255)
    end
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
    if self.pressed then
      currentBg = self.pressColor
    elseif self.hovered then
      currentBg = self.hoverColor
    end

    draw.RoundedBox(h, 0, 0, w, h, currentBg)

    -- Text
    surface.SetFont("VersusButton")
    local textW, textH = surface.GetTextSize(self.text)
    surface.SetTextColor(self.textColor.r, self.textColor.g, self.textColor.b, self.textColor.a)
    surface.SetTextPos((w - textW) / 2, (h - textH) / 2)
    surface.DrawText(self.text)
  end

  vgui.Register("versus_Button", PANEL, "EditablePanel")
end

do
  -- Utility to draw background behind buttons
  function UNIT.drawButtonGroupBackground(x, y, w, h, alphaOverride)
    draw.RoundedBox(h, x, y, w, h, alphaOverride and ColorAlpha(color_background, alphaOverride) or color_background)
  end
end
