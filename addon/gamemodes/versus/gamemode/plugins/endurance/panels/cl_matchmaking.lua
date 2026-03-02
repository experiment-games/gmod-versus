local PLUGIN = PLUGIN

--[[
  Matchmaking panel
--]]

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

    self.bgAlpha      = 0
    self.contentAlpha = 0
    self.animStart    = CurTime()
    self.animDuration = 0.4

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    self.contentPanel = vgui.Create("DSizeToContents", self)
    self.contentPanel:SetSizeX(false)

    -- Title
    self.titleLabel = vgui.Create("DLabel", self.contentPanel)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("Endurance Matchmaking")
    self.titleLabel:SetContentAlignment(5)
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Description
    self.descLabel = vgui.Create("DLabel", self.contentPanel)
    self.descLabel:SetFont("VersusDefault")
    self.descLabel:SetTextColor(Color(180, 190, 200, 255))
    self.descLabel:SetText(
      "Form a squad of " .. PLUGIN.SQUAD_MIN_SIZE .. "–" .. PLUGIN.SQUAD_MAX_SIZE ..
      " players and hold out against endless waves of enemies."
    )
    self.descLabel:SetWrap(true)
    self.descLabel:SetAutoStretchVertical(true)
    self.descLabel:Dock(TOP)
    self.descLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Member list
    self.memberList = vgui.Create("DSizeToContents", self.contentPanel)
    self.memberList:Dock(TOP)
    self.memberList:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.memberList:SetSizeX(false)

    -- Invite area
    self.inviteEntry = vgui.Create("versus_TextEntry", self.contentPanel)
    self.inviteEntry:SetPlaceholderText("Enter a player's name or Steam ID to invite…")
    self.inviteEntry:Dock(TOP)
    self.inviteEntry:DockMargin(0, 0, 0, GAMEMODE.SPACING / 2)

    self.inviteButton = vgui.Create("versus_Button", self.contentPanel)
    self.inviteButton:SetText("INVITE PLAYER")
    self.inviteButton:SetType("secondary")
    self.inviteButton:Dock(TOP)
    self.inviteButton:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.inviteButton.DoClick = function()
      self:DoInvite()
    end

    -- Action buttons
    self.readyButton = vgui.Create("versus_Button", self.contentPanel)
    self.readyButton:SetText("READY UP")
    self.readyButton:SetType("primary")
    self.readyButton:Dock(TOP)
    self.readyButton:DockMargin(0, 0, 0, GAMEMODE.SPACING / 2)

    self.readyButton.DoClick = function()
      net.Start("versus.endurance.readyUp")
      net.SendToServer()
    end

    self.disbandButton = vgui.Create("versus_Button", self.contentPanel)
    self.disbandButton:SetText("DISBAND SQUAD")
    self.disbandButton:SetType("secondary")
    self.disbandButton:Dock(TOP)
    self.disbandButton:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.disbandButton.DoClick = function()
      net.Start("versus.endurance.disbandSquad")
      net.SendToServer()
      self:Close()
    end

    self.closeButton = vgui.Create("versus_Button", self.contentPanel)
    self.closeButton:SetText("CLOSE")
    self.closeButton:SetType("secondary")
    self.closeButton:Dock(TOP)

    self.closeButton.DoClick = function()
      self:Close()
    end

    self:RebuildMemberList()
  end

  function PANEL:RebuildMemberList()
    self.memberList:Clear()

    if not PLUGIN.squadState then
      local noSquadLabel = vgui.Create("DLabel", self.memberList)
      noSquadLabel:SetFont("VersusDefault")
      noSquadLabel:SetTextColor(Color(160, 170, 180, 255))
      noSquadLabel:SetText("You are not in a squad yet.")
      noSquadLabel:SizeToContents()
      noSquadLabel:Dock(TOP)
      return
    end

    local headerLabel = vgui.Create("DLabel", self.memberList)
    headerLabel:SetFont("VersusHeading3")
    headerLabel:SetTextColor(Color(200, 210, 220, 255))
    headerLabel:SetText("Squad Members")
    headerLabel:SizeToContents()
    headerLabel:Dock(TOP)
    headerLabel:DockMargin(0, 0, 0, 4)

    for _, member in ipairs(PLUGIN.squadState.members) do
      local row = vgui.Create("DPanel", self.memberList)
      row:SetTall(30)
      row:Dock(TOP)
      row:DockMargin(0, 2, 0, 0)
      row.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 45, 52, 200))
      end

      local nameLabel = vgui.Create("DLabel", row)
      nameLabel:SetFont("VersusDefault")
      nameLabel:SetTextColor(Color(220, 230, 240, 255))
      nameLabel:SetText((member.isReady and "✓ " or "○ ") .. member.name)
      nameLabel:SizeToContents()
      nameLabel:SetPos(8, (30 - nameLabel:GetTall()) / 2)
    end

    if PLUGIN.squadState.pendingInviteCount and PLUGIN.squadState.pendingInviteCount > 0 then
      local pendingLabel = vgui.Create("DLabel", self.memberList)
      pendingLabel:SetFont("VersusDefault")
      pendingLabel:SetTextColor(Color(180, 160, 100, 255))
      pendingLabel:SetText(PLUGIN.squadState.pendingInviteCount .. " pending invite(s)")
      pendingLabel:SizeToContents()
      pendingLabel:Dock(TOP)
      pendingLabel:DockMargin(0, 4, 0, 0)
    end
  end

  function PANEL:DoInvite()
    local text = self.inviteEntry:GetValue():Trim()

    if text == "" then return end

    -- Try to find the player by name first, then by steam ID.
    local target = nil

    for _, ply in ipairs(player.GetAll()) do
      if ply:Nick():lower() == text:lower() or ply:SteamID64() == text then
        target = ply
        break
      end
    end

    if not IsValid(target) then
      -- Send the raw string; server will resolve it.
      net.Start("versus.endurance.invitePlayer")
      net.WriteString(text)
      net.SendToServer()
    else
      net.Start("versus.endurance.invitePlayer")
      net.WriteString(target:SteamID64())
      net.SendToServer()
    end

    self.inviteEntry:SetValue("")
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing    = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if not self.closing then
      if elapsed < self.animDuration then
        local progress    = math.ease.InOutQuad(elapsed / self.animDuration)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha      = 200
        self.contentAlpha = 255
      end
    else
      local closeElapsed = CurTime() - self.closeStart

      if closeElapsed < 0.3 then
        local progress    = 1 - (closeElapsed / 0.3)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self:Remove()
      end
    end

    self:SetAlpha(self.contentAlpha)

    -- Rebuild the member list whenever the squad state changes.
    if self._lastSquadState ~= PLUGIN.squadState then
      self._lastSquadState = PLUGIN.squadState
      self:RebuildMemberList()
    end
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)

    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self.contentPanel:SetWide(self:GetWide() - GAMEMODE.SPACING * 2)
    self.contentPanel:Center()

    self:Center()
  end

  vgui.Register("versus_EnduranceMatchmakingPanel", PANEL, "EditablePanel")
end

--[[
  Invite notification panel
--]]

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(340, 80)
    self:ParentToHUD()

    self.bgAlpha      = 0
    self.animStart    = CurTime()

    self.messageLabel = vgui.Create("DLabel", self)
    self.messageLabel:SetFont("VersusDefault")
    self.messageLabel:SetTextColor(Color(220, 230, 240, 255))
    self.messageLabel:SetWrap(true)
    self.messageLabel:SetAutoStretchVertical(true)
    self.messageLabel:SetPos(8, 8)
    self.messageLabel:SetWide(self:GetWide() - 16)

    self.acceptButton = vgui.Create("versus_Button", self)
    self.acceptButton:SetText("ACCEPT")
    self.acceptButton:SetType("primary")
    self.acceptButton:SetSize(100, 28)

    self.declineButton = vgui.Create("versus_Button", self)
    self.declineButton:SetText("DECLINE")
    self.declineButton:SetType("secondary")
    self.declineButton:SetSize(100, 28)
  end

  function PANEL:SetInviteData(leaderSteamID, leaderName)
    self.leaderSteamID = leaderSteamID
    self.messageLabel:SetText(leaderName .. " has invited you to an Endurance squad!")
    self.messageLabel:SizeToContents()

    local newHeight = math.max(80, self.messageLabel:GetTall() + 50)
    self:SetTall(newHeight)

    self.acceptButton:SetPos(8, newHeight - 36)
    self.declineButton:SetPos(116, newHeight - 36)

    self.acceptButton.DoClick = function()
      net.Start("versus.endurance.acceptInvite")
      net.WriteString(leaderSteamID)
      net.SendToServer()
      self:Remove()
      table.RemoveByValue(PLUGIN.pendingInvites, leaderSteamID)
    end

    self.declineButton.DoClick = function()
      net.Start("versus.endurance.declineInvite")
      net.WriteString(leaderSteamID)
      net.SendToServer()
      self:Remove()
      table.RemoveByValue(PLUGIN.pendingInvites, leaderSteamID)
    end

    -- Position in the top-right corner.
    self:SetPos(ScrW() - self:GetWide() - 16, 16 + 96 * #PLUGIN.pendingInvites)
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if elapsed < 0.4 then
      self.bgAlpha = 200 * math.ease.InOutQuad(elapsed / 0.4)
    else
      self.bgAlpha = 200
    end
  end

  function PANEL:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, Color(25, 30, 38, self.bgAlpha))
    draw.RoundedBoxEx(8, 0, 0, 4, h, Color(90, 160, 240, self.bgAlpha), true, false, true, false)
  end

  vgui.Register("versus_EnduranceInviteNotification", PANEL, "EditablePanel")
end
