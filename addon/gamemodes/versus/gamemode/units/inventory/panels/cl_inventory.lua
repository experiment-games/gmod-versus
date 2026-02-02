local UNIT = UNIT
local SPACING = 16
local ITEMS_PER_ROW = 5
local g_Player = player

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

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

    self.scrollPanel = vgui.Create("versus_ScrollPanel", self)
    self.scrollPanel:Dock(FILL)
    self.itemLists = {}

    self.updatePanel = true

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
    else
      inventories = {
        -- Copy to prevent accidental modifications (must go through server)
        [versus.item.genericCategory] = inventories
      }
    end

    local query = self.searchQuery

    if (query == nil) then
      return inventories
    end

    local filtered = {}

    for category, items in pairs(inventories) do
      for key, item in pairs(items) do
        if (string.find(item.name:lower(), query, nil, true)) then
          filtered[category] = filtered[category] or {}
          table.insert(filtered[category], {
            _isInventoryFiltered = true,
            key = key,
            item = item
          })
        end
      end
    end

    return filtered
  end

  function PANEL:BuildItemsList(items, parent)
    local itemsList = vgui.Create("DIconLayout", parent)
    itemsList:SetWide(self:GetWide())
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
      end

      if (itemB._isInventoryFiltered) then
        itemB = itemB.item
      end

      return itemA.name < itemB.name
    end)

    local inventory, inventoryCommand = self:GetInventory()

    for _, key in ipairs(sortedKeys) do
      local item = items[key]
      local itemPanel = vgui.Create("versus_Inventory_Item", self)
      itemPanel:SetInventoryCommand(inventoryCommand)

      if item._isInventoryFiltered then
        itemPanel:SetItem(item.key, item.item)
      else
        itemPanel:SetItem(key, item)
      end

      local listItem = itemsList:Add(itemPanel)
      listItem:SetSize(self.itemSize, self.itemSize)
    end

    return itemsList
  end

  function PANEL:Rebuild(inventories)
    self.header:Refresh()

    for _, itemList in pairs(self.itemLists) do
      if (IsValid(itemList)) then
        itemList:Remove()
      end
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

        table.insert(self.itemLists, category)

        local list = self:BuildItemsList(inventories[categoryName], category)
        list:SetPos(0, category:GetHeaderHeight())
      end
    end

    self.scrollPanel:Rebuild()
  end

  function PANEL:Refresh()
    self.updatePanel = true
  end

  function PANEL:Think()
    if (self.updatePanel) then
      local scrollBar = self.scrollPanel:GetVBar()
      local oldScroll = scrollBar:GetScroll()

      self.updatePanel = false

      self.itemSize = (self:GetWide() / ITEMS_PER_ROW) - ((SPACING * (ITEMS_PER_ROW - 1)) / ITEMS_PER_ROW)

      self:Rebuild(self:GetInventoryCategorized())

      timer.Simple(0, function()
        scrollBar:AnimateTo(oldScroll, 0.2)
      end)
    end
  end

  vgui.Register("versus_Inventory", PANEL, "Panel")
end

do
  local PANEL = {}

  DEFINE_BASECLASS("versus_Inventory")

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

  function PANEL:Think()
    if (UNIT.updatePanel) then
      UNIT.updatePanel = false

      self.updatePanel = true
    end

    BaseClass.Think(self)
  end

  vgui.Register("versus_Inventory_Player", PANEL, "versus_Inventory")
end

do
  local PANEL = {}

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

    self.modelPanel = vgui.Create("versus_ItemModelPanel", self)
    self.modelPanel:SetItem(item)
    self.modelPanel:SetFOV(item.inventoryFov or 80)
    self.modelPanel:SetSize(64, 64)
    self.modelPanel:SetAmbientLight(Color(200, 200, 200, 255))
    self.modelPanel.OnMousePressed = function(_, keyCode)
      self:OnMousePressed(keyCode)
    end

    self.size = vgui.Create("DLabel", self)
    if (item.size > 0) then
      self.size:SetText("(Size: " .. item.size .. ")")
    elseif (item.size < 0) then
      self.size:SetText("(Space: +" .. math.abs(item.size) .. ")")
    else
      self.size:SetText("(Size: 0)")
    end
    self.size:SetFont("VersusDefaultOutlined")
    self.size:SizeToContents()
    self.size:SetTextColor(color_white)

    self:SetTooltip(item.description)

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

    if (item.onUse) then
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

  function PANEL:GetInventoryCommand()
    return self.inventoryCommand or "inventory"
  end

  function PANEL:Think()
    if (not self.item) then
      return
    end

    if (IsValid(self.moreButton)) then
      self.moreButton:SetText(UNIT.getItemButtonText(self.item, "..."))
    end

    if (IsValid(self.useButton)) then
      self.useButton:SetText(UNIT.getItemButtonText(self.item, "Use"))
    end
  end

  function PANEL:PaintOver(width, height)
    if (self.wrappedName == nil) then
      self.wrappedName = {}
      versus.message.wrapText(self.item.name, "VersusDefaultOutlined", self:GetWide(), nil, self.wrappedName)
    end

    local y = SPACING

    for _, text in pairs(self.wrappedName) do
      draw.DrawText(text, "VersusDefaultOutlined", width * .5, y, color_white, TEXT_ALIGN_CENTER)
      y = y + 20
    end
  end

  function PANEL:BuildMoreMenu(itemFunctions)
    local menu = DermaMenu()
    local item = self.item
    local key = self.key
    local justDrop = function()
      versus.command.run(self:GetInventoryCommand(), key, "drop")

      versus.menu.toggle()
    end

    table.sort(itemFunctions)

    hook.Run("SortInventoryItemFunctions", item, key, itemFunctions)

    for _, text in pairs(itemFunctions) do
      local originalText = text

      if (item.actionTexts ~= nil) then
        local actionText = item.actionTexts[originalText]

        if (isstring(actionText)) then
          text = actionText
        elseif (isfunction(actionText)) then
          text = actionText(item)
        end
      end

      if (hook.Run("BuildInventoryItemFunction", item, key, menu, originalText, text, self) ~= false) then
        if (originalText == "Use") then
          menu:AddOption(text, function()
            versus.command.run(self:GetInventoryCommand(), key, "use")
          end)
        elseif (originalText == "Drop") then
          local dropMenu = menu:AddSubMenu(text, justDrop)
          dropMenu:AddOption("For anyone", justDrop)

          local childPlayerMenu = dropMenu:AddSubMenu("For specific player")
          for _, player in ipairs(g_Player.GetAll()) do
            childPlayerMenu:AddOption(string.format("Only for %s", player:getCombinedName()), function()
              if (not IsValid(player)) then
                Derma_Message("This player has just left!", "Player left!", "Retry")
                UNIT.updatePanel = true
                return
              end

              versus.command.run(self:GetInventoryCommand(), key, "drop", "restrict", player:getSteamID64())

              versus.menu.toggle()
            end)
          end

          dropMenu:AddOption("For anyone who pays " .. versus.config["Money Symbol"], function()
            Derma_StringRequest(
              "Drop " .. item.name .. " in exchange for money",
              "How much do you want to charge another player who wants to pickup this item?",
              "100",
              function(price)
                local priceNumber = tonumber(price)

                if (not priceNumber or priceNumber <= 0) then
                  Derma_Message(
                    "You can not drop an item for " ..
                    versus.util.formatMoney(priceNumber) ..
                    "! Choose an amount higher than 0.",
                    "Invalid price!", "Retry")
                  return
                end

                versus.command.run(self:GetInventoryCommand(), key, "drop", "charge", priceNumber)

                versus.menu.toggle()
              end,
              nil,
              "Drop item"
            )
          end)
        elseif (originalText == "Permanently Destroy") then
          local childMenu = menu:AddSubMenu(text)
          childMenu:AddOption("Cancel", function() end)
          childMenu:AddOption("I want to destroy this " .. item.name, function()
            Derma_Query(
              "You will lose this " .. item.name ..
              ". This can not be undone!\n\nDo you want destroy this " .. item.name .. "?",
              "Permanently Destroying " .. item.name,
              "No, I have changed my mind. Get me to safety!",
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

  function PANEL:OnMousePressed(mouse)
    if (mouse ~= MOUSE_FIRST) then
      return
    end

    if (self.lastClickTime) then
      local timeDistance = SysTime() - self.lastClickTime

      if (timeDistance < 0.3) then
        self:DoDoubleClick()
        return
      end
    end

    self.lastClickTime = SysTime()
  end

  function PANEL:PerformLayout(width, height)
    local distanceFromBottom = (self.useButton and self.useButton:GetTall()) or
        (self.moreButton and self.moreButton:GetTall()) or 0

    self.modelPanel:StretchToParent(0, 0, 0, distanceFromBottom)

    if (self.useButton) then
      self.useButton:SetWide(width - (self.moreButton and self.moreButton:GetWide() or 0))
      self.useButton:SetPos(0, height - self.useButton:GetTall())
    end

    if (self.moreButton) then
      self.moreButton:SetPos(width - self.moreButton:GetWide(), height - self.moreButton:GetTall())
    end

    self.size:SetPos((width * .5) - (self.size:GetWide() * .5), height - distanceFromBottom - self.size:GetTall())
  end

  function PANEL:Paint(width, height)
    GAMEMODE:DrawRoundedBox(0, 0, width, height, Color(50, 50, 50, 200))
  end

  vgui.Register("versus_Inventory_Item", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self:SetSizeX(false)

    self.spaceUsedBar = vgui.Create("versus_Inventory_Bar", self)
    self.spaceUsedBar:Dock(TOP)
    self.spaceUsedBar:SetLabelText("Space Used")
    self.spaceUsedBar:SetColors(Color(37, 52, 0), Color(98, 137, 0))
    self.spaceUsedBar:SetValueFunction(function()
      return UNIT.getConsumedSpace()
    end)
    self.spaceUsedBar:SetMaximumFunction(function()
      return UNIT.getMaximumSpace()
    end)

    self.searchBar = vgui.Create("versus_TextEntry", self)
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

  function PANEL:Refresh()
    self.spaceUsedBar:Refresh()
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

    self.label:SetText(self.labelText .. self.value .. "/" .. self.maximum)
    self.label:SizeToContents()
    self.label:SetPos((width / 2) - (self.label:GetWide() / 2), (height / 2) - (self.label:GetTall() / 2))
  end

  function PANEL:Paint(width, height)
    if (not self.value or not self.maximum) then
      return
    end

    local fraction = self.value / self.maximum
    GAMEMODE:DrawRoundedBox(0, 0, width, height, self.bgColor or Color(50, 50, 50))
    GAMEMODE:DrawRoundedBox(0, 0, width * fraction, height, self.fgColor or Color(100, 200, 100))
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
    self.label:SetFont("Trebuchet18")
    self.label:SetText("Stat")
    self.label:SizeToContents()

    self.valueLabel = vgui.Create("DLabel", self)
    self.valueLabel:SetTextColor(color_white)
    self.valueLabel:SetFont("Trebuchet24")
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
    GAMEMODE:DrawRoundedBox(0, 0, width, height, self.bgColor or Color(50, 50, 50))
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
      UNIT.updatePanel = true
    end

    self.convarInventoryShortcut = vgui.Create("DCheckBoxLabel", self)
    self.convarInventoryShortcut:DockMargin(SPACING, SPACING, SPACING, SPACING)
    self.convarInventoryShortcut:Dock(LEFT)
    self.convarInventoryShortcut:SetText("Enable press I to toggle inventory")
    self.convarInventoryShortcut:SetConVar(UNIT.convarInventoryShortcut:GetName())
    self.convarInventoryShortcut:SizeToContents()
    self.convarInventoryShortcut:SetTextColor(color_white)

    function self.convarInventoryShortcut:OnChange()
      if (game.SinglePlayer()) then
        ErrorNoHalt("Note: Pressing I to open the inventory will not work in SinglePlayer mode.\n")
      end
    end

    self:SetTall(self.optionCategorize:GetTall() + (SPACING * 2))
  end

  vgui.Register("versus_Inventory_Settings", PANEL, "EditablePanel")
end
