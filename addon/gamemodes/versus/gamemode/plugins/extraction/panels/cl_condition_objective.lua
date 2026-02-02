local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(360, 64)

    self.condition = nil
    self.alpha = 0
    self.targetAlpha = 255
    self.completed = false

    self.bgColor = Color(25, 35, 50, 200)
    self.accentColor = PLUGIN.unlockedColor
    self.completedColor = PLUGIN.completedColor
    self.textColor = Color(220, 230, 240, 255)
  end

  function PANEL:SetCondition(condition)
    self.condition = condition
    self:UpdateCompletionStatus()
  end

  function PANEL:GetCondition()
    return self.condition
  end

  function PANEL:SetTargetAlpha(alpha)
    self.targetAlpha = math.Clamp(alpha, 0, 255)
  end

  function PANEL:UpdateCompletionStatus()
    if not IsValid(self.condition) then return end

    self.completed = PLUGIN:hasCompletedCondition(LocalPlayer(), self.condition)
  end

  function PANEL:IsCompleted()
    return self.completed
  end

  function PANEL:Think()
    -- Smooth alpha transition
    self.alpha = Lerp(FrameTime() * 8, self.alpha, self.targetAlpha)

    -- Update completion status
    self:UpdateCompletionStatus()
  end

  function PANEL:Paint(w, h)
    if not IsValid(self.condition) then return end

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

    -- Condition name
    surface.SetFont("VersusDefault")
    local nameText = self.condition:GetConditionName():upper()

    local textColor = ColorAlpha(self.textColor, alpha)
    surface.SetTextColor(textColor)
    surface.SetTextPos(checkX + checkSize + 12, 12)
    surface.DrawText(nameText)

    -- Status text or distance
    surface.SetFont("VersusDefault")
    local statusText

    if self.completed then
      statusText = "COMPLETED"
    else
      local distance = LocalPlayer():GetPos():Distance(self.condition:GetPos())
      statusText = versus.indicator.unitsToMeters(distance) .. "m away"
    end

    local statusW, statusH = surface.GetTextSize(statusText)

    surface.SetTextColor(statusColor)
    surface.SetTextPos(checkX + checkSize + 12, h - statusH - 12)
    surface.DrawText(statusText)

    -- Description on right side (if not completed)
    if not self.completed then
      local desc = self.condition:GetConditionDescription()
      if desc and desc ~= "" then
        surface.SetFont("VersusDefault")
        local descW, descH = surface.GetTextSize(desc)

        surface.SetTextColor(statusColor)
        surface.SetTextPos(w - descW - 16, h / 2 - descH / 2)
        surface.DrawText(desc)
      end
    end
  end

  vgui.Register("versus_ConditionObjectivePanel", PANEL, "EditablePanel")
end
