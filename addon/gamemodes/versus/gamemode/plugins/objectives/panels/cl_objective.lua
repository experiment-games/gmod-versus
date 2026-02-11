local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(360, 120)
    self:SetSizeX(false)
    self:DockPadding(0, 8, 0, 14)

    self.title = ""
    self.description = ""
    self.distance = nil
    self.alpha = 0
    self.targetAlpha = 255

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = PLUGIN.unlockedColor
    self.textColor = Color(220, 230, 240, 255)

    -- Create labels
    self.titleLabel = self:Add("DLabel")
    self.titleLabel:SetText("OBJECTIVE")
    self.titleLabel:SetFont("VersusHeading2")
    self.titleLabel:SetTextColor(self.textColor)
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(16, 0, 16, 0)
    self.titleLabel:SetAutoStretchVertical(true)

    self.objectiveLabel = self:Add("DLabel")
    self.objectiveLabel:SetText("")
    self.objectiveLabel:SetFont("VersusDefault")
    self.objectiveLabel:SetTextColor(self.accentColor)
    self.objectiveLabel:Dock(TOP)
    self.objectiveLabel:DockMargin(16, 0, 16, 0)
    self.objectiveLabel:SetAutoStretchVertical(true)

    self.descriptionLabel = self:Add("DLabel")
    self.descriptionLabel:SetText("")
    self.descriptionLabel:SetFont("VersusDefault")
    self.descriptionLabel:SetTextColor(self.textColor)
    self.descriptionLabel:Dock(TOP)
    self.descriptionLabel:DockMargin(16, 0, 16, 0)
    self.descriptionLabel:SetAutoStretchVertical(true)
    self.descriptionLabel:SetWrap(true)

    self.distanceLabel = self:Add("DLabel")
    self.distanceLabel:SetText("")
    self.distanceLabel:SetFont("VersusDefault")
    self.distanceLabel:SetTextColor(Color(150, 170, 200, 255))
    self.distanceLabel:Dock(BOTTOM)
    self.distanceLabel:DockMargin(16, 0, 16, 12)
    self.distanceLabel:SetContentAlignment(6) -- Right align
    self.distanceLabel:SetAutoStretchVertical(true)
  end

  function PANEL:SetObjective(title, description, distance)
    self.title = title or ""
    self.description = description or ""
    self.distance = distance

    self.objectiveLabel:SetText(self.title:upper())
    self.descriptionLabel:SetText(self.description)

    if self.distance then
      self.distanceLabel:SetText(versus.indicator.unitsToMeters(self.distance) .. "m")
      self.distanceLabel:SetVisible(true)
    else
      self.distanceLabel:SetVisible(false)
    end
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

    -- Update label alphas
    local alpha = self.alpha

    local titleColor = ColorAlpha(self.textColor, alpha)
    self.titleLabel:SetTextColor(titleColor)

    local accentColor = ColorAlpha(self.accentColor, alpha)
    self.objectiveLabel:SetTextColor(accentColor)

    local descColor = ColorAlpha(self.textColor, alpha)
    self.descriptionLabel:SetTextColor(descColor)

    local distColor = ColorAlpha(Color(150, 170, 200, 255), alpha)
    self.distanceLabel:SetTextColor(distColor)
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
  end

  vgui.Register("versus_ObjectivePanel", PANEL, "DSizeToContents")
end
