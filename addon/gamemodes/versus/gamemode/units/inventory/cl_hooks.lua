local UNIT = UNIT

-- Called when the main menu tabs can be built
function UNIT.hook:BuildMainMenuTabs(tabs)
  tabs:addTab("Inventory", vgui.Create("versus_Inventory_WithCharacter"), 0)
end

function UNIT.hook:DrawOverlay(width, height)
  if (not IsValid(UNIT.itemGainedStackPanel)) then
    UNIT.itemGainedStackPanel = vgui.Create("versus_ItemNotificationStack")
    UNIT.itemGainedStackPanel:SetPaintedManually(true)
  end

  UNIT.itemGainedStackPanel:PaintManual()
end

-- For auto refresh we clear the item gained stack
if (IsValid(UNIT.itemGainedStackPanel)) then
  UNIT.itemGainedStackPanel:Remove()
  UNIT.itemGainedStackPanel = nil
end

function UNIT.hook:PlayerButtonUp(player, button)
  if (button == KEY_I and UNIT.convarInventoryShortcut:GetBool()) then
    if (player._LastInventoryShortcut and player._LastInventoryShortcut + 0.3 > CurTime()) then
      return
    end

    player._LastInventoryShortcut = CurTime()
    versus.menu.toggle("Inventory")
  end
end

function UNIT.hook:InventoryItemGivenNetworked(item)
  if IsValid(UNIT.namedInventoryTransferPanel) then
    return
  end

  UNIT.itemGainedStackPanel:ShowGainedItem(item)
end

function UNIT.hook:NamedInventoryReceived(chestName)
  if (IsValid(UNIT.namedInventoryTransferPanel)) then
    UNIT.namedInventoryTransferPanel:SetNamedInventory(chestName)
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.inventory.performItemAction", function(len)
  local key = net.ReadUInt(UNIT.bitSizeItemKeys)
  local action = net.ReadString()
  local takeItem = net.ReadBool()

  hook.Run("PlayerInventoryActionPerformed", UNIT.stored[key], key, action, takeItem)
end)

net.Receive("versus.inventory.refresh", function(len)
  UNIT.markPanelDirty()
end)

-- When the server sends the client an inventory item.
versus.network.receiveUnbounded("versus.inventory.giveItem", function(message)
  local item, key = UNIT.networkMessageReadItem(message)

  UNIT.stored[key] = item

  UNIT.debugItemKeys(UNIT.stored)

  UNIT.markPanelDirty()

  hook.Run("InventoryItemGivenNetworked", item)
end)

-- When the server sends the client the key of an inventory item to remove
net.Receive("versus.inventory.takeItem", function(len)
  local key = net.ReadUInt(20)
  UNIT.stored[key] = nil

  UNIT.debugItemKeys(UNIT.stored)

  UNIT.markPanelDirty()

  hook.Run("InventoryItemTakenNetworked", key)
end)

-- When the server updates the client on the members of an inventory item.
versus.network.receiveUnbounded("versus.inventory.itemOverrides", function(message)
  local key = message:readUInt(UNIT.bitSizeItemKeys)
  local instanceData = message:readTable()
  local isSpecific = message:readBool()
  local item = UNIT.stored[key]

  -- The item may already be removed from the inventory
  if (item) then
    if (isSpecific) then
      -- table.Merge(item.memberOverrides, instanceData)
      for k, v in pairs(instanceData) do
        item.memberOverrides = item.memberOverrides or {}

        if (istable(v) and istable(item.memberOverrides[k])) then
          versus.util.mergeNil(item.memberOverrides[k], v)
        else
          item.memberOverrides[k] = v
        end
      end
    else
      item.memberOverrides = instanceData
    end

    -- Go through instanceData and replace UNIT.nilReplacement with nil
    for k, v in pairs(item.memberOverrides) do
      if (v == UNIT.nilReplacement) then
        item.memberOverrides[k] = nil
      end
    end

    hook.Run("InventoryItemOverridesNetworked", item, instanceData)
  end

  UNIT.markPanelDirty()
end)

-- When the server sends the client the entire inventory at once.
versus.network.receiveUnbounded("versus.inventory.entireInventory", function(message)
  UNIT.stored = UNIT.networkMessageReadInventory(message)

  UNIT.debugItemKeys(UNIT.stored)

  UNIT.markPanelDirty()

  hook.Run("InventoryEntireInventoryNetworked")
end)

-- When the server sends the client an entire named inventory
versus.network.receiveUnbounded("versus.inventory.namedInventory.full", function(message)
  local chestName = message:readString()
  local maxSize = message:readUInt(16)
  local inventory = UNIT.networkMessageReadInventory(message)

  UNIT.namedInventories[chestName] = {
    maxSize = maxSize,
    inventory = inventory,
  }

  UNIT.markNamedInventoryDirty(chestName)

  hook.Run("NamedInventoryReceived", chestName)
end)

-- When the server adds an item to a named inventory
versus.network.receiveUnbounded("versus.inventory.namedInventory.giveItem", function(message)
  local chestName = message:readString()
  local item, key = UNIT.networkMessageReadItem(message)

  if (not UNIT.namedInventories[chestName]) then
    UNIT.namedInventories[chestName] = {
      maxSize = 0,
      inventory = {}
    }
  end

  UNIT.namedInventories[chestName].inventory[key] = item

  UNIT.markNamedInventoryDirty(chestName)

  hook.Run("NamedInventoryItemGiven", chestName, item)
end)

-- When the server removes an item from a named inventory
net.Receive("versus.inventory.namedInventory.takeItem", function(len)
  local chestName = net.ReadString()
  local key = net.ReadUInt(UNIT.bitSizeItemKeys)

  if (UNIT.namedInventories[chestName] and UNIT.namedInventories[chestName].inventory) then
    UNIT.namedInventories[chestName].inventory[key] = nil
  end

  UNIT.markNamedInventoryDirty(chestName)

  hook.Run("NamedInventoryItemTaken", chestName, key)
end)

-- When the server tells the client to open a named inventory
net.Receive("versus.inventory.namedInventory.open", function(len)
  local chestName = net.ReadString()

  UNIT.currentNamedInventory = chestName

  -- Close existing chest window if any
  if IsValid(UNIT.namedInventoryTransferPanel) then
    UNIT.namedInventoryTransferPanel:Remove()
  end

  local sideBySide = vgui.Create("versus_NamedInventory")
  sideBySide:SetNamedInventory(chestName)
  sideBySide.OnClose = function()
    UNIT.currentNamedInventory = nil
    UNIT.namedInventoryTransferPanel = nil
  end

  UNIT.namedInventoryTransferPanel = sideBySide

  hook.Run("NamedInventoryOpened", chestName)
end)

-- When the server forces the named inventory closed (e.g. the source entity was removed).
net.Receive("versus.inventory.namedInventory.close", function(len)
  if (IsValid(UNIT.namedInventoryTransferPanel)) then
    UNIT.namedInventoryTransferPanel:Remove()
    UNIT.namedInventoryTransferPanel = nil
  end

  UNIT.currentNamedInventory = nil
end)
