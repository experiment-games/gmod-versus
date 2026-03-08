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
    self.titleLabel:SetText("HOUSING")
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
    hook.Run("BuildHousingMenuTabs", tabBuilder, PLUGIN.currentInsideHousing)

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

  local color_text = Color(220, 230, 240, 255)
  local color_dim = Color(140, 155, 170, 255)
  local color_warn = Color(220, 180, 60, 255)

  function PANEL:Init()
    local spacing = GAMEMODE.SPACING

    -- Notification bar for incoming room invites (hidden by default)
    self.notifBar = vgui.Create("EditablePanel", self)
    self.notifBar:Dock(TOP)
    self.notifBar:SetTall(48)
    self.notifBar:DockMargin(0, 0, 0, spacing)
    self.notifBar:SetVisible(false)
    self.notifBar._ownerSteamID = nil
    self.notifBar.Paint = function(pnl, w, h)
      surface.SetDrawColor(80, 140, 220, 255)
      surface.DrawRect(0, 0, 3, h)
      surface.SetDrawColor(25, 36, 52, 200)
      surface.DrawRect(3, 0, w - 3, h)
    end

    self.notifLabel = vgui.Create("DLabel", self.notifBar)
    self.notifLabel:SetFont("VersusDefault")
    self.notifLabel:SetTextColor(color_warn)
    self.notifLabel:SetText("")
    self.notifLabel:Dock(FILL)
    self.notifLabel:DockMargin(12, 0, 8, 0)
    self.notifLabel:SetContentAlignment(4)

    self.notifDeclineBtn = vgui.Create("versus_Button", self.notifBar)
    self.notifDeclineBtn:SetText("DECLINE")
    self.notifDeclineBtn:SetType("secondary")
    self.notifDeclineBtn:Dock(RIGHT)
    self.notifDeclineBtn:SizeToContents()
    self.notifDeclineBtn:DockMargin(4, 6, 0, 6)
    self.notifDeclineBtn.DoClick = function()
      if self.notifBar._ownerSteamID then
        net.Start("versus.housing.respondToRoomInvite")
        net.WriteString(self.notifBar._ownerSteamID)
        net.WriteBool(false)
        net.SendToServer()
        self:RemovePendingInvite(self.notifBar._ownerSteamID)
      end
      self:ShowNextInvite()
    end

    self.notifAcceptBtn = vgui.Create("versus_Button", self.notifBar)
    self.notifAcceptBtn:SetText("ACCEPT")
    self.notifAcceptBtn:SetType("primary")
    self.notifAcceptBtn:Dock(RIGHT)
    self.notifAcceptBtn:SizeToContents()
    self.notifAcceptBtn:DockMargin(0, 6, 4, 6)
    self.notifAcceptBtn.DoClick = function()
      if self.notifBar._ownerSteamID then
        net.Start("versus.housing.respondToRoomInvite")
        net.WriteString(self.notifBar._ownerSteamID)
        net.WriteBool(true)
        net.SendToServer()
        self:RemovePendingInvite(self.notifBar._ownerSteamID)
      end
      self:ShowNextInvite()
    end

    -- Content area
    if not PLUGIN.currentInsideHousing then
      self:BuildOutsideView(spacing)
    elseif PLUGIN.currentRoomIsOwner then
      self:BuildOwnerView(spacing)
    else
      self:BuildVisitorView(spacing)
    end

    PLUGIN.housingOverviewPanel = self

    -- Surface any invite that arrived before this panel was created
    self:ShowNextInvite()
  end

  function PANEL:BuildOutsideView(spacing)
    local headerLabel = vgui.Create("DLabel", self)
    headerLabel:SetFont("VersusHeading3")
    headerLabel:SetTextColor(Color(200, 210, 220, 255))
    headerLabel:SetText("Pending Room Invites")
    headerLabel:SizeToContents()
    headerLabel:Dock(TOP)
    headerLabel:DockMargin(0, 0, 0, spacing * 0.5)

    self.inviteList = vgui.Create("versus_ScrollPanel", self)
    self.inviteList:Dock(FILL)

    self:RebuildInviteList()
  end

  function PANEL:RebuildInviteList()
    if not IsValid(self.inviteList) then return end
    self.inviteList:Clear()

    local spacing = GAMEMODE.SPACING

    if #PLUGIN.pendingRoomInvites == 0 then
      local emptyLbl = vgui.Create("DLabel", self.inviteList)
      emptyLbl:SetFont("VersusDefault")
      emptyLbl:SetTextColor(color_dim)
      emptyLbl:SetText("No pending room invites.")
      emptyLbl:SizeToContents()
      emptyLbl:Dock(TOP)
      emptyLbl:DockMargin(spacing, spacing, spacing, 0)
      return
    end

    for _, invite in ipairs(PLUGIN.pendingRoomInvites) do
      local captureSID  = invite.steamID
      local captureName = invite.name

      local row         = vgui.Create("EditablePanel", self.inviteList)
      row:SetTall(48)
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, 4)
      row.Paint = function(_, w, h)
        surface.SetDrawColor(80, 140, 220, 255)
        surface.DrawRect(0, 0, 3, h)
        surface.SetDrawColor(25, 36, 52, 200)
        surface.DrawRect(3, 0, w - 3, h)
      end

      local declineBtn = vgui.Create("versus_Button", row)
      declineBtn:SetText("DECLINE")
      declineBtn:SetType("secondary")
      declineBtn:SizeToContents()
      declineBtn:SetTall(36)
      declineBtn:Dock(RIGHT)
      declineBtn:DockMargin(4, 6, spacing * 0.5, 6)
      declineBtn.DoClick = function()
        net.Start("versus.housing.respondToRoomInvite")
        net.WriteString(captureSID)
        net.WriteBool(false)
        net.SendToServer()
        self:RemovePendingInvite(captureSID)
        self:RebuildInviteList()
      end

      local acceptBtn = vgui.Create("versus_Button", row)
      acceptBtn:SetText("ACCEPT")
      acceptBtn:SetType("primary")
      acceptBtn:SizeToContents()
      acceptBtn:SetTall(36)
      acceptBtn:Dock(RIGHT)
      acceptBtn:DockMargin(0, 6, 4, 6)
      acceptBtn.DoClick = function()
        net.Start("versus.housing.respondToRoomInvite")
        net.WriteString(captureSID)
        net.WriteBool(true)
        net.SendToServer()
        self:RemovePendingInvite(captureSID)
        self:RebuildInviteList()
      end

      local nameLbl = vgui.Create("DLabel", row)
      nameLbl:SetFont("VersusDefault")
      nameLbl:SetTextColor(color_text)
      nameLbl:SetText(captureName .. " invited you to their room")
      nameLbl:Dock(FILL)
      nameLbl:DockMargin(spacing, 0, spacing * 0.5, 0)
      nameLbl:SetContentAlignment(4)
    end
  end

  function PANEL:BuildOwnerView(spacing)
    local headerLabel = vgui.Create("DLabel", self)
    headerLabel:SetFont("VersusHeading3")
    headerLabel:SetTextColor(Color(200, 210, 220, 255))
    headerLabel:SetText("Invite Players")
    headerLabel:SizeToContents()
    headerLabel:Dock(TOP)
    headerLabel:DockMargin(0, 0, 0, spacing * 0.5)

    self.inviteEntry = vgui.Create("versus_TextEntry", self)
    self.inviteEntry:SetPlaceholderText("Filter players…")
    self.inviteEntry:Dock(TOP)
    self.inviteEntry:DockMargin(0, 0, 0, spacing * 0.5)
    self.inviteEntry:SetTabbingDisabled(true)
    self.inviteEntry:SetUpdateOnType(true)
    self.inviteEntry.OnValueChange = function(_, value)
      self:RebuildPlayerList(value)
    end

    self.playerList = vgui.Create("versus_ScrollPanel", self)
    self.playerList:Dock(FILL)

    self:RebuildPlayerList("")
  end

  function PANEL:BuildVisitorView(spacing)
    local ownerLabel = vgui.Create("DLabel", self)
    ownerLabel:SetFont("VersusDefault")
    ownerLabel:SetTextColor(color_dim)
    ownerLabel:SetText(
      PLUGIN.currentRoomOwnerName ~= "" and
      ("You are visiting " .. PLUGIN.currentRoomOwnerName .. "'s room.") or
      "You are visiting someone's room."
    )
    ownerLabel:SetWrap(true)
    ownerLabel:SetAutoStretchVertical(true)
    ownerLabel:Dock(TOP)
    ownerLabel:DockMargin(0, 0, 0, spacing)
  end

  function PANEL:RebuildPlayerList(filter)
    self.playerList:Clear()
    filter = (filter or ""):lower():Trim()

    local localID = LocalPlayer():SteamID64()
    local anyShown = false
    local spacing = GAMEMODE.SPACING

    for _, ply in ipairs(player.GetAll()) do
      if not IsValid(ply) then continue end
      local sid = ply:SteamID64()
      if sid == localID then continue end

      local name = ply:Nick()
      if filter ~= "" and not name:lower():find(filter, 1, true) then continue end

      anyShown = true

      local row = vgui.Create("EditablePanel", self.playerList)
      row:SetTall(36)
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, 2)
      row.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(25, 36, 52, 200))
      end

      local invBtn = vgui.Create("versus_Button", row)
      invBtn:SetText("INVITE")
      invBtn:SetType("secondary")
      invBtn:SizeToContents()
      invBtn:SetWide(invBtn:GetWide() * 0.75)
      invBtn:SetTall(28)
      invBtn:Dock(RIGHT)
      invBtn:DockMargin(0, 4, spacing * 0.5, 4)
      local captureSID = sid
      invBtn.DoClick = function()
        net.Start("versus.housing.inviteToRoom")
        net.WriteString(captureSID)
        net.SendToServer()
      end

      local nameLbl = vgui.Create("DLabel", row)
      nameLbl:SetFont("VersusDefault")
      nameLbl:SetTextColor(color_text)
      nameLbl:SetText(name)
      nameLbl:Dock(FILL)
      nameLbl:DockMargin(spacing, 0, spacing * 0.5, 0)
      nameLbl:SetContentAlignment(4)
    end

    if not anyShown then
      local emptyLbl = vgui.Create("DLabel", self.playerList)
      emptyLbl:SetFont("VersusDefault")
      emptyLbl:SetTextColor(color_dim)
      emptyLbl:SetText(filter ~= "" and "No matching players." or "No other players online.")
      emptyLbl:SizeToContents()
      emptyLbl:Dock(TOP)
      emptyLbl:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, 0)
    end
  end

  function PANEL:ShowInvite(ownerSteamID, ownerName)
    if not PLUGIN.currentInsideHousing then
      -- Outside housing: invites are shown in the list directly
      self:RebuildInviteList()
      return
    end

    self.notifBar._ownerSteamID = ownerSteamID
    self.notifLabel:SetText(ownerName .. " has invited you to their room")
    self.notifBar:SetVisible(true)
  end

  function PANEL:ShowNextInvite()
    if not PLUGIN.currentInsideHousing then
      self:RebuildInviteList()
      return
    end

    if #PLUGIN.pendingRoomInvites == 0 then
      self.notifBar:SetVisible(false)
      return
    end

    local invite = table.remove(PLUGIN.pendingRoomInvites, 1)
    self:ShowInvite(invite.steamID, invite.name)
  end

  function PANEL:RemovePendingInvite(steamID)
    for i, inv in ipairs(PLUGIN.pendingRoomInvites) do
      if inv.steamID == steamID then
        table.remove(PLUGIN.pendingRoomInvites, i)
        return
      end
    end
  end

  function PANEL:Think()
    -- Periodically refresh the player list so it stays current
    if PLUGIN.currentInsideHousing and PLUGIN.currentRoomIsOwner and IsValid(self.playerList) then
      if not self._nextPlayerListRefresh or CurTime() > self._nextPlayerListRefresh then
        self._nextPlayerListRefresh = CurTime() + 3
        self:RebuildPlayerList(IsValid(self.inviteEntry) and self.inviteEntry:GetValue() or "")
      end
    end
  end

  function PANEL:OnRemove()
    if PLUGIN.housingOverviewPanel == self then
      PLUGIN.housingOverviewPanel = nil
    end
  end

  vgui.Register("versus_HousingOverview", PANEL, "EditablePanel")
end
