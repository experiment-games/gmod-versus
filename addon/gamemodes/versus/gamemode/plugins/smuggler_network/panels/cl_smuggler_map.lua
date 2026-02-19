local PLUGIN = PLUGIN

local color_panel = Color(20, 28, 40, 255)
local color_border = Color(40, 55, 75, 255)
local color_text = Color(220, 230, 240, 255)
local color_dim = Color(140, 155, 170, 255)
local color_accent = Color(80, 140, 220, 255)
local color_mapBg = Color(10, 15, 22, 255)

-- Draws a filled circle using surface primitives.
local function drawFilledCircle(x, y, radius)
  local segCount = math.max(12, math.floor(radius * 2))
  local verts = { { x = x, y = y } }

  for i = 0, segCount do
    local angle = math.rad(i * 360 / segCount)
    table.insert(verts, {
      x = x + math.cos(angle) * radius,
      y = y + math.sin(angle) * radius,
    })
  end

  surface.DrawPoly(verts)
end

-- Returns the shortest distance from point (px,py) to the segment (x1,y1)-(x2,y2).
local function distToSegment(px, py, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  local lenSq = dx * dx + dy * dy

  if (lenSq < 0.0001) then
    return math.sqrt((px - x1) ^ 2 + (py - y1) ^ 2)
  end

  local t = math.Clamp(((px - x1) * dx + (py - y1) * dy) / lenSq, 0, 1)

  return math.sqrt((px - x1 - t * dx) ^ 2 + (py - y1 - t * dy) ^ 2)
end

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(math.min(ScrW(), math.max(ScrW() * 0.75, 1100)), ScrH())
    self:ParentToHUD()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)

    self.animStart = CurTime()
    self.animDuration = 0.4
    self.bgAlpha = 0
    self.contentAlpha = 0
    self.selectedRoute = nil
    self.selectedRunner = "rookie"
    self.selectedMapID = nil -- set in BuildMapSelector

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    self.contentPanel = vgui.Create("EditablePanel", self)
    self.contentPanel:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    -- Heading (title + money display)
    local headingContainer = vgui.Create("EditablePanel", self.contentPanel)
    headingContainer:Dock(TOP)
    headingContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)

    self.titleLabel = vgui.Create("DLabel", headingContainer)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(color_text)
    self.titleLabel:SetText("SMUGGLER NETWORK")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(FILL)

    headingContainer:SetTall(self.titleLabel:GetTall())

    self.moneyDisplay = vgui.Create("versus_MoneyDisplay", headingContainer)
    self.moneyDisplay:Dock(RIGHT)
    self.moneyDisplay:DockMargin(GAMEMODE.SPACING, 0, 0, 0)
    self.moneyDisplay:SizeToContents()

    -- A description of what the smuggler network is
    local descLabel = vgui.Create("DLabel", self.contentPanel)
    descLabel:SetFont("VersusDefault")
    descLabel:SetTextColor(color_dim)
    descLabel:SetText(
      "Hire runners to complete smuggling runs along various routes. They'll do this while you are focussing on other work. Come back later to see how they did and collect your earnings!"
    )
    descLabel:SetWrap(true)
    descLabel:SetAutoStretchVertical(true)
    descLabel:Dock(TOP)
    descLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)

    -- Map selector (horizontal tab buttons, one per registered map)
    self.mapSelector = vgui.Create("DHorizontalScroller", self.contentPanel)
    self.mapSelector:Dock(TOP)
    self.mapSelector:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.mapSelector:SetTall(45)
    self.mapSelector:SetOverlap(-(GAMEMODE.SPACING * 0.5))
    self.mapSelectorButtons = {}

    self:BuildMapSelector()

    -- Cancel button at the bottom of contentPanel
    self.cancelButton = vgui.Create("versus_Button", self.contentPanel)
    self.cancelButton:SetText("CLOSE")
    self.cancelButton:Dock(BOTTOM)
    self.cancelButton:SetType("secondary")
    self.cancelButton.DoClick = function()
      self:Close()
    end

    -- Horizontal content split: left (map + route list) | right (details)
    local contentSplit = vgui.Create("EditablePanel", self.contentPanel)
    contentSplit:Dock(FILL)
    contentSplit:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Left column: map visualization + route list
    self.leftColumn = vgui.Create("EditablePanel", contentSplit)
    self.leftColumn:Dock(LEFT)
    self.leftColumn:SetWide(math.floor(self:GetWide() * 0.38))
    self.leftColumn:DockMargin(0, 0, GAMEMODE.SPACING, 0)

    -- Map view panel (fixed height)
    self.mapView = vgui.Create("EditablePanel", self.leftColumn)
    self.mapView:Dock(TOP)
    self.mapView:SetTall(200)
    self.mapView:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.mapView:SetMouseInputEnabled(true)
    self.mapView.Paint = function(p, w, h)
      self:DrawMap(p, w, h)
    end
    self.mapView.OnMousePressed = function(p, btn)
      self:OnMapClick(p, btn)
    end

    -- Route list (scrollable)
    self.routeListScroller = vgui.Create("versus_ScrollPanel", self.leftColumn)
    self.routeListScroller:Dock(FILL)

    -- Right column: details
    self.detailsPanel = vgui.Create("EditablePanel", contentSplit)
    self.detailsPanel:Dock(FILL)
    self.detailsPanel:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)
    self.detailsPanel.Paint = function(p, w, h)
      surface.SetDrawColor(color_panel)
      surface.DrawRect(0, 0, w, h)
    end

    -- Bottom bar (fixed, holds action buttons) — must be added before detailsScroller
    -- so that Dock(BOTTOM) reserves space before Dock(FILL) takes the rest.
    -- DSizeToContents auto-sizes the height to match visible button children.
    self.detailsBottomBar = vgui.Create("DSizeToContents", self.detailsPanel)
    self.detailsBottomBar:Dock(BOTTOM)
    self.detailsBottomBar:SetSizeX(false)

    -- Pre-create launch button in the bottom bar
    self.launchBtn = vgui.Create("versus_Button", self.detailsBottomBar)
    self.launchBtn:SetText("LAUNCH RUN")
    self.launchBtn:SetType("primary")
    self.launchBtn:SetRequireHoldToClick(true)
    self.launchBtn:Dock(TOP)
    self.launchBtn:SetVisible(false)

    -- Scrollable details content (above the bottom bar)
    self.detailsScroller = vgui.Create("versus_ScrollPanel", self.detailsPanel)
    self.detailsScroller:Dock(FILL)
    self.detailsScroller:DockMargin(0, 0, 0, GAMEMODE.SPACING * .25)

    self:BuildDetailsPlaceholder()
  end

  -- Builds (or rebuilds) the map selector tab buttons from the registered maps.
  function PANEL:BuildMapSelector()
    -- Clear existing buttons
    for _, btn in ipairs(self.mapSelectorButtons) do
      btn:Remove()
    end

    self.mapSelectorButtons = {}

    -- Sort map IDs for a stable order
    local mapIDs = {}
    for mapID in pairs(PLUGIN.maps) do
      table.insert(mapIDs, mapID)
    end
    table.sort(mapIDs)

    -- Pick a default selection
    if (not self.selectedMapID or not PLUGIN.maps[self.selectedMapID]) then
      self.selectedMapID = mapIDs[1]
    end

    for _, mapID in ipairs(mapIDs) do
      local map = PLUGIN.maps[mapID]
      local capturedID = mapID

      local btn = vgui.Create("versus_Button", self.mapSelector)
      btn:SetText(string.upper(map.name or mapID))
      btn:Dock(LEFT)
      btn:SizeToContents()
      btn:DockMargin(0, 0, GAMEMODE.SPACING * 0.5, 0)
      btn:SetType(self.selectedMapID == capturedID and "primary" or "secondary")
      btn.DoClick = function()
        self.selectedMapID = capturedID
        self.selectedRoute = nil

        -- Update button styles
        for _, b in ipairs(self.mapSelectorButtons) do
          b:SetType("secondary")
        end

        btn:SetType("primary")

        self:Refresh()
      end

      self.mapSelector:AddPanel(btn)
      table.insert(self.mapSelectorButtons, btn)
    end
  end

  -- Returns (scale, offsetX, offsetY) that fit the map into a w×h panel with padding.
  function PANEL:GetMapTransform(map, w, h, padding)
    local availW = w - padding * 2
    local availH = h - padding * 2
    local scale = math.min(availW / map.width, availH / map.height)
    local ox = padding + (availW - map.width * scale) / 2
    local oy = padding + (availH - map.height * scale) / 2

    return scale, ox, oy
  end

  -- Returns the currently selected map, or the first registered map as a fallback.
  function PANEL:GetCurrentMap()
    if (self.selectedMapID and PLUGIN.maps[self.selectedMapID]) then
      return PLUGIN.maps[self.selectedMapID]
    end

    for _, map in pairs(PLUGIN.maps) do
      return map
    end
  end

  -- Returns the node table with the given ID from the map, or nil.
  function PANEL:GetNodeById(map, nodeID)
    for _, node in ipairs(map.nodes or {}) do
      if (node.id == nodeID) then return node end
    end
  end

  -- Paints the map visualization onto the mapView panel.
  function PANEL:DrawMap(panel, w, h)
    local map = self:GetCurrentMap()

    -- Map background
    surface.SetDrawColor(color_mapBg)
    surface.DrawRect(0, 0, w, h)

    if (not map) then return end

    local padding = 22
    local scale, ox, oy = self:GetMapTransform(map, w, h, padding)

    -- Draw all route lines
    for _, route in ipairs(map.routes or {}) do
      local isSelected = self.selectedRoute == route.id
      local activeRun = self:GetActiveRun(route.id)

      local lineColor
      if (isSelected) then
        lineColor = color_accent
      elseif (activeRun) then
        lineColor = Color(70, 190, 90, 180)
      else
        lineColor = Color(45, 65, 90, 140)
      end

      surface.SetDrawColor(lineColor)

      for i = 1, #(route.nodes or {}) - 1 do
        local nodeA = self:GetNodeById(map, route.nodes[i])
        local nodeB = self:GetNodeById(map, route.nodes[i + 1])

        if (nodeA and nodeB) then
          local x1 = ox + nodeA.x * scale
          local y1 = oy + nodeA.y * scale
          local x2 = ox + nodeB.x * scale
          local y2 = oy + nodeB.y * scale

          surface.DrawLine(x1, y1, x2, y2)

          -- Extra parallel lines for selected route to appear thicker
          if (isSelected) then
            local nx, ny = -(y2 - y1), x2 - x1
            local len = math.sqrt(nx * nx + ny * ny)

            if (len > 0.001) then
              nx, ny = nx / len, ny / len
              surface.DrawLine(x1 + nx, y1 + ny, x2 + nx, y2 + ny)
              surface.DrawLine(x1 - nx, y1 - ny, x2 - nx, y2 - ny)
            end
          end
        end
      end
    end

    -- Draw nodes
    for _, node in ipairs(map.nodes or {}) do
      local nx = ox + node.x * scale
      local ny = oy + node.y * scale
      local radius = node.canBribe and 7 or 5

      surface.SetDrawColor(node.color)
      drawFilledCircle(nx, ny, radius)

      -- Bribeable nodes get an outline ring
      if (node.canBribe) then
        surface.SetDrawColor(ColorAlpha(node.color, 120))
        drawFilledCircle(nx, ny, radius + 3)
        surface.SetDrawColor(node.color)
        drawFilledCircle(nx, ny, radius)
      end

      -- Node label
      if (node.displayName) then
        surface.SetFont("VersusSmall")
        local labelW = surface.GetTextSize(node.displayName)
        surface.SetTextColor(Color(170, 185, 205))
        surface.SetTextPos(nx - labelW / 2, ny + radius + 3)
        surface.DrawText(node.displayName)
      end
    end
  end

  -- Handles clicks on the map view: selects a route via line proximity,
  -- or bribes a node on the selected route.
  function PANEL:OnMapClick(panel, btn)
    if (btn ~= MOUSE_LEFT) then return end

    local map = self:GetCurrentMap()
    if (not map) then return end

    local mx, my = panel:CursorPos()
    local w, h = panel:GetWide(), panel:GetTall()
    local scale, ox, oy = self:GetMapTransform(map, w, h, 22)

    -- Check for route line click (within 8px of any segment)
    local closestRoute = nil
    local minDist = 8

    for _, route in ipairs(map.routes or {}) do
      for i = 1, #(route.nodes or {}) - 1 do
        local nodeA = self:GetNodeById(map, route.nodes[i])
        local nodeB = self:GetNodeById(map, route.nodes[i + 1])

        if (nodeA and nodeB) then
          local dist = distToSegment(
            mx, my,
            ox + nodeA.x * scale, oy + nodeA.y * scale,
            ox + nodeB.x * scale, oy + nodeB.y * scale
          )

          if (dist < minDist) then
            minDist = dist
            closestRoute = route
          end
        end
      end
    end

    if (closestRoute) then
      self.selectedRoute = closestRoute.id
      self:BuildRouteDetails(closestRoute)
      self:RefreshRouteList()
    end
  end

  function PANEL:BuildDetailsPlaceholder()
    self.detailsScroller:Clear()
    self.launchBtn:SetVisible(false)
    self.detailsBottomBar:SizeToContents()

    local placeholder = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(placeholder)
    placeholder:SetFont("VersusDefault")
    placeholder:SetTextColor(color_dim)
    placeholder:SetText("Select a route from the list or click a line on the map.")
    placeholder:SizeToContents()
    placeholder:Dock(TOP)
  end

  function PANEL:BuildRouteDetails(route)
    self.detailsScroller:Clear()

    local heat = self:GetRouteHeat(route.id)
    local heatLabel = PLUGIN.getHeatLabel(heat)
    local heatColor = PLUGIN.getHeatColor(heat)
    local activeRun = self:GetActiveRun(route.id)
    local isBurned = heat >= PLUGIN.HEAT_BURNED

    -- Route name
    local nameLabel = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(nameLabel)
    nameLabel:SetFont("VersusHeading2")
    nameLabel:SetTextColor(color_text)
    nameLabel:SetText(route.name)
    nameLabel:SizeToContents()
    nameLabel:Dock(TOP)
    nameLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.25)

    -- Route description
    local descLabel = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(descLabel)
    descLabel:SetFont("VersusDefault")
    descLabel:SetTextColor(color_dim)
    descLabel:SetText(route.description)
    descLabel:SetWrap(true)
    descLabel:SetAutoStretchVertical(true)
    descLabel:Dock(TOP)
    descLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    -- Stats rows
    local stats = {
      { "Duration", PLUGIN.formatDuration(route.duration) },
      { "Route Cost", versus.util.formatMoney(route.cost) },
      { "Base Risk", math.floor(route.baseRisk * 100) .. "%" },
      { "Reward", versus.util.formatMoney(route.reward.min) .. " – " .. versus.util.formatMoney(route.reward.max) },
    }

    for _, stat in ipairs(stats) do
      local row = vgui.Create("DPanel", self.detailsScroller)
      self.detailsScroller:AddItem(row)
      row:Dock(TOP)
      row:SetTall(26)
      row:DockMargin(0, 0, 0, 2)
      row.Paint = function() end

      local keyLbl = vgui.Create("DLabel", row)
      keyLbl:SetFont("VersusDefault")
      keyLbl:SetTextColor(color_dim)
      keyLbl:SetText(stat[1])
      keyLbl:SizeToContents()
      keyLbl:Dock(LEFT)

      local valLbl = vgui.Create("DLabel", row)
      valLbl:SetFont("VersusDefault")
      valLbl:SetTextColor(color_text)
      valLbl:SetText(stat[2])
      valLbl:SizeToContents()
      valLbl:Dock(RIGHT)
    end

    -- Heat bar
    local heatContainer = vgui.Create("DPanel", self.detailsScroller)
    self.detailsScroller:AddItem(heatContainer)
    heatContainer:Dock(TOP)
    heatContainer:SetTall(46)
    heatContainer:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, GAMEMODE.SPACING * 0.5)
    heatContainer.Paint = function(p, w, h)
      surface.SetDrawColor(color_border)
      surface.DrawRect(0, 32, w, 10)
      surface.SetDrawColor(heatColor)
      surface.DrawRect(0, 32, w * (heat / PLUGIN.HEAT_MAX), 10)
    end

    local heatTitleLbl = vgui.Create("DLabel", heatContainer)
    heatTitleLbl:SetFont("VersusDefault")
    heatTitleLbl:SetTextColor(color_dim)
    heatTitleLbl:SetText("HEAT")
    heatTitleLbl:SizeToContents()
    heatTitleLbl:Dock(LEFT)

    local heatValLbl = vgui.Create("DLabel", heatContainer)
    heatValLbl:SetFont("VersusDefault")
    heatValLbl:SetTextColor(heatColor)
    heatValLbl:SetText(heatLabel)
    heatValLbl:SizeToContents()
    heatValLbl:Dock(RIGHT)

    -- State-specific content in the scroller
    if (isBurned) then
      self:BuildBurnedState(route, heat)
    elseif (activeRun) then
      self:BuildActiveRunState(activeRun)
    else
      self:BuildRunSetupState(route, heat)
    end
  end

  function PANEL:BuildBurnedState(route, heat)
    local warningLabel = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(warningLabel)
    warningLabel:SetFont("VersusDefault")
    warningLabel:SetTextColor(Color(220, 60, 60))
    warningLabel:SetText("This route is burned. Heat must drop below " .. PLUGIN.HEAT_BURNED .. " to run again.")
    warningLabel:SetWrap(true)
    warningLabel:SetAutoStretchVertical(true)
    warningLabel:Dock(TOP)
    warningLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    self:BuildBribeableNodeButtons(route, heat)

    self.launchBtn:SetVisible(false)
    self.detailsBottomBar:SizeToContents()
  end

  function PANEL:BuildActiveRunState(activeRun)
    local runner = PLUGIN.getRunner(activeRun.runnerID)
    local runnerName = runner and runner.name or activeRun.runnerID

    local statusLabel = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(statusLabel)
    statusLabel:SetFont("VersusDefault")
    statusLabel:SetTextColor(Color(70, 190, 90))
    statusLabel:SetText("Run in progress with " .. runnerName .. ".")
    statusLabel:SizeToContents()
    statusLabel:Dock(TOP)
    statusLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.25)

    local timerLabel = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(timerLabel)
    timerLabel:SetFont("VersusDefault")
    timerLabel:SetTextColor(color_dim)
    timerLabel:Dock(TOP)
    timerLabel.Think = function(p)
      local data = PLUGIN._cachedData
      local cachedNow = (data and data.now and data._receivedAt)
          and (data.now + (RealTime() - data._receivedAt))
          or os.time()
      local timeLeft = math.max(0, activeRun.endTime - cachedNow)
      local text = "Returns in: " .. PLUGIN.formatDuration(timeLeft)

      if (p:GetText() ~= text) then
        p:SetText(text)
        p:SizeToContents()
      end
    end

    self.launchBtn:SetVisible(false)
    self.detailsBottomBar:SizeToContents()
  end

  function PANEL:BuildRunSetupState(route, heat)
    -- Runner selection heading
    local runnerHeading = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(runnerHeading)
    runnerHeading:SetFont("VersusDefault")
    runnerHeading:SetTextColor(color_dim)
    runnerHeading:SetText("SELECT RUNNER")
    runnerHeading:SizeToContents()
    runnerHeading:Dock(TOP)
    runnerHeading:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, GAMEMODE.SPACING * 0.25)

    for _, runner in ipairs(PLUGIN.runners) do
      local capturedRunner = runner
      local runnerBtn = vgui.Create("DPanel", self.detailsScroller)
      self.detailsScroller:AddItem(runnerBtn)
      runnerBtn:Dock(TOP)
      runnerBtn:SetTall(54)
      runnerBtn:DockMargin(0, 0, 0, 4)
      runnerBtn:SetCursor("hand")
      runnerBtn.Paint = function(p, w, h)
        if (self.selectedRunner == capturedRunner.id) then
          surface.SetDrawColor(Color(40, 70, 110, 255))
        elseif (p:IsHovered()) then
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

      local nameLabel = vgui.Create("DLabel", runnerBtn)
      nameLabel:SetFont("VersusDefault")
      nameLabel:SetTextColor(self.selectedRunner == capturedRunner.id and color_accent or color_text)
      nameLabel:SetText(runner.name .. " — " .. versus.util.formatMoney(runner.fee) .. " fee")
      nameLabel:SizeToContents()
      nameLabel:Dock(TOP)
      nameLabel:DockMargin(8, 6, 8, 2)

      local descLabel = vgui.Create("DLabel", runnerBtn)
      descLabel:SetFont("VersusSmall")
      descLabel:SetTextColor(color_dim)
      descLabel:SetText(runner.description)
      descLabel:SizeToContents()
      descLabel:Dock(TOP)
      descLabel:DockMargin(8, 0, 8, 2)
    end

    -- Cost breakdown
    local selectedRunnerData = PLUGIN.getRunner(self.selectedRunner)
    local runnerFee = selectedRunnerData and selectedRunnerData.fee or 0
    local totalCost = route.cost + runnerFee

    local costLabel = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(costLabel)
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
    costLabel:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, 0)

    -- Bribeable node buttons (hold-to-confirm) in the scroller
    self:BuildBribeableNodeButtons(route, heat)

    -- Launch button in the bottom bar
    self.launchBtn:SetVisible(true)
    self.launchBtn.DoClick = function()
      if (not self.selectedRunner) then return end

      surface.PlaySound("buttons/button15.wav")

      net.Start("versus.smuggler.launchRun")
      net.WriteString(route.id)
      net.WriteString(self.selectedRunner)
      net.SendToServer()
    end

    self.detailsBottomBar:SizeToContents()
  end

  -- Adds a "CHECKPOINTS" section with a hold-to-confirm bribe button for each
  -- bribeable node on the route into the details scroller.
  function PANEL:BuildBribeableNodeButtons(route, heat)
    local map = PLUGIN.getMap(route.mapID)
    local bribeableNodes = {}

    for _, nodeID in ipairs(route.nodes or {}) do
      local node = map and self:GetNodeById(map, nodeID)

      if (node and node.canBribe) then
        table.insert(bribeableNodes, node)
      end
    end

    if (#bribeableNodes == 0) then return end

    local heading = vgui.Create("DLabel", self.detailsScroller)
    self.detailsScroller:AddItem(heading)
    heading:SetFont("VersusDefault")
    heading:SetTextColor(color_dim)
    heading:SetText("CHECKPOINTS")
    heading:SizeToContents()
    heading:Dock(TOP)
    heading:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, GAMEMODE.SPACING * 0.25)

    for _, node in ipairs(bribeableNodes) do
      local capturedNode = node
      local bribeCost = PLUGIN.calculateBribeCost(capturedNode, heat)
      local canBribe = heat > 0

      local bribeBtn = vgui.Create("versus_Button", self.detailsScroller)
      self.detailsScroller:AddItem(bribeBtn)
      local actionLabel = capturedNode.bribeActionLabel or "Bribe"
      bribeBtn:SetText(
        actionLabel .. " " .. (capturedNode.displayName or capturedNode.id) ..
        "  (-" .. capturedNode.bribeHeatReduction .. " Heat, " .. versus.util.formatMoney(bribeCost) .. ")"
      )
      bribeBtn:SetType("secondary")
      bribeBtn:SetRequireHoldToClick(true)
      bribeBtn:SetEnabled(canBribe)
      bribeBtn:Dock(TOP)
      bribeBtn:DockMargin(0, 0, 0, 4)
      bribeBtn.DoClick = function()
        net.Start("versus.smuggler.bribeNode")
        net.WriteString(route.id)
        net.WriteString(capturedNode.id)
        net.SendToServer()
      end
    end
  end

  -- Returns the current heat for a route from the cached server data.
  function PANEL:GetRouteHeat(routeID)
    local data = PLUGIN._cachedData
    if (not data or not data.routeHeats) then return 0 end

    return data.routeHeats[routeID] or 0
  end

  -- Returns the active run entry for a route from the cached server data, or nil.
  function PANEL:GetActiveRun(routeID)
    local data = PLUGIN._cachedData
    if (not data or not data.activeRuns) then return nil end

    for _, run in ipairs(data.activeRuns) do
      if (run.routeID == routeID) then return run end
    end
  end

  -- Rebuilds only the scrollable route list on the left column.
  function PANEL:RefreshRouteList()
    self.routeListScroller:Clear()

    local map = self:GetCurrentMap()
    if (not map) then return end

    for _, route in ipairs(map.routes or {}) do
      local heat = self:GetRouteHeat(route.id)
      local heatColor = PLUGIN.getHeatColor(heat)
      local activeRun = self:GetActiveRun(route.id)
      local capturedRoute = route

      local entry = vgui.Create("EditablePanel", self.routeListScroller)
      self.routeListScroller:AddItem(entry)
      entry:Dock(TOP)
      entry:SetTall(80)
      entry:DockMargin(0, 0, 0, 4)
      entry:DockPadding(GAMEMODE.SPACING, 16, GAMEMODE.SPACING, 16)
      entry:SetCursor("hand")

      entry.Paint = function(p, w, h)
        if (self.selectedRoute == capturedRoute.id) then
          surface.SetDrawColor(Color(40, 70, 110, 255))
        elseif (p:IsHovered()) then
          surface.SetDrawColor(Color(25, 38, 55, 255))
        else
          surface.SetDrawColor(color_panel)
        end

        surface.DrawRect(0, 0, w, h)

        -- Heat strip at the bottom
        surface.SetDrawColor(color_border)
        surface.DrawRect(0, h - 4, w, 4)
        surface.SetDrawColor(heatColor)
        surface.DrawRect(0, h - 4, w * (heat / PLUGIN.HEAT_MAX), 4)

        -- Progress circle for active runs
        if (activeRun) then
          local data = PLUGIN._cachedData
          local cachedNow = (data and data.now and data._receivedAt)
              and (data.now + (RealTime() - data._receivedAt))
              or os.time()
          local timeLeft = math.max(0, activeRun.endTime - cachedNow)
          local runProgress = math.Clamp(1 - (timeLeft / capturedRoute.duration), 0.01, 1)
          local circleRadius = 16
          local cx = w - GAMEMODE.SPACING - circleRadius
          local cy = 22
          local circleThickness = 8

          draw.NoTexture()
          -- Background track
          versus.util.drawProgressCircle(cx, cy, circleRadius, 1, circleThickness, Color(45, 65, 90, 160))
          -- Progress arc
          versus.util.drawProgressCircle(cx, cy, circleRadius, runProgress, circleThickness, Color(70, 190, 90, 220))

          -- "Returns in" text below the circle
          surface.SetFont("VersusSmall")
          surface.SetTextColor(Color(70, 190, 90, 220))
          local line1 = "Returns in"
          local line1W = surface.GetTextSize(line1)
          surface.SetTextPos(cx - line1W * 0.5, cy + circleRadius + 3)
          surface.DrawText(line1)

          local line2 = PLUGIN.formatDuration(timeLeft)
          local line2W = surface.GetTextSize(line2)
          surface.SetTextPos(cx - line2W * 0.5, cy + circleRadius + 14)
          surface.DrawText(line2)
        end
      end

      entry.OnMousePressed = function()
        self.selectedRoute = capturedRoute.id
        self:BuildRouteDetails(capturedRoute)
        self:RefreshRouteList()
      end

      local nameLabel = vgui.Create("DLabel", entry)
      nameLabel:SetFont("VersusHeading3")
      nameLabel:SetTextColor(color_text)
      nameLabel:SetText(route.name)
      nameLabel:SizeToContents()
      nameLabel:Dock(TOP)

      local heatLabel = vgui.Create("DLabel", entry)
      heatLabel:SetFont("VersusSmall")
      heatLabel:SetTextColor(heatColor)
      heatLabel:SetText(PLUGIN.getHeatLabel(heat))
      heatLabel:SizeToContents()
      heatLabel:Dock(TOP)
    end
  end

  -- Full refresh: route list + selected route details + pending banner.
  function PANEL:Refresh()
    self:RefreshRouteList()

    if (self.selectedRoute) then
      local route = PLUGIN.getRoute(self.selectedRoute)
      if (route) then self:BuildRouteDetails(route) end
    end

    -- Pending results banner
    local data = PLUGIN._cachedData
    local hasPending = data and data.pendingResults and data.pendingResults > 0

    if (hasPending) then
      if (not IsValid(self.pendingBanner)) then
        self.pendingBanner = vgui.Create("DPanel", self.contentPanel)
        self.pendingBanner:Dock(TOP)
        self.pendingBanner:SetTall(54)
        self.pendingBanner:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.25)
        self.pendingBanner:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING * 0.25, GAMEMODE.SPACING,
          GAMEMODE.SPACING * 0.25)
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
    elseif (IsValid(self.pendingBanner)) then
      self.pendingBanner:Remove()
      self.pendingBanner = nil
    end
  end

  function PANEL:Close()
    if (self.closing) then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if (not self.closing) then
      if (elapsed < self.animDuration) then
        local progress = math.ease.InOutQuad(elapsed / self.animDuration)
        self.bgAlpha = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha = 200
        self.contentAlpha = 255
      end
    else
      local closeElapsed = CurTime() - self.closeStart

      if (closeElapsed < 0.3) then
        local progress = 1 - (closeElapsed / 0.3)
        self.bgAlpha = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self:Remove()
      end
    end

    self:SetAlpha(self.contentAlpha)
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)
    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self.contentPanel:SetWide(w - GAMEMODE.SPACING * 2)
    self.contentPanel:SetTall(h)
    self.contentPanel:Center()

    self.leftColumn:SetWide(math.floor(self.contentPanel:GetWide() * 0.38))

    self:Center()
  end

  vgui.Register("versus_SmugglerMap", PANEL, "EditablePanel")
end
