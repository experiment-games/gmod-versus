local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(
      math.max(ScrW() * 0.5, 600),
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

    self.contentPanel = vgui.Create("EditablePanel", self)
    self.contentPanel:DockPadding(
      GAMEMODE.SPACING,
      GAMEMODE.SPACING,
      GAMEMODE.SPACING,
      GAMEMODE.SPACING
    )

    self.titleLabel = vgui.Create("DLabel", self.contentPanel)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("SHOP")
    self.titleLabel:SetContentAlignment(5)
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.shopItemsContainer = vgui.Create("versus_ScrollPanel", self.contentPanel)
    self.shopItemsContainer:Dock(FILL)
    self.shopItemsContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.cancelButton = vgui.Create("versus_Button", self.contentPanel)
    self.cancelButton:SetText("CANCEL")
    self.cancelButton:Dock(BOTTOM)
    self.cancelButton:SetType("secondary")
    self.cancelButton.DoClick = function()
      self:Close()
    end
  end

  function PANEL:Populate(shopID)
    self.titleLabel:SetText(shopID:upper())
    self.shopItemsContainer:Clear()

    local allItems = versus.item.all()
    local filteredItems = {}

    for _, item in pairs(allItems) do
      if (item.seller and table.HasValue(item.seller, shopID)) then
        table.insert(filteredItems, item)
      end
    end

    -- Sort by cost and name
    table.sort(filteredItems, function(a, b)
      if a.cost == b.cost then
        return a.name < b.name
      end

      return a.cost < b.cost
    end)

    for _, item in ipairs(filteredItems) do
      local itemPanel = vgui.Create("versus_ShopItem", self.shopItemsContainer)
      itemPanel:SetItem(item)
      self.shopItemsContainer:AddItem(itemPanel)
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
    self.contentPanel:SetTall(h)
    self.contentPanel:Center()

    self:Center()
  end

  vgui.Register("versus_Shop", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    self:Dock(TOP)
    self:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)

    self.isHovered = false
    self:SetMouseInputEnabled(true)

    -- Left container for the 3D model
    self.leftContainer = vgui.Create("EditablePanel", self)
    self.leftContainer:Dock(LEFT)
    self.leftContainer:SetMouseInputEnabled(false)

    -- 3D Item Model Panel
    self.itemModel = vgui.Create("versus_ItemModelPanel", self.leftContainer)
    self.itemModel:Dock(FILL)
    self.itemModel:SetMouseInputEnabled(false)

    -- Right container for the purchase button
    self.rightContainer = vgui.Create("EditablePanel", self)
    self.rightContainer:SetWide(200)
    self.rightContainer:Dock(RIGHT)
    self.rightContainer:DockPadding(0, 10, 10, 10)

    -- Center container for item info
    self.centerContainer = vgui.Create("EditablePanel", self)
    self.centerContainer:Dock(FILL)
    self.centerContainer:DockPadding(10, 10, 10, 10)

    -- Item Name label
    self.itemNameLabel = vgui.Create("DLabel", self.centerContainer)
    self.itemNameLabel:SetFont("VersusHeading3")
    self.itemNameLabel:SetTextColor(Color(220, 230, 240, 255))
    self.itemNameLabel:SetText("Loading...")
    self.itemNameLabel:Dock(TOP)
    self.itemNameLabel:SizeToContents()

    -- Item Description label
    self.descriptionLabel = vgui.Create("DLabel", self.centerContainer)
    self.descriptionLabel:SetFont("VersusDefault")
    self.descriptionLabel:SetTextColor(Color(140, 150, 160, 255))
    self.descriptionLabel:Dock(TOP)
    self.descriptionLabel:SizeToContents()

    -- Item Category/Type label
    self.categoryLabel = vgui.Create("DLabel", self.centerContainer)
    self.categoryLabel:SetFont("VersusDefault")
    self.categoryLabel:SetTextColor(Color(180, 190, 200, 255))
    self.categoryLabel:Dock(TOP)
    self.categoryLabel:DockMargin(0, 10, 0, 0)
    self.categoryLabel:SetVisible(false)

    -- Purchase button
    self.purchaseButton = vgui.Create("versus_Button", self.rightContainer)
    self.purchaseButton:SetText("BUY")
    self.purchaseButton:Dock(BOTTOM)
    self.purchaseButton:DockMargin(0, 0, 0, 0)
    self.purchaseButton:SetType("primary")
    -- self.purchaseButton:SetRequireHoldToClick(true)

    -- Price label
    self.priceLabel = vgui.Create("DLabel", self.rightContainer)
    self.priceLabel:SetFont("VersusDefault")
    self.priceLabel:SetTextColor(Color(120, 200, 120, 255))
    self.priceLabel:Dock(TOP)
    self.priceLabel:SetVisible(false)
    self.priceLabel:SetContentAlignment(5)
  end

  function PANEL:SetItem(item)
    self.item = item

    if not item then return end

    self.itemModel:SetItem(item)

    -- Set item name
    local itemName = item.name or "Unknown Item"
    self.itemNameLabel:SetText(itemName)
    self.itemNameLabel:SizeToContents()

    -- Set description
    local description = item.description or ""
    if description ~= "" then
      -- Limit description length for display
      if #description > 60 then
        description = string.sub(description, 1, 57) .. "..."
      end
      self.descriptionLabel:SetText(description)
      self.descriptionLabel:SizeToContents()
    else
      self.descriptionLabel:SetVisible(false)
    end

    -- Set category/type
    local category = item.category
    if category then
      self.categoryLabel:SetText(tostring(category))
      self.categoryLabel:SetVisible(true)
      self.categoryLabel:SizeToContents()
    end

    -- Set price with currency formatting
    local cost = item.cost or 0
    self.priceLabel:SetText(versus.util.formatMoney(cost))
    self.priceLabel:SetVisible(true)
    self.priceLabel:SizeToContents()

    -- Setup purchase button
    self.purchaseButton.DoClick = function()
      self:OnPurchase()
    end

    self.DoClick = function()
      self:OnPurchase()
    end

    -- Check if player can afford
    self:UpdateAffordability()
    self:SizeToContents()
  end

  function PANEL:UpdateAffordability()
    if not self.item then return end

    local playerMoney = versus.finance.getMoney()
    local cost = self.item.cost or 0

    if playerMoney >= cost then
      self.priceLabel:SetTextColor(Color(120, 200, 120, 255)) -- Green if affordable
      self.purchaseButton:SetEnabled(true)
    else
      self.priceLabel:SetTextColor(Color(220, 80, 80, 255)) -- Red if too expensive
      self.purchaseButton:SetEnabled(false)
    end
  end

  function PANEL:OnPurchase()
    if not self.item then return end

    -- Send purchase request to server
    net.Start("versus_PurchaseItem")
    net.WriteString(self.item.uniqueID or self.item.id or "")
    net.SendToServer()

    -- Play a sound effect
    surface.PlaySound("buttons/button14.wav")
  end

  function PANEL:Think()
    -- Periodically update affordability
    if self.item and (not self.nextAffordCheck or CurTime() > self.nextAffordCheck) then
      self:UpdateAffordability()
      self.nextAffordCheck = CurTime() + 0.5
    end
  end

  function PANEL:Paint(w, h)
    -- Draw background with hover effect
    local bgColor = self.isHovered and Color(40, 45, 52, 220) or Color(30, 35, 40, 200)
    draw.RoundedBox(16, 0, 0, w, h, bgColor)

    -- Draw accent line on left (behind the model)
    local accentColor = self.isHovered and Color(90, 160, 240, 230) or Color(80, 140, 220, 200)
    draw.RoundedBoxEx(16, 0, 0, self.leftContainer:GetWide(), h, accentColor, true, false, true, false)
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

    self.purchaseButton:SetHovered(true)
    self.isHovered = true
  end

  function PANEL:OnCursorExited()
    if not self:IsEnabled() then return end

    self.purchaseButton:SetHovered(false)
    self.isHovered = false
  end

  -- Size based on the title, description, and price labels, with a minimum height to accommodate the model and button
  function PANEL:SizeToContents()
    local titleHeight = self.itemNameLabel:GetTall()
    local descriptionHeight = self.descriptionLabel:GetTall()
    local categoryHeight = self.categoryLabel:GetTall()
    local priceHeight = self.priceLabel:GetTall()

    -- Also account for the padding between elements
    local titleLeft, titleTop, titleRight, titleBottom = self.itemNameLabel:GetDockMargin()
    local descriptionLeft, descriptionTop, descriptionRight, descriptionBottom = self.descriptionLabel:GetDockMargin()
    local categoryLeft, categoryTop, categoryRight, categoryBottom = self.categoryLabel:GetDockMargin()
    local priceLeft, priceTop, priceRight, priceBottom = self.priceLabel:GetDockMargin()

    local contentHeight = titleHeight + descriptionHeight + categoryHeight + priceHeight
        + titleTop + titleBottom
        + descriptionTop + descriptionBottom
        + categoryTop + categoryBottom
        + priceTop + priceBottom

    self.leftContainer:SetWide(contentHeight)
    self:SetTall(contentHeight)
  end

  vgui.Register("versus_ShopItem", PANEL, "EditablePanel")
end
