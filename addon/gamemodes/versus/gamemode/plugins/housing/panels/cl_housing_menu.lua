local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(
      math.max(ScrW() * 0.6, 700),
      ScrH()
    )

    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha = 0
    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    local headingContainer = vgui.Create("EditablePanel", self)
    headingContainer:Dock(TOP)
    headingContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.titleLabel = vgui.Create("DLabel", headingContainer)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("HIDEOUT")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(FILL)

    headingContainer:SetTall(self.titleLabel:GetTall())

    self.closeButton = vgui.Create("versus_Button", headingContainer)
    self.closeButton:SetText("CLOSE")
    self.closeButton:Dock(RIGHT)
    self.closeButton:DockMargin(GAMEMODE.SPACING, 0, 0, 0)
    self.closeButton:SetType("secondary")
    self.closeButton:SizeToContents()
    self.closeButton.DoClick = function()
      self:Close()
    end

    self.tabHolder = vgui.Create("versus_TabPanel", self)
    self.tabHolder:Dock(FILL)
    self.tabs = {}

    local tabBuilder = versus.menu.getTabBuilder()
    hook.Run("BuildHousingMenuTabs", tabBuilder)

    for i, tab in pairs(tabBuilder:getSorted()) do
      table.insert(self.tabs, tab:buildInto(self.tabHolder))
      tab.contentPanel.parentMenu = self
    end
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if not self.closing then
      if elapsed < self.animDuration then
        local progress = elapsed / self.animDuration
        progress = math.ease.InOutQuad(progress)

        self.bgAlpha = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha = 200
        self.contentAlpha = 255
      end
    else
      local closeElapsed = CurTime() - self.closeStart
      if closeElapsed < 0.3 then
        local progress = 1 - (closeElapsed / 0.3)
        self.bgAlpha = 200 * progress
        self.contentAlpha = 255 * progress
      else
        PLUGIN.housingMenuPanel = nil
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
    self:Center()
  end

  function PANEL:OnKeyCodeReleased(keyCode)
    if keyCode == KEY_ESCAPE then
      self:Close()
    end
  end

  vgui.Register("versus_HousingMenu", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    self.label = vgui.Create("DLabel", self)
    self.label:SetFont("VersusHeading1")
    self.label:SetTextColor(Color(220, 230, 240, 255))
    self.label:SetText("WORK IN PROGRESS")
    self.label:SizeToContents()
  end

  function PANEL:PerformLayout(w, h)
    self.label:SetPos(
      (w - self.label:GetWide()) / 2,
      (h - self.label:GetTall()) / 2
    )
  end

  vgui.Register("versus_HousingOverview", PANEL, "EditablePanel")
end
