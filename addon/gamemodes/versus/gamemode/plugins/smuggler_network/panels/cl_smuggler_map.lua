local PLUGIN = PLUGIN

local color_bg = Color(15, 20, 30, 240)
local color_panel = Color(20, 28, 40, 255)
local color_border = Color(40, 55, 75, 255)
local color_text = Color(220, 230, 240, 255)
local color_dim = Color(140, 155, 170, 255)
local color_accent = Color(80, 140, 220, 255)

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(math.min(ScrW() * 0.75, 1100), ScrH() * 0.85)
    self:Center()
    self:ParentToHUD()
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(true)

    self.animStart = CurTime()
    self.animDuration = 0.3
    self.bgAlpha = 0
    self.selectedRoute = nil
    self.selectedRunner = "rookie"

    -- Title bar
    self.titleBar = vgui.Create("DPanel", self)
    self.titleBar:Dock(TOP)
    self.titleBar:SetTall(54)
    self.titleBar:DockPadding(GAMEMODE.SPACING, 0, GAMEMODE.SPACING, 0)
    self.titleBar.Paint = function(p, w, h)
      surface.SetDrawColor(color_panel)
      surface.DrawRect(0, 0, w, h)
      surface.SetDrawColor(color_border)
      surface.DrawRect(0, h - 1, w, 1)
    end

    self.titleLabel = vgui.Create("DLabel", self.titleBar)
    self.titleLabel:SetFont("VersusHeading2")
    self.titleLabel:SetTextColor(color_text)
    self.titleLabel:SetText("SMUGGLER NETWORK")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(LEFT)

    local closeBtn = vgui.Create("versus_Button", self.titleBar)
    closeBtn:SetText("CLOSE")
    closeBtn:SetType("secondary")
    closeBtn:Dock(RIGHT)
    closeBtn:SetWide(120)
    closeBtn.DoClick = function()
      self:Close()
    end

    self.titleBar:SetTall(math.max(54, self.titleLabel:GetTall() + GAMEMODE.SPACING))

    -- Pending results banner (filled in by Refresh if there are results)
    self.pendingBanner = nil

    -- Content split: left route list, right details
    self.contentArea = vgui.Create("DPanel", self)
    self.contentArea:Dock(FILL)
    self.contentArea:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)
    self.contentArea.Paint = function() end

    self.routeListScroller = vgui.Create("versus_ScrollPanel", self.contentArea)
    self.routeListScroller:Dock(LEFT)
    self.routeListScroller:SetWide(self:GetWide() * 0.40)
    self.routeListScroller:DockMargin(0, 0, GAMEMODE.SPACING, 0)

    self.detailsPanel = vgui.Create("DPanel", self.contentArea)
    self.detailsPanel:Dock(FILL)
    self.detailsPanel:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)
    self.detailsPanel.Paint = function(p, w, h)
      surface.SetDrawColor(color_panel)
      surface.DrawRect(0, 0, w, h)
      surface.SetDrawColor(color_border)
      surface.DrawOutlinedRect(0, 0, w, h)
    end

    self:BuildDetailsPlaceholder()
  end

  function PANEL:BuildDetailsPlaceholder()
    self.detailsPanel:Clear()

    local placeholder = vgui.Create("DLabel", self.detailsPanel)
    placeholder:SetFont("VersusDefault")
    placeholder:SetTextColor(color_dim)
    placeholder:SetText("Select a route from the list to view details.")
    placeholder:SizeToContents()
    placeholder:Dock(TOP)
  end

  function PANEL:BuildRouteDetails(route)
    self.detailsPanel:Clear()

    local heat = self:GetRouteHeat(route.id)
    local heatLabel = PLUGIN.getHeatLabel(heat)
    local heatColor = PLUGIN.getHeatColor(heat)
    local activeRun = self:GetActiveRun(route.id)
    local isBurned = heat >= PLUGIN.HEAT_BURNED

    -- Route name
    local nameLabel = vgui.Create("DLabel", self.detailsPanel)
    nameLabel:SetFont("VersusHeading2")
    nameLabel:SetTextColor(color_text)
    nameLabel:SetText(route.name)
    nameLabel:SizeToContents()
    nameLabel:Dock(TOP)
    nameLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.25)

    -- Route description
    local descLabel = vgui.Create("DLabel", self.detailsPanel)
    descLabel:SetFont("VersusDefault")
    descLabel:SetTextColor(color_dim)
    descLabel:SetText(route.description)
    descLabel:SetWrap(true)
    descLabel:SetAutoStretchVertical(true)
    descLabel:Dock(TOP)
    descLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    -- Stats
    local stats = {
      { "Duration",  PLUGIN.formatDuration(route.duration) },
      { "Route Cost", versus.util.formatMoney(route.cost) },
      { "Base Risk",  math.floor(route.baseRisk * 100) .. "%" },
      { "Reward",     versus.util.formatMoney(route.reward.min) .. " – " .. versus.util.formatMoney(route.reward.max) },
    }

    for _, stat in ipairs(stats) do
      local row = vgui.Create("DPanel", self.detailsPanel)
      row:Dock(TOP)
      row:SetTall(26)
      row:DockMargin(0, 0, 0, 2)
      row.Paint = function() end

      local keyLabel = vgui.Create("DLabel", row)
      keyLabel:SetFont("VersusDefault")
      keyLabel:SetTextColor(color_dim)
      keyLabel:SetText(stat[1])
      keyLabel:SizeToContents()
      keyLabel:Dock(LEFT)

      local valLabel = vgui.Create("DLabel", row)
      valLabel:SetFont("VersusDefault")
      valLabel:SetTextColor(color_text)
      valLabel:SetText(stat[2])
      valLabel:SizeToContents()
      valLabel:Dock(RIGHT)
    end

    -- Heat bar
    local heatContainer = vgui.Create("DPanel", self.detailsPanel)
    heatContainer:Dock(TOP)
    heatContainer:SetTall(46)
    heatContainer:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, GAMEMODE.SPACING * 0.5)
    heatContainer.Paint = function(p, w, h)
      -- Track background
      surface.SetDrawColor(color_border)
      surface.DrawRect(0, 32, w, 10)
      -- Heat fill
      surface.SetDrawColor(heatColor)
      surface.DrawRect(0, 32, w * (heat / PLUGIN.HEAT_MAX), 10)
    end

    local heatTitleLabel = vgui.Create("DLabel", heatContainer)
    heatTitleLabel:SetFont("VersusDefault")
    heatTitleLabel:SetTextColor(color_dim)
    heatTitleLabel:SetText("HEAT")
    heatTitleLabel:SizeToContents()
    heatTitleLabel:Dock(LEFT)

    local heatValLabel = vgui.Create("DLabel", heatContainer)
    heatValLabel:SetFont("VersusDefault")
    heatValLabel:SetTextColor(heatColor)
    heatValLabel:SetText(heatLabel)
    heatValLabel:SizeToContents()
    heatValLabel:Dock(RIGHT)

    -- State-specific content
    if(isBurned)then
      self:BuildBurnedState(route)
    elseif(activeRun)then
      self:BuildActiveRunState(activeRun)
    else
      self:BuildRunSetupState(route, heat)
    end
  end

  function PANEL:BuildBurnedState(route)
    local warningLabel = vgui.Create("DLabel", self.detailsPanel)
    warningLabel:SetFont("VersusDefault")
    warningLabel:SetTextColor(Color(220, 60, 60))
    warningLabel:SetText("This route is burned. Heat must drop below " .. PLUGIN.HEAT_BURNED .. " before it can be run again.")
    warningLabel:SetWrap(true)
    warningLabel:SetAutoStretchVertical(true)
    warningLabel:Dock(TOP)
    warningLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    local currentHeat = self:GetRouteHeat(route.id)
    local bribeCost = PLUGIN.calculateBribeCost(currentHeat)

    local bribeBtn = vgui.Create("versus_Button", self.detailsPanel)
    bribeBtn:SetText("BRIBE CONTACT  (-" .. PLUGIN.BRIBE_HEAT_REDUCTION .. " Heat, " .. versus.util.formatMoney(bribeCost) .. ")")
    bribeBtn:Dock(BOTTOM)
    bribeBtn:SetType("secondary")
    bribeBtn.DoClick = function()
      net.Start("versus.smuggler.bribeNode")
      net.WriteString(route.id)
      net.SendToServer()
    end
  end

  function PANEL:BuildActiveRunState(activeRun)
    local cachedNow = (PLUGIN._cachedData and PLUGIN._cachedData.now) or os.time()
    local timeLeft = math.max(0, activeRun.endTime - cachedNow)

    local runner = PLUGIN.getRunner(activeRun.runnerID)
    local runnerName = runner and runner.name or activeRun.runnerID

    local statusLabel = vgui.Create("DLabel", self.detailsPanel)
    statusLabel:SetFont("VersusDefault")
    statusLabel:SetTextColor(Color(70, 190, 90))
    statusLabel:SetText("Run in progress with " .. runnerName .. ".")
    statusLabel:SizeToContents()
    statusLabel:Dock(TOP)
    statusLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.25)

    local timerLabel = vgui.Create("DLabel", self.detailsPanel)
    timerLabel:SetFont("VersusDefault")
    timerLabel:SetTextColor(color_dim)
    timerLabel:SetText("Returns in: " .. PLUGIN.formatDuration(timeLeft))
    timerLabel:SizeToContents()
    timerLabel:Dock(TOP)
  end

  function PANEL:BuildRunSetupState(route, heat)
    -- Runner selection heading
    local runnerHeading = vgui.Create("DLabel", self.detailsPanel)
    runnerHeading:SetFont("VersusDefault")
    runnerHeading:SetTextColor(color_dim)
    runnerHeading:SetText("SELECT RUNNER")
    runnerHeading:SizeToContents()
    runnerHeading:Dock(TOP)
    runnerHeading:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, GAMEMODE.SPACING * 0.25)

    for _, runner in ipairs(PLUGIN.runners) do
      local isSelected = self.selectedRunner == runner.id

      local runnerBtn = vgui.Create("DPanel", self.detailsPanel)
      runnerBtn:Dock(TOP)
      runnerBtn:SetTall(54)
      runnerBtn:DockMargin(0, 0, 0, 4)
      runnerBtn:SetCursor("hand")

      -- Capture for closure
      local capturedRunner = runner

      runnerBtn.Paint = function(p, w, h)
        if(self.selectedRunner == capturedRunner.id)then
          surface.SetDrawColor(Color(40, 70, 110, 255))
        elseif(p:IsHovered())then
          surface.SetDrawColor(Color(28, 42, 60, 255))
        else
          surface.SetDrawColor(color_border)
        end

        surface.DrawRect(0, 0, w, h)
      end

      runnerBtn.OnMousePressed = function()
        self.selectedRunner = capturedRunner.id
        self:BuildRouteDetails(route)
      end

      local runnerNameLabel = vgui.Create("DLabel", runnerBtn)
      runnerNameLabel:SetFont("VersusDefault")
      runnerNameLabel:SetTextColor(isSelected and color_accent or color_text)
      runnerNameLabel:SetText(runner.name .. " — " .. versus.util.formatMoney(runner.fee) .. " fee")
      runnerNameLabel:SizeToContents()
      runnerNameLabel:Dock(TOP)
      runnerNameLabel:DockMargin(8, 6, 8, 2)

      local runnerDescLabel = vgui.Create("DLabel", runnerBtn)
      runnerDescLabel:SetFont("VersusSmall")
      runnerDescLabel:SetTextColor(color_dim)
      runnerDescLabel:SetText(runner.description)
      runnerDescLabel:SizeToContents()
      runnerDescLabel:Dock(TOP)
      runnerDescLabel:DockMargin(8, 0, 8, 2)
    end

    -- Cost breakdown
    local selectedRunnerData = PLUGIN.getRunner(self.selectedRunner)
    local runnerFee = selectedRunnerData and selectedRunnerData.fee or 0
    local totalCost = route.cost + runnerFee

    local costLabel = vgui.Create("DLabel", self.detailsPanel)
    costLabel:SetFont("VersusDefault")
    costLabel:SetTextColor(color_dim)
    costLabel:SetText(
      "Total: " .. versus.util.formatMoney(totalCost) ..
      "  (route " .. versus.util.formatMoney(route.cost) ..
      " + runner " .. versus.util.formatMoney(runnerFee) .. ")"
    )
    costLabel:SetWrap(true)
    costLabel:SetAutoStretchVertical(true)
    costLabel:Dock(TOP)
    costLabel:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, GAMEMODE.SPACING * 0.5)

    -- Bribe button
    local bribeCost = PLUGIN.calculateBribeCost(heat)
    local bribeBtn = vgui.Create("versus_Button", self.detailsPanel)
    bribeBtn:SetText("BRIBE CONTACT  (-" .. PLUGIN.BRIBE_HEAT_REDUCTION .. " Heat, " .. versus.util.formatMoney(bribeCost) .. ")")
    bribeBtn:Dock(BOTTOM)
    bribeBtn:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.25)
    bribeBtn:SetType("secondary")
    bribeBtn.DoClick = function()
      net.Start("versus.smuggler.bribeNode")
      net.WriteString(route.id)
      net.SendToServer()
    end

    -- Launch button
    local launchBtn = vgui.Create("versus_Button", self.detailsPanel)
    launchBtn:SetText("LAUNCH RUN")
    launchBtn:Dock(BOTTOM)
    launchBtn:SetType("primary")
    launchBtn:SetRequireHoldToClick(true)
    launchBtn.DoClick = function()
      if(not self.selectedRunner)then return end

      net.Start("versus.smuggler.launchRun")
      net.WriteString(route.id)
      net.WriteString(self.selectedRunner)
      net.SendToServer()

      self:Close()
    end
  end

  -- Returns the current heat for a route from the cached server data.
  function PANEL:GetRouteHeat(routeID)
    local data = PLUGIN._cachedData
    if(not data or not data.routeHeats)then return 0 end

    return data.routeHeats[routeID] or 0
  end

  -- Returns the active run entry for a route from the cached server data, or nil.
  function PANEL:GetActiveRun(routeID)
    local data = PLUGIN._cachedData
    if(not data or not data.activeRuns)then return nil end

    for _, run in ipairs(data.activeRuns) do
      if(run.routeID == routeID)then
        return run
      end
    end

    return nil
  end

  -- Rebuilds the route list and refreshes the selected details panel.
  function PANEL:Refresh()
    self.routeListScroller:Clear()

    for _, route in ipairs(PLUGIN.routes) do
      local heat = self:GetRouteHeat(route.id)
      local heatColor = PLUGIN.getHeatColor(heat)
      local activeRun = self:GetActiveRun(route.id)

      local routeEntry = vgui.Create("DPanel", self.routeListScroller)
      routeEntry:SetTall(84)
      routeEntry:Dock(TOP)
      routeEntry:DockMargin(0, 0, 0, 4)
      routeEntry:DockPadding(10, 6, 10, 6)
      routeEntry:SetCursor("hand")

      local capturedRoute = route

      routeEntry.Paint = function(p, w, h)
        if(self.selectedRoute == capturedRoute.id)then
          surface.SetDrawColor(Color(40, 70, 110, 255))
        elseif(p:IsHovered())then
          surface.SetDrawColor(Color(25, 38, 55, 255))
        else
          surface.SetDrawColor(color_panel)
        end

        surface.DrawRect(0, 0, w, h)

        -- Heat strip at the bottom
        surface.SetDrawColor(color_border)
        surface.DrawRect(0, h - 5, w, 5)
        surface.SetDrawColor(heatColor)
        surface.DrawRect(0, h - 5, w * (heat / PLUGIN.HEAT_MAX), 5)
      end

      routeEntry.OnMousePressed = function()
        self.selectedRoute = capturedRoute.id
        self:BuildRouteDetails(capturedRoute)
        self:Refresh()
      end

      local routeNameLabel = vgui.Create("DLabel", routeEntry)
      routeNameLabel:SetFont("VersusHeading3")
      routeNameLabel:SetTextColor(color_text)
      routeNameLabel:SetText(route.name)
      routeNameLabel:SizeToContents()
      routeNameLabel:Dock(TOP)

      local heatStatusLabel = vgui.Create("DLabel", routeEntry)
      heatStatusLabel:SetFont("VersusSmall")
      heatStatusLabel:SetTextColor(heatColor)
      heatStatusLabel:SetText(PLUGIN.getHeatLabel(heat))
      heatStatusLabel:SizeToContents()
      heatStatusLabel:Dock(TOP)

      if(activeRun)then
        local cachedNow = (PLUGIN._cachedData and PLUGIN._cachedData.now) or os.time()
        local timeLeft = math.max(0, activeRun.endTime - cachedNow)

        local runLabel = vgui.Create("DLabel", routeEntry)
        runLabel:SetFont("VersusSmall")
        runLabel:SetTextColor(Color(70, 190, 90))
        runLabel:SetText("▶ Returns in " .. PLUGIN.formatDuration(timeLeft))
        runLabel:SizeToContents()
        runLabel:Dock(TOP)
      end

      self.routeListScroller:AddItem(routeEntry)
    end

    -- Rebuild selected route details if one is active
    if(self.selectedRoute)then
      local route = PLUGIN.getRoute(self.selectedRoute)

      if(route)then
        self:BuildRouteDetails(route)
      end
    end

    -- Pending results banner
    local data = PLUGIN._cachedData
    local hasPending = data and data.pendingResults and data.pendingResults > 0

    if(hasPending)then
      if(not IsValid(self.pendingBanner))then
        self.pendingBanner = vgui.Create("DPanel", self)
        self.pendingBanner:Dock(BOTTOM)
        self.pendingBanner:SetTall(54)
        self.pendingBanner:DockPadding(GAMEMODE.SPACING, 0, GAMEMODE.SPACING, 0)
        self.pendingBanner.Paint = function(p, w, h)
          surface.SetDrawColor(Color(60, 130, 200, 220))
          surface.DrawRect(0, 0, w, h)
        end

        local pendingLabel = vgui.Create("DLabel", self.pendingBanner)
        pendingLabel:SetFont("VersusDefault")
        pendingLabel:SetTextColor(color_text)
        pendingLabel:SetText(data.pendingResults .. " run(s) have returned with results!")
        pendingLabel:SizeToContents()
        pendingLabel:Dock(LEFT)

        local claimBtn = vgui.Create("versus_Button", self.pendingBanner)
        claimBtn:SetText("CLAIM RESULT")
        claimBtn:SetType("primary")
        claimBtn:Dock(RIGHT)
        claimBtn:SetWide(180)
        claimBtn.DoClick = function()
          net.Start("versus.smuggler.claimResult")
          net.SendToServer()
          self:Close()
        end
      end
    elseif(IsValid(self.pendingBanner))then
      self.pendingBanner:Remove()
      self.pendingBanner = nil
    end
  end

  function PANEL:Close()
    if(self.closing)then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if(not self.closing)then
      self.bgAlpha = 200 * math.min(elapsed / self.animDuration, 1)
    else
      local closeElapsed = CurTime() - self.closeStart

      if(closeElapsed < 0.25)then
        local progress = 1 - (closeElapsed / 0.25)
        self.bgAlpha = 200 * progress
        self:SetAlpha(255 * progress)
      else
        self:Remove()
      end
    end
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)
    surface.SetDrawColor(ColorAlpha(color_bg, self.bgAlpha))
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(color_panel)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self:Center()
  end

  vgui.Register("versus_SmugglerMap", PANEL, "EditablePanel")
end
