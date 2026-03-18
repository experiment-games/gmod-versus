local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    PLUGIN.armorWelderPanel = self

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
    self.titleLabel:SetText("ARMOR WELDER")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, 0)

    -- Info text
    self.infoLabel = vgui.Create("DLabel", self.contentPanel)
    self.infoLabel:SetFont("VersusDefault")
    self.infoLabel:SetTextColor(Color(180, 190, 200, 255))
    self.infoLabel:SetText(
      "Bring your worn armor back to peak condition. Repairs cost " ..
      versus.util.formatMoney(PLUGIN.armorHitPointCost) .. " per hitpoint restored."
    )
    self.infoLabel:SetWrap(true)
    self.infoLabel:SetAutoStretchVertical(true)
    self.infoLabel:Dock(TOP)
    self.infoLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)

    -- Inventory panel filtered to armor with maxHealth
    self.inventoryPanel = vgui.Create("versus_Inventory", self.contentPanel)
    self.inventoryPanel:Dock(FILL)
    self.inventoryPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.inventoryPanel:SetDisableSettings(true)
    self.inventoryPanel:SetItemsPerRow(3)
    self.inventoryPanel:SetItemFilter(function(item)
      return item.maxHealth ~= nil and item.maxHealth > 0
    end)

    -- Set custom item actions
    self.inventoryPanel:SetOverrideItemActions(function(stackData)
      return self:CreateRepairMenu(stackData)
    end)

    -- Primary action repairs the first item in the stack to full
    self.inventoryPanel:SetOverrideItemPrimaryAction({
      label = "Repair",
      callback = function(stackData)
        local repairCost = PLUGIN.getRepairCost(stackData.item)

        if repairCost == nil then return end

        if repairCost == 0 then
          versus.message.notify("This item is already fully repaired!", NOTIFY_GENERIC)
          return
        end

        self:RepairItem(stackData.keys[1], repairCost, stackData.item.name)
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
    self.inventoryPanel:Refresh()
  end

  function PANEL:CreateRepairMenu(stackData)
    local menu = DermaMenu()

    if not stackData or not stackData.item then
      return
    end

    local item = stackData.item
    local repairCost = PLUGIN.getRepairCost(item)

    if repairCost == nil then
      menu:AddOption("This item cannot be repaired.")
      menu:Open()
      return
    end

    if repairCost == 0 then
      menu:AddOption("Already fully repaired.")
      menu:Open()
      return
    end

    menu:AddOption(
      "Repair for " .. versus.util.formatMoney(repairCost),
      function()
        self:RepairItem(stackData.keys[1], repairCost, item.name)
      end
    )

    menu:Open()
  end

  function PANEL:RepairItem(itemKey, repairCost, itemName)
    if not itemKey then return end

    local confirmText = string.format(
      "Repair %s for %s?\n\nThis will restore it to full condition.",
      itemName,
      versus.util.formatMoney(repairCost)
    )

    versus.panel.query(
      confirmText,
      "Confirm Repair",
      "Yes, Repair",
      function()
        net.Start("versus.npc.repairItem")
        net.WriteUInt(itemKey, 32)
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

  vgui.Register("versus_ArmorWelder", PANEL, "EditablePanel")
end
