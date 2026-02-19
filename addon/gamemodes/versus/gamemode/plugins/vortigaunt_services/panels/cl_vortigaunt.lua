local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    PLUGIN.vortigauntPanel = self

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
    self.titleLabel:SetTextColor(PLUGIN.XEN_COLOR)
    self.titleLabel:SetText("VORTIGAUNT")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, 0)

    self.infoLabel = vgui.Create("DLabel", self.contentPanel)
    self.infoLabel:SetFont("VersusDefault")
    self.infoLabel:SetTextColor(Color(180, 190, 200, 255))
    self.infoLabel:SetText(
      "The Vortigaunt can channel raw Xen energy into your weapons, " ..
      "making them more effective against NPCs. Each weapon can only be infused once " ..
      "and the result cannot be undone. The effectiveness is random."
    )
    self.infoLabel:SetWrap(true)
    self.infoLabel:SetAutoStretchVertical(true)
    self.infoLabel:Dock(TOP)
    self.infoLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    self.costLabel = vgui.Create("DLabel", self.contentPanel)
    self.costLabel:SetFont("VersusDefault")
    self.costLabel:SetTextColor(PLUGIN.XEN_COLOR)
    self.costLabel:SetText("Cost: " .. versus.util.formatMoney(PLUGIN.UPGRADE_COST) .. " per weapon")
    self.costLabel:SizeToContents()
    self.costLabel:Dock(TOP)
    self.costLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    self.inventoryPanel = vgui.Create("versus_Inventory", self.contentPanel)
    self.inventoryPanel:Dock(FILL)
    self.inventoryPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.inventoryPanel:SetDisableSettings(true)
    self.inventoryPanel:SetItemsPerRow(3)
    self.inventoryPanel:SetItemFilter(function(item)
      return item.isWeapon == true
    end)

    self.inventoryPanel:SetOverrideItemActions(function(stackData)
      return self:CreateUpgradeMenu(stackData)
    end)

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
    self.inventoryPanel:SetInventory(versus.inventory.stored, "inventory")
    self.inventoryPanel:Refresh()
  end

  function PANEL:CreateUpgradeMenu(stackData)
    local menu = DermaMenu()

    if not stackData or not stackData.item then
      return
    end

    local item = stackData.item

    if (item.xenEnergy ~= nil) then
      local percent = math.floor(item.xenEnergy * 100)
      menu:AddOption(string.format("Already Infused (%d%% Xen Energy)", percent), function() end)
        :SetEnabled(false)
    else
      menu:AddOption(
        string.format("Infuse with Xen Energy (%s)", versus.util.formatMoney(PLUGIN.UPGRADE_COST)),
        function()
          self:UpgradeWeapon(stackData.keys[1], item)
        end
      )
    end

    menu:Open()
  end

  function PANEL:UpgradeWeapon(itemKey, item)
    if not itemKey then return end

    local confirmText = string.format(
      "Are you sure you want the Vortigaunt to infuse %s with Xen energy for %s?\n\n" ..
      "The effectiveness is random and cannot be undone!",
      item.name,
      versus.util.formatMoney(PLUGIN.UPGRADE_COST)
    )

    versus.panel.query(
      confirmText,
      "Confirm Xen Infusion",
      "Yes, Infuse",
      function()
        net.Start("versus.vortigaunt.upgradeWeapon")
        net.WriteUInt(itemKey, versus.inventory.bitSizeItemKeys)
        net.SendToServer()

        surface.PlaySound("ambient/energy/spark6.wav")
      end,
      "Cancel",
      function()
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
    self.contentPanel:SetWide(self:GetWide() - GAMEMODE.SPACING * 2)
    self.contentPanel:SetTall(h)
    self.contentPanel:Center()

    self:Center()
  end

  vgui.Register("versus_Vortigaunt", PANEL, "EditablePanel")
end

hook.Add("InventoryItemGivenNetworked", "versus.vortigauntRefresh", function(item)
  if IsValid(PLUGIN.vortigauntPanel) then
    PLUGIN.vortigauntPanel:Populate()
  end
end)

hook.Add("InventoryItemTakenNetworked", "versus.vortigauntRefresh", function(itemKey)
  if IsValid(PLUGIN.vortigauntPanel) then
    PLUGIN.vortigauntPanel:Populate()
  end
end)

hook.Add("InventoryEntireInventoryNetworked", "versus.vortigauntRefresh", function()
  if IsValid(PLUGIN.vortigauntPanel) then
    PLUGIN.vortigauntPanel:Populate()
  end
end)

hook.Add("InventoryItemOverridesNetworked", "versus.vortigauntRefresh", function(item)
  if IsValid(PLUGIN.vortigauntPanel) then
    PLUGIN.vortigauntPanel:Populate()
  end
end)
