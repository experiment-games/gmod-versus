local UNIT = UNIT
local PADDING = 50

do
  local PANEL = {}

  AccessorFunc(PANEL, "hovered", "Hovered", FORCE_BOOL)

  function PANEL:Init()
    self:SetCursor("hand")
    self:SetTall(48)

    self.hovered = false
    self.pressed = false
    self.text = ""

    self:SetType("default")

    self.animProgress = 0

    -- Hold-to-click properties
    self.requireHold = false
    self.holdDuration = 2.5
    self.holdStartTime = 0
    self.holdProgress = 0
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

  function PANEL:SetRequireHoldToClick(requireHold, duration)
    self.requireHold = requireHold
    self.holdDuration = duration or 1.5

    self:SetTall(requireHold and 64 or 48)
  end

  function PANEL:DoClick()
    -- Override this function
  end

  function PANEL:OnCursorEntered()
    if not self:IsEnabled() then return end
    self.hovered = true
  end

  function PANEL:OnCursorExited()
    self.hovered = false
    -- Reset hold progress when cursor leaves
    if self.requireHold then
      self.holdProgress = 0
      self.holdStartTime = 0
    end
  end

  function PANEL:OnMousePressed()
    if not self:IsEnabled() then return end
    self.pressed = true
    if self.requireHold then
      self.holdStartTime = CurTime()
      self.holdProgress = 0
    end
  end

  function PANEL:OnMouseReleased()
    if self.requireHold then
      -- Only trigger if hold duration was met
      if self.pressed and self.hovered and self.holdProgress >= 1 then
        self:DoClick()
      end
      self.holdProgress = 0
      self.holdStartTime = 0
    else
      -- Normal click behavior
      if self.pressed and self.hovered then
        self:DoClick()
      end
    end
    self.pressed = false
  end

  function PANEL:Think()
    local target = (self.hovered and 1) or 0
    self.animProgress = Lerp(FrameTime() * 8, self.animProgress, target)

    -- Update hold progress
    if self.requireHold and self.pressed and self.hovered and self.holdStartTime > 0 then
      local elapsed = CurTime() - self.holdStartTime
      self.holdProgress = math.Clamp(elapsed / self.holdDuration, 0, 1)

      -- Trigger click when hold is complete
      if self.holdProgress >= 1 and not self.holdTriggered then
        self.holdTriggered = true
        self:DoClick()
      end
    else
      self.holdTriggered = false
    end
  end

  function PANEL:SizeToContents()
    surface.SetFont("VersusButton")
    local textW, textH = surface.GetTextSize(self:GetText())
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

    -- Apply disabled appearance
    if not self:IsEnabled() then
      currentBg = ColorAlpha(currentBg, 10)
    end

    surface.SetFont("VersusButton")
    local textW, textH = surface.GetTextSize(self:GetText())
    local textY = (h - textH) / 2

    -- Hold progress indicator
    if self.requireHold and self.holdProgress > 0 then
      draw.RoundedBox(h, 0, 0, w, h, ColorAlpha(currentBg, 100))

      local progressW = w * self.holdProgress
      local progressColor = ColorAlpha(self.accentColor, 255)
      draw.RoundedBox(h, 0, 0, math.max(h, progressW), h, progressColor)
    else
      draw.RoundedBox(h, 0, 0, w, h, currentBg)
    end

    if self.requireHold then
      -- Draw 'Hold to Confirm' text under the main text, then move the main text up slightly
      local holdText = "Hold to Confirm"
      surface.SetFont("VersusButtonSmall")
      local holdTextW, holdTextH = surface.GetTextSize(holdText)
      local holdTextY = textY + textH * .5
      surface.SetTextColor(ColorAlpha(self.textColor, not self:IsEnabled() and 100 or 255))
      surface.SetTextPos((w - holdTextW) / 2, holdTextY)
      surface.DrawText(holdText)

      -- Move main text up to make room for hold text
      textY = textY - (holdTextH / 2)
    end

    -- Text
    surface.SetFont("VersusButton")
    surface.SetTextColor(not self:IsEnabled() and ColorAlpha(self.textColor, 100) or self.textColor)
    surface.SetTextPos((w - textW) / 2, textY)
    surface.DrawText(self:GetText())
  end

  vgui.Register("versus_Button", PANEL, "EditablePanel")
end

do
  -- Utility to draw background behind buttons
  function UNIT.drawButtonGroupBackground(x, y, w, h, alphaOverride)
    draw.RoundedBox(h, x, y, w, h, alphaOverride and ColorAlpha(color_background, alphaOverride) or color_background)
  end
end
