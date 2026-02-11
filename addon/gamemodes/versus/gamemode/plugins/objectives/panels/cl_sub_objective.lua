local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(360, 64)

    self.id = ""
    self.text = ""
    self.completed = false
    self.distance = nil
    self.alpha = 0
    self.targetAlpha = 255

    self.bgColor = Color(25, 35, 50, 200)
    self.accentColor = PLUGIN.unlockedColor
    self.completedColor = PLUGIN.completedColor
    self.textColor = Color(220, 230, 240, 255)
  end

  function PANEL:SetSubObjective(id, text, completed, distance)
    self.id = id
    self.text = text or ""
    self.completed = completed or false
    self.distance = distance
  end

  function PANEL:GetID()
    return self.id
  end

  function PANEL:GetText()
    return self.text
  end

  function PANEL:SetTargetAlpha(alpha)
    self.targetAlpha = math.Clamp(alpha, 0, 255)
  end

  function PANEL:IsCompleted()
    return self.completed
  end

  function PANEL:Think()
    -- Smooth alpha transition
    self.alpha = Lerp(FrameTime() * 8, self.alpha, self.targetAlpha)
  end

  function PANEL:Paint(w, h)
    if self.text == "" then return end

    local alpha = self.alpha
    if alpha < 1 then return end

    local statusColor = self.completed and self.completedColor or self.accentColor

    -- Background
    local bgColor = ColorAlpha(self.bgColor, alpha)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, w, h)

    -- Left accent bar
    local accentColor = ColorAlpha(statusColor, alpha)
    surface.SetDrawColor(accentColor)
    surface.DrawRect(0, 0, 4, h)

    -- Checkbox/Status indicator
    local checkSize = 16
    local checkX = 16
    local checkY = h / 2 - checkSize / 2

    -- Checkbox background
    surface.SetDrawColor(ColorAlpha(Color(40, 50, 65, 255), alpha))
    surface.DrawRect(checkX, checkY, checkSize, checkSize)

    -- Checkbox border
    surface.SetDrawColor(accentColor)
    surface.DrawOutlinedRect(checkX, checkY, checkSize, checkSize, 2)

    -- Checkmark if completed
    if self.completed then
      surface.SetDrawColor(accentColor)
      surface.DrawLine(checkX + 3, checkY + 8, checkX + 6, checkY + 13)
      surface.DrawLine(checkX + 6, checkY + 13, checkX + 13, checkY + 3)
      surface.DrawLine(checkX + 4, checkY + 8, checkX + 7, checkY + 13)
      surface.DrawLine(checkX + 7, checkY + 13, checkX + 14, checkY + 3)
    end

    -- Sub-objective text
    surface.SetFont("VersusDefault")
    local nameText = self.text:upper()

    local textColor = ColorAlpha(self.textColor, alpha)
    surface.SetTextColor(textColor)
    surface.SetTextPos(checkX + checkSize + 12, 12)
    surface.DrawText(nameText)

    -- Status text or distance
    surface.SetFont("VersusDefault")
    local statusText

    if self.completed then
      statusText = "COMPLETED"
    elseif self.distance then
      statusText = versus.indicator.unitsToMeters(self.distance) .. "m away"
    else
      statusText = "IN PROGRESS"
    end

    local statusW, statusH = surface.GetTextSize(statusText)

    surface.SetTextColor(statusColor)
    surface.SetTextPos(checkX + checkSize + 12, h - statusH - 12)
    surface.DrawText(statusText)
  end

  vgui.Register("versus_SubObjectivePanel", PANEL, "EditablePanel")
end
