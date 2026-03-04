local PLUGIN         = PLUGIN

local color_text     = Color(220, 230, 240, 255)
local color_dim      = Color(140, 155, 170, 255)
local color_accent   = Color(80, 140, 220, 255)
local color_row_even = Color(25, 36, 52, 200)
local color_row_odd  = Color(20, 28, 40, 200)
local color_success  = Color(80, 200, 120, 255)
local color_warn     = Color(220, 180, 60, 255)

--[[
  Matchmaking panel (tab-embedded, no popup)
--]]

do
  local PANEL = {}

  function PANEL:Init()
    local spacing = GAMEMODE.SPACING

    -- Invite notification bar (hidden until an invite arrives)
    self.notifBar = vgui.Create("EditablePanel", self)
    self.notifBar:Dock(TOP)
    self.notifBar:SetTall(48)
    self.notifBar:DockMargin(0, 0, 0, spacing)
    self.notifBar:SetVisible(false)
    self.notifBar._inviteLeader = nil
    self.notifBar.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(55, 44, 15, 230))
      surface.SetDrawColor(color_warn.r, color_warn.g, color_warn.b, 220)
      surface.DrawRect(0, 0, 3, h)
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
      if not self.notifBar._inviteLeader then return end
      net.Start("versus.endurance.declineInvite")
      net.WriteString(self.notifBar._inviteLeader)
      net.SendToServer()
      table.RemoveByValue(PLUGIN.pendingInvites, self.notifBar._inviteLeader)
      self:ShowNextInvite()
    end

    self.notifAcceptBtn = vgui.Create("versus_Button", self.notifBar)
    self.notifAcceptBtn:SetText("ACCEPT")
    self.notifAcceptBtn:SetType("primary")
    self.notifAcceptBtn:Dock(RIGHT)
    self.notifAcceptBtn:SizeToContents()
    self.notifAcceptBtn:DockMargin(0, 6, 4, 6)
    self.notifAcceptBtn.DoClick = function()
      if not self.notifBar._inviteLeader then return end
      net.Start("versus.endurance.acceptInvite")
      net.WriteString(self.notifBar._inviteLeader)
      net.SendToServer()
      table.RemoveByValue(PLUGIN.pendingInvites, self.notifBar._inviteLeader)
      self:ShowNextInvite()
    end

    -- Main two-column area
    -- Right column is added first so FILL takes the remainder correctly.
    self.mainArea = vgui.Create("EditablePanel", self)
    self.mainArea:Dock(FILL)
    self.mainArea.Paint = function() end

    self.rightCol = vgui.Create("EditablePanel", self.mainArea)
    self.rightCol:Dock(RIGHT)
    self.rightCol:SetWide(280)
    self.rightCol.Paint = function() end

    self.leftCol = vgui.Create("EditablePanel", self.mainArea)
    self.leftCol:Dock(FILL)
    self.leftCol:DockMargin(0, 0, spacing, 0)
    self.leftCol.Paint = function() end

    -- Left column: squad member list
    self.squadHeaderLabel = vgui.Create("DLabel", self.leftCol)
    self.squadHeaderLabel:SetFont("VersusHeading3")
    self.squadHeaderLabel:SetTextColor(Color(200, 210, 220, 255))
    self.squadHeaderLabel:SetText("Squad Members")
    self.squadHeaderLabel:SizeToContents()
    self.squadHeaderLabel:Dock(TOP)
    self.squadHeaderLabel:DockMargin(0, 0, 0, spacing * 0.5)

    self.memberList = vgui.Create("versus_ScrollPanel", self.leftCol)
    self.memberList:Dock(FILL)

    -- Right column: description, invite, actions
    self.descLabel = vgui.Create("DLabel", self.rightCol)
    self.descLabel:SetFont("VersusDefault")
    self.descLabel:SetTextColor(color_dim)
    self.descLabel:SetText(
      "Form a squad of " .. PLUGIN.SQUAD_MIN_SIZE .. "–" .. PLUGIN.SQUAD_MAX_SIZE ..
      " players and hold out against endless waves of enemies."
    )
    self.descLabel:SetWrap(true)
    self.descLabel:SetAutoStretchVertical(true)
    self.descLabel:Dock(TOP)
    self.descLabel:DockMargin(0, 0, 0, spacing)

    self.formButton = vgui.Create("versus_Button", self.rightCol)
    self.formButton:SetText("FORM SQUAD")
    self.formButton:SetType("primary")
    self.formButton:Dock(TOP)
    self.formButton:DockMargin(0, 0, 0, spacing)
    self.formButton.DoClick = function()
      net.Start("versus.endurance.formSquad")
      net.SendToServer()
    end

    self.inviteHeaderLabel = vgui.Create("DLabel", self.rightCol)
    self.inviteHeaderLabel:SetFont("VersusHeading3")
    self.inviteHeaderLabel:SetTextColor(Color(200, 210, 220, 255))
    self.inviteHeaderLabel:SetText("Invite Players")
    self.inviteHeaderLabel:SizeToContents()
    self.inviteHeaderLabel:Dock(TOP)
    self.inviteHeaderLabel:DockMargin(0, 0, 0, spacing * 0.5)

    self.inviteEntry = vgui.Create("versus_TextEntry", self.rightCol)
    self.inviteEntry:SetPlaceholderText("Filter players…")
    self.inviteEntry:Dock(TOP)
    self.inviteEntry:DockMargin(0, 0, 0, spacing * 0.5)
    self.inviteEntry:SetTabbingDisabled(true)
    self.inviteEntry:SetUpdateOnType(true)
    self.inviteEntry.OnValueChange = function(_, value)
      self:RebuildPlayerList(value)
    end

    self.playerList = vgui.Create("versus_ScrollPanel", self.rightCol)
    self.playerList:Dock(TOP)
    self.playerList:SetTall(180)
    self.playerList:DockMargin(0, 0, 0, spacing)

    -- Thin separator
    self.inviteSep = vgui.Create("EditablePanel", self.rightCol)
    self.inviteSep:Dock(TOP)
    self.inviteSep:SetTall(1)
    self.inviteSep:DockMargin(0, 0, 0, spacing)
    self.inviteSep.Paint = function(_, w, h)
      surface.SetDrawColor(35, 48, 65, 255)
      surface.DrawRect(0, 0, w, h)
    end

    self.readyButton = vgui.Create("versus_Button", self.rightCol)
    self.readyButton:SetText("READY UP")
    self.readyButton:SetType("primary")
    self.readyButton:Dock(TOP)
    self.readyButton:DockMargin(0, 0, 0, spacing * 0.5)
    self.readyButton.DoClick = function()
      net.Start("versus.endurance.readyUp")
      net.SendToServer()
    end

    self.disbandButton = vgui.Create("versus_Button", self.rightCol)
    self.disbandButton:SetText("DISBAND SQUAD")
    self.disbandButton:SetType("secondary")
    self.disbandButton:Dock(TOP)
    self.disbandButton.DoClick = function()
      net.Start("versus.endurance.disbandSquad")
      net.SendToServer()
      PLUGIN.squadState = nil
      PLUGIN.pendingInvites = {}
      self:RebuildMemberList()
    end

    self.leaveButton = vgui.Create("versus_Button", self.rightCol)
    self.leaveButton:SetText("LEAVE SQUAD")
    self.leaveButton:SetType("secondary")
    self.leaveButton:Dock(TOP)
    self.leaveButton.DoClick = function()
      net.Start("versus.endurance.leaveSquad")
      net.SendToServer()
      PLUGIN.squadState = nil
      PLUGIN.pendingInvites = {}
      self:RebuildMemberList()
    end

    self:RebuildMemberList()

    PLUGIN.matchmakingPanel = self
  end

  --- Show a pending invite in the notification bar.
  function PANEL:ShowInvite(leaderSteamID, leaderName)
    self.notifBar._inviteLeader = leaderSteamID
    self.notifLabel:SetText(leaderName .. " has invited you to their Endurance squad!")
    self.notifBar:SetVisible(true)
  end

  --- Advance to the next queued invite, or hide the bar if none remain.
  function PANEL:ShowNextInvite()
    if #PLUGIN.pendingInvites > 0 then
      local nextID   = PLUGIN.pendingInvites[1]
      local nextName = nextID

      for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID64() == nextID then
          nextName = ply:Nick()
          break
        end
      end

      self.notifBar._inviteLeader = nextID
      self.notifLabel:SetText(nextName .. " has invited you to their Endurance squad!")
    else
      self.notifBar._inviteLeader = nil
      self.notifBar:SetVisible(false)
    end
  end

  --- Show or hide squad-specific controls depending on whether the local player is in a squad.
  function PANEL:UpdateControlVisibility()
    local inSquad  = PLUGIN.squadState ~= nil
    local isLeader = inSquad and PLUGIN.squadState.leader == LocalPlayer():SteamID64()

    self.formButton:SetVisible(not inSquad)
    self.inviteHeaderLabel:SetVisible(isLeader)
    self.inviteEntry:SetVisible(isLeader)
    self.playerList:SetVisible(isLeader)
    self.inviteSep:SetVisible(inSquad)
    self.readyButton:SetVisible(inSquad)
    self.disbandButton:SetVisible(isLeader)
    self.leaveButton:SetVisible(inSquad and not isLeader)
  end

  --- Re-populate the member list from PLUGIN.squadState.
  function PANEL:RebuildMemberList()
    self.memberList:Clear()

    if not PLUGIN.squadState then
      local lbl = vgui.Create("DLabel", self.memberList)
      lbl:SetFont("VersusDefault")
      lbl:SetTextColor(color_dim)
      lbl:SetText("You are not in a squad yet.")
      lbl:SizeToContents()
      lbl:Dock(TOP)
      lbl:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, 0)
      self:UpdateControlVisibility()
      return
    end

    for i, member in ipairs(PLUGIN.squadState.members) do
      local row = vgui.Create("EditablePanel", self.memberList)
      row:SetTall(36)
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, 4)
      local isEven = i % 2 == 0
      row.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, isEven and color_row_even or color_row_odd)
      end

      -- Ready / not-ready badge (right side)
      local badge = vgui.Create("DLabel", row)
      badge:SetFont("VersusDefault")
      badge:SetTextColor(member.isReady and color_success or color_dim)
      badge:SetText(member.isReady and "READY" or "NOT READY")
      badge:SizeToContents()
      badge:Dock(RIGHT)
      badge:DockMargin(0, 0, GAMEMODE.SPACING, 0)

      local nameLbl = vgui.Create("DLabel", row)
      nameLbl:SetFont("VersusDefault")
      nameLbl:SetTextColor(color_text)
      nameLbl:SetText(member.name)
      nameLbl:Dock(FILL)
      nameLbl:DockMargin(GAMEMODE.SPACING, 0, 0, 0)
      nameLbl:SetContentAlignment(4)
    end

    if PLUGIN.squadState.pendingInviteCount and PLUGIN.squadState.pendingInviteCount > 0 then
      local pendingLbl = vgui.Create("DLabel", self.memberList)
      pendingLbl:SetFont("VersusDefault")
      pendingLbl:SetTextColor(Color(180, 160, 100, 255))
      pendingLbl:SetText(PLUGIN.squadState.pendingInviteCount .. " pending invite(s)…")
      pendingLbl:SizeToContents()
      pendingLbl:Dock(TOP)
      pendingLbl:DockMargin(GAMEMODE.SPACING, 8, GAMEMODE.SPACING, 0)
    end

    self:UpdateControlVisibility()
    self:RebuildPlayerList(IsValid(self.inviteEntry) and self.inviteEntry:GetValue() or "")
  end

  --- Re-populate the online-player list, filtered by an optional search string.
  function PANEL:RebuildPlayerList(filter)
    self.playerList:Clear()
    filter = (filter or ""):lower():Trim()

    local localID = LocalPlayer():SteamID64()
    local memberIDs = {}
    if PLUGIN.squadState then
      for _, member in ipairs(PLUGIN.squadState.members) do
        memberIDs[member.steamID] = true
      end
    end

    local anyShown = false
    for _, ply in ipairs(player.GetAll()) do
      if not IsValid(ply) then continue end
      local sid = ply:SteamID64()
      if sid == localID then continue end
      if memberIDs[sid] then continue end

      local name = ply:Nick()
      if filter ~= "" and not name:lower():find(filter, 1, true) then continue end

      anyShown = true
      local spacing = GAMEMODE.SPACING
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
        self:DoInvite(captureSID)
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

  function PANEL:DoInvite(steamID64)
    net.Start("versus.endurance.invitePlayer")
    net.WriteString(steamID64)
    net.SendToServer()
  end

  function PANEL:Think()
    -- Rebuild the member list whenever squad state changes.
    if self._lastSquadState ~= PLUGIN.squadState then
      self._lastSquadState = PLUGIN.squadState
      self:RebuildMemberList()
    end

    -- Periodically refresh the online player list so it stays current.
    if not self._nextPlayerListRefresh or CurTime() > self._nextPlayerListRefresh then
      self._nextPlayerListRefresh = CurTime() + 3
      if IsValid(self.playerList) and self.playerList:IsVisible() then
        self:RebuildPlayerList(IsValid(self.inviteEntry) and self.inviteEntry:GetValue() or "")
      end
    end
  end

  function PANEL:OnMenuShown()
    self:RebuildMemberList()
    -- Surface any invite that arrived before this panel was visible.
    if #PLUGIN.pendingInvites > 0 and not self.notifBar:IsVisible() then
      self:ShowNextInvite()
    end
  end

  vgui.Register("versus_EnduranceMatchmakingPanel", PANEL, "EditablePanel")
end
