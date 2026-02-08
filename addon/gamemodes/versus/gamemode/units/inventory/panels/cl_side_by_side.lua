local UNIT = UNIT

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    local function dropAction(itemPanel)
      -- Check if we're in a side-by-side view and over the other inventory panel
      if IsValid(itemPanel.inventoryParent) then
        local mx, my = input.GetCursorPos()
        local leftPanel = self.leftPanel
        local rightPanel = self.rightPanel
        local targetPanel = nil

        -- Determine which panel we're dragging from and find the target
        if itemPanel.inventoryParent == leftPanel then
          -- Dragging from left (player inventory) to right (chest)
          if IsValid(rightPanel) then
            local rx, ry = rightPanel:LocalToScreen(0, 0)
            local rw, rh = rightPanel:GetSize()

            if mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh then
              targetPanel = rightPanel
              itemPanel:MoveItemToChest()
              itemPanel:StopDragging()
              return
            end
          end
        elseif itemPanel.inventoryParent == rightPanel then
          -- Dragging from right (chest) to left (player inventory)
          if IsValid(leftPanel) then
            local lx, ly = leftPanel:LocalToScreen(0, 0)
            local lw, lh = leftPanel:GetSize()

            if mx >= lx and mx <= lx + lw and my >= ly and my <= ly + lh then
              targetPanel = leftPanel
              itemPanel:MoveItemFromChest()
              itemPanel:StopDragging()
              return
            end
          end
        end
      end
    end

    local function makeItemActions(directionAction)
      return true -- Just hide default actions for now

      -- TODO: Make this work, can't send keys as they shift :/
      -- return function(stackData)
      --   local menu = DermaMenu()

      --   -- Move all in stack action
      --   menu:AddOption("Move All", function()
      --       for _, itemKey in pairs(stackData.keys) do
      --           versus.command.run("chest", UNIT.currentNamedInventory, directionAction, itemKey)
      --       end
      --   end)

      --   menu:Open()
      -- end
    end

    -- Create container for both inventories
    self.container = vgui.Create("Panel", self)
    self.container:Dock(FILL)

    -- Left panel: Player inventory
    self.leftPanel = vgui.Create("versus_Inventory", self.container)
    self.leftPanel:Dock(LEFT)
    self.leftPanel:SetWide(self:GetWide() / 2 - GAMEMODE.SPACING / 2)
    self.leftPanel:DockMargin(0, 0, GAMEMODE.SPACING / 2, 0)
    self.leftPanel:SetInventory(UNIT.stored, "inventory")
    self.leftPanel:SetOverrideItemActions(makeItemActions("move_to"))
    self.leftPanel:SetDisableSettings(true)
    self.leftPanel:SetDropAction(dropAction)

    -- Right panel: Named inventory (chest)
    self.rightPanel = vgui.Create("versus_Inventory", self.container)
    self.rightPanel:Dock(FILL)
    self.rightPanel:DockMargin(GAMEMODE.SPACING / 2, 0, 0, 0)
    self.rightPanel:SetInventory({}, "chest") -- Initialize with empty inventory
    self.rightPanel:SetOverrideItemActions(makeItemActions("move_from"))
    self.rightPanel:SetDisableSettings(true)
    self.rightPanel:SetDropAction(dropAction)

    self.namedInventoryName = nil
  end

  function PANEL:SetNamedInventory(chestName)
    self.namedInventoryName = chestName

    self.rightPanel.inventoryLabel = "Storage"

    local namedInventory = UNIT.namedInventories[chestName]

    if (namedInventory and namedInventory.inventory) then
      self.rightPanel:SetInventory(namedInventory.inventory, "chest")
      self.rightPanel.inventoryMaxSize = namedInventory.maxSize or 100
    else
      -- If named inventory doesn't exist yet, set empty
      self.rightPanel:SetInventory({}, "chest")
      self.rightPanel.inventoryMaxSize = 100
    end

    -- Set label for player inventory and ensure it's using the correct inventory
    self.leftPanel:SetInventory(UNIT.stored, "inventory")
    self.leftPanel.inventoryLabel = "Your Inventory"

    -- Update both panels
    self.leftPanel:Refresh()
    self.rightPanel:Refresh()
  end

  function PANEL:PerformLayout(width, height)
    -- Update widths when resized
    local halfWidth = (width - GAMEMODE.SPACING) / 2
    self.leftPanel:SetWide(halfWidth)
  end

  function PANEL:Think()
    if (UNIT.updatePanel) then
      UNIT.updatePanel = false

      if (IsValid(self.leftPanel)) then
        -- Refresh the player inventory reference
        self.leftPanel:SetInventory(UNIT.stored, "inventory")
        self.leftPanel.updatePanel = true
      end

      if (IsValid(self.rightPanel) and self.namedInventoryName) then
        -- Refresh the named inventory reference
        local namedInventory = UNIT.namedInventories[self.namedInventoryName]
        if (namedInventory and namedInventory.inventory) then
          self.rightPanel:SetInventory(namedInventory.inventory, "chest")
        end
        self.rightPanel.updatePanel = true
      end
    end

    -- Check distance to named inventory position
    if (self.namedInventoryName and UNIT.currentNamedInventoryPosition) then
      local distance = LocalPlayer():GetPos():Distance(UNIT.currentNamedInventoryPosition)

      if (distance > UNIT.namedInventoryMaxDistance) then
        -- Player moved too far away, close the frame
        if IsValid(UNIT.namedInventoryTransferPanel) then
          UNIT.namedInventoryTransferPanel:Close()
        end
      end
    end
  end

  function PANEL:OnRemove()
    -- Clean up dragging state from child panels
    if IsValid(self.leftPanel) and self.leftPanel.OnMenuHidden then
      self.leftPanel:OnMenuHidden()
    end

    if IsValid(self.rightPanel) and self.rightPanel.OnMenuHidden then
      self.rightPanel:OnMenuHidden()
    end
  end

  vgui.Register("versus_Inventory_SideBySide", PANEL, "Panel")
end
