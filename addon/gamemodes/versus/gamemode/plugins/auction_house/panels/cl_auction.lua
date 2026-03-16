local PLUGIN          = PLUGIN

local color_header_bg = Color(15, 22, 32, 255)
local color_text      = Color(220, 230, 240, 255)
local color_dim       = Color(140, 155, 170, 255)
local color_accent    = Color(80, 140, 220, 255)
local color_row_even  = Color(25, 36, 52, 200)
local color_row_odd   = Color(20, 28, 40, 200)
local color_row_hover = Color(42, 60, 88, 220)
local color_green     = Color(80, 200, 120, 255)
local color_orange    = Color(230, 160, 60, 255)
local color_form_bg   = Color(15, 22, 32, 245)

-- Fixed column widths measured from the right edge of the row
local COL_EXPIRES     = 100
local COL_BUYOUT      = 130
local COL_BID         = 120
local COL_SELLER      = 160
local ROW_H           = 70
local COL_ICON        = ROW_H -- model panel column width

--- Format seconds until expiry into a compact human-readable string.
local function formatTimeRemaining(expireUnix)
  local remaining = expireUnix - os.time()

  if remaining <= 0 then return "Expired" end

  local days    = math.floor(remaining / 86400)
  remaining     = remaining % 86400
  local hours   = math.floor(remaining / 3600)
  remaining     = remaining % 3600
  local minutes = math.floor(remaining / 60)

  if days > 0 then
    return string.format("%dd %dh", days, hours)
  elseif hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  else
    return string.format("%dm", math.max(1, minutes))
  end
end

--- Compute the minimum valid next bid for an entry (mirrors the server helper).
local function minNextBid(entry)
  local current = entry.currentBid

  if current > 0 then
    local increment = math.max(
      PLUGIN.BID_INCREMENT_MIN,
      math.floor(current * PLUGIN.BID_INCREMENT_FRACTION)
    )
    return current + increment
  end

  return entry.minBid
end

--[[
  Individual auction listing row
--]]

do
  local ROW = {}

  function ROW:Init()
    self:SetTall(ROW_H)
    self.entry      = nil
    self.tab        = "browse"
    self.isEven     = false
    self.hovered    = false

    self.modelPanel = vgui.Create("versus_ItemModelPanel", self)
    self.modelPanel:SetSize(COL_ICON, ROW_H)
    self.modelPanel:SetAmbientLight(Color(200, 200, 200, 255))
  end

  function ROW:SetData(entry, tab, isEven)
    self.entry        = entry
    self.tab          = tab
    self.isEven       = isEven

    -- Resolve item definition and rarity once (avoids repeated lookups in Paint)
    local itemDef     = entry.itemID ~= "" and versus.item.get(entry.itemID) or nil
    local rarityID    = (entry.itemRarity ~= "" and entry.itemRarity)
        or (itemDef and itemDef.rarity)
        or nil

    self.cachedRarity = rarityID and versus.item.getRarity(rarityID) or nil

    local function tooltipBuilder(tooltip)
      local description = tooltip:AddRow("description")
      description:SetText(versus.util.resolve(itemDef.description))
      description:SizeToContents()
    end

    self:SetVersusTooltip(tooltipBuilder)
    self.modelPanel:SetVersusTooltip(tooltipBuilder)

    if itemDef and IsValid(self.modelPanel) then
      self.modelPanel:SetItem(itemDef)
      self.modelPanel:SetFOV(50)
    end
  end

  function ROW:PerformLayout(w, h)
    if IsValid(self.modelPanel) then
      self.modelPanel:SetPos(0, 0)
      self.modelPanel:SetSize(COL_ICON, h)
    end
  end

  function ROW:OnCursorEntered() self.hovered = true end

  function ROW:OnCursorExited() self.hovered = false end

  function ROW:Paint(w, h)
    if not self.entry then return end

    local bg = self.hovered and color_row_hover
        or (self.isEven and color_row_even or color_row_odd)

    draw.RoundedBox(4, 0, 0, w, h, bg)

    local sp        = GAMEMODE.SPACING
    local cy        = h / 2
    local entry     = self.entry

    -- Column right-edge x positions
    local xExpires  = w - sp
    local xBuyout   = xExpires - COL_EXPIRES - sp
    local xBid      = xBuyout - COL_BUYOUT - sp
    local xSeller   = xBid - COL_BID - sp

    local itemNameX = COL_ICON + sp
    local rarity    = self.cachedRarity

    draw.SimpleText(
      tostring(entry.itemName),
      "VersusDefault",
      itemNameX, cy,
      color_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )

    -- Rarity badge drawn after (to the right of) the item name, vertically centred.
    -- drawRarityBadge draws with TEXT_ALIGN_TOP, so shift y up by half the badge text height.
    if rarity then
      surface.SetFont("VersusDefault")
      local nameW = surface.GetTextSize(tostring(entry.itemName))
      surface.SetFont("VersusSmall")
      local _, rarityH = surface.GetTextSize(rarity.id:upper())
      versus.item.drawRarityBadge(rarity.id, itemNameX + nameW + sp, cy - rarityH * 0.5, true)
    end

    -- Seller name
    draw.SimpleText(
      tostring(entry.sellerName),
      "VersusDefault",
      xSeller - COL_SELLER, cy,
      color_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )

    -- Bid column: show current bid (accent) or min bid (dim)
    if entry.currentBid > 0 then
      draw.SimpleText(
        versus.util.formatMoney(entry.currentBid),
        "VersusDefault",
        xBid, cy,
        color_accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
      )
    else
      draw.SimpleText(
        versus.util.formatMoney(entry.minBid),
        "VersusDefault",
        xBid, cy,
        color_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
      )
    end

    -- Buy-out column
    if entry.buyoutPrice > 0 then
      draw.SimpleText(
        versus.util.formatMoney(entry.buyoutPrice),
        "VersusDefault",
        xBuyout, cy,
        color_green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
      )
    else
      draw.SimpleText(
        "—",
        "VersusDefault",
        xBuyout, cy,
        color_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
      )
    end

    -- Expires column
    local timeStr   = formatTimeRemaining(entry.expireUnix)
    local timeColor = (entry.expireUnix - os.time()) < 3600 and color_orange or color_dim

    draw.SimpleText(
      timeStr,
      "VersusDefault",
      xExpires, cy,
      timeColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
    )
  end

  function ROW:OnMousePressed(mouseCode)
    if mouseCode ~= MOUSE_LEFT then return end
    if not self.entry then return end

    local entry  = self.entry
    local myID   = LocalPlayer():SteamID64()
    local isMine = (entry.sellerSteamID == myID)
    local menu   = DermaMenu()

    if self.tab == "my_listings" or isMine then
      menu:AddOption(
        "Cancel Listing",
        function()
          versus.panel.query(
            string.format(
              "Cancel the listing for \"%s\"?\nThe item will be returned to your inventory.",
              entry.itemName
            ),
            "Cancel Listing",
            "Yes, Cancel",
            function()
              net.Start("versus.auction.cancelListing")
              net.WriteUInt(entry.id, 32)
              net.SendToServer()
            end,
            "Keep Listing",
            function() end
          )
        end
      )
    else
      -- Place bid
      local nextBid = minNextBid(entry)

      menu:AddOption(
        string.format("Place Bid (min %s)", versus.util.formatMoney(nextBid)),
        function()
          Derma_StringRequest(
            "Place Bid",
            string.format(
              "Enter your bid for \"%s\".\nMinimum: %s",
              entry.itemName,
              versus.util.formatMoney(nextBid)
            ),
            tostring(nextBid),
            function(value)
              local amount = math.floor(tonumber(value) or 0)

              if amount < nextBid then
                Derma_Message(
                  string.format("Bid must be at least %s.", versus.util.formatMoney(nextBid)),
                  "Invalid Bid",
                  "OK"
                )
                return
              end

              net.Start("versus.auction.placeBid")
              net.WriteUInt(entry.id, 32)
              net.WriteUInt(amount, 32)
              net.SendToServer()
            end,
            function() end
          )
        end
      )

      -- Buy now (only if a buyout price is set)
      if entry.buyoutPrice > 0 then
        menu:AddOption(
          string.format("Buy Now — %s", versus.util.formatMoney(entry.buyoutPrice)),
          function()
            versus.panel.query(
              string.format(
                "Buy \"%s\" outright for %s?",
                entry.itemName,
                versus.util.formatMoney(entry.buyoutPrice)
              ),
              "Buy Now",
              "Confirm Purchase",
              function()
                net.Start("versus.auction.buyout")
                net.WriteUInt(entry.id, 32)
                net.SendToServer()
              end,
              "Cancel",
              function() end
            )
          end
        )
      end

      menu:AddSpacer()

      menu:AddOption(
        "View Seller Profile",
        function()
          gui.OpenURL("https://steamcommunity.com/profiles/" .. tostring(entry.sellerSteamID))
        end
      )
    end

    menu:Open()
  end

  vgui.Register("versus_AuctionRow", ROW, "EditablePanel")
end

--[[
  Listing configuration form (popup shown when listing an item for sale)
--]]

do
  local FORM = {}

  function FORM:Init()
    self:SetSize(600, 0)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.stackData        = nil
    self.selectedDuration = 1

    local sp              = GAMEMODE.SPACING

    self:DockPadding(sp, sp, sp, sp)

    -- Title
    local titleLabel = vgui.Create("DLabel", self)
    titleLabel:SetFont("VersusHeading2")
    titleLabel:SetTextColor(color_text)
    titleLabel:SetText("LIST ITEM FOR AUCTION")
    titleLabel:SizeToContents()
    titleLabel:Dock(TOP)
    titleLabel:DockMargin(0, 0, 0, sp * 0.5)

    -- Item name display
    self.itemNameLabel = vgui.Create("DLabel", self)
    self.itemNameLabel:SetFont("VersusDefault")
    self.itemNameLabel:SetTextColor(color_accent)
    self.itemNameLabel:SetText("—")
    self.itemNameLabel:SizeToContents()
    self.itemNameLabel:Dock(TOP)
    self.itemNameLabel:DockMargin(0, 0, 0, sp * 0.5)

    -- Minimum bid row
    local minBidRow = vgui.Create("EditablePanel", self)
    minBidRow:Dock(TOP)
    minBidRow:SetTall(36)
    minBidRow:DockMargin(0, 0, 0, 8)

    local minBidLabel = vgui.Create("DLabel", minBidRow)
    minBidLabel:SetFont("VersusButton")
    minBidLabel:SetTextColor(color_dim)
    minBidLabel:SetText("MIN BID")
    minBidLabel:SetWide(100)
    minBidLabel:SetTall(36)
    minBidLabel:Dock(LEFT)

    self.minBidInput = vgui.Create("DTextEntry", minBidRow)
    self.minBidInput:Dock(FILL)
    self.minBidInput:SetFont("VersusDefault")
    self.minBidInput:SetText("100")
    self.minBidInput:SetNumeric(true)
    self.minBidInput.OnChange = function()
      self:UpdateFeeDisplay()
    end

    -- Buy-out row
    local buyoutRow = vgui.Create("EditablePanel", self)
    buyoutRow:Dock(TOP)
    buyoutRow:SetTall(36)
    buyoutRow:DockMargin(0, 0, 0, 8)

    local buyoutLabel = vgui.Create("DLabel", buyoutRow)
    buyoutLabel:SetFont("VersusButton")
    buyoutLabel:SetTextColor(color_dim)
    buyoutLabel:SetText("BUY-OUT")
    buyoutLabel:SetWide(100)
    buyoutLabel:SetTall(36)
    buyoutLabel:Dock(LEFT)

    self.buyoutCheck = vgui.Create("DCheckBox", buyoutRow)
    self.buyoutCheck:SetSize(20, 20)
    self.buyoutCheck:Dock(LEFT)
    self.buyoutCheck:DockMargin(0, 8, 8, 8)
    self.buyoutCheck.OnChange = function(_, val)
      self.buyoutInput:SetEnabled(val)
      self:UpdateFeeDisplay()
    end

    self.buyoutInput = vgui.Create("DTextEntry", buyoutRow)
    self.buyoutInput:Dock(FILL)
    self.buyoutInput:SetFont("VersusDefault")
    self.buyoutInput:SetText("0")
    self.buyoutInput:SetNumeric(true)
    self.buyoutInput:SetEnabled(false)
    self.buyoutInput.OnChange = function()
      self:UpdateFeeDisplay()
    end

    -- Duration label
    local durLabel = vgui.Create("DLabel", self)
    durLabel:SetFont("VersusButton")
    durLabel:SetTextColor(color_dim)
    durLabel:SetText("DURATION")
    durLabel:SizeToContents()
    durLabel:Dock(TOP)
    durLabel:DockMargin(0, 0, 0, 8)

    -- Duration buttons
    local durBar = vgui.Create("EditablePanel", self)
    durBar:Dock(TOP)
    durBar:SetTall(40)
    durBar:DockMargin(0, 0, 0, sp * 0.5)

    self.durButtons = {}

    for i, dur in ipairs(PLUGIN.DURATIONS) do
      local btn = vgui.Create("versus_Button", durBar)
      btn:Dock(LEFT)
      btn:DockMargin(0, 0, 8, 0)
      btn:SetWide(106)
      btn:SetText(dur.label)
      btn:SetType(i == 1 and "primary" or "default")

      local idx = i
      btn.DoClick = function()
        self:SetDuration(idx)
      end

      self.durButtons[i] = btn
    end

    -- Fee display
    self.feeLabel = vgui.Create("DLabel", self)
    self.feeLabel:SetFont("VersusDefault")
    self.feeLabel:SetTextColor(color_accent)
    self.feeLabel:SetText("Listing fee: —")
    self.feeLabel:SizeToContents()
    self.feeLabel:Dock(TOP)
    self.feeLabel:DockMargin(0, 0, 0, sp * 0.5)

    -- Confirm / Cancel buttons
    local btnRow = vgui.Create("EditablePanel", self)
    btnRow:Dock(TOP)
    btnRow:SetTall(40)

    self.confirmBtn = vgui.Create("versus_Button", btnRow)
    self.confirmBtn:Dock(LEFT)
    self.confirmBtn:SetWide(200)
    self.confirmBtn:SetText("LIST ITEM")
    self.confirmBtn:SetType("primary")
    self.confirmBtn.DoClick = function()
      self:TryList()
    end

    local cancelBtn = vgui.Create("versus_Button", btnRow)
    cancelBtn:Dock(RIGHT)
    cancelBtn:SetWide(140)
    cancelBtn:SetText("CANCEL")
    cancelBtn:SetType("secondary")
    cancelBtn.DoClick = function()
      self:Remove()
    end
  end

  function FORM:PerformLayout(w, h)
    self:SizeToChildren(false, true)
    self:Center()
  end

  function FORM:SetItemData(stackData)
    self.stackData = stackData

    local item = stackData and stackData.item

    if item then
      self.itemNameLabel:SetText(tostring(item.name or item.itemID or "Unknown"))
      self.itemNameLabel:SizeToContents()
    end

    self:UpdateFeeDisplay()
  end

  function FORM:SetDuration(idx)
    self.selectedDuration = idx

    for i, btn in ipairs(self.durButtons) do
      btn:SetType(i == idx and "primary" or "default")
    end

    self:UpdateFeeDisplay()
  end

  function FORM:UpdateFeeDisplay()
    local minBid = math.floor(tonumber(self.minBidInput:GetValue()) or 0)
    local dur    = PLUGIN.DURATIONS[self.selectedDuration]

    if not dur or minBid <= 0 then
      self.feeLabel:SetText("Listing fee: —")
    else
      local fee = math.max(1, math.floor(minBid * dur.feeMultiplier))
      self.feeLabel:SetText(
        string.format(
          "Listing fee: %s  (%d%% of min bid, for %s)",
          versus.util.formatMoney(fee),
          dur.feeMultiplier * 100,
          dur.label
        )
      )
    end

    self.feeLabel:SizeToContents()
  end

  function FORM:TryList()
    if not self.stackData or not self.stackData.item then return end

    local itemKey = self.stackData.keys and self.stackData.keys[1]

    if not itemKey then return end

    local minBid = math.floor(tonumber(self.minBidInput:GetValue()) or 0)

    if minBid < 1 then
      Derma_Message("Minimum bid must be at least 1.", "Invalid Input", "OK")
      return
    end

    local buyoutPrice = 0

    if self.buyoutCheck:GetChecked() then
      buyoutPrice = math.floor(tonumber(self.buyoutInput:GetValue()) or 0)

      if buyoutPrice > 0 and buyoutPrice <= minBid then
        Derma_Message("Buy-out price must be higher than the minimum bid.", "Invalid Input", "OK")
        return
      end
    end

    net.Start("versus.auction.listItem")
    net.WriteUInt(itemKey, versus.inventory.bitSizeItemKeys)
    net.WriteUInt(minBid, 32)
    net.WriteUInt(math.max(0, buyoutPrice), 32)
    net.WriteUInt(self.selectedDuration, 4)
    net.SendToServer()

    self:Remove()
  end

  function FORM:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, color_form_bg)
    draw.RoundedBoxEx(8, 0, 0, w, 3, color_accent, true, true, false, false)
  end

  function FORM:OnKeyCodeTyped(keyCode)
    if keyCode == KEY_ESCAPE then
      self:Remove()
      return true
    end
  end

  vgui.Register("versus_AuctionListForm", FORM, "EditablePanel")
end

--[[
  Main Auction panel
--]]

do
  local PANEL = {}

  local TABS = {
    { key = "browse",      label = "BROWSE" },
    { key = "my_bids",     label = "MY BIDS" },
    { key = "my_listings", label = "MY LISTINGS" },
    { key = "sell",        label = "SELL" },
  }

  function PANEL:Init()
    PLUGIN.auctionPanel = self

    local w = math.max(ScrW() * 0.65, 900)
    local h = ScrH()

    self:SetSize(w, h)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha         = 0
    self.contentAlpha    = 0
    self.animStart       = CurTime()
    self.animDuration    = 0.35
    self.closing         = false
    self.closeStart      = 0

    self.activeTab       = "browse"
    self.currentPage     = 1
    self.totalRows       = 0
    self.inflightRequest = nil

    local sp             = GAMEMODE.SPACING

    self:DockPadding(sp, sp, sp, sp)

    -- Title
    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(color_text)
    self.titleLabel:SetText("AUCTION")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, sp * 0.5)

    -- Tab bar
    self.tabBar = vgui.Create("EditablePanel", self)
    self.tabBar:Dock(TOP)
    self.tabBar:SetTall(48)
    self.tabBar:DockMargin(0, 0, 0, sp * 0.5)

    self.tabButtons = {}

    for _, tab in ipairs(TABS) do
      local btn = vgui.Create("versus_Button", self.tabBar)
      btn:Dock(LEFT)
      btn:DockMargin(0, 0, sp * 0.5, 0)
      btn:SetWide(180)
      btn:SetText(tab.label)
      btn:SetType(tab.key == self.activeTab and "primary" or "default")

      local tabKey = tab.key
      btn.DoClick = function()
        self:SetActiveTab(tabKey)
      end

      self.tabButtons[tab.key] = btn
    end

    -- Close button (docked to bottom first so FILL works correctly)
    self.closeButton = vgui.Create("versus_Button", self)
    self.closeButton:Dock(BOTTOM)
    self.closeButton:DockMargin(0, sp * 0.5, 0, 0)
    self.closeButton:SetText("CLOSE")
    self.closeButton:SetType("secondary")
    self.closeButton.DoClick = function()
      self:Close()
    end

    -- Pagination bar (BOTTOM for the three listing tabs)
    self.navBar = vgui.Create("EditablePanel", self)
    self.navBar:Dock(BOTTOM)
    self.navBar:SetTall(48)
    self.navBar:DockMargin(0, sp * 0.5, 0, 0)

    self.prevButton = vgui.Create("versus_Button", self.navBar)
    self.prevButton:SetSize(120, 48)
    self.prevButton:SetPos(0, 0)
    self.prevButton:SetText("◄ PREV")
    self.prevButton.DoClick = function()
      if self.currentPage > 1 then
        self:GotoPage(self.currentPage - 1)
      end
    end

    self.pageLabel = vgui.Create("DLabel", self.navBar)
    self.pageLabel:SetFont("VersusButton")
    self.pageLabel:SetTextColor(color_dim)
    self.pageLabel:SetText("Page 1 of 1")
    self.pageLabel:SizeToContents()

    self.nextButton = vgui.Create("versus_Button", self.navBar)
    self.nextButton:SetSize(120, 48)
    self.nextButton:SetText("NEXT ►")
    self.nextButton.DoClick = function()
      local maxPages = math.max(1, math.ceil(self.totalRows / PLUGIN.PAGE_SIZE))
      if self.currentPage < maxPages then
        self:GotoPage(self.currentPage + 1)
      end
    end

    -- Listing slots bar (shown only on the my_listings tab)
    self.slotBar = vgui.Create("EditablePanel", self)
    self.slotBar:Dock(BOTTOM)
    self.slotBar:SetTall(72)
    self.slotBar:DockMargin(0, sp * 0.5, 0, 0)
    self.slotBar:SetVisible(false)

    -- Column header (shown only for the three listing tabs)
    self.columnHeader = vgui.Create("EditablePanel", self)
    self.columnHeader:Dock(TOP)
    self.columnHeader:SetTall(48)
    self.columnHeader:DockMargin(0, 0, 0, 8)
    self.columnHeader.Paint = function(pnl, pw, ph)
      draw.RoundedBox(4, 0, 0, pw, ph, color_header_bg)

      local psp      = GAMEMODE.SPACING
      local cy       = ph / 2

      local xExpires = pw - psp
      local xBuyout  = xExpires - COL_EXPIRES - psp
      local xBid     = xBuyout - COL_BUYOUT - psp
      local xSeller  = xBid - COL_BID - psp

      draw.SimpleText("ITEM", "VersusButton", COL_ICON + psp, cy, color_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      draw.SimpleText("SELLER", "VersusButton", xSeller - COL_SELLER, cy, color_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      draw.SimpleText("BID", "VersusButton", xBid, cy, color_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
      draw.SimpleText("BUY-OUT", "VersusButton", xBuyout, cy, color_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
      draw.SimpleText("EXPIRES", "VersusButton", xExpires, cy, color_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Scrollable row list (FILL for listing tabs)
    self.rowList = vgui.Create("versus_ScrollPanel", self)
    self.rowList:Dock(FILL)

    -- Sell tab container (hidden by default)
    self.sellContainer = vgui.Create("EditablePanel", self)
    self.sellContainer:Dock(FILL)
    self.sellContainer:SetVisible(false)

    self:BuildSellPanel()

    self:GotoPage(1)
  end

  --- Populate the sell tab with its description and inventory grid.
  function PANEL:BuildSellPanel()
    local sp = GAMEMODE.SPACING

    local infoLabel = vgui.Create("DLabel", self.sellContainer)
    infoLabel:SetFont("VersusDefault")
    infoLabel:SetTextColor(color_dim)
    infoLabel:SetText(
      "Click an item in your inventory to list it for auction. " ..
      "An up-front listing fee is charged based on your minimum bid and the duration you choose. " ..
      "Listing fees are non-refundable."
    )
    infoLabel:SetWrap(true)
    infoLabel:SetAutoStretchVertical(true)
    infoLabel:Dock(TOP)
    infoLabel:DockMargin(0, 0, 0, sp * 0.25)

    self.inventoryPanel = vgui.Create("versus_Inventory", self.sellContainer)
    self.inventoryPanel:Dock(FILL)
    self.inventoryPanel:SetDisableSettings(true)
    self.inventoryPanel:SetItemFilter(function(item)
      return item.noAuction ~= true
    end)

    self.inventoryPanel:SetOverrideItemPrimaryAction({
      label = "List for Auction",
      callback = function(stackData)
        self:ShowListingForm(stackData)
      end
    })

    self.inventoryPanel:SetOverrideItemActions(false)
  end

  --- Switch to a different tab. Refreshes data for listing tabs.
  function PANEL:SetActiveTab(tab)
    if self.activeTab == tab then return end

    self.activeTab = tab

    for key, btn in pairs(self.tabButtons) do
      btn:SetType(key == tab and "primary" or "default")
    end

    local isSell = (tab == "sell")

    self.columnHeader:SetVisible(not isSell)
    self.rowList:SetVisible(not isSell)
    self.navBar:SetVisible(not isSell)
    self.slotBar:SetVisible(tab == "my_listings")
    self.sellContainer:SetVisible(isSell)

    if not isSell then
      self.currentPage     = 1
      self.totalRows       = 0
      self.inflightRequest = nil
      self:GotoPage(1)
    else
      self:PopulateSell()
    end
  end

  --- Refresh the inventory grid shown on the sell tab.
  function PANEL:PopulateSell()
    if IsValid(self.inventoryPanel) then
      self.inventoryPanel:Refresh()
    end
  end

  --- Open the listing configuration form for the given inventory stack.
  function PANEL:ShowListingForm(stackData)
    if IsValid(self.listForm) then
      self.listForm:Remove()
    end

    self.listForm = vgui.Create("versus_AuctionListForm")
    self.listForm:SetItemData(stackData)
  end

  --- Request the given page from the server.
  function PANEL:GotoPage(page)
    self.currentPage = page

    if self.inflightRequest
        and self.inflightRequest.tab == self.activeTab
        and self.inflightRequest.page == page then
      return
    end

    self.inflightRequest = { tab = self.activeTab, page = page }
    self:SetLoading(true)

    net.Start("versus.auction.requestPage")
    net.WriteString(self.activeTab)
    net.WriteUInt(page, 16)
    net.SendToServer()
  end

  --- Called by cl_init when the server returns a page of data.
  function PANEL:OnPageData(tab, page, total, entries, meta)
    if self.inflightRequest
        and self.inflightRequest.tab == tab
        and self.inflightRequest.page == page then
      self.inflightRequest = nil
    end

    if self.activeTab == tab and self.currentPage == page then
      self:DisplayPage(tab, page, total, entries, meta)
    end
  end

  --- Rebuild the row list with the received data.
  function PANEL:DisplayPage(tab, page, total, entries, meta)
    self:SetLoading(false)

    self.totalRows = total

    -- Rebuild the listing slot indicators for my_listings
    if tab == "my_listings" and meta then
      self:UpdateSlotBar(total, meta.limit)
    end

    local spacing = GAMEMODE.SPACING

    self.rowList:Clear()

    if #entries == 0 then
      local emptyLabel = vgui.Create("DLabel", self.rowList)
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(color_dim)
      emptyLabel:SetText("No listings found.")
      emptyLabel:SizeToContents()
      emptyLabel:Dock(TOP)
      emptyLabel:DockMargin(spacing, spacing, spacing, 0)
    else
      for i, entry in ipairs(entries) do
        local row = vgui.Create("versus_AuctionRow", self.rowList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 8)
        row:SetData(entry, tab, (i % 2 == 0))
      end
    end

    local maxPages = math.max(1, math.ceil(total / PLUGIN.PAGE_SIZE))
    self.pageLabel:SetText("Page " .. page .. " of " .. maxPages)
    self.pageLabel:SizeToContents()

    self.prevButton:SetEnabled(page > 1)
    self.nextButton:SetEnabled(page < maxPages)

    self:InvalidateLayout()
  end

  --- Rebuild the listing slot indicator bar for the my_listings tab.
  --- @param usedCount number  Active listing count for this player
  --- @param limit     number  Max listings allowed for this player
  function PANEL:UpdateSlotBar(usedCount, limit)
    local isPremium = LocalPlayer():HasPremiumPackage("supporter-role-lifetime")
        or LocalPlayer():HasPremiumPackage("supporter-role-monthly")
    self.slotBar:Clear()

    local sp        = GAMEMODE.SPACING
    local slotW     = 40
    local slotH     = 40
    local gap       = 6
    local slotY     = 26
    local maxSlots  = PLUGIN.LISTING_LIMIT_PREMIUM
    local baseLimit = PLUGIN.LISTING_LIMIT_BASE

    -- "LISTING SLOTS  X / Y" header label
    local hdr       = vgui.Create("DLabel", self.slotBar)
    hdr:SetFont("VersusButton")
    hdr:SetTextColor(color_dim)
    hdr:SetText("LISTING SLOTS USED  " .. usedCount .. " / " .. limit)
    hdr:SizeToContents()
    hdr:SetPos(0, 0)

    -- Individual slot boxes
    for i = 1, maxSlots do
      local idx      = i -- safe copy of loop var for closures
      local isFilled = (idx <= usedCount)
      local isLocked = (idx > limit)

      local slot     = vgui.Create("EditablePanel", self.slotBar)
      slot:SetSize(slotW, slotH)
      slot:SetPos((idx - 1) * (slotW + gap), slotY)

      if isLocked then
        slot.Paint = function(s, w, h)
          draw.RoundedBox(32, 0, 0, w, h, Color(18, 24, 36, 200))
        end
        slot:SetTooltip("Locked — Supporter Role unlocks up to " .. maxSlots .. " listing slots!")
      elseif isFilled then
        slot.Paint = function(s, w, h)
          draw.RoundedBox(32, 0, 0, w, h, Color(color_accent.r, color_accent.g, color_accent.b, 200))
        end
        slot:SetTooltip("Slot " .. idx .. " — Active listing")
      else
        slot.Paint = function(s, w, h)
          draw.RoundedBox(32, 0, 0, w, h, Color(28, 42, 62, 180))
        end
        slot:SetTooltip("Slot " .. idx .. " — Available")
      end

      -- Draw a subtle separator between the base and premium slot groups
      if not isPremium and idx == baseLimit then
        slot.Paint = (function(origPaint)
          return function(s, w, h)
            origPaint(s, w, h)
            surface.SetDrawColor(70, 90, 120, 160)
            surface.DrawRect(w + math.floor(gap / 2), 4, 2, h - 8)
          end
        end)(slot.Paint)
      end
    end

    -- Supporter unlock hint shown to the right of the slot row for non-premium players
    if not isPremium then
      local hint = vgui.Create("DLabel", self.slotBar)
      hint:SetFont("VersusDefault")
      hint:SetTextColor(Color(165, 130, 215, 210))
      hint:SetText("(Become a Supporter to unlock " .. (maxSlots - baseLimit) .. " additional slots)")
      hint:SizeToContents()
      hint:SetPos(hdr:GetWide() + 8, 0)
    end
  end

  --- Show or hide a loading indicator while a server request is in flight.
  function PANEL:SetLoading(loading)
    self.loading = loading

    if IsValid(self.prevButton) then
      self.prevButton:SetEnabled(not loading)
    end

    if IsValid(self.nextButton) then
      self.nextButton:SetEnabled(not loading)
    end

    self.rowList:Clear()

    if loading then
      local loadingPanel = vgui.Create("EditablePanel", self.rowList)
      loadingPanel:Dock(TOP)
      loadingPanel:SetTall(300)

      local indicator = vgui.Create("versus_LoadingIndicator", loadingPanel)
      indicator:SetSize(80, 80)
      indicator:Center()
    end
  end

  --- Called by the NPC system after the panel is created.
  function PANEL:Populate()
    -- All setup is handled in Init; this exists for NPC menu compatibility.
  end

  --- Refresh the current page after a successful action (bid, buyout, list, cancel).
  function PANEL:OnActionResult()
    self.inflightRequest = nil
    self:GotoPage(self.currentPage)
  end

  --- Called when the player's inventory changes while the sell tab is visible.
  function PANEL:OnInventoryChanged()
    if self.activeTab == "sell" then
      self:PopulateSell()
    end
  end

  function PANEL:Close()
    if self.closing then return end

    if IsValid(self.listForm) then
      self.listForm:Remove()
    end

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
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)

    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self:Center()

    if IsValid(self.navBar) and IsValid(self.pageLabel) then
      local nbW = self.navBar:GetWide()
      local nbH = self.navBar:GetTall()

      self.pageLabel:SetPos(
        nbW / 2 - self.pageLabel:GetWide() / 2,
        nbH / 2 - self.pageLabel:GetTall() / 2
      )

      if IsValid(self.nextButton) then
        self.nextButton:SetPos(nbW - 120, 0)
      end
    end
  end

  vgui.Register("versus_Auction", PANEL, "EditablePanel")
end
