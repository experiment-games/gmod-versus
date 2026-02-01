local UNIT = UNIT
UNIT.libraryKey = "inventory"

UNIT.bitSizeItemKeys = 20 -- ! 20 = Hard cap of 1048575 items in inventory

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

-- Get the player's item by the key it's in in their inventory.
function UNIT.getItem(player, key)
  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored

  return inventory[key]
end

-- Get any item from the player by it's ID.
function UNIT.getAnyItem(player, targetItem)
  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored

  for key, item in pairs(inventory) do
    if (item.itemID == targetItem) then
      return item, key
    end
  end

  return nil, nil
end

--- Get how many of a given item the player has
--- If given an instance will count how many items with the same ID
function UNIT.countItem(player, targetItem)
  if (CLIENT and player ~= LocalPlayer()) then
    ErrorNoHalt(
      "versus.inventory.countItem: Non-local player inventories are not accessible on the client! Using local player's inventory instead.\n"
    )
    player = LocalPlayer()
  end

  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored
  local shouldMatchID = isstring(targetItem)
  local count = 0

  for _, item in pairs(inventory) do
    if ((shouldMatchID and item.itemID == targetItem) or item.itemID == targetItem.itemID) then
      count = count + 1
    end
  end

  return count
end

-- Get whether a player has the given item
function UNIT.hasItem(player, targetItem)
  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored
  local shouldMatchID = isstring(targetItem)

  for _, item in pairs(inventory) do
    if ((shouldMatchID and item.itemID == targetItem) or item == targetItem) then
      return true
    end
  end

  return false
end

-- Get the key whe players item is in their inventory.
function UNIT.getItemKey(player, item)
  local inventory
  if (SERVER) then
    inventory = player:getCharacter("inventory")
  elseif (player == LocalPlayer()) then
    inventory = UNIT.stored
  else
    ErrorNoHalt("versus.inventory.getItemKey: Player is not local player, can not get their inventory!\n")
  end

  return table.KeyFromValue(inventory, item)
end

-- Get the maximum amount of space a player has
function UNIT.getMaximumSpace(player)
  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored
  local size = versus.config["Inventory Size"]

  -- Items that have a negative size increase space (like pockets)
  for _, item in pairs(inventory) do
    if (not item.size) then
      ErrorNoHalt("NO SIZE" .. item.itemID)
      return
    end
    if (item.size < 0) then
      size = size + math.abs(item.size)
    end
  end

  return size
end

-- Get the size of a player's inventory.
function UNIT.getConsumedSpace(player)
  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored
  local size = 0

  for _, item in pairs(inventory) do
    if (item.size > 0) then
      size = size + item.size
    end
  end

  return size
end

-- Check if a player can fit a specified size into their inventory.
function UNIT.canFit(player, size)
  if (UNIT.getConsumedSpace(player) + size > UNIT.getMaximumSpace(player)) then
    return false
  else
    return true
  end
end

-- Get all the players' items by the value of one of their attributes
function UNIT.findAllBy(player, attributeKey, value, exactMatch)
  local items = {}

  if (exactMatch == nil) then
    exactMatch = false
  end

  local inventory

  if (CLIENT) then
    if (player ~= LocalPlayer()) then
      ErrorNoHalt("versus.inventory.findAllBy: Player is not local player, can not get their inventory!\n")
    end

    inventory = UNIT.stored
  else
    inventory = player:getCharacter("inventory")
  end

  for itemKey, item in pairs(inventory) do
    local attribute = item[attributeKey]

    if (attribute) then
      if ((exactMatch and string.find(attribute, value, nil, true) ~= nil)
            or string.find(string.lower(attribute), string.lower(value), nil, true) ~= nil) then
        if (not IsValid(player) or versus.inventory.hasItem(player, item.itemID)) then
          items[itemKey] = item
        end
      end
    end
  end

  return items
end

-- Get all the players' items by the item it's based on
function UNIT.findAllByBase(player, base)
  local items = {}

  local inventory

  if (CLIENT) then
    if (player ~= LocalPlayer()) then
      ErrorNoHalt("versus.inventory.findAllByBase: Player is not local player, can not get their inventory!\n")
    end

    inventory = UNIT.stored
  else
    inventory = player:getCharacter("inventory")
  end

  for itemKey, item in pairs(inventory) do
    if (item:isBasedOf(base)) then
      items[itemKey] = item
    end
  end

  return items
end
