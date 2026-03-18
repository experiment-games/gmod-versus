local PLUGIN = PLUGIN

do
  -- Individual admin payment record entry panel
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(150)
    self:DockPadding(10, 10, 10, 10)
  end

  function PANEL:SetPaymentRecord(record, index)
    self.record = record
    self.index = index

    -- Top row: Player info and Status
    local topRow = self:Add("EditablePanel")
    topRow:SetTall(25)
    topRow:Dock(TOP)

    -- Player name and Steam ID
    self.playerLabel = topRow:Add("DLabel")
    self.playerLabel:SetText(record.player_name .. " (" .. record.steamid64 .. ")")
    self.playerLabel:SetFont("VersusDefault")
    self.playerLabel:SetTextColor(Color(255, 255, 255))
    self.playerLabel:Dock(LEFT)
    self.playerLabel:SizeToContents()

    -- Status label
    self.statusLabel = topRow:Add("DLabel")
    self.statusLabel:SetText(string.upper(record.status))
    self.statusLabel:SetFont("VersusSmall")
    self.statusLabel:SetContentAlignment(6) -- Right align
    self.statusLabel:Dock(RIGHT)
    self.statusLabel:SizeToContents()

    -- Set status color
    local statusColor = Color(255, 255, 255)
    if (record.status == "purchased" or record.status == "renewed") then
      statusColor = PLUGIN.THEME.success
    elseif (record.status == "expired") then
      statusColor = PLUGIN.THEME.warning
    elseif (record.status == "refunded" or record.status == "canceled") then
      statusColor = PLUGIN.THEME.danger
    end

    self.statusLabel:SetTextColor(statusColor)

    -- Package and date row
    local infoRow = self:Add("EditablePanel")
    infoRow:SetTall(25)
    infoRow:Dock(TOP)
    infoRow:DockMargin(0, 5, 0, 0)

    -- Package name
    local packageName = "Unknown Package"
    local package = PLUGIN.PREMIUM_PACKAGES[record.item_slug]
    if (package) then
      packageName = package.name
    end

    self.packageLabel = infoRow:Add("DLabel")
    self.packageLabel:SetText("Package: " .. packageName)
    self.packageLabel:SetFont("VersusDefault")
    self.packageLabel:SetTextColor(PLUGIN.THEME.premium)
    self.packageLabel:Dock(LEFT)
    self.packageLabel:SizeToContents()

    -- Date
    local dateText = os.date("%Y-%m-%d %H:%M", record.created_at)
    self.dateLabel = infoRow:Add("DLabel")
    self.dateLabel:SetText("Date: " .. dateText)
    self.dateLabel:SetFont("VersusDefault")
    self.dateLabel:SetTextColor(PLUGIN.THEME.textSecondary)
    self.dateLabel:SetContentAlignment(6) -- Right align
    self.dateLabel:Dock(RIGHT)
    self.dateLabel:SizeToContents()

    -- Order ID row
    local orderRow = self:Add("EditablePanel")
    orderRow:SetTall(25)
    orderRow:Dock(TOP)
    orderRow:DockMargin(0, 5, 0, 0)

    local orderLabel = orderRow:Add("DLabel")
    orderLabel:SetText("Order ID:")
    orderLabel:SetFont("VersusDefault")
    orderLabel:SetTextColor(PLUGIN.THEME.textSecondary)
    orderLabel:SizeToContents()
    orderLabel:Dock(LEFT)

    -- Order ID text entry (read-only)
    self.orderEntry = orderRow:Add("DTextEntry")
    self.orderEntry:SetText(record.order_id)
    self.orderEntry:SetDisabled(true)
    self.orderEntry:SetFont("VersusDefault")
    self.orderEntry:Dock(FILL)
    self.orderEntry:DockMargin(5, 0, 5, 0)

    -- Copy button for order ID
    self.copyButton = orderRow:Add("versus_Button")
    self.copyButton:SetText("Copy")
    self.copyButton:SizeToContents()
    self.copyButton:Dock(RIGHT)
    self.copyButton.DoClick = function()
      self.orderEntry:SelectAll()
      SetClipboardText(record.order_id)
      versus.message.notify("Order ID copied to clipboard!", NOTIFY_CHAT_LIGHTBULB)
    end

    -- Button row
    local buttonRow = self:Add("EditablePanel")
    buttonRow:Dock(FILL)
    buttonRow:DockMargin(0, 5, 0, 0)

    -- View player button
    self.viewPlayerButton = buttonRow:Add("versus_Button")
    self.viewPlayerButton:SetText("Check if Player is Online")
    self.viewPlayerButton:SizeToContents()
    self.viewPlayerButton:Dock(LEFT)
    self.viewPlayerButton.DoClick = function()
      -- Try to find the player
      local targetPlayer = nil

      for _, ply in ipairs(player.GetAll()) do
        if (ply:SteamID64() == record.steamid64) then
          targetPlayer = ply
          break
        end
      end

      if (targetPlayer) then
        versus.message.notify(targetPlayer:Name() .. " is online", NOTIFY_INFORMATION)
      else
        versus.message.notify("Player not currently online", NOTIFY_ERROR)
      end
    end

    -- Paint background with status-based coloring
    self.Paint = function(pnl, w, h)
      local bgColor = PLUGIN.THEME.panel

      if (record.status == "purchased" or record.status == "renewed") then
        bgColor = Color(40, 60, 40) -- Green tint
      elseif (record.status == "expired") then
        bgColor = Color(60, 60, 40) -- Yellow tint
      elseif (record.status == "refunded" or record.status == "canceled") then
        bgColor = Color(60, 40, 40) -- Red tint
      end

      draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end
  end

  vgui.Register("versus_AdminPaymentRecordPanel", PANEL, "EditablePanel")
end

do
  -- Main admin payments panel
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(900, 700)
    self:Center()
    self:SetTitle("Admin: Payment Records")
    self:SetDeleteOnClose(true)

    -- Search panel
    local searchPanel = self:Add("EditablePanel")
    searchPanel:SetTall(60)
    searchPanel:Dock(TOP)
    searchPanel:DockMargin(8, 8, 8, 8)

    -- Search label
    local searchLabel = searchPanel:Add("DLabel")
    searchLabel:SetText("Search payment records:")
    searchLabel:SetFont("VersusDefault")
    searchLabel:SetTextColor(Color(255, 255, 255))
    searchLabel:SetPos(0, 5)
    searchLabel:SizeToContents()

    -- Search entry
    self.searchEntry = searchPanel:Add("DTextEntry")
    self.searchEntry:SetSize(300, 25)
    self.searchEntry:SetPos(0, 30)
    self.searchEntry:SetFont("VersusDefault")
    self.searchEntry:SetPlaceholderText("Search by player name, Steam ID, or order ID...")
    self.searchEntry.OnTextChanged = function(entry)
      -- Debounced search
      timer.Remove("AdminPaymentSearch")
      timer.Create("AdminPaymentSearch", 0.5, 1, function()
        if (IsValid(self)) then
          self:SearchPaymentRecords(entry:GetText())
        end
      end)
    end

    -- Stats panel
    self.statsPanel = self:Add("EditablePanel")
    self.statsPanel:SetTall(40)
    self.statsPanel:Dock(TOP)
    self.statsPanel:DockMargin(8, 0, 8, 8)
    self.statsPanel.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, PLUGIN.THEME.surface)
    end

    self.statsLabel = self.statsPanel:Add("DLabel")
    self.statsLabel:SetText("Loading payment records...")
    self.statsLabel:SetFont("VersusDefault")
    self.statsLabel:SetTextColor(Color(255, 255, 255))
    self.statsLabel:SetPos(10, 10)
    self.statsLabel:SizeToContents()

    -- Create loading indicator
    self.loadingLabel = self:Add("DLabel")
    self.loadingLabel:SetText("Loading payment records...")
    self.loadingLabel:SetFont("VersusDefault")
    self.loadingLabel:SetTextColor(PLUGIN.THEME.textSecondary)
    self.loadingLabel:SetContentAlignment(5)
    self.loadingLabel:Dock(FILL)

    -- Scroll panel (hidden initially)
    self.scroll = self:Add("DScrollPanel")
    self.scroll:Dock(FILL)
    self.scroll:DockMargin(8, 8, 8, 8)
    self.scroll:SetVisible(false)

    self.paymentRecords = {}
  end

  function PANEL:SearchPaymentRecords(query)
    net.Start("versus.premium_shop.requestAdminPayments")
    net.WriteString(query or "")
    net.SendToServer()
  end

  function PANEL:DisplayPaymentRecords(paymentRecords, searchQuery)
    -- Hide loading indicator
    self.loadingLabel:SetVisible(false)

    -- Show scroll panel
    self.scroll:SetVisible(true)
    self.scroll:Clear()

    self.paymentRecords = paymentRecords

    -- Update statistics
    self:UpdateStatistics(paymentRecords)

    if (#paymentRecords == 0) then
      local emptyLabel = self.scroll:Add("DLabel")
      if (searchQuery and searchQuery ~= "") then
        emptyLabel:SetText("No payment records found matching search criteria")
      else
        emptyLabel:SetText("No payment records found")
      end
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(PLUGIN.THEME.textSecondary)
      emptyLabel:SetContentAlignment(5)
      emptyLabel:Dock(FILL)
      return
    end

    -- Sort records by date (newest first)
    table.sort(paymentRecords, function(a, b)
      return a.created_at > b.created_at
    end)

    -- Create payment record entries
    for i, record in ipairs(paymentRecords) do
      local recordPanel = self.scroll:Add("versus_AdminPaymentRecordPanel")
      recordPanel:SetPaymentRecord(record, i)
      recordPanel:Dock(TOP)
      recordPanel:DockMargin(5, 5, 5, 5)
    end
  end

  function PANEL:UpdateStatistics(paymentRecords)
    local stats = {
      total = #paymentRecords,
      purchased = 0,
      renewed = 0,
      expired = 0,
      refunded = 0,
      canceled = 0
    }

    for _, record in ipairs(paymentRecords) do
      stats[record.status] = (stats[record.status] or 0) + 1
    end

    local statsText = string.format(
      "Total: %d | Purchased: %d | Renewed: %d | Expired: %d | Refunded: %d | Canceled: %d",
      stats.total, stats.purchased, stats.renewed, stats.expired, stats.refunded, stats.canceled
    )

    self.statsLabel:SetText(statsText)
    self.statsLabel:SizeToContents()
  end

  -- Always keep on top so we don't go behind the main menu
  function PANEL:Think()
    self:MoveToFront()
  end

  vgui.Register("versus_AdminPaymentsPanel", PANEL, "DFrame")
end
