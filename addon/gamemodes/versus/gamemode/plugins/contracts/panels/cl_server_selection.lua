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
    -- Create a container for the server entry
    local serverContainer = vgui.Create("DPanel", self.serverListContainer)
    serverContainer:Dock(TOP)
    serverContainer:DockMargin(0, 0, 0, 0)
    serverContainer:SetTall(80)
    serverContainer.Paint = function(pnl, w, h)
      -- Draw background
      surface.SetDrawColor(30, 35, 40, 200)
      surface.DrawRect(0, 0, w, h)

      -- Draw border
      surface.SetDrawColor(60, 70, 80, 255)
      surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- IP Address label
    local ipLabel = vgui.Create("DLabel", serverContainer)
    ipLabel:SetFont("VersusDefault")
    ipLabel:SetTextColor(Color(220, 230, 240, 255))
    ipLabel:SetText(serverAddress)
    ipLabel:SetPos(20, 15)
    ipLabel:SizeToContents()

    -- Loading indicator
    local loadingIndicator = vgui.Create("versus_LoadingIndicator", serverContainer)
    loadingIndicator:SetPos(0, 0)

    -- Server info label (map and players)
    local infoLabel = vgui.Create("DLabel", serverContainer)
    infoLabel:SetFont("VersusDefault")
    infoLabel:SetTextColor(Color(180, 190, 200, 255))
    infoLabel:SetPos(20, 20 + 20)
    infoLabel:SetText("Loading server info...")
    infoLabel:SizeToContents()
    infoLabel:SetVisible(false)

    -- Connect button
    local connectButton = vgui.Create("versus_Button", serverContainer)
    connectButton:SetText("CONNECT")
    connectButton:SetSize(120, 35)
    connectButton:SetType("primary")
    connectButton:SetEnabled(false)
    connectButton.DoClick = function()
      permissions.AskToConnect(serverAddress)
    end

    connectButton.PerformLayout = function(pnl, w, h)
      pnl:SetPos(serverContainer:GetWide() - w - GAMEMODE.SPACING, (serverContainer:GetTall() - h) / 2)
    end

    local ip, port = serverAddress:match("([^:]+):(%d+)")

    if ip and port then
      port = tonumber(port)

      versus.serverInfo.getInfo(ip, port, function(success, data)
        if IsValid(loadingIndicator) then
          loadingIndicator:Remove()
        end

        if IsValid(infoLabel) and IsValid(connectButton) then
          if success then
            local mapName = data.map or "Unknown"
            local players = data.players or 0
            local maxPlayers = data.max_players or 0

            infoLabel:SetText(string.format("Map: %s | Players: %d/%d", mapName, players, maxPlayers))
            infoLabel:SetTextColor(Color(180, 190, 200, 255))
            infoLabel:SetVisible(true)
            infoLabel:SizeToContents()

            connectButton:SetEnabled(true)
          else
            infoLabel:SetText("Failed to retrieve server info")
            infoLabel:SetTextColor(Color(220, 80, 80, 255))
            infoLabel:SetVisible(true)
            infoLabel:SizeToContents()

            -- Still allow connection even if query failed
            connectButton:SetEnabled(true)
          end
        end
      end)
    else
      -- Invalid address format
      if IsValid(loadingIndicator) then
        loadingIndicator:Remove()
      end

      if IsValid(infoLabel) then
        infoLabel:SetText("Invalid server address format")
        infoLabel:SetTextColor(Color(220, 80, 80, 255))
        infoLabel:SetVisible(true)
        infoLabel:SizeToContents()
      end
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
