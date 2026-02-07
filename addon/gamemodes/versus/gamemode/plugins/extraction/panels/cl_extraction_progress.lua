local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(400, 80)

    self.extractionPoint = nil
    self.startTime = 0
    self.extractionTime = 10
    self.alpha = 0
    self.targetAlpha = 255

    self.bgColor = Color(25, 35, 50, 240)
    self.accentColor = Color(255, 200, 80, 255)
    self.progressColor = Color(100, 255, 100, 255)
    self.textColor = Color(220, 230, 240, 255)

    -- Center on screen
    self:SetPos(ScrW() / 2 - self:GetWide() / 2, ScrH() * 0.7)
  end

  function PANEL:SetExtractionData(extractionPoint, extractionTime)
    self.extractionPoint = extractionPoint
    self.extractionTime = extractionTime
    self.startTime = CurTime()
    self.targetAlpha = 255
  end

  function PANEL:GetProgress()
    if self.extractionTime <= 0 then return 1 end

    local elapsed = CurTime() - self.startTime
    return math.Clamp(elapsed / self.extractionTime, 0, 1)
  end

  function PANEL:GetTimeRemaining()
    local elapsed = CurTime() - self.startTime
    return math.max(0, self.extractionTime - elapsed)
  end

  function PANEL:Think()
    -- Smooth alpha transition
    self.alpha = Lerp(FrameTime() * 10, self.alpha, self.targetAlpha)

    -- Auto-remove when complete
    if self:GetProgress() >= 1 then
      self.targetAlpha = 0

      if self.alpha < 1 then
        self:Remove()
      end
    end

    -- Center position
    self:SetPos(ScrW() / 2 - self:GetWide() / 2, ScrH() * 0.7)
  end

  function PANEL:Paint(w, h)
    local alpha = self.alpha
    if alpha < 1 then return end

    -- Background
    local bgColor = ColorAlpha(self.bgColor, alpha)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, w, h)

    -- Title
    surface.SetFont("VersusHeading2")
    local titleText = "EXTRACTING"
    local titleW, titleH = surface.GetTextSize(titleText)

    local textColor = ColorAlpha(self.textColor, alpha)
    surface.SetTextColor(textColor)
    surface.SetTextPos(w / 2 - titleW / 2, 12)
    surface.DrawText(titleText)

    -- Progress bar background
    local barX = 20
    local barY = 12 + titleH + 12
    local barW = w - 40
    local barH = 20

    surface.SetDrawColor(ColorAlpha(Color(40, 50, 65, 255), alpha))
    surface.DrawRect(barX, barY, barW, barH)

    -- Progress bar fill
    local progress = self:GetProgress()
    local fillW = barW * progress

    local progressColor = ColorAlpha(self.progressColor, alpha)
    surface.SetDrawColor(progressColor)
    surface.DrawRect(barX, barY, fillW, barH)

    -- Progress bar border
    surface.SetDrawColor(ColorAlpha(self.accentColor, alpha))
    surface.DrawOutlinedRect(barX, barY, barW, barH, 2)

    -- Time remaining text
    surface.SetFont("VersusDefault")
    local timeRemaining = self:GetTimeRemaining()
    local timeText = string.format("%.1fs", timeRemaining)
    local timeW, timeH = surface.GetTextSize(timeText)

    surface.SetTextColor(textColor)
    surface.SetTextPos(w / 2 - timeW / 2, barY + barH / 2 - timeH / 2)
    surface.DrawText(timeText)

    -- Warning text
    surface.SetFont("VersusDefault")
    local warningText = "Stay near the extraction point!"
    local warningW, warningH = surface.GetTextSize(warningText)

    local warningColor = ColorAlpha(Color(255, 200, 80, 255), alpha * 0.8)
    surface.SetTextColor(warningColor)
    surface.SetTextPos(w / 2 - warningW / 2, h - warningH - 8)
    surface.DrawText(warningText)
  end

  vgui.Register("versus_ExtractionProgressPanel", PANEL, "EditablePanel")
end
