local UNIT = UNIT

UNIT.open = nil
UNIT.width = 700
UNIT.height = 700

do
  local PANEL = {}

  DEFINE_BASECLASS("DFrame")

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self:SetTitle("Main Menu")
    self:SetBackgroundBlur(true)
    self:SetDeleteOnClose(false)
    self:ShowCloseButton(false)

    -- Create the close button.
    self.close = vgui.Create("DButton", self)
    self.close:SetText("Close")
    self.close.DoClick = function(self)
      UNIT.toggle()
    end

    self.tabHolder = vgui.Create("DPropertySheet", self)
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
    self.tabHolder:SwitchToName(targetTab)
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
    local activePanel = self.tabHolder:GetActiveTab():GetPanel()

    if (activePanel.OnKeyCodePressed) then
      activePanel:OnKeyCodePressed(keyCode)
    end
  end

  function PANEL:PerformLayout(width, height)
    UNIT.width = math.min(UNIT.width, ScrW() * .7)
    UNIT.height = math.min(UNIT.height, ScrH() * .7)

    self:SetVisible(UNIT.open)
    self:SetSize(UNIT.width, UNIT.height)
    self:SetPos(ScrW() / 2 - self:GetWide() / 2, ScrH() / 2 - self:GetTall() / 2)

    -- Set the size and position of the close button.
    self.close:SetSize(48, 16)
    self.close:SetPos(self:GetWide() - self.close:GetWide() - 4, 3)

    -- Stretch the tabs to the parent.
    self.tabHolder:StretchToParent(4, 28, 4, 4)

    -- Size To Contents.
    self:SizeToContents()

    -- Perform the layout of the main frame.
    BaseClass.PerformLayout(self, width, height)
  end

  vgui.Register("versus_Menu", PANEL, "DFrame")
end

do
  -- Standalone menu to show when the player hasn't initialized yet (and the
  -- main menu can't toggle yet)
  local PANEL = {}

  DEFINE_BASECLASS("DFrame")

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self:SetTitle("Main Menu")
    self:SetBackgroundBlur(true)
    self:SetDeleteOnClose(false)
    self:ShowCloseButton(false)

    self.tabHolder = vgui.Create("DPropertySheet", self)
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

    self.tabHolder:StretchToParent(4, 28, 4, 4)

    self:SizeToContents()

    -- Perform the layout of the main frame.
    BaseClass.PerformLayout(self, width, height)
  end

  vgui.Register("versus_Menu_Standalone", PANEL, "DFrame")
end
