local UNIT = UNIT

UNIT.convarCategorize = CreateClientConVar("versus_inventory_categorize", "0", true, false)
UNIT.convarInventoryShortcut = CreateClientConVar("versus_inventory_shortcut", "0", true, false)

UNIT.stored = UNIT.stored or {}
UNIT.namedInventories = UNIT.namedInventories or {}
UNIT.updatePanel = true

function UNIT.markPanelDirty()
  UNIT.updatePanel = true

  hook.Run("InventoryNeedsRefresh")
end

function UNIT.markNamedInventoryDirty(chestName)
  -- Mark the panel dirty so it refreshes
  UNIT.updatePanel = true

  hook.Run("InventoryNeedsRefresh", chestName)
end

function UNIT.getItemButtonText(item, defaultText)
  if (item.actionTexts ~= nil) then
    local value = versus.util.resolve(item.actionTexts[defaultText], item)

    if (value ~= nil) then
      return value
    end
  end

  return defaultText
end

function UNIT.networkMessageReadItem(message)
  local itemID = message:readString()
  local key = message:readUInt(UNIT.bitSizeItemKeys)
  local instanceData = message:readTable()

  instanceData.itemID = itemID

  local item = versus.item.restoreInstance(instanceData)

  return item, key
end

function UNIT.networkMessageReadInventory(message)
  local itemCount = message:readUInt(16)
  local inventory = {}

  for i = 1, itemCount do
    local item, key = UNIT.networkMessageReadItem(message)

    inventory[key] = item
  end

  return inventory
end

function UNIT.requestDropMultiple(itemID, amount)
  net.Start("versus.inventory.dropMultiple")
  net.WriteString(itemID)
  net.WriteUInt(amount, 8)
  net.SendToServer()
end
