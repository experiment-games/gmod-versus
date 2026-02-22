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

    -- Main content container
    self.contentPanel = vgui.Create("DSizeToContents", self)
    self.contentPanel:SetSizeX(false)

    local headingContainer = vgui.Create("EditablePanel", self.contentPanel)
    headingContainer:Dock(TOP)
    headingContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Title label
    self.titleLabel = vgui.Create("DLabel", headingContainer)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("Purchase this room")
    self.titleLabel:SetContentAlignment(5)
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(FILL)

    headingContainer:SetTall(self.titleLabel:GetTall())

    self.moneyDisplay = vgui.Create("versus_MoneyDisplay", headingContainer)
    self.moneyDisplay:Dock(RIGHT)
    self.moneyDisplay:DockMargin(GAMEMODE.SPACING, 0, 0, 0)
    self.moneyDisplay:SizeToContents()

    -- Price label
    self.priceLabel = vgui.Create("DLabel", self.contentPanel)
    self.priceLabel:SetFont("VersusHeadingHuge")
    self.priceLabel:SetTextColor(Color(80, 140, 220, 255))
    self.priceLabel:SetText("")
    self.priceLabel:SetContentAlignment(5)
    self.priceLabel:Dock(TOP)
    self.priceLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.descriptionLabel = vgui.Create("DLabel", self.contentPanel)
    self.descriptionLabel:SetFont("VersusDefault")
    self.descriptionLabel:SetTextColor(Color(180, 190, 200, 255))
    self.descriptionLabel:SetText(
      "Inside your room, you can place your earnings from contracts, display trophies, and more! Each room is its own separate instance, so you can only see the things you place in there.")
    self.descriptionLabel:SetWrap(true)
    self.descriptionLabel:SetAutoStretchVertical(true)
    self.descriptionLabel:Dock(TOP)
    self.descriptionLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)

    -- Button container
    local buttonContainer = vgui.Create("DSizeToContents", self.contentPanel)
    buttonContainer:Dock(TOP)
    buttonContainer:DockMargin(0, GAMEMODE.SPACING, 0, GAMEMODE.SPACING)
    buttonContainer:SetSizeX(false)

    -- Purchase button
    self.purchaseButton = vgui.Create("versus_Button", buttonContainer)
    self.purchaseButton:SetText("PURCHASE")
    self.purchaseButton:Dock(TOP)
    self.purchaseButton:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)
    self.purchaseButton:SetType("primary")
    self.purchaseButton:SetRequireHoldToClick(true)
    self.purchaseButton.DoClick = function()
      self:OnPurchase()
    end

    -- Cancel button
    self.cancelButton = vgui.Create("versus_Button", buttonContainer)
    self.cancelButton:SetText("CANCEL")
    self.cancelButton:Dock(TOP)
    self.cancelButton:SetType("secondary")
    self.cancelButton.DoClick = function()
      self:OnCancel()
    end
  end

  function PANEL:SetRoomData(roomID, priceScale)
    self.roomID = roomID
    self.priceScale = priceScale
    local price = priceScale * PLUGIN.baseRoomPrice
    self.priceLabel:SetText(versus.util.formatMoney(price))
    self.priceLabel:SizeToContents()

    local canAfford, deficit = versus.finance.canAfford(price)

    if not canAfford then
      self.priceLabel:SetTextColor(Color(220, 80, 80, 255))
      self.purchaseButton:SetEnabled(false)
      self.descriptionLabel:SetText(
        "You need another " ..
        versus.util.formatMoney(deficit) .. " to purchase this room. Earn more money from contracts to afford it!")
    else
      self.priceLabel:SetTextColor(Color(80, 140, 220, 255))
      self.purchaseButton:SetEnabled(true)
      self.descriptionLabel:SetText(
        "Inside your room, you can place your earnings from contracts, display trophies, and more! Each room is its own separate instance, so you can only see the things you place in there.")
    end
  end

  function PANEL:OnPurchase()
    if self.closing then
      return
    end

    net.Start("versus.housing.purchaseRoom")
    net.WriteString(self.roomID)
    net.SendToServer()

    self:Close()
  end

  function PANEL:OnCancel()
    self:Close()
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

  vgui.Register("versus_RoomPurchaseScreen", PANEL, "EditablePanel")
end

net.Receive("versus.housing.showRoomPurchaseScreen", function()
  local roomID = net.ReadString()
  local priceScale = net.ReadFloat()

  local panel = vgui.Create("versus_RoomPurchaseScreen")
  panel:SetRoomData(roomID, priceScale)
end)
