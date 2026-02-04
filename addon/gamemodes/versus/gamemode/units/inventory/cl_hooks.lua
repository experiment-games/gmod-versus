local UNIT = UNIT
UNIT._LastItemUpdateID = UNIT._LastItemUpdateID or 0
UNIT._RemoveQueue = UNIT._RemoveQueue or {}

-- Called when the main menu tabs can be built
function UNIT.hook:BuildMainMenuTabs(tabs)
  tabs:addTab("Inventory", vgui.Create("versus_Inventory_Player"), "icon16/application_view_tile.png", 15)
end

function UNIT.hook:HUDPaint(width, height)
  if (not IsValid(UNIT.itemGainedStackPanel)) then
    UNIT.itemGainedStackPanel = vgui.Create("versus_ItemNotificationStack")
  end
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
  UNIT.itemGainedStackPanel:ShowGainedItem(item)
end

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
  UNIT.markPanelDirty()

  hook.Run("InventoryItemGivenNetworked", item)
end)

-- When the server sends the client the key of an inventory item to remove
net.Receive("versus.inventory.takeItem", function(len)
  local key = net.ReadUInt(20)
  -- local messageID = net.ReadUInt(8) -- 2

  -- if(UNIT._LastItemUpdateID + 1 ~= messageID)then
  -- 	UNIT._RemoveQueue[messageID] = key
  -- 	return
  -- end

  table.remove(UNIT.stored, key)
  UNIT.markPanelDirty()
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
      table.Merge(item.memberOverrides, instanceData)
    else
      item.memberOverrides = instanceData
    end

    hook.Run("InventoryItemOverridesNetworked", item, instanceData)
  end

  UNIT.markPanelDirty()
end)

-- When the server sends the client the entire inventory at once.
versus.network.receiveUnbounded("versus.inventory.entireInventory", function(message)
  UNIT.stored = UNIT.networkMessageReadInventory(message)

  UNIT.markPanelDirty()
end)
