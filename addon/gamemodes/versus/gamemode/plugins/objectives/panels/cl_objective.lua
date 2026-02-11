local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(360, 120)

    self.title = ""
    self.description = ""
    self.distance = nil
    self.alpha = 0
    self.targetAlpha = 255

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = PLUGIN.unlockedColor
    self.textColor = Color(220, 230, 240, 255)
  end

  function PANEL:SetObjective(title, description, distance)
    self.title = title or ""
    self.description = description or ""
    self.distance = distance
  end

  function PANEL:GetTitle()
    return self.title
  end

  function PANEL:SetTargetAlpha(alpha)
    self.targetAlpha = math.Clamp(alpha, 0, 255)
  end

  function PANEL:Think()
    -- Smooth alpha transition
    self.alpha = Lerp(FrameTime() * 8, self.alpha, self.targetAlpha)
  end

  function PANEL:Paint(w, h)
    if self.title == "" then return end

    local alpha = self.alpha
    if alpha < 1 then return end

    -- Background
    local bgColor = ColorAlpha(self.bgColor, alpha)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, w, h)

    -- Left accent bar
    local accentColor = ColorAlpha(self.accentColor, alpha)
    surface.SetDrawColor(accentColor)
    surface.DrawRect(0, 0, 4, h)

    -- Title
    surface.SetFont("VersusHeading2")
    local titleText = "OBJECTIVE"
    local titleW, titleH = surface.GetTextSize(titleText)

    local textColor = ColorAlpha(self.textColor, alpha)
    surface.SetTextColor(textColor)
    surface.SetTextPos(16, 12)
    surface.DrawText(titleText)

    -- Objective text
    surface.SetFont("VersusDefault")
    local objectiveText = self.title:upper()

    surface.SetTextColor(accentColor)
    surface.SetTextPos(16, 12 + titleH + 8)
    surface.DrawText(objectiveText)

    -- Description
    if self.description ~= "" then
      surface.SetFont("VersusDefault")
      local descText = self.description
      local descW, descH = surface.GetTextSize(descText)

      surface.SetTextColor(textColor)
      surface.SetTextPos(16, h - descH - 12)
      surface.DrawText(descText)
    end

    -- Distance (if provided)
    if self.distance then
      surface.SetFont("VersusDefault")
      local distanceText = versus.indicator.unitsToMeters(self.distance) .. "m"
      local distanceW, distanceH = surface.GetTextSize(distanceText)

      local distColor = ColorAlpha(Color(150, 170, 200, 255), alpha)
      surface.SetTextColor(distColor)
      surface.SetTextPos(w - distanceW - 16, h - distanceH - 12)
      surface.DrawText(distanceText)
    end
  end

  vgui.Register("versus_ObjectivePanel", PANEL, "EditablePanel")
end
