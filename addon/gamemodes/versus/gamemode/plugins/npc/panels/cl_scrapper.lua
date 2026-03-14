local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    PLUGIN.scrapperPanel = self

    self:SetSize(
      math.max(ScrW() * 0.5, 700),
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
    self.titleLabel:SetText("SCRAPPER")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, 0)

    -- Info text
    self.infoLabel = vgui.Create("DLabel", self.contentPanel)
    self.infoLabel:SetFont("VersusDefault")
    self.infoLabel:SetTextColor(Color(180, 190, 200, 255))
    self.infoLabel:SetText(
      "Certain items from your inventory can be scrapped for cash. There's no going back, so choose wisely!"
    )
    self.infoLabel:SetWrap(true)
    self.infoLabel:SetAutoStretchVertical(true)
    self.infoLabel:Dock(TOP)
    self.infoLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)

    -- Inventory panel with custom scrap actions
    self.inventoryPanel = vgui.Create("versus_Inventory", self.contentPanel)
    self.inventoryPanel:Dock(FILL)
    self.inventoryPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.inventoryPanel:SetDisableSettings(true)
    self.inventoryPanel:SetItemsPerRow(3)
    self.inventoryPanel:SetItemFilter(function(item)
      return PLUGIN.getScrapValue(item) ~= nil
    end)

    -- Set custom item actions for scrapping
    self.inventoryPanel:SetOverrideItemActions(function(stackData)
      return self:CreateScrapMenu(stackData)
    end)

    -- Set the main action to scrapping all
    self.inventoryPanel:SetOverrideItemPrimaryAction({
      label = "Scrap All",
      callback = function(stackData)
        local scrapValue = PLUGIN.getScrapValue(stackData.item)

        if scrapValue then
          local totalValue = scrapValue * stackData.count
          self:ScrapItem(stackData.keys[1], stackData.count, totalValue)
        end
      end
    })

    -- Bottom button container
    local buttonContainer = vgui.Create("EditablePanel", self.contentPanel)
    buttonContainer:Dock(BOTTOM)
    buttonContainer:SetTall(50)

    self.cancelButton = vgui.Create("versus_Button", buttonContainer)
    self.cancelButton:SetText("CLOSE")
    self.cancelButton:Dock(FILL)
    self.cancelButton:SetType("secondary")
    self.cancelButton.DoClick = function()
      self:Close()
    end
  end

  function PANEL:Populate()
    -- Set the inventory to the player's inventory
    self.inventoryPanel:SetInventory(versus.inventory.stored, "inventory")
    self.inventoryPanel:Refresh()
  end

  function PANEL:CreateScrapMenu(stackData)
    local menu = DermaMenu()

    if not stackData or not stackData.item then
      return
    end

    local item = stackData.item
    local scrapValue = PLUGIN.getScrapValue(item)

    -- Scrap single item
    menu:AddOption("Scrap 1x for " .. versus.util.formatMoney(scrapValue), function()
      self:ScrapItem(stackData.keys[1], 1, scrapValue)
    end)

    -- Scrap all items in stack
    if stackData.count > 1 then
      local totalValue = scrapValue * stackData.count
      menu:AddOption("Scrap All (" .. stackData.count .. "x) for " .. versus.util.formatMoney(totalValue), function()
        self:ScrapItem(stackData.keys[1], stackData.count, totalValue)
      end)

      -- Scrap half
      local halfAmount = math.ceil(stackData.count * 0.5)
      local halfValue = scrapValue * halfAmount
      menu:AddOption("Scrap Half (" .. halfAmount .. "x) for " .. versus.util.formatMoney(halfValue), function()
        self:ScrapItem(stackData.keys[1], halfAmount, halfValue)
      end)

      -- Scrap custom amount
      menu:AddOption("Scrap Amount...", function()
        versus.panel.stringRequest(
          "Scrap Amount",
          "Enter the amount to scrap (Value per item: " .. versus.util.formatMoney(scrapValue) .. "):",
          "",
          function(text)
            local amount = tonumber(text)

            if amount and amount > 0 and amount <= stackData.count then
              local value = scrapValue * amount
              self:ScrapItem(stackData.keys[1], amount, value)
            else
              versus.message.notify("Invalid amount entered!", NOTIFY_ERROR)
            end
          end
        )
      end)
    end

    menu:Open()
  end

  function PANEL:ScrapItem(itemKey, amount, totalValue)
    if not itemKey then return end

    -- Confirm the scrap action
    local confirmText = string.format(
      "Are you sure you want to scrap %dx for %s?\n\nThis action cannot be undone!",
      amount,
      versus.util.formatMoney(totalValue)
    )

    versus.panel.query(
      confirmText,
      "Confirm Scrap",
      "Yes, Scrap",
      function()
        net.Start("versus.npc.scrapItem")
        net.WriteUInt(itemKey, 16)
        net.WriteUInt(amount, 16)
        net.SendToServer()

        surface.PlaySound("buttons/button14.wav")
      end,
      "Cancel",
      function()
        -- Do nothing
      end
    )
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

  vgui.Register("versus_Scrapper", PANEL, "EditablePanel")
end
