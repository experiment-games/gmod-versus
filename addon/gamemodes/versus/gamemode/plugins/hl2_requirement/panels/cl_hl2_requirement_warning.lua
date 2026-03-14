local PLUGIN = PLUGIN

do
  --- @class versus_HL2RequirementWarning : EditablePanel
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(
      math.max(ScrW() * 0.45, 700),
      ScrH()
    )

    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha = 0
    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.35

    self.closing = false
    self.closeStart = 0

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    self.contentPanel = vgui.Create("DSizeToContents", self)
    self.contentPanel:SetSizeX(false)

    self.titleLabel = vgui.Create("DLabel", self.contentPanel)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("Half-Life 2 Required")
    self.titleLabel:SetContentAlignment(5)
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    self.descriptionLabel = vgui.Create("DLabel", self.contentPanel)
    self.descriptionLabel:SetFont("VersusDefault")
    self.descriptionLabel:SetTextColor(Color(180, 190, 200, 255))
    self.descriptionLabel:SetWrap(true)
    self.descriptionLabel:SetAutoStretchVertical(true)
    self.descriptionLabel:SetText("")
    self.descriptionLabel:Dock(TOP)
    self.descriptionLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.6)

    self.guidanceLabel = vgui.Create("DLabel", self.contentPanel)
    self.guidanceLabel:SetFont("VersusDefault")
    self.guidanceLabel:SetTextColor(Color(220, 230, 240, 255))
    self.guidanceLabel:SetWrap(true)
    self.guidanceLabel:SetAutoStretchVertical(true)
    self.guidanceLabel:SetText("")
    self.guidanceLabel:Dock(TOP)
    self.guidanceLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.buttonContainer = vgui.Create("DSizeToContents", self.contentPanel)
    self.buttonContainer:Dock(TOP)
    self.buttonContainer:SetSizeX(false)

    ---@type any
    self.storeButton = vgui.Create("versus_Button", self.buttonContainer)
    self.storeButton:SetText("OPEN HALF-LIFE 2 STORE PAGE")
    self.storeButton:SetType("primary")
    self.storeButton:Dock(TOP)
    self.storeButton:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)
    self.storeButton.DoClick = function()
      PLUGIN.openHalfLife2StorePage()
    end

    ---@type any
    self.recheckButton = vgui.Create("versus_Button", self.buttonContainer)
    self.recheckButton:SetText("RECHECK")
    self.recheckButton:SetType("primary")
    self.recheckButton:Dock(TOP)
    self.recheckButton:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)
    self.recheckButton.DoClick = function()
      PLUGIN.checkHalfLife2Requirements()
    end

    ---@type any
    self.closeButton = vgui.Create("versus_Button", self.buttonContainer)
    self.closeButton:SetText("CONTINUE ANYWAY")
    self.closeButton:SetType("secondary")
    self.closeButton:Dock(TOP)
    self.closeButton.DoClick = function()
      self:Close()
    end
  end

  --- @param data table
  function PANEL:SetWarningData(data)
    self.titleLabel:SetText(data.title or "Half-Life 2 Required")
    self.titleLabel:SizeToContents()

    self.descriptionLabel:SetText(data.description or "")
    self.guidanceLabel:SetText(data.guidance or "")

    self.storeButton:SetVisible(data.showStoreButton == true)

    self:InvalidateLayout(true)
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:OnRemove()
    if PLUGIN.warningPanel == self then
      PLUGIN.warningPanel = nil
    end
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

      if closeElapsed < 0.25 then
        local progress = 1 - (closeElapsed / 0.25)
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

  function PANEL:PerformLayout()
    self.contentPanel:SetWide(self:GetWide() - GAMEMODE.SPACING * 2)
    self.contentPanel:Center()

    self:Center()
  end

  vgui.Register("versus_HL2RequirementWarning", PANEL, "EditablePanel")
end
