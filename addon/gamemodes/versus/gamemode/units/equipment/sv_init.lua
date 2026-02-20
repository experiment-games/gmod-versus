local UNIT = UNIT
local playerIterator = player.Iterator

util.AddNetworkString("versus.equipment.unequip")

--- Equips an item instance into its designated slot. If the slot is already occupied,
--- the previously equipped item is returned to the player's inventory first.
--- @param player Player The player equipping the item
--- @param item VersusItemInstance The item instance to equip (must have an equipSlot field)
function UNIT.setEquippedItem(player, item)
  local slot = item.equipSlot

  if (not slot) then
    ErrorNoHalt("Item " .. tostring(item.itemID) .. " has no equipSlot defined!\n")
    return
  end

  local data = player:getCharacter("data")
  data.equippedItems = data.equippedItems or {}

  -- Return the currently equipped item in this slot to the player's inventory
  local existingItem = data.equippedItems[slot]

  if (existingItem) then
    UNIT.sendUnequipMessage(player, slot)
    versus.inventory.giveItem(player, existingItem)
  end

  data.equippedItems[slot] = item
  player:setCharacterDirty(true)

  UNIT.sendEquipMessage(player, slot, item)
end

--- Removes an equipped item from a slot and returns the instance to the player's inventory.
--- @param player Player The player unequipping the item
--- @param slot string The equipment slot to clear
function UNIT.unequipItem(player, slot)
  local data = player:getCharacter("data")
  data.equippedItems = data.equippedItems or {}

  local item = data.equippedItems[slot]

  if (not item) then
    return
  end

  data.equippedItems[slot] = nil
  player:setCharacterDirty(true)

  UNIT.sendUnequipMessage(player, slot)
  versus.inventory.giveItem(player, item)
end

--- Broadcasts to all clients that a player has equipped an item in a slot.
--- @param player Player
--- @param slot string
--- @param item VersusItemInstance
function UNIT.sendEquipMessage(player, slot, item)
  local overrides = item:getNetworkData()

  local message = versus.network.startUnboundedMessage("versus.equipment.sendEquippedItem")
  message:writePlayer(player)
  message:writeString(slot)
  message:writeBool(true)
  message:writeString(item.itemID)
  message:writeTable(overrides)
  message:broadcast()
end

--- Broadcasts to all clients that a player's slot has been cleared.
--- @param player Player
--- @param slot string
function UNIT.sendUnequipMessage(player, slot)
  local message = versus.network.startUnboundedMessage("versus.equipment.sendEquippedItem")
  message:writePlayer(player)
  message:writeString(slot)
  message:writeBool(false)
  message:broadcast()
end

--- Gets all equipped items for a player as a slot -> instance table.
--- @param player Player
--- @return table # { [slot] = VersusItemInstance, ... }
function UNIT.getEquippedItems(player)
  local data = player:getCharacter("data")
  return data.equippedItems or {}
end

--- Gets the equipped item instance in a specific slot.
--- @param player Player
--- @param slot string
--- @return VersusItemInstance? # The equipped item, or nil if the slot is empty
function UNIT.getEquippedItem(player, slot)
  return UNIT.getEquippedItems(player)[slot]
end

--- Networks all equipped items for a player to a specific client, or all clients.
--- @param player Player The player whose equipped items we want to network
--- @param target Player? The player to network to, or nil to broadcast to all
function UNIT.networkEquippedItems(player, target)
  local equippedItems = UNIT.getEquippedItems(player)
  local count = table.Count(equippedItems)

  if (count == 0) then
    return
  end

  local message = versus.network.startUnboundedMessage("versus.equipment.sendEquippedItems")
  message:writePlayer(player)
  message:writeUInt(count, 16)

  for slot, item in pairs(equippedItems) do
    message:writeString(slot)
    message:writeString(item.itemID)
    message:writeTable(item:getNetworkData())
  end

  if (target) then
    message:send(target)
  else
    message:broadcast()
  end
end

--[[
  Hooks
--]]

-- When a player initializes their character, network their equipped items to everyone.
function UNIT.hook:PlayerInitialized(player)
  UNIT.networkEquippedItems(player)

  -- Also send them all currently equipped items for everyone else, so they have the correct info on round start.
  for _, otherPlayer in playerIterator() do
    if (otherPlayer == player) then
      continue
    end

    UNIT.networkEquippedItems(otherPlayer, player)
  end
end

-- Convert item instances to safe data before database serialization.
function UNIT.hook:PlayerSavingData(player, data)
  if (data.equippedItems) then
    local cleanEquipped = {}

    for slot, instance in pairs(data.equippedItems) do
      cleanEquipped[slot] = instance:getSafeData()
    end

    data.equippedItems = cleanEquipped
  end
end

-- Convert safe data back to item instances after database deserialization.
function UNIT.hook:PlayerConvertingData(player, data)
  if (data.equippedItems) then
    for slot, itemData in pairs(data.equippedItems) do
      data.equippedItems[slot] = versus.item.restoreInstance(itemData)
    end
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.equipment.unequip", function(len, player)
  local slot = net.ReadString()

  if (not slot or slot == "") then
    return
  end

  UNIT.unequipItem(player, slot)
end)
