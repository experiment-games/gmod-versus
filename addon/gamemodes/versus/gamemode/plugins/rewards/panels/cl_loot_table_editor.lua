local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetTitle("Adjust NPC Spawner Loot Table")
    self:SetSize(400, 300)
    self:Center()
    self:MakePopup()

    self.ItemList = vgui.Create("DListView", self)
    self.ItemList:Dock(FILL)
    self.ItemList:AddColumn("Item ID")
    self.ItemList:AddColumn("Chance")
    self.ItemList:SetMultiSelect(false)

    local editButton = vgui.Create("DButton", self)
    editButton:Dock(BOTTOM)
    editButton:SetText("Edit Selected Item")
    editButton.DoClick = function()
      local selected = self.ItemList:GetSelectedLine()
      if not selected then
        Derma_Message("Please select an item to edit.", "Error", "OK")
        return
      end

      local line = self.ItemList:GetLine(selected)
      local currentItemID = line:GetValue(1)
      local currentChance = line:GetValue(2)

      self:OpenEditPopup(currentItemID, currentChance, function(itemID, chance)
        line:SetValue(1, itemID)
        line:SetValue(2, tostring(chance))
      end)
    end

    local addButton = vgui.Create("DButton", self)
    addButton:Dock(BOTTOM)
    addButton:SetText("Add Item")
    addButton.DoClick = function()
      self:OpenEditPopup("", "", function(itemID, chance)
        self.ItemList:AddLine(itemID, tostring(chance))
      end)
    end

    local removeButton = vgui.Create("DButton", self)
    removeButton:Dock(BOTTOM)
    removeButton:SetText("Remove Selected Item")
    removeButton.DoClick = function()
      local selected = self.ItemList:GetSelectedLine()
      if selected then
        self.ItemList:RemoveLine(selected)
      else
        Derma_Message("Please select an item to remove.", "Error", "OK")
      end
    end

    local saveButton = vgui.Create("DButton", self)
    saveButton:Dock(BOTTOM)
    saveButton:SetText("Save Loot Table")
    saveButton.DoClick = function()
      self:SaveLootTable()
    end
  end

  function PANEL:OpenEditPopup(defaultItemID, defaultChance, callback)
    local popup = vgui.Create("DFrame")
    popup:SetTitle(defaultItemID == "" and "Add Item to Loot Table" or "Edit Item in Loot Table")
    popup:SetSize(300, 150)
    popup:Center()
    popup:MakePopup()

    local itemSelect = vgui.Create("DComboBox", popup)
    itemSelect:Dock(TOP)
    itemSelect:SetValue(defaultItemID ~= "" and defaultItemID or "Select Item")

    local items = versus.item.all()
    for itemID, itemData in pairs(items) do
      if (itemData.isBaseItem or item.hidden) then
        continue
      end

      itemSelect:AddChoice(itemData.name, itemID)

      if itemID == defaultItemID then
        itemSelect:ChooseOptionID(itemSelect:GetOptionID(itemData.name))
      end
    end

    local chanceEntry = vgui.Create("DTextEntry", popup)
    chanceEntry:Dock(TOP)
    chanceEntry:SetPlaceholderText("Chance % (e.g., 25.5)")
    chanceEntry:SetNumeric(true)
    chanceEntry:SetValue(defaultChance)

    local submitButton = vgui.Create("DButton", popup)
    submitButton:Dock(BOTTOM)
    submitButton:SetText(defaultItemID == "" and "Add" or "Update")
    submitButton.DoClick = function()
      local itemName, itemID = itemSelect:GetSelected()
      local chance = tonumber(chanceEntry:GetValue())

      if itemID and itemID ~= "" and chance then
        callback(itemID, chance)
        popup:Close()
      else
        Derma_Message("Please enter a valid Item ID and Chance.", "Error", "OK")
      end
    end
  end

  function PANEL:SetEntity(entity)
    self.Entity = entity
  end

  function PANEL:SetLootTable(lootTable)
    self.ItemList:Clear()

    for itemID, chance in pairs(lootTable or {}) do
      self.ItemList:AddLine(itemID, tostring(chance))
    end
  end

  function PANEL:SaveLootTable()
    if not IsValid(self.Entity) then
      Derma_Message("Invalid spawner entity.", "Error", "OK")
      return
    end

    local newLootTable = {}

    for _, line in ipairs(self.ItemList:GetLines()) do
      local itemID = line:GetValue(1)
      local chance = tonumber(line:GetValue(2))
      if itemID and chance then
        newLootTable[itemID] = chance
      end
    end

    net.Start("versus.npc.adjustLootTable")
    net.WriteEntity(self.Entity)
    net.WriteUInt(table.Count(newLootTable), 8)

    for itemID, chance in pairs(newLootTable) do
      net.WriteString(itemID)
      net.WriteFloat(chance)
    end

    net.SendToServer()
    self:Close()
  end

  vgui.Register("VersusNPCLootTableEditor", PANEL, "DFrame")
end

-- TODO: Rework looting
-- net.Receive("versus.npc.startAdjustLootTable", function()
--   local entity = net.ReadEntity()
--   local lootTable = net.ReadTable()

--   if not IsValid(entity) or entity:GetClass() ~= "versus_npc_spawner" then
--     return
--   end

--   local frame = vgui.Create("VersusNPCLootTableEditor")
--   frame:SetEntity(entity)
--   frame:SetLootTable(lootTable)
-- end)
