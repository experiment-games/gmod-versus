local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(360, 120)

    self.extractionPoint = nil
    self.alpha = 0
    self.targetAlpha = 255

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = PLUGIN.unlockedColor
    self.textColor = Color(220, 230, 240, 255)
  end

  function PANEL:SetExtractionPoint(extractionPoint)
    self.extractionPoint = extractionPoint
  end

  function PANEL:GetExtractionPoint()
    return self.extractionPoint
  end

  function PANEL:SetTargetAlpha(alpha)
    self.targetAlpha = math.Clamp(alpha, 0, 255)
  end

  function PANEL:Think()
    -- Smooth alpha transition
    self.alpha = Lerp(FrameTime() * 8, self.alpha, self.targetAlpha)
  end

  function PANEL:Paint(w, h)
    if not IsValid(self.extractionPoint) then return end

    local alpha = self.alpha
    if alpha < 1 then return end

    local locked = self.extractionPoint:GetLocked()
    local statusColor = locked and PLUGIN.lockedColor or PLUGIN.unlockedColor

    -- Background
    local bgColor = ColorAlpha(self.bgColor, alpha)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, w, h)

    -- Left accent bar
    local accentColor = ColorAlpha(statusColor, alpha)
    surface.SetDrawColor(accentColor)
    surface.DrawRect(0, 0, 4, h)

    -- Title
    surface.SetFont("VersusHeading2")
    local titleText = "EXTRACTION OBJECTIVE"
    local titleW, titleH = surface.GetTextSize(titleText)

    local textColor = ColorAlpha(self.textColor, alpha)
    surface.SetTextColor(textColor)
    surface.SetTextPos(16, 12)
    surface.DrawText(titleText)

    -- Extraction point name
    surface.SetFont("VersusDefault")
    local nameText = self.extractionPoint:GetExtractionName():upper()

    surface.SetTextColor(accentColor)
    surface.SetTextPos(16, 12 + titleH + 8)
    surface.DrawText(nameText)

    -- Status
    surface.SetFont("VersusDefault")
    local statusText = locked and "LOCKED - COMPLETE OBJECTIVES" or "UNLOCKED - READY TO EXTRACT"

    if (PLUGIN.localExtractions[self.extractionPoint:EntIndex()]) then
      statusText = "EXTRACTION IN PROGRESS"
    end

    local statusTextW, statusTextH = surface.GetTextSize(statusText)

    surface.SetTextColor(accentColor)
    surface.SetTextPos(16, h - statusTextH - 12)
    surface.DrawText(statusText)

    -- Distance
    local distance = LocalPlayer():GetPos():Distance(self.extractionPoint:GetPos())
    local distanceText = versus.indicator.unitsToMeters(distance) .. "m"
    local distanceW, distanceH = surface.GetTextSize(distanceText)

    local distColor = ColorAlpha(Color(150, 170, 200, 255), alpha)
    surface.SetTextColor(distColor)
    surface.SetTextPos(w - distanceW - 16, h - distanceH - 12)
    surface.DrawText(distanceText)
  end

  vgui.Register("versus_ExtractionObjectivePanel", PANEL, "EditablePanel")
end
