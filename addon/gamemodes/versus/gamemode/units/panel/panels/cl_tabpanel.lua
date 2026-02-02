local UNIT = UNIT
local BUTTON_SPACING = 32
local BUTTON_HEIGHT = 48

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    -- Top bar for tab buttons
    self.tabBar = vgui.Create("EditablePanel", self)
    self.tabBar:Dock(TOP)
    self.tabBar:SetTall(64)

    -- Container for centering buttons (50% width)
    self.buttonContainer = vgui.Create("EditablePanel", self.tabBar)

    -- Content area
    self.contentPanel = vgui.Create("EditablePanel", self)
    self.contentPanel:Dock(FILL)

    self.tabs = {}
    self.activeTab = nil
    self.tabButtons = {}
  end

  function PANEL:AddTab(name, panel)
    -- Create tab button
    local btn = vgui.Create("versus_TabButton", self.buttonContainer)
    btn:SetText(name:upper())
    btn:SetTall(48)
    btn:SizeToContents()

    -- Custom colors for tab buttons
    btn.bgColor = Color(20, 28, 40, 0)
    btn.hoverColor = Color(25, 35, 50, 180)
    btn.pressColor = Color(20, 30, 45, 220)
    btn.accentColor = Color(80, 140, 220, 255)

    -- Store original DoClick before overriding
    btn.tabName = name
    btn.DoClick = function()
      self:SetActiveTab(name)
    end

    -- Set up the panel
    if panel then
      panel:SetParent(self.contentPanel)
      panel:Dock(FILL)
      panel:SetVisible(false)
    end

    table.insert(self.tabs, {
      name = name,
      button = btn,
      panel = panel
    })

    table.insert(self.tabButtons, btn)

    -- If this is the first tab, activate it
    if #self.tabs == 1 then
      self:SetActiveTab(name)
    end

    self:InvalidateLayout()

    return panel
  end

  function PANEL:SetActiveTab(name)
    -- Deactivate all tabs
    for _, tab in ipairs(self.tabs) do
      if tab.panel then
        tab.panel:SetVisible(false)
      end

      -- Reset button appearance
      tab.button.bgColor = Color(20, 28, 40, 0)
      tab.button.textColor = Color(150, 170, 200, 255)
    end

    -- Activate the selected tab
    for _, tab in ipairs(self.tabs) do
      if tab.name == name then
        if tab.panel then
          tab.panel:SetVisible(true)
        end

        -- Highlight active button
        tab.button.bgColor = Color(25, 35, 50, 200)
        tab.button.textColor = Color(220, 230, 240, 255)

        self.activeTab = name
        break
      end
    end
  end

  function PANEL:GetActiveTab()
    return self.activeTab, self:GetTabPanel(self.activeTab)
  end

  function PANEL:GetTabPanel(name)
    for _, tab in ipairs(self.tabs) do
      if tab.name == name then
        return tab.panel
      end
    end

    return nil
  end

  function PANEL:Think()
    -- Update button container layout if needed
    if self.needsButtonLayout then
      self.needsButtonLayout = false
      self:LayoutButtons()
    end
  end

  function PANEL:LayoutButtons()
    local numButtons = #self.tabButtons
    if numButtons == 0 then return end

    local containerW = self.buttonContainer:GetWide()

    -- Calculate total width needed for all buttons
    local totalButtonWidth = 0
    for _, btn in ipairs(self.tabButtons) do
      btn:SizeToContents()
      btn:SetTall(BUTTON_HEIGHT)
      local minWidth = math.max(btn:GetWide() + 32, 120) -- Minimum 120px width
      btn:SetWide(minWidth)
      totalButtonWidth = totalButtonWidth + btn:GetWide()
    end

    -- Add spacing between buttons
    totalButtonWidth = totalButtonWidth + (BUTTON_SPACING * (numButtons - 1))

    -- Position buttons evenly within the container
    local startX = (containerW - totalButtonWidth) / 2
    local currentX = startX

    for _, btn in ipairs(self.tabButtons) do
      btn:SetPos(currentX, 8)
      currentX = currentX + btn:GetWide() + BUTTON_SPACING
    end
  end

  function PANEL:PerformLayout(w, h)
    -- Position button container in center 50% of tab bar
    local barWidth = self.tabBar:GetWide()
    local containerWidth = barWidth * 0.5
    local containerX = (barWidth - containerWidth) / 2

    self.buttonContainer:SetPos(containerX, 0)
    self.buttonContainer:SetSize(containerWidth, self.tabBar:GetTall())

    -- Layout buttons
    self:LayoutButtons()
  end

  vgui.Register("versus_TabPanel", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  vgui.Register("versus_TabButton", PANEL, "versus_Button")
end
