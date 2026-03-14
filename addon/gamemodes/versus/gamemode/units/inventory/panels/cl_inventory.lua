local UNIT = UNIT
local SPACING = 16

local COLOR_ACCENT = Color(255, 200, 80, 255)

-- Stack identical items together
local function stackItems(items)
  local stacked = {}

  for key, item in pairs(items) do
    if item.notInInventory then
      continue
    end

    local safeData = item:getSafeData()
    local foundStack = false

    -- Check if this item matches any existing stack
    for stackKey, stackData in pairs(stacked) do
      local stackSafeData = stackData.item:getSafeData()

      if versus.item.dataEqual(safeData, stackSafeData) then
        -- Add to existing stack
        stackData.count = stackData.count + 1
        table.insert(stackData.keys, key)
        foundStack = true
        break
      end
    end

    -- Create new stack if no match found
    if not foundStack then
      stacked[key] = {
        item = item,
        count = 1,
        keys = { key }
      }
    end
  end

  return stacked
end

do
  local PANEL = {}
  AccessorFunc(PANEL, "itemFilter", "ItemFilter")
  AccessorFunc(PANEL, "itemsPerRow", "ItemsPerRow", FORCE_NUMBER)
  AccessorFunc(PANEL, "overrideItemPrimaryAction", "OverrideItemPrimaryAction")
  AccessorFunc(PANEL, "overrideItemActions", "OverrideItemActions")
  AccessorFunc(PANEL, "disableSettings", "DisableSettings", FORCE_BOOL)
  AccessorFunc(PANEL, "dropAction", "DropAction")
  AccessorFunc(PANEL, "showMoneyDisplay", "ShowMoneyDisplay", FORCE_BOOL)

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self:SetItemsPerRow(3)
    self:SetShowMoneyDisplay(true)

    self.header = self:Add(vgui.Create("versus_Inventory_Information", self))
    self.header:Dock(TOP)
    self.header:DockMargin(0, 0, 0, SPACING)
    self.header:SetFilterCallback(function(query)
      self.searchQuery = query

      self:Rebuild(self:GetInventoryCategorized())
    end)

    self.footer = self:Add(vgui.Create("DSizeToContents", self))
    self.footer:SetSizeX(false)
    self.footer:Dock(BOTTOM)

    hook.Run("BuildInventoryFooter", self.footer)

    self.settings = self.footer:Add(vgui.Create("versus_Inventory_Settings", self.footer))
    self.settings:Dock(TOP)

    -- Ghost panel for dragging
    self.ghostPanel = nil
    self.draggingItem = nil
    self.isDragging = false

    self.scrollPanel = vgui.Create("versus_ScrollPanel", self)
    self.scrollPanel:Dock(FILL)
    self.itemLists = {}

    self.updatePanel = true

    hook.Add("InventoryNeedsRefresh", self, function()
      self.updatePanel = true
    end)

    self:Think()
  end

  function PANEL:SetInventory(inventory, inventoryCommand)
    self.inventory = inventory
    self.inventoryCommand = inventoryCommand

    self.updatePanel = true
  end

  function PANEL:GetInventory()
    return self.inventory or UNIT.stored,
        self.inventoryCommand or "inventory"
  end

  function PANEL:GetInventoryCategorized()
    local inventory, inventoryCommand = self:GetInventory()
    local inventories = {}

    for key, item in pairs(inventory) do
      if (item.notInInventory) then
        continue
      end

      inventories[key] = item
    end

    if (UNIT.convarCategorize:GetBool()) then
      inventories = versus.item.groupByCategories(inventories)

      -- Stack items within each category
      for category, items in pairs(inventories) do
        inventories[category] = stackItems(items)
      end
    else
      -- Stack all items together
      local stackedItems = stackItems(inventories)
      inventories = {
        [versus.item.genericCategory] = stackedItems
      }
    end

    local query = self.searchQuery
    local filterFunc = self:GetItemFilter()

    if (query == nil and not filterFunc) then
      return inventories
    end

    local filtered = {}

    for category, items in pairs(inventories) do
      for key, stackData in pairs(items) do
        local item = stackData.item
        if ((not query or string.find(item.name:lower(), query, nil, true)) and (not filterFunc or filterFunc(item))) then
          filtered[category] = filtered[category] or {}
          table.insert(filtered[category], {
            _isInventoryFiltered = true,
            key = key,
            item = item,
            stackData = stackData
          })
        end
      end
    end

    return filtered
  end

  function PANEL:BuildItemsList(items, parent)
    local itemsList = vgui.Create("DIconLayout", parent)
    itemsList:SetWide(self:GetWide() - 8)
    itemsList:SetBorder(0)
    itemsList:SetSpaceX(SPACING)
    itemsList:SetSpaceY(SPACING)
    itemsList:SetStretchHeight(true)
    itemsList:Clear()

    local sortedKeys = {}
    for key in pairs(items or {}) do
      table.insert(sortedKeys, key)
    end

    table.sort(sortedKeys, function(a, b)
      local itemA = items[a]
      local itemB = items[b]

      if (itemA._isInventoryFiltered) then
        itemA = itemA.item
      elseif (itemA.item) then
        itemA = itemA.item
      end

      if (itemB._isInventoryFiltered) then
        itemB = itemB.item
      elseif (itemB.item) then
        itemB = itemB.item
      end

      return itemA.name < itemB.name
    end)

    local inventory, inventoryCommand = self:GetInventory()

    for _, key in ipairs(sortedKeys) do
      local stackData = items[key]
      local itemPanel = vgui.Create("versus_Inventory_Item", self)
      itemPanel:SetInventoryCommand(inventoryCommand)
      itemPanel:SetOverrideItemPrimaryAction(self:GetOverrideItemPrimaryAction())
      itemPanel:SetOverrideItemActions(self:GetOverrideItemActions())
      itemPanel:SetDropAction(self:GetDropAction())
      itemPanel.inventoryPanel = self

      if stackData._isInventoryFiltered then
        itemPanel:SetItem(stackData.key, stackData.item)
        itemPanel:SetStackData(stackData.stackData)
      else
        itemPanel:SetItem(key, stackData.item)
        itemPanel:SetStackData(stackData)
      end

      local listItem = itemsList:Add(itemPanel)
      listItem:SetSize(self.itemSize, self.itemSize)
    end

    return itemsList
  end

  function PANEL:Rebuild(inventories)
    self.header:SetShowMoneyDisplay(self:GetShowMoneyDisplay())
    self.header:Refresh()

    for _, itemList in pairs(self.itemLists) do
      if (IsValid(itemList)) then
        itemList:Remove()
      end
    end

    -- If empty, show a message
    local isEmpty = true

    for _, items in pairs(inventories) do
      if (table.Count(items) > 0) then
        isEmpty = false
        break
      end
    end

    if (isEmpty) then
      self:SetupEmptyState()
      return
    end

    if (UNIT.convarCategorize:GetBool() == false) then
      table.insert(self.itemLists, self:BuildItemsList(inventories[versus.item.genericCategory], self.scrollPanel))
    else
      local sortedCategories = table.GetKeys(inventories)
      table.sort(sortedCategories)

      for _, categoryName in pairs(sortedCategories) do
        if (table.Count(inventories[categoryName]) == 0) then
          continue
        end

        local category = vgui.Create("DCollapsibleCategory", self.scrollPanel)
        category:SetLabel(categoryName)
        category:Dock(TOP)
        category:DockMargin(0, SPACING, 0, 0)
        category:SetWide(self:GetWide())
        category:SetExpanded(true)
        category:SetHeaderHeight(42)
        category.Paint = function(_, width, height)
          GAMEMODE:DrawBackgroundBox(0, 0, width, height, ColorAlpha(color_background, 50))
        end

        table.insert(self.itemLists, category)

        local list = self:BuildItemsList(inventories[categoryName], category)
        list:SetPos(0, category:GetHeaderHeight())
      end
    end

    self.scrollPanel:Rebuild()
  end

  function PANEL:SetupEmptyState()
    for _, itemList in pairs(self.itemLists) do
      if (IsValid(itemList)) then
        itemList:Remove()
      end
    end

    local emptyPanel = vgui.Create("DSizeToContents", self.scrollPanel)
    self.emptyPanel = emptyPanel
    emptyPanel:SetWide(500)
    emptyPanel:SetSizeX(false)

    local emptyLabel = vgui.Create("DLabel", emptyPanel)
    local message = "Your inventory is empty."

    if (self.searchQuery and #self.searchQuery > 0) then
      message = "No items match your search."

      -- Add a clear search button
      local clearButton = vgui.Create("versus_Button", emptyPanel)
      clearButton:Dock(TOP)
      clearButton:DockMargin(0, SPACING, 0, 0)
      clearButton:SetText("Clear Search")
      clearButton:SizeToContents()
      clearButton.DoClick = function()
        self.searchQuery = nil
        self.header.searchBar:SetText("")
        self.updatePanel = true
      end
      self.itemLists = { emptyLabel, clearButton }
    else
      self.itemLists = { emptyLabel }
    end

    emptyLabel:Dock(TOP)
    emptyLabel:SetText(message)
    emptyLabel:SetFont("VersusDefaultOutlined")
    emptyLabel:SetContentAlignment(5)
    emptyLabel:SizeToContents()
    emptyPanel:CenterHorizontal()
  end

  function PANEL:Refresh()
    self.updatePanel = true

    if (IsValid(self.settings)) then
      self.settings:SetVisible(not self.disableSettings)
    end
  end

  function PANEL:SetDragging(dragging, item, stackData)
    self.isDragging = dragging

    if dragging and item then
      -- Create ghost panel without parent for screen coordinates
      if IsValid(self.ghostPanel) then
        self.ghostPanel:Remove()
      end

      self.ghostPanel = vgui.Create("versus_Inventory_ItemGhost")
      self.ghostPanel:SetItem(item)
      self.ghostPanel:SetStackData(stackData)
      self.ghostPanel:SetSize(128, 128)
      self.ghostPanel:SetZPos(9999)
      self.ghostPanel:SetMouseInputEnabled(false)
      self.ghostPanel:SetKeyboardInputEnabled(false)
      self.ghostPanel:SetPaintedManually(true)
      self.draggingItem = item

      versus.dragDrop.startDragSession(
        "inventory",
        {
          item = item,
          ghostPanel = self.ghostPanel,
        }
      )
    else
      -- Remove ghost panel
      if IsValid(self.ghostPanel) then
        self.ghostPanel:Remove()
        self.ghostPanel = nil
      end
      self.draggingItem = nil

      versus.dragDrop.endDragSession("inventory")
    end
  end

  function PANEL:OnMenuHidden()
    -- Stop dragging if menu is hidden
    if self.isDragging then
      self:SetDragging(false)
    end

    self.updatePanel = true
  end

  function PANEL:Think()
    if (self.updatePanel) then
      local scrollBar = self.scrollPanel:GetVBar()
      local oldScroll = scrollBar:GetScroll()
      local itemsPerRow = self:GetItemsPerRow()

      self.updatePanel = false

      self.itemSize = ((self:GetWide() - 8) / itemsPerRow) - ((SPACING * (itemsPerRow - 1)) / itemsPerRow)

      self:Rebuild(self:GetInventoryCategorized())

      versus.util.nextFrame(function()
        scrollBar:AnimateTo(oldScroll, 0.2)
      end, scrollBar)
    end

    -- Update ghost panel position in screen coordinates
    if IsValid(self.ghostPanel) and self.draggingItem then
      local x, y = input.GetCursorPos()
      self.ghostPanel:SetPos(x - 64, y - 64)
    end
  end

  function PANEL:PerformLayout(width, height)
    if (IsValid(self.emptyPanel)) then
      self.emptyPanel:CenterHorizontal()
    end
  end

  vgui.Register("versus_Inventory", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  DEFINE_BASECLASS("versus_Inventory")

  function PANEL:Init()
    hook.Add("InventoryNeedsRefresh", self, function()
      self.updatePanel = true
    end)
  end

  function PANEL:OnKeyCodePressed(keyCode)
    if (self.header.searchBar:HasFocus()) then
      return
    end

    if (keyCode == KEY_I and UNIT.convarInventoryShortcut:GetBool()) then
      if (LocalPlayer()._LastInventoryShortcut and LocalPlayer()._LastInventoryShortcut + 0.3 > CurTime()) then
        return
      end

      LocalPlayer()._LastInventoryShortcut = CurTime()
      versus.menu.toggle()
    end
  end

  function PANEL:OnMenuHidden()
    if (BaseClass.OnMenuHidden) then
      BaseClass.OnMenuHidden(self)
    end
  end

  vgui.Register("versus_Inventory_Player", PANEL, "versus_Inventory")
end

do
  local PANEL = {}

  DEFINE_BASECLASS("versus_DraggableItem")

  AccessorFunc(PANEL, "overrideItemPrimaryAction", "OverrideItemPrimaryAction")
  AccessorFunc(PANEL, "overrideItemActions", "OverrideItemActions")
  AccessorFunc(PANEL, "dropAction", "DropAction")

  function PANEL:Init()
    versus.panel.initPanelSkin(self)
  end

  function PANEL:SetItem(key, item)
    self.key = key
    self.item = item

    if (self.isAlreadyBuilt) then
      return
    end

    self.isAlreadyBuilt = true

    -- Enable dragging if item can be dropped
    if item.onDrop then
      self:Droppable("versus_inventory_item")
    end

    -- Covers most of the interactable area of the item
    self.modelPanel = vgui.Create("versus_ItemModelPanel", self)
    self.modelPanel:SetVersusTooltip(function(tooltip)
      local description = tooltip:AddRow("description")
      description:SetText(versus.util.resolve(item.description))
      description:SizeToContents()

      hook.Run("BuildItemTooltipRows", tooltip, item)

      if (not self.item.ammoType) then
        return
      end

      for _, weapon in ipairs(LocalPlayer():GetWeapons()) do
        if (not IsValid(weapon)) then
          return
        end

        local ammoType1 = weapon:GetPrimaryAmmoType()
        local ammoName1 = game.GetAmmoName(ammoType1)

        local ammoType2 = weapon:GetSecondaryAmmoType()
        local ammoName2 = game.GetAmmoName(ammoType2)

        -- Outline the item if we have a weapon equipped that can use this ammo
        if (ammoName1 == self.item.ammoType or ammoName2 == self.item.ammoType) then
          local hint = tooltip:AddRow("ammoHint" .. self.item.ammoType)
          hint:SetText("Your " .. weapon:GetPrintName() .. " can use this ammo!")
          hint:SetTextColor(COLOR_ACCENT)
        end
      end
    end)

    self.modelPanel:SetItem(item)
    self.modelPanel:SetFOV(item.inventoryFov or 80)
    self.modelPanel:SetSize(64, 64)
    self.modelPanel:SetAmbientLight(Color(200, 200, 200, 255))
    self.modelPanel.OnMousePressed = function(_, keyCode)
      self:OnMousePressed(keyCode)
    end

    self.size = vgui.Create("DLabel", self)
    if (item.size > 0) then
      self.size:SetText("(" .. item.size .. " kg)")
    elseif (item.size < 0) then
      self.size:SetText("(Space: +" .. math.abs(item.size) .. " kg)")
    else
      self.size:SetText("")
    end
    self.size:SetFont("VersusDefaultOutlined")
    self.size:SizeToContents()
    self.size:SetTextColor(color_white)
    self.size:SetAlpha(50)

    -- Stack count label (created here, text will be set in SetStackData)
    self.stackCount = vgui.Create("DLabel", self)
    self.stackCount:SetFont("VersusDefaultOutlined")
    self.stackCount:SetTextColor(color_white)
    self.stackCount:SetVisible(false)

    self:SetTooltip(versus.util.resolve(item.description))

    local overrideItemActions = self:GetOverrideItemActions()
    local primaryAction = self:GetOverrideItemPrimaryAction()

    if (primaryAction) then
      self.useButton = vgui.Create("versus_Button", self)
      self.useButton.isCustom = true
      self.useButton:SetText(primaryAction.label)
      self.useButton.DoClick = function()
        primaryAction.callback(self.stackData)
      end
    end

    if (overrideItemActions or isbool(overrideItemActions)) then
      if (isfunction(overrideItemActions)) then
        self.moreButton = vgui.Create("versus_Button", self)
        self.moreButton:SetText(UNIT.getItemButtonText(item, "..."))
        self.moreButton:SizeToContents()
        self.moreButton.DoClick = function()
          overrideItemActions(self.stackData)
        end
      end

      return
    end

    local itemFunctions = {}

    if (item.onDrop) then table.insert(itemFunctions, "Drop") end
    if (item.onDestroy) then table.insert(itemFunctions, "Permanently Destroy") end

    hook.Run("BuildInventoryItemFunctions", item, key, itemFunctions)

    if (#itemFunctions > 0) then
      self.moreButton = vgui.Create("versus_Button", self)
      self.moreButton:SetText(UNIT.getItemButtonText(item, "..."))
      self.moreButton:SizeToContents()
      self.moreButton.DoClick = function()
        local menu = self:BuildMoreMenu(itemFunctions)
        menu:Open()
      end
    end

    if (not primaryAction and item.onUse) then
      self.useButton = vgui.Create("versus_Button", self)
      self.useButton:SetText(UNIT.getItemButtonText(item, "Use"))
      self.useButton.DoClick = function()
        versus.command.run(self:GetInventoryCommand(), key, "use")
      end
    end
  end

  function PANEL:SetInventoryCommand(inventoryCommand)
    self.inventoryCommand = inventoryCommand
  end

  function PANEL:SetStackData(stackData)
    self.stackData = stackData

    if stackData and stackData.count and stackData.count > 1 then
      self.stackCount:SetText("x" .. stackData.count)
      self.stackCount:SizeToContents()
      self.stackCount:SetVisible(true)
    else
      self.stackCount:SetVisible(false)
    end
  end

  function PANEL:GetInventoryCommand()
    return self.inventoryCommand or "inventory"
  end

  function PANEL:Think()
    if self.item then
      if (IsValid(self.moreButton)) then
        self.moreButton:SetText(UNIT.getItemButtonText(self.item, "..."))
      end

      if (IsValid(self.useButton) and not self.useButton.isCustom) then
        self.useButton:SetText(UNIT.getItemButtonText(self.item, "Use"))
      end
    end

    BaseClass.Think(self)
  end

  function PANEL:DropItem()
    local key = self.key

    -- If this is a stack with multiple items, use the first item's key
    if self.stackData and self.stackData.count > 1 then
      key = self.stackData.keys[1]
    end

    versus.command.run(self:GetInventoryCommand(), key, "drop")
    versus.menu.toggle()

    self:_StopDrag(true)
  end

  function PANEL:EquipItem()
    local key = self.key

    -- If this is a stack with multiple items, use the first item's key
    if self.stackData and self.stackData.count > 1 then
      key = self.stackData.keys[1]
    end

    versus.command.run(self:GetInventoryCommand(), key, "use")
    self:_StopDrag(true)
  end

  function PANEL:MoveItemToChest()
    local key = self.key

    -- If this is a stack with multiple items, use the first item's key
    if self.stackData and self.stackData.count > 1 then
      key = self.stackData.keys[1]
    end

    -- Get the chest name from UNIT.currentNamedInventory
    if UNIT.currentNamedInventory then
      versus.command.run("chest", UNIT.currentNamedInventory, "move_to", key)
    end
  end

  function PANEL:MoveItemFromChest()
    local key = self.key

    -- If this is a stack with multiple items, use the first item's key
    if self.stackData and self.stackData.count > 1 then
      key = self.stackData.keys[1]
    end

    -- Get the chest name from UNIT.currentNamedInventory
    if UNIT.currentNamedInventory then
      versus.command.run("chest", UNIT.currentNamedInventory, "move_from", key)
    end
  end

  function PANEL:PaintOver(width, height)
    if (self.wrappedName == nil) then
      self.wrappedName = {}
      versus.message.wrapText(self.item.name, "VersusDefaultOutlined", self:GetWide(), nil, self.wrappedName)
    end

    local y = SPACING
    local rarityID = self.item.rarity
    local rarity = versus.item.getRarity(rarityID)
    local color = rarity and rarity.color or color_white

    self.nameTextY = y

    for _, text in pairs(self.wrappedName) do
      draw.DrawText(text, "VersusDefaultOutlined", width * .5, y, color, TEXT_ALIGN_CENTER)
      y = y + 20
    end

    self.textHeight = y

    versus.item.drawRarityBadge(rarityID, width / 2, (self.textHeight or SPACING) + 8)

    if (self.item.onPaintOver) then
      self.item:onPaintOver(self, width, height)
    end

    hook.Run("PaintInventoryItemOver", self, width, height)
  end

  function PANEL:BuildMoreMenu(itemFunctions)
    local menu = DermaMenu()
    local item = self.item
    local key = self.key

    -- If this is a stack with multiple items, use the first item's key
    if self.stackData and self.stackData.count > 1 then
      key = self.stackData.keys[1]
    end

    -- Single behavior for both stacked and single items
    local justDrop = function()
      versus.command.run(self:GetInventoryCommand(), key, "drop")
      versus.menu.toggle()
    end

    table.sort(itemFunctions)
    hook.Run("SortInventoryItemFunctions", item, key, itemFunctions)

    for _, text in pairs(itemFunctions) do
      local originalText = text

      if (item.actionTexts ~= nil) then
        text = versus.util.resolve(item.actionTexts[originalText], item) or originalText
      end

      if (hook.Run("BuildInventoryItemFunction", item, key, menu, originalText, text, self) ~= false) then
        if (originalText == "Use") then
          menu:AddOption(text, function()
            versus.command.run(self:GetInventoryCommand(), key, "use")
          end)
        elseif (originalText == "Drop") then
          menu:AddOption(text, justDrop)
        elseif (originalText == "Permanently Destroy") then
          menu:AddOption(text, function()
            versus.panel.query(
              "You will lose this " .. item.name ..
              ". This can not be undone!\n\nDo you want destroy this " .. item.name .. "?",
              "Permanently Destroying " .. item.name,
              "No, do not destroy the item",
              nil,
              "Yes, destroy the item",
              function()
                versus.command.run(self:GetInventoryCommand(), key, "destroy")
              end)
          end)
        end
      end
    end

    return menu
  end

  function PANEL:DoDoubleClick()
    local button = self.useButton or self.moreButton

    if (button) then
      button:DoClick()
    end
  end

  function PANEL:CanStartDrag()
    return self.item ~= nil and self.item.onDrop ~= nil
  end

  function PANEL:OnDragStarted()
    if IsValid(self.inventoryPanel) then
      self.inventoryPanel:SetDragging(true, self.item, self.stackData)
      self.inventoryParent = self.inventoryPanel
    end
  end

  function PANEL:OnDragDropped()
    local dropAction = self:GetDropAction()
    if dropAction and dropAction(self) then return end

    local handled = versus.dragDrop.fireDroppedForSession("inventory", self)
    self:_StopDrag(handled)
  end

  function PANEL:OnDragStopped(dropped)
    if IsValid(self.inventoryParent) then
      self.inventoryParent:SetDragging(false)
      self.inventoryParent = nil
    end
  end

  function PANEL:OnMousePressed(mouse)
    if mouse ~= MOUSE_FIRST then return end

    if self.lastClickTime and SysTime() - self.lastClickTime < 0.3 then
      self:DoDoubleClick()
      return
    end

    self.lastClickTime = SysTime()
    BaseClass.OnMousePressed(self, mouse)
  end

  function PANEL:OnRemove()
    BaseClass.OnRemove(self)
  end

  function PANEL:PerformLayout(width, height)
    local distanceFromBottom = (IsValid(self.useButton) and self.useButton:GetTall()) or
        (IsValid(self.moreButton) and self.moreButton:GetTall()) or 0

    self.modelPanel:StretchToParent(0, 0, 0, distanceFromBottom)

    if (IsValid(self.useButton)) then
      self.useButton:SetWide(width - (IsValid(self.moreButton) and (self.moreButton:GetWide() + SPACING) or 0))
      self.useButton:SetPos(0, height - self.useButton:GetTall())
    end

    if (IsValid(self.moreButton)) then
      self.moreButton:SetPos(width - self.moreButton:GetWide(), height - self.moreButton:GetTall())
    end

    self.size:SetPos(
      (width * .5) - (self.size:GetWide() * .5),
      height - distanceFromBottom - self.size:GetTall() - SPACING
    )

    -- Position stack count in top-right corner
    if IsValid(self.stackCount) and self.stackCount:IsVisible() then
      self.stackCount:SetPos(width - self.stackCount:GetWide() - 4, 4)
    end
  end

  function PANEL:Paint(width, height)
    local bottomOffset = IsValid(self.useButton) and self.useButton:GetTall() or
        (IsValid(self.moreButton) and self.moreButton:GetTall() or 0)
    GAMEMODE:DrawBackgroundBox(0, 0, width, height - bottomOffset * .5, color_background)
    versus.panel.drawButtonGroupBackground(0, height - bottomOffset, width, bottomOffset, 255)
  end

  vgui.Register("versus_Inventory_Item", PANEL, "versus_DraggableItem")
end

do
  local PANEL = {}

  AccessorFunc(PANEL, "showMoneyDisplay", "ShowMoneyDisplay", FORCE_BOOL)

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self:SetSizeX(false)
    self:SetShowMoneyDisplay(true)

    self.inventoryLabel = vgui.Create("DLabel", self)
    self.inventoryLabel:SetFont("VersusDefault")
    self.inventoryLabel:SetTextColor(Color(255, 200, 80))
    self.inventoryLabel:SetText("")
    self.inventoryLabel:Dock(TOP)
    self.inventoryLabel:DockMargin(0, 0, 0, SPACING)
    self.inventoryLabel:SetContentAlignment(5) -- Center
    self.inventoryLabel:SetVisible(false)

    local container = vgui.Create("EditablePanel", self)
    container:Dock(TOP)
    container:SetTall(64)

    self.spaceUsedBar = vgui.Create("versus_Inventory_Bar", container)
    self.spaceUsedBar:Dock(FILL)
    self.spaceUsedBar:SetLabelText("Space Used")
    self.spaceUsedBar:SetColors(Color(37, 52, 0), Color(98, 137, 0))
    self.spaceUsedBar:SetValueFunction(function()
      return self:GetConsumedSpace()
    end)
    self.spaceUsedBar:SetMaximumFunction(function()
      return self:GetMaximumSpace()
    end)
    self.spaceUsedBar:SetUnitText(" kg")

    self.moneyDisplay = vgui.Create("versus_MoneyDisplay", container)
    self.moneyDisplay:Dock(RIGHT)
    self.moneyDisplay:DockMargin(SPACING, 0, 0, 0)
    self.moneyDisplay:SizeToContents()

    self.searchBar = vgui.Create("versus_TextEntry", self)
    self.searchBar:SetTabbingDisabled(true)
    self.searchBar:Dock(TOP)
    self.searchBar:DockMargin(0, SPACING, 0, 0)
    self.searchBar:SetPlaceholderText("Search items by name")
    self.searchBar:SetUpdateOnType(true)
    self.searchBar.OnValueChange = function(searchBar, value)
      if (self.filterCallback) then
        self.filterCallback(value)
      end
    end
  end

  function PANEL:SetFilterCallback(filterCallback)
    self.filterCallback = filterCallback
  end

  function PANEL:GetConsumedSpace()
    local parent = self:GetParent()

    -- Check if parent is a versus_Inventory and has override inventory
    if (IsValid(parent) and parent.inventory) then
      local consumed = 0
      for key, item in pairs(parent.inventory) do
        if (not item.notInInventory) then
          consumed = consumed + item.size
        end
      end
      return consumed
    end

    return UNIT.getConsumedSpace()
  end

  function PANEL:GetMaximumSpace()
    local parent = self:GetParent()

    -- Check if parent is a versus_Inventory and has override max size
    if (IsValid(parent) and parent.inventoryMaxSize) then
      return parent.inventoryMaxSize
    end

    return UNIT.getMaximumSpace(LocalPlayer())
  end

  function PANEL:Refresh()
    local parent = self:GetParent()

    -- Update label visibility and text
    if (IsValid(parent) and parent.inventoryLabel) then
      self.inventoryLabel:SetText(parent.inventoryLabel)
      self.inventoryLabel:SetVisible(true)
      self.inventoryLabel:SizeToContents()
    else
      self.inventoryLabel:SetVisible(false)
    end

    self.moneyDisplay:SetVisible(self.showMoneyDisplay)
    self.spaceUsedBar:Refresh()
    self:InvalidateLayout(true)
  end

  vgui.Register("versus_Inventory_Information", PANEL, "DSizeToContents")
end

do
  local PANEL = {}

  function PANEL:Init()
    self.label = vgui.Create("DLabel", self)
    self.label:SetTextColor(color_white)
    self.label:SetFont("VersusDefaultOutlined")

    self:SetTall(32)

    self.labelText = ""
    self.unit = ""
  end

  function PANEL:SetValueFunction(func)
    self.getValue = func
  end

  function PANEL:SetMaximumFunction(func)
    self.getMaximum = func
  end

  function PANEL:SetLabelText(text)
    self.labelText = text .. ": "
  end

  function PANEL:SetUnitText(unit)
    self.unit = unit or ""
  end

  function PANEL:SetColors(bgColor, fgColor)
    self.bgColor = bgColor
    self.fgColor = fgColor
  end

  function PANEL:PerformLayout(width, height)
    if (not self.getValue or not self.getMaximum) then
      return
    end

    self.value = self.getValue()
    self.maximum = self.getMaximum()

    self.label:SetText(self.labelText .. self.value .. "/" .. self.maximum .. self.unit)
    self.label:SizeToContents()
    self.label:SetPos((width / 2) - (self.label:GetWide() / 2), (height / 2) - (self.label:GetTall() / 2))
  end

  function PANEL:Paint(width, height)
    if (not self.value or not self.maximum) then
      return
    end

    local fraction = self.value / self.maximum
    draw.RoundedBox(height, 0, 0, width, height, self.bgColor or Color(50, 50, 50))

    local x, y = self:LocalToScreen(0, 0)
    render.SetScissorRect(x, y, x + width * fraction, y + height, true)
    draw.RoundedBox(height, 0, 0, width, height, self.fgColor or Color(100, 200, 100))
    render.SetScissorRect(0, 0, 0, 0, false)
  end

  function PANEL:Refresh()
    self:InvalidateLayout(true)
  end

  vgui.Register("versus_Inventory_Bar", PANEL, "EditablePanel")
end

do
  -- Stat, has color like a bar, but no maximum. Just shows the label with a large number under it
  local PANEL = {}

  function PANEL:Init()
    self.label = vgui.Create("DLabel", self)
    self.label:SetTextColor(color_white)
    self.label:SetFont("VersusDefault")
    self.label:SetText("Stat")
    self.label:SizeToContents()

    self.valueLabel = vgui.Create("DLabel", self)
    self.valueLabel:SetTextColor(color_white)
    self.valueLabel:SetFont("VersusDefaultOutlined")
    self.valueLabel:SetText("0")
    self.valueLabel:SizeToContents()

    self.labelText = ""

    self:SetTall(self.label:GetTall() + self.valueLabel:GetTall() + (SPACING * 3))
  end

  function PANEL:SetValueFunction(func)
    self.getValue = func
  end

  function PANEL:SetLabelText(text)
    self.labelText = text
  end

  function PANEL:SetColors(bgColor, fgColor)
    self.bgColor = bgColor
    self.fgColor = fgColor

    self.label:SetTextColor(self.fgColor or color_white)
    self.valueLabel:SetTextColor(self.fgColor or color_white)
  end

  function PANEL:PerformLayout(width, height)
    if (not self.getValue) then
      return
    end

    self.value = self.getValue()

    self.label:SetText(self.labelText)
    self.label:SizeToContents()
    self.label:SetPos((width / 2) - (self.label:GetWide() / 2), SPACING)

    self.valueLabel:SetText(tostring(self.value))
    self.valueLabel:SizeToContents()
    self.valueLabel:SetPos((width / 2) - (self.valueLabel:GetWide() / 2), SPACING + self.label:GetTall())
  end

  function PANEL:Paint(width, height)
    GAMEMODE:DrawBackgroundBox(0, 0, width, height, self.bgColor or Color(50, 50, 50))
  end

  function PANEL:Refresh()
    self:InvalidateLayout(true)
  end

  function PANEL:DoClick()
    -- Override in instance
  end

  function PANEL:OnMousePressed(mouse)
    if (mouse ~= MOUSE_FIRST) then
      return
    end

    self:DoClick()
  end

  vgui.Register("versus_Inventory_Stat", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self.optionCategorize = vgui.Create("DCheckBoxLabel", self)
    self.optionCategorize:DockMargin(SPACING, SPACING, SPACING, SPACING)
    self.optionCategorize:Dock(LEFT)
    self.optionCategorize:SetText("Categorize by type")
    self.optionCategorize:SetConVar(UNIT.convarCategorize:GetName())
    self.optionCategorize:SizeToContents()
    self.optionCategorize:SetTextColor(color_white)
    self.optionCategorize.OnChange = function()
      hook.Run("InventoryNeedsRefresh")
    end

    self.optionInventoryShortcut = vgui.Create("DCheckBoxLabel", self)
    self.optionInventoryShortcut:DockMargin(SPACING, SPACING, SPACING, SPACING)
    self.optionInventoryShortcut:Dock(LEFT)
    self.optionInventoryShortcut:SetText("Enable press I to toggle inventory")
    self.optionInventoryShortcut:SetConVar(UNIT.convarInventoryShortcut:GetName())
    self.optionInventoryShortcut:SizeToContents()
    self.optionInventoryShortcut:SetTextColor(color_white)

    function self.optionInventoryShortcut:OnChange()
      if (game.SinglePlayer()) then
        ErrorNoHalt("Note: Pressing I to open the inventory will not work in SinglePlayer mode.\n")
      end
    end

    hook.Run("BuildInventorySettings", self)

    self:SetTall(self.optionCategorize:GetTall() + (SPACING * 2))
  end

  vgui.Register("versus_Inventory_Settings", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:SetItem(item)
    self.item = item

    self.modelPanel = vgui.Create("versus_ItemModelPanel", self)
    self.modelPanel:SetItem(item)
    self.modelPanel:SetFOV(item.inventoryFov or 80)
    self.modelPanel:SetSize(64, 64)
    self.modelPanel:SetAmbientLight(Color(200, 200, 200, 255))
    self.modelPanel:SetMouseInputEnabled(false)

    self.wrappedName = {}
    versus.message.wrapText(item.name, "VersusDefaultOutlined", self:GetWide(), nil, self.wrappedName)
  end

  function PANEL:SetStackData(stackData)
    self.stackData = stackData
  end

  function PANEL:PerformLayout(width, height)
    if IsValid(self.modelPanel) then
      self.modelPanel:StretchToParent(0, 0, 0, 0)
    end
  end

  function PANEL:Paint(width, height)
    local borderThickness = 4
    local cornerRadius = 8

    local accentColor = Color(255, 200, 80, 255)
    surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 255)
    versus.util.drawRoundedOutline(cornerRadius, 0, 0, width, height, borderThickness)

    -- Draw semi-transparent background
    GAMEMODE:DrawBackgroundBox(borderThickness, borderThickness,
      width - borderThickness * 2, height - borderThickness * 2,
      ColorAlpha(color_background, 200))
  end

  function PANEL:PaintOver(width, height)
    if not self.item or not self.wrappedName then return end

    local y = SPACING
    for _, text in pairs(self.wrappedName) do
      draw.DrawText(text, "VersusDefaultOutlined", width * .5, y, color_white, TEXT_ALIGN_CENTER)
      y = y + 20
    end

    -- Draw stack count if applicable
    if self.stackData and self.stackData.count and self.stackData.count > 1 then
      draw.SimpleText("x" .. self.stackData.count, "VersusDefaultOutlined",
        width - 8, 8, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end
  end

  vgui.Register("versus_Inventory_ItemGhost", PANEL, "EditablePanel")
end

-- Character model viewer used inside the inventory tab
do
  local PANEL = {}

  function PANEL:Init()
    self.characterModel = vgui.Create("versus_Character_Model", self)
    self.characterModel:Dock(FILL)
    self.characterModel:SetFOV(30)
  end

  -- Called by versus_EquippedItems:Refresh() to update the model view after equip/unequip
  function PANEL:UpdateModel()
    if IsValid(self.characterModel) then
      self.characterModel:RefreshPlayerModel()
      self.characterModel:UpdateModel(self.characterModel.model)
    end
  end

  vgui.Register("versus_Inventory_CharacterView", PANEL, "EditablePanel")
end

-- Inventory tab wrapper: player inventory on the left, character model + equipment on the right
do
  local PANEL = {}

  function PANEL:Init()
    self:DockPadding(0, GAMEMODE.SPACING * .5, 0, GAMEMODE.SPACING)

    -- Left 50%: Player inventory
    self.inventoryPanel = vgui.Create("versus_Inventory_Player", self)
    self.inventoryPanel:Dock(LEFT)

    -- Right: split between character model and equipment list
    self.rightPanel = vgui.Create("EditablePanel", self)
    self.rightPanel:Dock(FILL)
    self.rightPanel:DockMargin(GAMEMODE.SPACING, 0, 0, 0)

    -- Left part of right panel: character model
    self.characterView = vgui.Create("versus_Inventory_CharacterView", self.rightPanel)
    self.characterView:Dock(FILL)

    -- Right part of right panel: equipment scroll list
    self.equipmentScroll = vgui.Create("versus_ScrollPanel", self.rightPanel)
    self.equipmentScroll:Dock(RIGHT)
    self.equipmentScroll:DockMargin(GAMEMODE.SPACING, 0, 0, 0)

    self.equippedItems = vgui.Create("versus_EquippedItems", self.equipmentScroll)
    self.equippedItems:Dock(TOP)
    self.equippedItems:SetCharacterPanel(self.characterView)
    self.equippedItems:Refresh()

    self.lastEquipSig = ""

    local invPanel    = self.inventoryPanel
    local equipTarget = self.rightPanel

    -- Equip zone: the right-hand panel showing the character and equipment list.
    -- Only shown when dragging an equippable item with the menu open.
    versus.dragDrop.registerDropZone("equip", {
      text      = "EQUIP ITEM",
      color     = Color(80, 200, 120, 255),
      getPanel  = function() return equipTarget end,
      condition = function(sessionId, drag)
        return sessionId == "inventory" and versus.menu.open
            and drag.item and (drag.item.isEquipment or drag.item.isWeapon)
      end,
      onDropped = function(sessionId, drag, itemPanel)
        itemPanel:EquipItem()
      end,
    })

    -- Drop zone: the area to the left of the inventory panel.
    -- Shown whenever any inventory item is being dragged with the menu open.
    versus.dragDrop.registerDropZone("drop", {
      text      = "DROP ITEM",
      color     = Color(255, 200, 80, 255),
      getRect   = function(sessionId, drag)
        if not IsValid(invPanel) then return end
        local x, y = invPanel:LocalToScreen(0, 0)
        return
            GAMEMODE.SPACING,
            y + GAMEMODE.SPACING,
            x - GAMEMODE.SPACING * 2,
            invPanel:GetTall() - GAMEMODE.SPACING * 2
      end,
      condition = function(sessionId, drag)
        return sessionId == "inventory" and versus.menu.open
      end,
      onDropped = function(sessionId, drag, itemPanel)
        itemPanel:DropItem()
      end,
    })

    -- Unequip zone: the inventory panel itself becomes the target when an
    -- equipped item is being dragged back.
    versus.dragDrop.registerDropZone("unequip", {
      text      = "UNEQUIP ITEM",
      color     = Color(100, 160, 240, 255),
      getPanel  = function() return invPanel end,
      condition = function(sessionId, drag)
        return sessionId == "equipped" and versus.menu.open
      end,
      onDropped = function(sessionId, drag)
        net.Start("versus.equipment.unequip")
        net.WriteString(drag.slot)
        net.SendToServer()
      end,
    })

    -- Equipped-drop zone: the same left-side area as the inventory drop zone,
    -- but shown when dragging a droppable equipped item. Drops the item on the ground.
    versus.dragDrop.registerDropZone("equippedDrop", {
      text      = "DROP ITEM",
      color     = Color(255, 200, 80, 255),
      getRect   = function(sessionId, drag)
        if not IsValid(invPanel) then return end
        local x, y = invPanel:LocalToScreen(0, 0)
        return
            GAMEMODE.SPACING,
            y + GAMEMODE.SPACING,
            x - GAMEMODE.SPACING * 2,
            invPanel:GetTall() - GAMEMODE.SPACING * 2
      end,
      condition = function(sessionId, drag)
        return sessionId == "equipped" and versus.menu.open
            and drag.item and drag.item.onDrop ~= nil
      end,
      onDropped = function(sessionId, drag)
        net.Start("versus.equipment.drop")
        net.WriteString(drag.slot)
        net.SendToServer()
      end,
    })
  end

  function PANEL:OnRemove()
    versus.dragDrop.unregisterDropZone("equip")
    versus.dragDrop.unregisterDropZone("drop")
    versus.dragDrop.unregisterDropZone("unequip")
    versus.dragDrop.unregisterDropZone("equippedDrop")
  end

  function PANEL:PerformLayout(width, height)
    local spacing = GAMEMODE.SPACING or 8
    local halfWidth = math.floor(width / 2)
    self.inventoryPanel:SetWide(halfWidth)

    -- Divide the right panel between character view and equipment
    local rightWidth = width - halfWidth - spacing
    self.equipmentScroll:SetWide(math.floor(rightWidth / 3))
  end

  function PANEL:Think()
    -- Poll for equipment changes to keep the equipment list in sync
    local equippedItems = versus.equipment.getEquippedItems(LocalPlayer())
    local sig = ""

    for slot, item in SortedPairs(equippedItems) do
      sig = sig .. slot .. ":" .. (item and item.itemID or "nil") .. ";"
    end

    if sig ~= self.lastEquipSig then
      self.lastEquipSig = sig
      self.equippedItems:Refresh()
    end
  end

  vgui.Register("versus_Inventory_WithCharacter", PANEL, "EditablePanel")
end
