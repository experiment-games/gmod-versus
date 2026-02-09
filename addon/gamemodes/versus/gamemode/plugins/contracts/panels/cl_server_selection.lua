local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(
      math.max(ScrW() * 0.4, 600),
      ScrH()
    )

    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)

    self.bgAlpha = 0
    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    self.contentPanel = vgui.Create("DSizeToContents", self)
    self.contentPanel:SetSizeX(false)

    self.titleLabel = vgui.Create("DLabel", self.contentPanel)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("Select Contract Server")
    self.titleLabel:SetContentAlignment(5)
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.descriptionLabel = vgui.Create("DLabel", self.contentPanel)
    self.descriptionLabel:SetFont("VersusDefault")
    self.descriptionLabel:SetTextColor(Color(180, 190, 200, 255))
    self.descriptionLabel:SetText(
      "Choose a contract server to connect to. Your progress is synchronized across all servers, but each server may have a different map and thus different available contracts."
    )
    self.descriptionLabel:SetWrap(true)
    self.descriptionLabel:SetAutoStretchVertical(true)
    self.descriptionLabel:Dock(TOP)
    self.descriptionLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.serverListContainer = vgui.Create("DSizeToContents", self.contentPanel)
    self.serverListContainer:Dock(TOP)
    self.serverListContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.serverListContainer:SetSizeX(false)

    self.earlyAccessLabel = vgui.Create("DLabel", self.contentPanel)
    self.earlyAccessLabel:SetFont("VersusDefault")
    self.earlyAccessLabel:SetTextColor(Color(180, 190, 200, 100))
    self.earlyAccessLabel:SetText(
      "In the future, we plan to show more information about each server, such as the current map, available contracts, and player population. "
      ..
      "During this prototyping phase (early access), please manually add the servers to your favorites and check their details in the server browser before connecting."
    )
    self.earlyAccessLabel:SetWrap(true)
    self.earlyAccessLabel:SetAutoStretchVertical(true)
    self.earlyAccessLabel:Dock(TOP)
    self.earlyAccessLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.cancelButton = vgui.Create("versus_Button", self.contentPanel)
    self.cancelButton:SetText("CANCEL")
    self.cancelButton:Dock(TOP)
    self.cancelButton:SetType("secondary")
    self.cancelButton.DoClick = function()
      self:Close()
    end
  end

  function PANEL:SetServerList(serverListString)
    self.serverListContainer:Clear()

    -- Parse the comma-separated server list
    local servers = string.Explode(",", serverListString)

    if #servers == 0 then
      local noServersLabel = vgui.Create("DLabel", self.serverListContainer)
      noServersLabel:SetFont("VersusDefault")
      noServersLabel:SetTextColor(Color(220, 80, 80, 255))
      noServersLabel:SetText("No servers available")
      noServersLabel:SetContentAlignment(5)
      noServersLabel:SizeToContents()
      noServersLabel:Dock(TOP)
      return
    end

    for i, serverAddress in ipairs(servers) do
      serverAddress = string.Trim(serverAddress)

      if serverAddress ~= "" then
        self:AddServerButton(serverAddress, i)
      end
    end
  end

  function PANEL:AddServerButton(serverAddress, index)
    local serverButton = vgui.Create("versus_Button", self.serverListContainer)
    serverButton:SetText(serverAddress)
    serverButton:Dock(TOP)
    serverButton:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)
    serverButton:SetType("primary")

    serverButton.DoClick = function()
      permissions.AskToConnect(serverAddress)
    end
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    -- Fade in animation
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
      -- Fade out animation
      local closeElapsed = CurTime() - self.closeStart
      if closeElapsed < 0.3 then
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

    -- Dark overlay background
    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self.contentPanel:SetWide(self:GetWide() - GAMEMODE.SPACING * 2)
    self.contentPanel:Center()

    self:Center()
  end

  vgui.Register("versus_CombatServerSelectionScreen", PANEL, "EditablePanel")
end

net.Receive("versus.combat.showServerSelectionScreen", function()
  local serverList = net.ReadString()

  local panel = vgui.Create("versus_CombatServerSelectionScreen")
  panel:SetServerList(serverList)
end)
