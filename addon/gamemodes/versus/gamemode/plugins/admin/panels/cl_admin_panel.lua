local PLUGIN            = PLUGIN

local COLOR_BG_ROW_EVEN = Color(25, 36, 52, 200)
local COLOR_BG_ROW_ODD  = Color(20, 28, 40, 200)
local COLOR_BG_HEADER   = Color(15, 22, 32, 255)
local COLOR_TEXT        = Color(220, 230, 240, 255)
local COLOR_DIM         = Color(140, 155, 170, 255)
local COLOR_WARN        = Color(255, 200, 80, 255)
local COLOR_DANGER      = Color(255, 90, 80, 255)
local COLOR_OK          = Color(80, 200, 120, 255)
local COLOR_MUTED       = Color(255, 160, 60, 255)

local function openStringRequest(title, text, placeholder, callback, defaultText)
  versus.panel.stringRequest(
    title,
    text,
    defaultText or "",
    callback,
    nil,
    "Confirm",
    "Cancel"
  )
end

do
  --- @class versus_AdminOnlinePlayerRow : EditablePanel
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(56)
    self.isEven = false
    self.playerData = nil
  end

  --- Populate the row with data for one online player.
  function PANEL:SetPlayerData(data, isEven)
    self.playerData = data
    self.isEven = isEven

    local sp = GAMEMODE.SPACING

    self:DockPadding(sp, 0, sp, 0)

    -- Name / info label
    self.nameLabel = vgui.Create("DLabel", self)
    self.nameLabel:Dock(LEFT)
    self.nameLabel:SetWide(220)
    self.nameLabel:SetFont("VersusDefault")
    self.nameLabel:SetTextColor(data.isAdmin and COLOR_WARN or COLOR_TEXT)
    self.nameLabel:SetText(data.name)
    self.nameLabel:SetContentAlignment(4)

    -- Status label (muted / warnings)
    local statusText = ""
    if data.muteRemaining > 0 then
      statusText = string.format("MUTED %dm", math.ceil(data.muteRemaining / 60))
    end
    if data.warnings > 0 then
      local warnStr = string.format("⚠ %d", data.warnings)
      statusText = statusText ~= "" and (statusText .. "  " .. warnStr) or warnStr
    end

    self.statusLabel = vgui.Create("DLabel", self)
    self.statusLabel:Dock(LEFT)
    self.statusLabel:SetWide(120)
    self.statusLabel:SetFont("VersusDefault")
    self.statusLabel:SetTextColor(data.muteRemaining > 0 and COLOR_MUTED or COLOR_DIM)
    self.statusLabel:SetText(statusText)
    self.statusLabel:SetContentAlignment(4)

    -- Action buttons (right side)
    local btnPanel = vgui.Create("EditablePanel", self)
    btnPanel:Dock(FILL)
    btnPanel:DockPadding(0, 8, 0, 8)

    -- Spectate
    local btnSpectate = btnPanel:Add("versus_Button")
    btnSpectate:SetText("Spectate")
    btnSpectate:SizeToContents()
    btnSpectate:Dock(RIGHT)
    btnSpectate:DockMargin(4, 0, 0, 0)
    btnSpectate.DoClick = function()
      net.Start("versus.admin.spectate")
      net.WriteString(data.steamID64)
      net.SendToServer()
    end

    -- Warn
    local btnWarn = btnPanel:Add("versus_Button")
    btnWarn:SetText("Warn")
    btnWarn:SizeToContents()
    btnWarn:Dock(RIGHT)
    btnWarn:DockMargin(4, 0, 0, 0)
    btnWarn.DoClick = function()
      openStringRequest(
        "Warn Player",
        "Reason for warning " .. data.name .. ":",
        "Reason...",
        function(reason)
          if reason == "" then return end
          net.Start("versus.admin.warn")
          net.WriteString(data.steamID64)
          net.WriteString(reason)
          net.SendToServer()
        end
      )
    end

    -- Mute / Unmute toggle
    if data.muteRemaining > 0 then
      local btnUnmute = btnPanel:Add("versus_Button")
      btnUnmute:SetText("Unmute")
      btnUnmute:SizeToContents()
      btnUnmute:Dock(RIGHT)
      btnUnmute:DockMargin(4, 0, 0, 0)
      btnUnmute.DoClick = function()
        net.Start("versus.admin.unmute")
        net.WriteString(data.steamID64)
        net.SendToServer()
      end
    else
      local btnMute = btnPanel:Add("versus_Button")
      btnMute:SetText("Mute")
      btnMute:SizeToContents()
      btnMute:Dock(RIGHT)
      btnMute:DockMargin(4, 0, 0, 0)
      btnMute.DoClick = function()
        openStringRequest(
          "Mute Player",
          "Duration in minutes for muting " .. data.name .. ":",
          "Minutes (e.g. 30)...",
          function(durationStr)
            local duration = tonumber(durationStr)
            if not duration or duration <= 0 then return end

            openStringRequest(
              "Mute Reason",
              "Reason for muting " .. data.name .. ":",
              "Reason...",
              function(reason)
                if reason == "" then return end
                net.Start("versus.admin.mute")
                net.WriteString(data.steamID64)
                net.WriteUInt(math.floor(duration), 16)
                net.WriteString(reason)
                net.SendToServer()
              end
            )
          end
        )
      end
    end

    -- Ban
    local btnBan = btnPanel:Add("versus_Button")
    btnBan:SetText("Ban")
    btnBan:SizeToContents()
    btnBan:Dock(RIGHT)
    btnBan:DockMargin(4, 0, 0, 0)
    btnBan.DoClick = function()
      openStringRequest(
        "Ban Player",
        "Ban duration in seconds for " .. data.name .. " (e.g. 86400 = 1 day):",
        "Seconds (e.g. 86400)...",
        function(durationStr)
          local duration = tonumber(durationStr)
          if not duration or duration <= 0 then return end

          openStringRequest(
            "Ban Reason",
            "Reason for banning " .. data.name .. ":",
            "Reason...",
            function(reason)
              if reason == "" then return end
              net.Start("versus.admin.ban")
              net.WriteString(data.steamID64)
              net.WriteUInt(math.floor(duration), 32)
              net.WriteString(reason)
              net.SendToServer()
            end
          )
        end
      )
    end

    -- Kick
    local btnKick = btnPanel:Add("versus_Button")
    btnKick:SetText("Kick")
    btnKick:SizeToContents()
    btnKick:Dock(RIGHT)
    btnKick:DockMargin(4, 0, 0, 0)
    btnKick.DoClick = function()
      openStringRequest(
        "Kick Player",
        "Reason for kicking " .. data.name .. ":",
        "Reason...",
        function(reason)
          if reason == "" then return end
          net.Start("versus.admin.kick")
          net.WriteString(data.steamID64)
          net.WriteString(reason)
          net.SendToServer()
        end
      )
    end
  end

  function PANEL:Paint(w, h)
    local bg = self.isEven and COLOR_BG_ROW_EVEN or COLOR_BG_ROW_ODD
    draw.RoundedBox(4, 0, 0, w, h, bg)
  end

  vgui.Register("versus_AdminOnlinePlayerRow", PANEL, "EditablePanel")
end

do
  --- @class versus_AdminBannedPlayerRow : EditablePanel
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(52)
    self.isEven = false
  end

  function PANEL:SetBanData(data, isEven)
    self.banData = data
    self.isEven = isEven

    local sp = GAMEMODE.SPACING

    self:DockPadding(sp, 0, sp, 0)

    -- Steam ID label
    self.steamLabel = vgui.Create("DLabel", self)
    self.steamLabel:Dock(LEFT)
    self.steamLabel:SetWide(180)
    self.steamLabel:SetFont("VersusDefault")
    self.steamLabel:SetTextColor(COLOR_TEXT)
    self.steamLabel:SetText(data.steamID64)
    self.steamLabel:SetContentAlignment(4)

    -- Expiry label
    local expiryText = data.expiresAt
        and os.date("Expires: %Y-%m-%d %H:%M", data.expiresAt)
        or "Permanent"

    self.expiryLabel = vgui.Create("DLabel", self)
    self.expiryLabel:Dock(LEFT)
    self.expiryLabel:SetWide(200)
    self.expiryLabel:SetFont("VersusDefault")
    self.expiryLabel:SetTextColor(COLOR_DIM)
    self.expiryLabel:SetText(expiryText)
    self.expiryLabel:SetContentAlignment(4)

    -- Reason label
    self.reasonLabel = vgui.Create("DLabel", self)
    self.reasonLabel:Dock(FILL)
    self.reasonLabel:SetFont("VersusDefault")
    self.reasonLabel:SetTextColor(COLOR_DANGER)
    self.reasonLabel:SetText(data.reason or "")
    self.reasonLabel:SetContentAlignment(4)

    -- Unban button
    local btnPanel = vgui.Create("EditablePanel", self)
    btnPanel:Dock(RIGHT)
    btnPanel:SetWide(100)
    btnPanel:DockPadding(0, 8, 0, 8)

    local btnUnban = btnPanel:Add("versus_Button")
    btnUnban:SetText("Unban")
    btnUnban:Dock(FILL)
    btnUnban.DoClick = function()
      local query = vgui.Create("versus_Query")
      query:SetTitle("Unban Player")
      query:SetText("Unban " .. data.steamID64 .. "?")
      query:AddButtons(
        "Unban", function()
          net.Start("versus.admin.unban")
          net.WriteString(data.steamID64)
          net.SendToServer()
        end,
        "Cancel", function() end
      )
    end
  end

  function PANEL:Paint(w, h)
    local bg = self.isEven and COLOR_BG_ROW_EVEN or COLOR_BG_ROW_ODD
    draw.RoundedBox(4, 0, 0, w, h, bg)
  end

  vgui.Register("versus_AdminBannedPlayerRow", PANEL, "EditablePanel")
end

do
  --- @class versus_AdminPanel : EditablePanel
  local PANEL = {}

  function PANEL:Init()
    versus.admin.adminPanel = self

    self:DockPadding(0, GAMEMODE.SPACING * .5, 0, GAMEMODE.SPACING)

    -- Tab panel
    self.tabPanel = vgui.Create("versus_TabPanel", self)
    self.tabPanel:Dock(FILL)

    -- Online Players tab
    self.onlinePanel = vgui.Create("EditablePanel", self.tabPanel)
    self.tabPanel:AddTab("Online Players", self.onlinePanel)

    -- Banned Players tab
    self.bannedPanel = vgui.Create("EditablePanel", self.tabPanel)
    self.tabPanel:AddTab("Banned Players", self.bannedPanel)

    self:BuildOnlineTab()
    self:BuildBannedTab()
  end

  function PANEL:OnMenuShown()
    self:RefreshOnlinePlayers()
    self:RefreshBannedPlayers()
  end

  function PANEL:BuildOnlineTab()
    local sp = GAMEMODE.SPACING

    -- Top bar: title + stop spectating + refresh
    local topBar = self.onlinePanel:Add("EditablePanel")
    topBar:SetTall(36)
    topBar:Dock(TOP)
    topBar:DockMargin(0, 0, 0, sp)

    local titleLabel = topBar:Add("DLabel")
    titleLabel:SetFont("VersusHeading2")
    titleLabel:SetTextColor(COLOR_TEXT)
    titleLabel:SetText("Online Players")
    titleLabel:SizeToContents()
    titleLabel:Dock(LEFT)

    local btnStopSpectate = topBar:Add("versus_Button")
    btnStopSpectate:SetText("Stop Spectating")
    btnStopSpectate:SizeToContents()
    btnStopSpectate:Dock(RIGHT)
    btnStopSpectate.DoClick = function()
      net.Start("versus.admin.stopSpectating")
      net.SendToServer()
    end

    local btnRefresh = topBar:Add("versus_Button")
    btnRefresh:SetText("Refresh")
    btnRefresh:SizeToContents()
    btnRefresh:Dock(RIGHT)
    btnRefresh:DockMargin(0, 0, sp, 0)
    btnRefresh.DoClick = function()
      self:RefreshOnlinePlayers()
    end

    -- Scroll panel for player rows
    self.onlineScroll = self.onlinePanel:Add("versus_ScrollPanel")
    self.onlineScroll:Dock(FILL)

    self.onlineLoadingLabel = self.onlineScroll:Add("DLabel")
    self.onlineLoadingLabel:SetFont("VersusDefault")
    self.onlineLoadingLabel:SetTextColor(COLOR_DIM)
    self.onlineLoadingLabel:SetText("Loading online players...")
    self.onlineLoadingLabel:SetContentAlignment(5)
    self.onlineLoadingLabel:Dock(FILL)
  end

  function PANEL:RefreshOnlinePlayers()
    net.Start("versus.admin.requestOnlinePlayers")
    net.SendToServer()
  end

  function PANEL:DisplayOnlinePlayers(players)
    self.onlineScroll:Clear()

    if #players == 0 then
      local emptyLabel = self.onlineScroll:Add("DLabel")
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(COLOR_DIM)
      emptyLabel:SetText("No players online.")
      emptyLabel:SetContentAlignment(5)
      emptyLabel:Dock(FILL)
      return
    end

    local sp = GAMEMODE.SPACING

    for i, data in ipairs(players) do
      local row = self.onlineScroll:Add("versus_AdminOnlinePlayerRow")
      row:SetPlayerData(data, i % 2 == 0)
      row:Dock(TOP)
      row:DockMargin(0, 2, 0, 2)
    end
  end

  function PANEL:BuildBannedTab()
    local sp = GAMEMODE.SPACING

    local topBar = self.bannedPanel:Add("EditablePanel")
    topBar:SetTall(36)
    topBar:Dock(TOP)
    topBar:DockMargin(0, 0, 0, sp)

    local titleLabel = topBar:Add("DLabel")
    titleLabel:SetFont("VersusHeading2")
    titleLabel:SetTextColor(COLOR_TEXT)
    titleLabel:SetText("Banned Players")
    titleLabel:SizeToContents()
    titleLabel:Dock(LEFT)

    local btnRefresh = topBar:Add("versus_Button")
    btnRefresh:SetText("Refresh")
    btnRefresh:SizeToContents()
    btnRefresh:Dock(RIGHT)
    btnRefresh.DoClick = function()
      self:RefreshBannedPlayers()
    end

    self.bannedScroll = self.bannedPanel:Add("versus_ScrollPanel")
    self.bannedScroll:Dock(FILL)

    self.bannedLoadingLabel = self.bannedScroll:Add("DLabel")
    self.bannedLoadingLabel:SetFont("VersusDefault")
    self.bannedLoadingLabel:SetTextColor(COLOR_DIM)
    self.bannedLoadingLabel:SetText("Loading banned players...")
    self.bannedLoadingLabel:SetContentAlignment(5)
    self.bannedLoadingLabel:Dock(FILL)
  end

  function PANEL:RefreshBannedPlayers()
    net.Start("versus.admin.requestBannedPlayers")
    net.SendToServer()
  end

  function PANEL:DisplayBannedPlayers(bans)
    self.bannedScroll:Clear()

    if #bans == 0 then
      local emptyLabel = self.bannedScroll:Add("DLabel")
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(COLOR_OK)
      emptyLabel:SetText("No players are currently banned.")
      emptyLabel:SetContentAlignment(5)
      emptyLabel:Dock(FILL)
      return
    end

    for i, data in ipairs(bans) do
      local row = self.bannedScroll:Add("versus_AdminBannedPlayerRow")
      row:SetBanData(data, i % 2 == 0)
      row:Dock(TOP)
      row:DockMargin(0, 2, 0, 2)
    end
  end

  vgui.Register("versus_AdminPanel", PANEL, "EditablePanel")
end
