local PLUGIN = PLUGIN

do
  local PANEL = {}

  -- Colour palette
  local colorTitle = Color(80, 220, 160, 255)   -- Teal/green hazmat colour
  local colorWarning = Color(220, 180, 40, 255) -- Amber for radiation bar
  local colorDanger = Color(220, 80, 80, 255)   -- Red when high
  local colorSafe = Color(80, 200, 100, 255)    -- Green when low
  local colorSubtext = Color(160, 180, 190, 255)
  local colorBarTrack = Color(50, 55, 60, 255)
  local colorAccent = Color(60, 180, 130, 255)
  local colorPanelBg = Color(18, 22, 28, 240)

  local function getRadiationBarColor(level, maxLevel)
    local frac = level / maxLevel
    if frac < 0.4 then
      return colorSafe
    elseif frac < 0.75 then
      return colorWarning
    else
      return colorDanger
    end
  end

  function PANEL:Init()
    PLUGIN.decontaminatorPanel = self

    self:SetSize(
      math.max(ScrW() * 0.5, 700),
      ScrH()
    )

    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha      = 0
    self.contentAlpha = 0
    self.animStart    = CurTime()
    self.animDuration = 0.4

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    self.contentPanel = vgui.Create("EditablePanel", self)
    self.contentPanel:DockPadding(
      GAMEMODE.SPACING,
      GAMEMODE.SPACING,
      GAMEMODE.SPACING,
      GAMEMODE.SPACING
    )

    -- Title
    self.titleLabel = vgui.Create("DLabel", self.contentPanel)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(colorTitle)
    self.titleLabel:SetText("DECONTAMINATOR")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, 0)

    -- Subtitle / flavour description
    self.infoLabel = vgui.Create("DLabel", self.contentPanel)
    self.infoLabel:SetFont("VersusDefault")
    self.infoLabel:SetTextColor(colorSubtext)
    self.infoLabel:SetText(
      "Cutting-edge hazmat protocols can flush radiation from your body. " ..
      "One treatment halves your current radiation level. " ..
      "Return as many times as needed... For a price."
    )
    self.infoLabel:SetWrap(true)
    self.infoLabel:SetAutoStretchVertical(true)
    self.infoLabel:Dock(TOP)
    self.infoLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Radiation readout card
    self.readoutPanel = vgui.Create("EditablePanel", self.contentPanel)
    self.readoutPanel:Dock(TOP)
    self.readoutPanel:SetTall(110)
    self.readoutPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Treatment details card
    self.detailsPanel = vgui.Create("EditablePanel", self.contentPanel)
    self.detailsPanel:Dock(TOP)
    self.detailsPanel:SetTall(90)
    self.detailsPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Cost label inside details
    self.costLabel = vgui.Create("DLabel", self.detailsPanel)
    self.costLabel:SetFont("VersusHeading3")
    self.costLabel:SetTextColor(colorTitle)
    self.costLabel:SetText(
      "Treatment cost: " .. versus.util.formatMoney(PLUGIN.decontaminationFee)
    )
    self.costLabel:SizeToContents()
    self.costLabel:Dock(TOP)
    self.costLabel:DockMargin(16, 16, 16, 4)

    self.resultLabel = vgui.Create("DLabel", self.detailsPanel)
    self.resultLabel:SetFont("VersusDefault")
    self.resultLabel:SetTextColor(colorSubtext)
    self.resultLabel:SetText("Calculating...")
    self.resultLabel:SizeToContents()
    self.resultLabel:Dock(TOP)
    self.resultLabel:DockMargin(16, 0, 16, 16)

    -- Spacer
    local spacer = vgui.Create("EditablePanel", self.contentPanel)
    spacer:Dock(FILL)

    -- Button container
    local buttonContainer = vgui.Create("EditablePanel", self.contentPanel)
    buttonContainer:Dock(BOTTOM)
    buttonContainer:SetTall(50)
    buttonContainer:DockMargin(0, GAMEMODE.SPACING, 0, 0)

    -- Close button
    self.cancelButton = vgui.Create("versus_Button", buttonContainer)
    self.cancelButton:SetText("CLOSE")
    self.cancelButton:SetWide(160)
    self.cancelButton:Dock(RIGHT)
    self.cancelButton:SetType("secondary")
    self.cancelButton.DoClick = function()
      self:Close()
    end

    -- Decontaminate button
    self.decontaminateButton = vgui.Create("versus_Button", buttonContainer)
    self.decontaminateButton:SetText(
      string.format("DECONTAMINATE  %s", versus.util.formatMoney(PLUGIN.decontaminationFee))
    )
    self.decontaminateButton:Dock(FILL)
    self.decontaminateButton:DockMargin(0, 0, GAMEMODE.SPACING, 0)
    self.decontaminateButton:SetType("primary")
    self.decontaminateButton.DoClick = function()
      self:RequestDecontamination()
    end
  end

  function PANEL:Populate()
    self:UpdateReadout()
  end

  function PANEL:UpdateReadout()
    local level    = PLUGIN.getLocalRadiationLevel()
    local maxLevel = PLUGIN.maxLevel
    local fraction = PLUGIN.decontaminationFraction
    local newLevel = math.max(0, math.Round(level * (1 - fraction)))

    -- Result label
    if level <= 0 then
      self.resultLabel:SetText("You are not irradiated. No treatment needed.")
      self.decontaminateButton:SetEnabled(false)
    elseif newLevel >= level then
      self.resultLabel:SetText("Your radiation level is too low for treatment to have any effect.")
      self.decontaminateButton:SetEnabled(false)
    else
      self.resultLabel:SetText(
        string.format(
          "After treatment: %d → %d  (-%d radiation units)",
          level,
          newLevel,
          level - newLevel
        )
      )

      local playerMoney = versus.finance.getMoney()
      self.decontaminateButton:SetEnabled(playerMoney >= PLUGIN.decontaminationFee)
    end

    self.resultLabel:SizeToContents()

    -- Store for Paint
    self._cachedLevel    = level
    self._cachedMaxLevel = maxLevel
  end

  function PANEL:RequestDecontamination()
    local level = PLUGIN.getLocalRadiationLevel()

    if level <= 0 then
      return
    end

    local fraction = PLUGIN.decontaminationFraction
    local newLevel = math.max(0, math.Round(level * (1 - fraction)))

    versus.panel.query(
      string.format(
        "Pay %s to reduce your radiation from %d to %d?\n\nYou can return for further treatments.",
        versus.util.formatMoney(PLUGIN.decontaminationFee),
        level,
        newLevel
      ),
      "Confirm Decontamination",
      "Yes, Decontaminate",
      function()
        net.Start("versus.radiation.decontaminate")
        net.SendToServer()

        surface.PlaySound("ambient/energy/weld2.wav")
      end,
      "Cancel",
      function() end
    )
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing    = true
    self.closeStart = CurTime()
  end

  function PANEL:OnRemove()
    if PLUGIN.decontaminatorPanel == self then
      PLUGIN.decontaminatorPanel = nil
    end
  end

  function PANEL:Think()
    -- Periodically refresh the readout so money/level changes are reflected.
    if not self.nextReadoutRefresh or CurTime() > self.nextReadoutRefresh then
      self:UpdateReadout()
      self.nextReadoutRefresh = CurTime() + 0.5
    end

    local elapsed = CurTime() - self.animStart

    if not self.closing then
      if elapsed < self.animDuration then
        local progress    = math.ease.InOutQuad(elapsed / self.animDuration)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha      = 200
        self.contentAlpha = 255
      end
    else
      local closeElapsed = CurTime() - self.closeStart
      if closeElapsed < 0.3 then
        local progress    = 1 - (closeElapsed / 0.3)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self:Remove()
      end
    end

    self:SetAlpha(self.contentAlpha)
  end

  -- Draw the animated radiation readout card.
  function PANEL:PaintReadout(panel)
    local w, h     = panel:GetSize()
    local level    = self._cachedLevel or 0
    local maxLevel = self._cachedMaxLevel or PLUGIN.maxLevel
    local padding  = 16

    -- Card background
    draw.RoundedBox(8, 0, 0, w, h, colorPanelBg)

    -- Left accent strip
    draw.RoundedBoxEx(8, 0, 0, 6, h, colorAccent, true, false, true, false)

    -- "CURRENT RADIATION" caption
    surface.SetFont("VersusDefault")
    surface.SetTextColor(colorSubtext)
    surface.SetTextPos(padding + 6, padding)
    surface.DrawText("CURRENT RADIATION LEVEL")

    -- Large numeric readout
    local levelText = tostring(level)
    local maxText   = " / " .. tostring(maxLevel)

    surface.SetFont("VersusHeading1")
    surface.SetTextColor(getRadiationBarColor(level, maxLevel))
    surface.SetTextPos(padding + 6, padding + 12)
    surface.DrawText(levelText)

    local tw, _ = surface.GetTextSize(levelText)
    surface.SetFont("VersusDefault")
    surface.SetTextColor(colorSubtext)
    surface.SetTextPos(padding + 6 + tw, padding + 24)
    surface.DrawText(maxText)

    -- Progress bar
    local barY = h - padding - 14
    local barX = padding + 6
    local barW = w - padding * 2 - 6
    local barH = 10

    -- Track
    surface.SetDrawColor(colorBarTrack)
    surface.DrawRect(barX, barY, barW, barH)

    -- Fill
    local fillFrac = maxLevel > 0 and (level / maxLevel) or 0
    local fillW    = math.max(0, math.Round(barW * fillFrac))
    local barColor = getRadiationBarColor(level, maxLevel)

    -- Animated pulse when level is at the contract threshold or higher
    if level >= PLUGIN.contractThreshold then
      local pulse = 0.6 + 0.4 * math.abs(math.sin(RealTime() * 2.5))
      barColor = ColorAlpha(barColor, math.Round(barColor.a * pulse))
    end

    surface.SetDrawColor(barColor)
    surface.DrawRect(barX, barY, fillW, barH)

    -- Threshold marker
    local markerX = barX + math.Round(barW * (PLUGIN.contractThreshold / maxLevel))
    surface.SetDrawColor(220, 220, 220, 160)
    surface.DrawRect(markerX - 1, barY - 3, 2, barH + 6)
  end

  -- Draw the treatment details card.
  function PANEL:PaintDetails(panel)
    local w, h = panel:GetSize()

    draw.RoundedBox(8, 0, 0, w, h, colorPanelBg)
    draw.RoundedBoxEx(8, 0, 0, 6, h, colorTitle, true, false, true, false)
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)

    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self.contentPanel:SetWide(self:GetWide() - GAMEMODE.SPACING * 2)
    self.contentPanel:SetTall(h)
    self.contentPanel:Center()

    self:Center()

    -- Hook custom paints after layout so panel references are valid.
    self.readoutPanel.Paint = function(panel, pw, ph)
      self:PaintReadout(panel)
    end

    self.detailsPanel.Paint = function(panel, pw, ph)
      self:PaintDetails(panel)
    end
  end

  vgui.Register("versus_Decontaminator", PANEL, "EditablePanel")
end
