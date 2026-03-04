local PLUGIN = PLUGIN

do
  -- Individual player stats entry panel
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(120)
    self:DockPadding(4, 4, 4, 4)
  end

  function PANEL:SetPlayerStats(playerData, index)
    self.playerData = playerData
    self.index = index

    -- Top row: Player info
    local topRow = self:Add("EditablePanel")
    topRow:SetTall(25)
    topRow:Dock(TOP)

    -- Player name and Steam ID
    self.playerLabel = topRow:Add("DLabel")
    self.playerLabel:SetText(playerData.steam_name .. " (" .. playerData.steam_id .. ")")
    self.playerLabel:SetFont("VersusDefault")
    self.playerLabel:SetTextColor(Color(255, 255, 255))
    self.playerLabel:Dock(LEFT)
    self.playerLabel:SizeToContents()

    -- Suspicion level indicator
    local suspicionLevel = self:CalculateSuspicionLevel(playerData)
    self.suspicionLabel = topRow:Add("DLabel")
    self.suspicionLabel:SetText(suspicionLevel.text)
    self.suspicionLabel:SetFont("VersusSmall")
    self.suspicionLabel:SetTextColor(suspicionLevel.color)
    self.suspicionLabel:SetContentAlignment(6) -- Right align
    self.suspicionLabel:Dock(RIGHT)
    self.suspicionLabel:SizeToContents()

    -- Stats row
    local statsRow = self:Add("EditablePanel")
    statsRow:SetTall(25)
    statsRow:Dock(TOP)
    statsRow:DockMargin(0, 5, 0, 0)

    -- Accuracy
    self.accuracyLabel = statsRow:Add("DLabel")
    local accuracyText = string.format("Accuracy: %.1f%%", playerData.accuracy or 0)
    self.accuracyLabel:SetText(accuracyText)
    self.accuracyLabel:SetFont("VersusDefault")
    self.accuracyLabel:SetTextColor(self:GetAccuracyColor(playerData.accuracy or 0))
    self.accuracyLabel:Dock(LEFT)
    self.accuracyLabel:SizeToContents()

    -- Headshot rate
    self.headshotLabel = statsRow:Add("DLabel")
    local headshotText = string.format("  |  Headshots: %.1f%%", playerData.headshot_rate or 0)
    self.headshotLabel:SetText(headshotText)
    self.headshotLabel:SetFont("VersusDefault")
    self.headshotLabel:SetTextColor(self:GetHeadshotColor(playerData.headshot_rate or 0))
    self.headshotLabel:Dock(LEFT)
    self.headshotLabel:SizeToContents()

    -- K/D Ratio
    self.kdLabel = statsRow:Add("DLabel")
    local kdText = string.format("  |  K/D: %.2f", playerData.kd_ratio or 0)
    self.kdLabel:SetText(kdText)
    self.kdLabel:SetFont("VersusDefault")
    self.kdLabel:SetTextColor(Color(200, 200, 200))
    self.kdLabel:Dock(LEFT)
    self.kdLabel:SizeToContents()

    -- Shots fired
    self.shotsLabel = statsRow:Add("DLabel")
    local shotsText = string.format("Shots: %d", playerData.total_shots or 0)
    self.shotsLabel:SetText(shotsText)
    self.shotsLabel:SetFont("VersusDefault")
    self.shotsLabel:SetTextColor(Color(180, 180, 180))
    self.shotsLabel:SetContentAlignment(6) -- Right align
    self.shotsLabel:Dock(RIGHT)
    self.shotsLabel:SizeToContents()

    -- Button row
    local buttonRow = self:Add("EditablePanel")
    buttonRow:Dock(FILL)
    buttonRow:DockMargin(0, 5, 0, 0)

    -- View details button
    self.detailsButton = buttonRow:Add("versus_Button")
    self.detailsButton:SetText("View Details")
    self.detailsButton:SizeToContents()
    self.detailsButton:Dock(LEFT)
    self.detailsButton.DoClick = function()
      net.Start("versus.hitStatistics.requestPlayerStats")
      net.WriteString(playerData.steam_id)
      net.SendToServer()
    end

    -- Find player button (if online)
    local onlinePlayer = self:FindOnlinePlayer(playerData.steam_id)
    if (onlinePlayer) then
      self.findPlayerButton = buttonRow:Add("versus_Button")
      self.findPlayerButton:SetText("Spectate")
      self.findPlayerButton:SizeToContents()
      self.findPlayerButton:Dock(RIGHT)
      self.findPlayerButton:DockMargin(5, 0, 0, 0)
      self.findPlayerButton.DoClick = function()
        if (IsValid(onlinePlayer)) then
          LocalPlayer():ConCommand("ulx spectate " .. onlinePlayer:Nick())
        else
          LocalPlayer():Notify("Player is no longer online")
        end
      end
    end

    -- Paint background with suspicion-based coloring
    self.Paint = function(pnl, w, h)
      local bgColor = Color(40, 40, 45)

      if (suspicionLevel.level == "HIGH") then
        bgColor = Color(60, 40, 40) -- Red tint
      elseif (suspicionLevel.level == "MEDIUM") then
        bgColor = Color(60, 55, 40) -- Yellow tint
      elseif (suspicionLevel.level == "LOW") then
        bgColor = Color(45, 55, 45) -- Green tint
      end

      draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end
  end

  function PANEL:CalculateSuspicionLevel(playerData)
    local accuracy = playerData.accuracy or 0
    local headshotRate = playerData.headshot_rate or 0
    local totalShots = playerData.total_shots or 0

    -- Don't flag players with too few shots
    if (totalShots < 50) then
      return {
        level = "INSUFFICIENT_DATA",
        text = "INSUFFICIENT DATA",
        color = Color(150, 150, 150)
      }
    end

    local suspicionScore = 0

    -- High accuracy is suspicious
    if (accuracy > 85) then
      suspicionScore = suspicionScore + 3
    elseif (accuracy > 70) then
      suspicionScore = suspicionScore + 1
    end

    -- High headshot rate is suspicious
    if (headshotRate > 60) then
      suspicionScore = suspicionScore + 3
    elseif (headshotRate > 40) then
      suspicionScore = suspicionScore + 1
    end

    -- Very high K/D with high accuracy is suspicious
    local kdRatio = playerData.kd_ratio or 0
    if (kdRatio > 5 and accuracy > 60) then
      suspicionScore = suspicionScore + 2
    end

    if (suspicionScore >= 4) then
      return {
        level = "HIGH",
        text = "HIGH SUSPICION",
        color = Color(255, 100, 100)
      }
    elseif (suspicionScore >= 2) then
      return {
        level = "MEDIUM",
        text = "MEDIUM SUSPICION",
        color = Color(255, 200, 100)
      }
    else
      return {
        level = "LOW",
        text = "LOW SUSPICION",
        color = Color(100, 255, 100)
      }
    end
  end

  function PANEL:GetAccuracyColor(accuracy)
    if (accuracy > 85) then
      return Color(255, 100, 100) -- Red for very high
    elseif (accuracy > 70) then
      return Color(255, 200, 100) -- Yellow for high
    elseif (accuracy > 40) then
      return Color(100, 255, 100) -- Green for normal
    else
      return Color(150, 150, 150) -- Gray for low
    end
  end

  function PANEL:GetHeadshotColor(headshotRate)
    if (headshotRate > 60) then
      return Color(255, 100, 100) -- Red for very high
    elseif (headshotRate > 40) then
      return Color(255, 200, 100) -- Yellow for high
    elseif (headshotRate > 20) then
      return Color(100, 255, 100) -- Green for normal
    else
      return Color(150, 150, 150) -- Gray for low
    end
  end

  function PANEL:FindOnlinePlayer(steamID)
    for _, ply in ipairs(player.GetAll()) do
      if (ply:SteamID() == steamID) then
        return ply
      end
    end
    return nil
  end

  vgui.Register("versus_PlayerHitPlayerEntryPanel", PANEL, "EditablePanel")
end

do
  -- Detailed player statistics panel
  local PANEL = {}

  function PANEL:Init()
    local w = math.max(ScrW() * 0.50, 700)
    local h = ScrH()

    self:SetSize(w, h)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha      = 0
    self.contentAlpha = 0
    self.animStart    = CurTime()
    self.animDuration = 0.35
    self.closing      = false
    self.closeStart   = 0

    local sp          = GAMEMODE.SPACING
    self:DockPadding(sp, sp, sp, sp)

    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("PLAYER HIT DETAILS")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, sp * 0.5)

    self.closeButton = vgui.Create("versus_Button", self)
    self.closeButton:Dock(BOTTOM)
    self.closeButton:DockMargin(0, sp * 0.5, 0, 0)
    self.closeButton:SetText("CLOSE")
    self.closeButton:SetType("secondary")
    self.closeButton.DoClick = function()
      self:Close()
    end

    self.playerStatsParent = vgui.Create("versus_ScrollPanel", self)
    self.playerStatsParent:Dock(FILL)
  end

  function PANEL:SetPlayerStats(stats, steamID)
    self.stats = stats
    self.steamID = steamID

    -- Clear existing content
    self.playerStatsParent:Clear()

    -- Player info header
    local headerPanel = self.playerStatsParent:Add("EditablePanel")
    headerPanel:SetTall(60)
    headerPanel:Dock(TOP)
    headerPanel:DockMargin(10, 10, 10, 10)
    headerPanel.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 55))
    end

    local playerName = "Unknown Player"
    for _, ply in ipairs(player.GetAll()) do
      if (ply:SteamID() == steamID) then
        playerName = ply:Name()
        break
      end
    end

    local headerLabel = headerPanel:Add("DLabel")
    headerLabel:SetText("Player: " .. playerName .. " (" .. steamID .. ")")
    headerLabel:SetFont("VersusDefault")
    headerLabel:SetTextColor(Color(255, 255, 255))
    headerLabel:SetPos(15, 15)
    headerLabel:SizeToContents()

    -- Main stats panel
    local mainStatsPanel = self.playerStatsParent:Add("DSizeToContents")
    mainStatsPanel:Dock(TOP)
    mainStatsPanel:DockMargin(10, 0, 0, 10)
    mainStatsPanel:DockPadding(6, 10, 6, 10)
    mainStatsPanel.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45))
    end

    -- Create main stats layout
    self:CreateMainStatsLayout(mainStatsPanel, stats)

    -- Player hitgroup distribution
    local hitgroupPanel = self.playerStatsParent:Add("EditablePanel")
    hitgroupPanel:SetTall(250)
    hitgroupPanel:Dock(TOP)
    hitgroupPanel:DockMargin(10, 0, 10, 10)
    hitgroupPanel:DockPadding(6, 10, 6, 10)
    hitgroupPanel.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45))
    end

    -- Header for player hitgroup section
    local hitgroupHeader = hitgroupPanel:Add("DLabel")
    hitgroupHeader:SetText("Body Part Hit Distribution (vs Players)")
    hitgroupHeader:SetFont("VersusDefault")
    hitgroupHeader:SetTextColor(Color(255, 255, 255))
    hitgroupHeader:SetTall(25)
    hitgroupHeader:Dock(TOP)
    hitgroupHeader:DockMargin(10, 10, 10, 5)

    self:CreateHitgroupLayout(hitgroupPanel, stats.hitgroups or {})

    -- NPC hitgroup distribution
    local npcHitgroupPanel = self.playerStatsParent:Add("EditablePanel")
    npcHitgroupPanel:SetTall(250)
    npcHitgroupPanel:Dock(TOP)
    npcHitgroupPanel:DockMargin(10, 0, 10, 10)
    npcHitgroupPanel:DockPadding(6, 10, 6, 10)
    npcHitgroupPanel.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(35, 45, 35))
    end

    -- Header for NPC hitgroup section
    local npcHitgroupHeader = npcHitgroupPanel:Add("DLabel")
    npcHitgroupHeader:SetText("Body Part Hit Distribution (vs NPCs)")
    npcHitgroupHeader:SetFont("VersusDefault")
    npcHitgroupHeader:SetTextColor(Color(200, 255, 200))
    npcHitgroupHeader:SetTall(25)
    npcHitgroupHeader:Dock(TOP)
    npcHitgroupHeader:DockMargin(10, 10, 10, 5)

    self:CreateHitgroupLayout(npcHitgroupPanel, stats.npc_hitgroups or {})
  end

  function PANEL:CreateStatLabel(parent, labelText, valueText, valueColor)
    local container = parent:Add("DSizeToContents")
    container:Dock(TOP)
    container:DockMargin(10, 0, 10, 5)

    local label = container:Add("DLabel")
    label:SetText(labelText)
    label:SetFont("VersusDefault")
    label:SetTextColor(Color(255, 255, 255))
    label:Dock(LEFT)
    label:SizeToContents()

    local value = container:Add("DLabel")
    value:SetText(" " .. valueText)
    value:SetFont("VersusDefault")
    value:SetTextColor(valueColor)
    value:Dock(FILL)
  end

  function PANEL:CreateMainStatsLayout(parent, stats)
    local totals = stats.totals or {}
    local accuracy = stats.accuracy or {}

    -- vs Players section header
    local pvpHeader = parent:Add("DLabel")
    pvpHeader:SetText("vs Players")
    pvpHeader:SetFont("VersusDefault")
    pvpHeader:SetTextColor(Color(200, 220, 255))
    pvpHeader:Dock(TOP)
    pvpHeader:DockMargin(10, 4, 10, 2)
    pvpHeader:SizeToContents()

    self:CreateStatLabel(
      parent,
      "Accuracy:",
      string.format(
        "%.1f%% (%d/%d)",
        accuracy.hit_rate or 0,
        totals.total_hits or 0,
        totals.shots_fired or 0
      ),
      self:GetAccuracyColor(accuracy.hit_rate or 0)
    )

    self:CreateStatLabel(
      parent,
      "Headshot Rate:",
      string.format(
        "%.1f%% (%d/%d)",
        accuracy.headshot_rate or 0,
        totals.headshot_hits or 0,
        totals.total_hits or 0
      ),
      self:GetHeadshotColor(accuracy.headshot_rate or 0)
    )

    self:CreateStatLabel(
      parent,
      "K/D Ratio:",
      string.format(
        "%.2f (%d/%d)",
        totals.kd_ratio or 0,
        totals.kills or 0,
        totals.deaths or 0
      ),
      Color(200, 200, 200)
    )

    self:CreateStatLabel(
      parent,
      "Headshot Kills:",
      string.format(
        "%d/%d",
        totals.headshot_kills or 0,
        totals.kills or 0
      ),
      Color(200, 200, 200)
    )

    self:CreateStatLabel(
      parent,
      "Total Shots:",
      tostring(totals.shots_fired or 0),
      Color(180, 180, 180)
    )
    self:CreateStatLabel(
      parent,
      "Total Hits:",
      tostring(totals.total_hits or 0),
      Color(180, 180, 180)
    )

    -- vs NPCs section header
    local npcHeader = parent:Add("DLabel")
    npcHeader:SetText("vs NPCs")
    npcHeader:SetFont("VersusDefault")
    npcHeader:SetTextColor(Color(200, 255, 200))
    npcHeader:Dock(TOP)
    npcHeader:DockMargin(10, 8, 10, 2)
    npcHeader:SizeToContents()

    self:CreateStatLabel(
      parent,
      "Hit Rate:",
      string.format(
        "%.1f%% (%d/%d)",
        accuracy.npc_hit_rate or 0,
        totals.total_npc_hits or 0,
        totals.shots_fired or 0
      ),
      self:GetAccuracyColor(accuracy.npc_hit_rate or 0)
    )

    self:CreateStatLabel(
      parent,
      "Headshot Rate:",
      string.format(
        "%.1f%% (%d/%d)",
        accuracy.npc_headshot_rate or 0,
        totals.headshot_npc_hits or 0,
        totals.total_npc_hits or 0
      ),
      self:GetHeadshotColor(accuracy.npc_headshot_rate or 0)
    )

    self:CreateStatLabel(
      parent,
      "NPC Kills:",
      tostring(totals.npc_kills or 0),
      Color(180, 180, 180)
    )
    self:CreateStatLabel(
      parent,
      "Total NPC Hits:",
      tostring(totals.total_npc_hits or 0),
      Color(180, 180, 180)
    )
  end

  function PANEL:CreateHitgroupLayout(parent, hitgroups, sectionLabel)
    local listPanel = parent:Add("versus_ScrollPanel")
    listPanel:Dock(FILL)
    listPanel:DockMargin(10, 0, 10, 10)

    if (sectionLabel) then
      local subHeader = listPanel:Add("DLabel")
      subHeader:SetText(sectionLabel)
      subHeader:SetFont("VersusDefault")
      subHeader:SetTextColor(Color(200, 200, 200))
      subHeader:Dock(TOP)
      subHeader:DockMargin(0, 0, 0, 4)
      subHeader:SizeToContents()
    end

    -- Calculate total hits for percentages
    local totalHits = 0
    for _, data in pairs(hitgroups) do
      totalHits = totalHits + (data.hits or 0)
    end

    if (totalHits == 0) then
      local noDataLabel = listPanel:Add("DLabel")
      noDataLabel:SetText("No hit data available")
      noDataLabel:SetFont("VersusDefault")
      noDataLabel:SetTextColor(Color(150, 150, 150))
      noDataLabel:SetContentAlignment(5)
      noDataLabel:Dock(FILL)
      return
    end

    -- Sort hitgroups by hit count
    local sortedHitgroups = {}
    for hitgroup, data in pairs(hitgroups) do
      table.insert(sortedHitgroups, { name = hitgroup, data = data })
    end

    table.sort(sortedHitgroups, function(a, b)
      return (a.data.hits or 0) > (b.data.hits or 0)
    end)

    for i, hitgroupData in ipairs(sortedHitgroups) do
      local hitgroup = hitgroupData.name
      local data = hitgroupData.data
      local percentage = (data.hits / totalHits) * 100

      local entryPanel = listPanel:Add("EditablePanel")
      entryPanel:SetTall(25)
      entryPanel:Dock(TOP)
      entryPanel:DockMargin(0, 2, 0, 2)

      local nameLabel = entryPanel:Add("DLabel")
      nameLabel:SetText(hitgroup .. ":")
      nameLabel:SetFont("VersusDefault")
      nameLabel:SetTextColor(Color(255, 255, 255))
      nameLabel:SetSize(100, 25)
      nameLabel:Dock(LEFT)

      local statsLabel = entryPanel:Add("DLabel")
      local statsText = string.format("%d hits (%.1f%%)", data.hits or 0, percentage)
      statsLabel:SetText(statsText)
      statsLabel:SetFont("VersusDefault")

      -- Color code based on hit type
      local textColor = Color(200, 200, 200)
      if (hitgroup == "Head") then
        textColor = Color(255, 150, 150)
      elseif (hitgroup == "Chest") then
        textColor = Color(150, 255, 150)
      end

      statsLabel:SetTextColor(textColor)
      statsLabel:Dock(FILL)
    end
  end

  function PANEL:GetAccuracyColor(accuracy)
    if (accuracy > 85) then
      return Color(255, 100, 100)
    elseif (accuracy > 70) then
      return Color(255, 200, 100)
    elseif (accuracy > 40) then
      return Color(100, 255, 100)
    else
      return Color(150, 150, 150)
    end
  end

  function PANEL:GetHeadshotColor(headshotRate)
    if (headshotRate > 60) then
      return Color(255, 100, 100)
    elseif (headshotRate > 40) then
      return Color(255, 200, 100)
    elseif (headshotRate > 20) then
      return Color(100, 255, 100)
    else
      return Color(150, 150, 150)
    end
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing    = true
    self.closeStart = CurTime()
  end

  function PANEL:OnKeyCodeTyped(keyCode)
    if keyCode == KEY_ESCAPE then
      self:Close()
      return true
    end
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if (not self.closing) then
      if (elapsed < self.animDuration) then
        local progress    = math.ease.InOutQuad(elapsed / self.animDuration)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha      = 200
        self.contentAlpha = 255
      end
    else
      local closeElapsed = CurTime() - self.closeStart

      if (closeElapsed < 0.3) then
        local progress    = 1 - (closeElapsed / 0.3)
        self.bgAlpha      = 200 * progress
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

  function PANEL:PerformLayout(w, h)
    self:Center()
  end

  vgui.Register("versus_PlayerHitDetailPanel", PANEL, "EditablePanel")
end

do
  -- Main hit statistics panel
  local PANEL = {}

  function PANEL:Init()
    local w = math.max(ScrW() * 0.65, 900)
    local h = ScrH()

    self:SetSize(w, h)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha      = 0
    self.contentAlpha = 0
    self.animStart    = CurTime()
    self.animDuration = 0.35
    self.closing      = false
    self.closeStart   = 0

    local sp          = GAMEMODE.SPACING
    self:DockPadding(sp, sp, sp, sp)

    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("HIT STATISTICS")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, sp * 0.5)

    self.closeButton = vgui.Create("versus_Button", self)
    self.closeButton:Dock(BOTTOM)
    self.closeButton:DockMargin(0, sp * 0.5, 0, 0)
    self.closeButton:SetText("CLOSE")
    self.closeButton:SetType("secondary")
    self.closeButton.DoClick = function()
      self:Close()
    end

    -- Tab system
    self.tabPanel = self:Add("versus_TabPanel")
    self.tabPanel:Dock(FILL)

    -- Overview tab
    self.overviewPanel = vgui.Create("DPanel")
    self.overviewPanel.Paint = function() end
    self.tabPanel:AddTab("All Players", self.overviewPanel)

    -- Suspicious players tab
    self.suspiciousPanel = vgui.Create("DPanel")
    self.suspiciousPanel.Paint = function() end
    self.tabPanel:AddTab("Suspicious", self.suspiciousPanel)

    self:CreateOverviewTab()
    self:CreateSuspiciousTab()
  end

  function PANEL:CreateOverviewTab()
    -- Search and filter panel
    local searchPanel = self.overviewPanel:Add("EditablePanel")
    searchPanel:SetTall(48)
    searchPanel:Dock(TOP)
    searchPanel:DockMargin(8, 8, 8, 8)

    -- Search label
    local searchLabel = searchPanel:Add("DLabel")
    searchLabel:SetText("Search players:")
    searchLabel:SetFont("VersusDefault")
    searchLabel:SetTextColor(Color(255, 255, 255))
    searchLabel:Dock(LEFT)
    searchLabel:DockMargin(0, 0, GAMEMODE.SPACING, 0)
    searchLabel:SizeToContents()

    -- Search entry
    self.searchEntry = searchPanel:Add("versus_TextEntry")
    self.searchEntry:SetSize(300, 25)
    self.searchEntry:Dock(FILL)
    self.searchEntry:SetPlaceholderText("Search by player name or Steam ID...")
    self.searchEntry.OnTextChanged = function(entry)
      local text = entry:GetText()
      self.overviewSearch = text
      timer.Simple(0.4, function()
        if (IsValid(self) and self.overviewSearch == text) then
          self:RequestOverviewPage(1, text)
        end
      end)
    end

    -- Refresh button
    self.refreshButton = searchPanel:Add("versus_Button")
    self.refreshButton:SetText("Refresh Data")
    self.refreshButton:SizeToContents()
    self.refreshButton:Dock(RIGHT)
    self.refreshButton:DockMargin(GAMEMODE.SPACING, 0, 0, 0)
    self.refreshButton.DoClick = function()
      self:RequestOverviewPage(1, self.searchEntry:GetText())
    end

    -- Pagination bar (BOTTOM before FILL so layout is correct)
    self.overviewPaginationBar = self.overviewPanel:Add("EditablePanel")
    self.overviewPaginationBar:SetTall(36)
    self.overviewPaginationBar:Dock(BOTTOM)
    self.overviewPaginationBar:DockMargin(8, 4, 8, 4)
    self.overviewPaginationBar:SetVisible(false)

    self.overviewPrevButton = self.overviewPaginationBar:Add("versus_Button")
    self.overviewPrevButton:SetText("< Prev")
    self.overviewPrevButton:SetSize(80, 28)
    self.overviewPrevButton:Dock(LEFT)
    self.overviewPrevButton.DoClick = function()
      if (self.overviewPage > 1) then
        self:RequestOverviewPage(self.overviewPage - 1, self.overviewSearch)
      end
    end

    self.overviewPageLabel = self.overviewPaginationBar:Add("DLabel")
    self.overviewPageLabel:SetFont("VersusDefault")
    self.overviewPageLabel:SetTextColor(Color(200, 200, 200))
    self.overviewPageLabel:SetContentAlignment(5)
    self.overviewPageLabel:Dock(FILL)

    self.overviewNextButton = self.overviewPaginationBar:Add("versus_Button")
    self.overviewNextButton:SetText("Next >")
    self.overviewNextButton:SetSize(80, 28)
    self.overviewNextButton:Dock(RIGHT)
    self.overviewNextButton.DoClick = function()
      if (self.overviewPage < self.overviewTotalPages) then
        self:RequestOverviewPage(self.overviewPage + 1, self.overviewSearch)
      end
    end

    -- Create loading indicator
    self.loadingLabel = self.overviewPanel:Add("DLabel")
    self.loadingLabel:SetText("Loading player statistics...")
    self.loadingLabel:SetFont("VersusDefault")
    self.loadingLabel:SetTextColor(Color(150, 150, 150))
    self.loadingLabel:SetContentAlignment(5)
    self.loadingLabel:Dock(FILL)

    -- Scroll panel (hidden initially)
    self.overviewScroll = self.overviewPanel:Add("versus_ScrollPanel")
    self.overviewScroll:Dock(FILL)
    self.overviewScroll:DockMargin(8, 8, 8, 8)
    self.overviewScroll:SetVisible(false)

    self.overviewPage = 1
    self.overviewSearch = ""
    self.overviewTotalPages = 1
    self.allPlayers = {}
    self.filteredPlayers = {}
  end

  function PANEL:CreateSuspiciousTab()
    -- Info panel
    local infoPanel = self.suspiciousPanel:Add("EditablePanel")
    infoPanel:SetTall(40)
    infoPanel:Dock(TOP)
    infoPanel:DockMargin(8, 8, 8, 8)
    infoPanel.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(60, 40, 40))
    end

    local infoLabel = infoPanel:Add("DLabel")
    infoLabel:SetText("Players flagged with suspicious accuracy patterns (>85% accuracy or >60% headshot rate)")
    infoLabel:SetFont("VersusDefault")
    infoLabel:SetTextColor(Color(255, 200, 200))
    infoLabel:SetPos(10, 10)
    infoLabel:SizeToContents()

    -- Refresh suspicious button
    self.refreshSuspiciousButton = self.suspiciousPanel:Add("versus_Button")
    self.refreshSuspiciousButton:SetText("Refresh Suspicious Players")
    self.refreshSuspiciousButton:SizeToContents()
    self.refreshSuspiciousButton:Dock(TOP)
    self.refreshSuspiciousButton:DockMargin(8, 0, 8, 8)
    self.refreshSuspiciousButton.DoClick = function()
      self:RequestSuspiciousPage(1)
    end

    -- Pagination bar (BOTTOM before FILL so layout is correct)
    self.suspiciousPaginationBar = self.suspiciousPanel:Add("EditablePanel")
    self.suspiciousPaginationBar:SetTall(36)
    self.suspiciousPaginationBar:Dock(BOTTOM)
    self.suspiciousPaginationBar:DockMargin(8, 4, 8, 4)
    self.suspiciousPaginationBar:SetVisible(false)

    self.suspiciousPrevButton = self.suspiciousPaginationBar:Add("versus_Button")
    self.suspiciousPrevButton:SetText("< Prev")
    self.suspiciousPrevButton:SetSize(80, 28)
    self.suspiciousPrevButton:Dock(LEFT)
    self.suspiciousPrevButton.DoClick = function()
      if (self.suspiciousPage > 1) then
        self:RequestSuspiciousPage(self.suspiciousPage - 1)
      end
    end

    self.suspiciousPageLabel = self.suspiciousPaginationBar:Add("DLabel")
    self.suspiciousPageLabel:SetFont("VersusDefault")
    self.suspiciousPageLabel:SetTextColor(Color(200, 200, 200))
    self.suspiciousPageLabel:SetContentAlignment(5)
    self.suspiciousPageLabel:Dock(FILL)

    self.suspiciousNextButton = self.suspiciousPaginationBar:Add("versus_Button")
    self.suspiciousNextButton:SetText("Next >")
    self.suspiciousNextButton:SetSize(80, 28)
    self.suspiciousNextButton:Dock(RIGHT)
    self.suspiciousNextButton.DoClick = function()
      if (self.suspiciousPage < self.suspiciousTotalPages) then
        self:RequestSuspiciousPage(self.suspiciousPage + 1)
      end
    end

    -- Suspicious players scroll
    self.suspiciousScroll = self.suspiciousPanel:Add("versus_ScrollPanel")
    self.suspiciousScroll:Dock(FILL)
    self.suspiciousScroll:DockMargin(8, 8, 8, 8)

    -- Pagination state
    self.suspiciousPage = 1
    self.suspiciousTotalPages = 1

    -- Request suspicious players data (page 1)
    self:RequestSuspiciousPage(1)
  end

  function PANEL:RequestOverviewPage(page, searchText)
    self.overviewPage = page
    self.overviewSearch = searchText or ""
    net.Start("versus.hitStatistics.requestPlayersOverview")
    net.WriteUInt(page, 16)
    net.WriteString(self.overviewSearch)
    net.SendToServer()
  end

  function PANEL:RequestSuspiciousPage(page)
    self.suspiciousPage = page
    local thresholds = {
      min_shots = 100,
      max_accuracy = 85,
      max_headshot_rate = 60
    }
    net.Start("versus.hitStatistics.requestSuspiciousPlayers")
    net.WriteTable(thresholds)
    net.WriteUInt(page, 16)
    net.SendToServer()
  end

  function PANEL:DisplayPlayersOverview(data)
    local playersStats = data.players or data
    local page = data.page or 1
    local totalPages = data.totalPages or 1
    local totalCount = data.totalCount or #playersStats

    self.overviewPage = page
    self.overviewTotalPages = totalPages

    -- Hide loading indicator
    self.loadingLabel:SetVisible(false)

    -- Show scroll panel
    self.overviewScroll:SetVisible(true)
    self.overviewScroll:Clear()

    -- Update pagination bar
    self.overviewPaginationBar:SetVisible(totalPages > 1)
    self.overviewPageLabel:SetText(string.format("Page %d / %d  (%d total)", page, totalPages, totalCount))
    self.overviewPrevButton:SetEnabled(page > 1)
    self.overviewNextButton:SetEnabled(page < totalPages)

    self.allPlayers = playersStats
    self.filteredPlayers = playersStats

    if (#playersStats == 0) then
      local emptyLabel = self.overviewScroll:Add("DLabel")
      emptyLabel:SetText("No player statistics found")
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(Color(150, 150, 150))
      emptyLabel:SetContentAlignment(5)
      emptyLabel:Dock(FILL)
      return
    end

    -- Create player entries (server pre-sorts by total shots)
    for i, playerData in ipairs(playersStats) do
      local playerPanel = self.overviewScroll:Add("versus_PlayerHitPlayerEntryPanel")
      playerPanel:SetPlayerStats(playerData, i)
      playerPanel:Dock(TOP)
      playerPanel:DockMargin(5, 5, 5, 5)
    end
  end

  function PANEL:DisplaySuspiciousPlayers(data)
    local suspiciousPlayers = data.players or data
    local page = data.page or 1
    local totalPages = data.totalPages or 1
    local totalCount = data.totalCount or #suspiciousPlayers

    self.suspiciousPage = page
    self.suspiciousTotalPages = totalPages

    self.suspiciousScroll:Clear()

    -- Update pagination bar
    self.suspiciousPaginationBar:SetVisible(totalPages > 1)
    self.suspiciousPageLabel:SetText(string.format("Page %d / %d  (%d total)", page, totalPages, totalCount))
    self.suspiciousPrevButton:SetEnabled(page > 1)
    self.suspiciousNextButton:SetEnabled(page < totalPages)

    if (#suspiciousPlayers == 0) then
      local emptyLabel = self.suspiciousScroll:Add("DLabel")
      emptyLabel:SetText("No suspicious players found")
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(Color(100, 255, 100))
      emptyLabel:SetContentAlignment(5)
      emptyLabel:Dock(FILL)
      return
    end

    -- Create suspicious player entries
    for i, playerData in ipairs(suspiciousPlayers) do
      local playerPanel = self.suspiciousScroll:Add("versus_PlayerHitPlayerEntryPanel")
      playerPanel:SetPlayerStats(playerData, i)
      playerPanel:Dock(TOP)
      playerPanel:DockMargin(5, 5, 5, 5)
    end
  end

  function PANEL:DisplayPlayerStats(stats, steamID)
    -- Create detailed stats panel
    local detailPanel = vgui.Create("versus_PlayerHitDetailPanel")
    detailPanel:SetPlayerStats(stats, steamID)
  end

  function PANEL:FilterPlayers(searchText)
    -- Delegate to server-side search, resetting to page 1
    self:RequestOverviewPage(1, searchText)
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing    = true
    self.closeStart = CurTime()
  end

  function PANEL:OnKeyCodeTyped(keyCode)
    if keyCode == KEY_ESCAPE then
      self:Close()
      return true
    end
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if (not self.closing) then
      if (elapsed < self.animDuration) then
        local progress    = math.ease.InOutQuad(elapsed / self.animDuration)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha      = 200
        self.contentAlpha = 255
      end
    else
      local closeElapsed = CurTime() - self.closeStart

      if (closeElapsed < 0.3) then
        local progress    = 1 - (closeElapsed / 0.3)
        self.bgAlpha      = 200 * progress
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

  function PANEL:PerformLayout(w, h)
    self:Center()
  end

  vgui.Register("versus_AdminHitStats", PANEL, "EditablePanel")
end
