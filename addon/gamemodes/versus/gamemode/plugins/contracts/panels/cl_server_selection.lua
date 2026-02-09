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
    self:ParentToHUD()

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
      "Choose a contract server to connect to. Your progress is synchronized across all servers. Each server may have a different map and thus different available contracts."
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
    local serverButton = vgui.Create("versus_ServerButton", self.serverListContainer)
    serverButton:SetServerAddress(serverAddress)
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

do
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(120)
    self:Dock(TOP)
    self:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.isHovered = false
    self:SetMouseInputEnabled(true)

    local offsetLeft = 50

    -- Server Name label
    self.serverNameLabel = vgui.Create("DLabel", self)
    self.serverNameLabel:SetFont("VersusHeading3")
    self.serverNameLabel:SetTextColor(Color(220, 230, 240, 255))
    self.serverNameLabel:SetText("Loading...")
    self.serverNameLabel:SetPos(offsetLeft, 10)
    self.serverNameLabel:SizeToContents()

    -- IP Address label
    self.ipLabel = vgui.Create("DLabel", self)
    self.ipLabel:SetFont("VersusDefault")
    self.ipLabel:SetTextColor(Color(140, 150, 160, 255))
    self.ipLabel:SetPos(offsetLeft, 35)
    self.ipLabel:SizeToContents()

    -- Loading indicator
    self.loadingIndicator = vgui.Create("versus_LoadingIndicator", self)
    self.loadingIndicator:Dock(FILL)

    -- Map label
    self.mapLabel = vgui.Create("DLabel", self)
    self.mapLabel:SetFont("VersusDefault")
    self.mapLabel:SetTextColor(Color(180, 190, 200, 255))
    self.mapLabel:SetPos(offsetLeft, 65)
    self.mapLabel:SetVisible(false)

    -- Players label
    self.playersLabel = vgui.Create("DLabel", self)
    self.playersLabel:SetFont("VersusDefault")
    self.playersLabel:SetTextColor(Color(160, 180, 200, 255))
    self.playersLabel:SetPos(offsetLeft, 85)
    self.playersLabel:SetVisible(false)

    -- Connect button
    self.connectButton = vgui.Create("versus_Button", self)
    self.connectButton:SetText("CONNECT")
    self.connectButton:SetSize(140, 40)
    self.connectButton:SetType("primary")
    self.connectButton:SetEnabled(false)

    self.connectButton.PerformLayout = function(pnl, w, h)
      pnl:SetPos(self:GetWide() - w - 20, (self:GetTall() - h) / 2)
    end
  end

  function PANEL:SetServerAddress(serverAddress)
    self.serverAddress = serverAddress
    self.ipLabel:SetText(serverAddress)
    self.ipLabel:SizeToContents()

    self.connectButton.DoClick = function()
      permissions.AskToConnect(serverAddress)
    end

    self.DoClick = function()
      permissions.AskToConnect(serverAddress)
    end

    -- Query server info
    local ip, port = serverAddress:match("([^:]+):(%d+)")

    if ip and port then
      port = tonumber(port)

      versus.serverInfo.getInfo(ip, port, function(success, data)
        if not IsValid(self) then return end

        if IsValid(self.loadingIndicator) then
          self.loadingIndicator:Remove()
        end

        if success then
          -- Set server name
          local serverName = data.name or "Unknown Server"
          self.serverNameLabel:SetText(serverName)
          self.serverNameLabel:SizeToContents()

          -- Set map info
          local mapName = data.map or "Unknown"
          self.mapLabel:SetText("Map: " .. mapName)
          self.mapLabel:SetVisible(true)
          self.mapLabel:SizeToContents()

          -- Set player info with color coding
          local players = data.players or 0
          local maxPlayers = data.max_players or 0
          self.playersLabel:SetText(string.format("Players: %d / %d", players, maxPlayers))

          -- Color code based on server population
          if players == maxPlayers and maxPlayers > 0 then
            self.playersLabel:SetTextColor(Color(220, 80, 80, 255))   -- Red if full
          elseif players > maxPlayers * 0.7 then
            self.playersLabel:SetTextColor(Color(220, 180, 80, 255))  -- Orange if nearly full
          else
            self.playersLabel:SetTextColor(Color(120, 200, 120, 255)) -- Green if available
          end
          self.playersLabel:SetVisible(true)
          self.playersLabel:SizeToContents()

          self.connectButton:SetEnabled(true)
        else
          -- Failed to get info
          self.serverNameLabel:SetText("Server Query Failed")
          self.serverNameLabel:SetTextColor(Color(220, 80, 80, 255))
          self.serverNameLabel:SizeToContents()

          self.mapLabel:SetText("Failed to retrieve server info")
          self.mapLabel:SetTextColor(Color(220, 80, 80, 255))
          self.mapLabel:SetVisible(true)
          self.mapLabel:SizeToContents()

          -- Still allow connection even if query failed
          self.connectButton:SetEnabled(true)
        end
      end)
    else
      -- Invalid address format
      if IsValid(self.loadingIndicator) then
        self.loadingIndicator:Remove()
      end

      self.serverNameLabel:SetText("Invalid Address")
      self.serverNameLabel:SetTextColor(Color(220, 80, 80, 255))
      self.serverNameLabel:SizeToContents()

      self.mapLabel:SetText("Invalid server address format")
      self.mapLabel:SetTextColor(Color(220, 80, 80, 255))
      self.mapLabel:SetVisible(true)
      self.mapLabel:SizeToContents()
    end
  end

  function PANEL:Paint(w, h)
    -- Draw background with hover effect
    local bgColor = self.isHovered and Color(40, 45, 52, 220) or Color(30, 35, 40, 200)
    draw.RoundedBox(16, 0, 0, w, h, bgColor)

    -- Draw accent line on left
    local accentColor = self.isHovered and Color(90, 160, 240, 230) or Color(80, 140, 220, 200)
    draw.RoundedBoxEx(16, 0, 0, 32, h, accentColor, true, false, true, false)
  end

  function PANEL:OnMousePressed()
    if not self:IsEnabled() then return end
    self.pressed = true
  end

  function PANEL:OnMouseReleased()
    if self.pressed and self.isHovered then
      self:DoClick()
    end
    self.pressed = false
  end

  function PANEL:OnCursorEntered()
    if not self:IsEnabled() then return end

    self.connectButton:SetHovered(true)
    self.isHovered = true
  end

  function PANEL:OnCursorExited()
    if not self:IsEnabled() then return end

    self.connectButton:SetHovered(false)
    self.isHovered = false
  end

  function PANEL:DoClick()
    -- Override this function
  end

  vgui.Register("versus_ServerButton", PANEL, "EditablePanel")
end

net.Receive("versus.combat.showServerSelectionScreen", function()
  local serverList = net.ReadString()

  local panel = vgui.Create("versus_CombatServerSelectionScreen")
  panel:SetServerList(serverList)
end)
