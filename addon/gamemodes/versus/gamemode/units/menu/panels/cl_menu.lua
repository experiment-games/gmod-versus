local UNIT = UNIT

UNIT.open = nil

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    -- Create the close button.
    self.close = vgui.Create("versus_Button", self)
    self.close:SetText("Close")
    self.close.DoClick = function(self)
      UNIT.toggle()
    end

    self.tabHolder = vgui.Create("versus_TabPanel", self)
    self.tabs = {}

    self.tabBuilder = UNIT.getTabBuilder()

    hook.Run("BuildMainMenuTabs", self.tabBuilder)

    self.tabBuilder:addTab("Rules", vgui.Create("versus_Rules"), "icon16/exclamation.png", 99999)

    for i, tab in pairs(self.tabBuilder:getSorted()) do
      table.insert(self.tabs, tab:buildInto(self.tabHolder))
      tab.contentPanel.parentMenu = self
    end
  end

  function PANEL:ShowTab(targetTab)
    self.tabHolder:SetActiveTab(targetTab)
  end

  function PANEL:CallShownEvent()
    for _, tab in pairs(self.tabs) do
      local tabData = tab.tabData

      if (UNIT.open and tabData.Panel.OnMenuShown) then
        tabData.Panel:OnMenuShown()
      end
    end

    hook.Run("VersusMenuToggled", UNIT.open)
  end

  function PANEL:OnKeyCodePressed(keyCode)
    local activeTabName, activeTabPanel = self.tabHolder:GetActiveTab()

    if (activeTabPanel.OnKeyCodePressed) then
      activeTabPanel:OnKeyCodePressed(keyCode)
    end
  end

  function PANEL:PerformLayout(width, height)
    self:SetVisible(UNIT.open)
    self:SetSize(UNIT.width, UNIT.height)
    self:SetPos(ScrW() / 2 - self:GetWide() / 2, ScrH() / 2 - self:GetTall() / 2)

    -- Set the size and position of the close button.
    self.close:SizeToContents()
    self.close:SetPos(self:GetWide() - self.close:GetWide() - 32, 32)

    local maxTabHolderWidth = math.Clamp(self:GetWide() * 0.75, 800, 1200)
    local horizontalOffset = (self:GetWide() - maxTabHolderWidth) / 2
    self.tabHolder:StretchToParent(horizontalOffset, 50, horizontalOffset, 50)

    -- Size To Contents.
    self:SizeToContents()
  end

  function PANEL:Paint(width, height)
    Derma_DrawBackgroundBlur(self, CurTime())
    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(0, 0, width, height)

    return true
  end

  vgui.Register("versus_Menu", PANEL, "EditablePanel")
end

do
  -- Standalone menu to show when the player hasn't initialized yet (and the
  -- main menu can't toggle yet)
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self.tabHolder = vgui.Create("versus_TabPanel", self)
  end

  function PANEL:BuildTabs(callback)
    self.tabBuilder = versus.menu.getTabBuilder()

    callback(self.tabBuilder)

    for _, tab in pairs(self.tabBuilder:getSorted()) do
      tab:buildInto(self.tabHolder)
      tab.contentPanel.parentMenu = self
    end
  end

  function PANEL:PerformLayout(width, height)
    self:SetSize(versus.menu.width, versus.menu.height)
    self:SetPos(ScrW() / 2 - self:GetWide() / 2, ScrH() / 2 - self:GetTall() / 2)

    local maxTabHolderWidth = math.Clamp(self:GetWide() * 0.75, 800, 1200)
    local horizontalOffset = (self:GetWide() - maxTabHolderWidth) / 2
    self.tabHolder:StretchToParent(horizontalOffset, 50, horizontalOffset, 50)

    self:SizeToContents()
  end

  vgui.Register("versus_Menu_Standalone", PANEL, "EditablePanel")
end
