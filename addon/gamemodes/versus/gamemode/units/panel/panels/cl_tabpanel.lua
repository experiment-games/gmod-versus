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

    self.buttonContainer = vgui.Create("DSizeToContents", self.tabBar)
    self.buttonContainer:SetSizeY(false)
    self.buttonContainer:SetTall(64)

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
    btn:Dock(LEFT)

    local isFirst = #self.tabs == 0

    if not isFirst then
      btn:DockMargin(BUTTON_SPACING, 0, 0, 0)
    end

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

  function PANEL:PerformLayout(w, h)
    self.buttonContainer:Center()
  end

  vgui.Register("versus_TabPanel", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  vgui.Register("versus_TabButton", PANEL, "versus_Button")
end
