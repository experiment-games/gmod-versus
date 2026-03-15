local PLUGIN = PLUGIN

local color_dim = Color(140, 155, 170, 255)

do
  local PANEL = {}

  function PANEL:Init()
    local spacing = GAMEMODE.SPACING

    self:DockPadding(0, spacing * .5, 0, GAMEMODE.SPACING)

    -- Mode selector: two large buttons at the top.
    self.modeSelector = vgui.Create("EditablePanel", self)
    self.modeSelector:Dock(TOP)
    self.modeSelector:SetTall(80)
    self.modeSelector:DockMargin(0, 0, 0, spacing)

    self.soloButton = vgui.Create("versus_Button", self.modeSelector)
    self.soloButton:SetText("CONTRACTS (SOLO)")
    self.soloButton:Dock(LEFT)
    self.soloButton.DoClick = function()
      self:SetMode("solo")
    end

    -- Spacer between the two mode buttons.
    local spacer = vgui.Create("EditablePanel", self.modeSelector)
    spacer:Dock(LEFT)
    spacer:SetWide(spacing)

    self.coopButton = vgui.Create("versus_Button", self.modeSelector)
    self.coopButton:SetText("ENDURANCE (CO-OP)")
    self.coopButton:Dock(LEFT)
    self.coopButton.DoClick = function()
      self:SetMode("coop")
    end

    -- Content area shown below the mode selector.
    self.soloContent = vgui.Create("versus_SoloServerList", self)
    self.soloContent:Dock(FILL)

    self.coopContent = vgui.Create("versus_EnduranceMatchmakingPanel", self)
    self.coopContent:Dock(FILL)
    self.coopContent:SetVisible(false)

    self.titleLabel = vgui.Create("DLabel", self.coopContent)
    self.titleLabel:SetFont("VersusDefault")
    self.titleLabel:SetTextColor(Color(180, 190, 200, 255))
    self.titleLabel:SetWrap(true)
    self.titleLabel:SetAutoStretchVertical(true)
    self.titleLabel:SetText(
      "In Endurance mode, you team up with " ..
      versus.endurance.SQUAD_MIN_SIZE .. "–" .. versus.endurance.SQUAD_MAX_SIZE ..
      " players to survive against endless waves of enemies. " ..
      "Form a squad and queue for matchmaking, then get ready to fight for your life!"
    )
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, spacing * 0.5)

    self:SetMode("solo")
  end

  --- Switch between "solo" and "coop" modes, updating button styles and visible content.
  function PANEL:SetMode(mode)
    self.mode = mode

    self.soloButton:SetType(mode == "solo" and "primary" or "default")
    self.coopButton:SetType(mode == "coop" and "primary" or "default")

    self.soloContent:SetVisible(mode == "solo")
    self.coopContent:SetVisible(mode == "coop")

    if mode == "solo" then
      self.soloContent:RefreshServers()
    end
  end

  function PANEL:PerformLayout(w, h)
    local spacing = GAMEMODE.SPACING
    local innerW  = w - spacing * 2
    local btnW    = (innerW - spacing) / 2

    self.soloButton:SetWide(btnW)
    self.coopButton:SetWide(btnW)
  end

  function PANEL:OnMenuShown()
    if self.mode == "solo" then
      self.soloContent:RefreshServers()
    end

    if IsValid(self.coopContent) and self.coopContent.OnMenuShown then
      self.coopContent:OnMenuShown()
    end
  end

  vgui.Register("versus_ServerSelectionTab", PANEL, "EditablePanel")
end

--[[
  Solo server list: reads the versus_combat_servers ConVar and displays
  a versus_ServerButton entry for each configured server.
--]]

do
  local PANEL = {}

  function PANEL:Init()
    local spacing = GAMEMODE.SPACING

    self.descLabel = vgui.Create("DLabel", self)
    self.descLabel:SetFont("VersusDefault")
    self.descLabel:SetTextColor(color_dim)
    self.descLabel:SetText(
      "Choose a contract server to connect to. " ..
      "Your progress is synchronized across all servers. " ..
      "Each server may have a different map and thus different available contracts."
    )
    self.descLabel:SetWrap(true)
    self.descLabel:SetAutoStretchVertical(true)
    self.descLabel:Dock(TOP)
    self.descLabel:DockMargin(0, 0, 0, spacing)

    self.serverListContainer = vgui.Create("versus_ScrollPanel", self)
    self.serverListContainer:Dock(FILL)

    self:RefreshServers()
  end

  --- Re-read the versus_combat_servers ConVar and rebuild the server list.
  function PANEL:RefreshServers()
    self.serverListContainer:Clear()

    local convar = GetConVar("versus_combat_servers")
    local serverListString = convar and convar:GetString() or ""

    if serverListString == "" then
      local noServersLabel = vgui.Create("DLabel", self.serverListContainer)
      noServersLabel:SetFont("VersusDefault")
      noServersLabel:SetTextColor(Color(220, 80, 80, 255))
      noServersLabel:SetText("No servers available")
      noServersLabel:SizeToContents()
      noServersLabel:Dock(TOP)
      noServersLabel:DockMargin(0, GAMEMODE.SPACING, 0, 0)
      return
    end

    local servers = string.Explode(",", serverListString)

    for _, serverAddress in ipairs(servers) do
      serverAddress = string.Trim(serverAddress)

      if serverAddress ~= "" then
        -- versus_ServerButton docks itself TOP with a margin in its Init.
        local serverButton = vgui.Create("versus_ServerButton", self.serverListContainer)
        serverButton:SetServerAddress(serverAddress)
      end
    end
  end

  vgui.Register("versus_SoloServerList", PANEL, "EditablePanel")
end
