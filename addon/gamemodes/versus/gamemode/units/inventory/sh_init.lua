local UNIT = UNIT
UNIT.libraryKey = "inventory"

UNIT.bitSizeItemKeys = 32 -- ! 32 = Hard maximum of at most 4294967295 items passing through inventory during this play session
UNIT.nilReplacement = "WE NEED THIS BECAUSE NIL WONT NETWORK"

UNIT.namedInventoryMaxDistance = 256

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

--- Helper to debug which are the current keys in a player's inventory, since it's not a sequential table
--- @param inventory table
function UNIT.debugItemKeys(inventory)
  if (true) then
    -- Disabled for now since we don't need it
    return
  end

  print("\nCurrent inventory keys:")

  for key, item in pairs(inventory) do
    print("Key:", key, "ItemID:", item.itemID)
  end
end

-- Get the player's item by the key it's in in their inventory.
function UNIT.getItem(player, key)
  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored

  return inventory[key]
end

--- Get any item from the player by it's ID, optionally matching the item data provided.
function UNIT.getAnyItem(player, targetItem, itemData)
  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored

  for key, item in pairs(inventory) do
    if (item.itemID == targetItem) then
      if (not itemData or versus.item.dataEqual(item:getSafeData(), itemData)) then
        return item, key
      end
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

--- Get a named inventory's data by its owner.
--- On the server the owner can be nil, which means the inventory belongs to the world
--- and is stored in UNIT.worldNamedInventories instead of a player's character data.
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
function UNIT.getNamedInventory(owner, chestName)
  if (CLIENT and owner ~= nil and owner ~= LocalPlayer()) then
    ErrorNoHalt(
      "versus.inventory.getNamedInventory: Non-local player inventories are not accessible on the client! Using local player instead.\n"
    )
    owner = LocalPlayer()
  end

  if (SERVER) then
    if (owner == nil) then
      return UNIT.worldNamedInventories[chestName]
    end

    local data = owner:getCharacter("data")
    if (not data.storageChests) then
      data.storageChests = {}
    end

    return data.storageChests[chestName]
  else
    return UNIT.namedInventories[chestName]
  end
end

--- Get an item from a named inventory by key
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
--- @param key number The key of the item
function UNIT.getNamedInventoryItem(owner, chestName, key)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

  if (not namedInventory or not namedInventory.inventory) then
    return nil
  end

  return namedInventory.inventory[key]
end

--- Get any item from a named inventory by item ID
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
--- @param targetItem string The item ID to search for
--- @param itemData? table Optional item data to match against
function UNIT.getAnyItemFromNamedInventory(owner, chestName, targetItem, itemData)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

  if (not namedInventory or not namedInventory.inventory) then
    return nil, nil
  end

  for key, item in pairs(namedInventory.inventory) do
    if (item.itemID == targetItem) then
      if (not itemData or versus.item.dataEqual(item:getSafeData(), itemData)) then
        return item, key
      end
    end
  end

  return nil, nil
end

--- Get the maximum size of a named inventory
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
function UNIT.getNamedInventoryMaxSize(owner, chestName)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

  if (not namedInventory) then
    return 0
  end

  return namedInventory.maxSize or 0
end

--- Get the consumed space in a named inventory
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
function UNIT.getNamedInventoryConsumedSpace(owner, chestName)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

  if (not namedInventory or not namedInventory.inventory) then
    return 0
  end

  local size = 0

  for _, item in pairs(namedInventory.inventory) do
    if (item.size and item.size > 0) then
      size = size + item.size
    end
  end

  return size
end

--- Check if an item of a given size can fit in a named inventory
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
--- @param size number The size to check
function UNIT.namedInventoryCanFit(owner, chestName, size)
  local consumedSpace = UNIT.getNamedInventoryConsumedSpace(owner, chestName)
  local maxSize = UNIT.getNamedInventoryMaxSize(owner, chestName)

  return (consumedSpace + size) <= maxSize
end

-- Finds all items with the given base in any of the players inventories, including named ones.
function UNIT.findAllWithBaseInAnyInventory(player, targetBase)
  local items = {}

  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored
  for key, item in pairs(inventory) do
    if (item:isBasedOf(targetBase)) then
      items[key] = item
    end
  end

  local data = player:getCharacter("data")
  if (data.storageChests) then
    for chestName, chestData in pairs(data.storageChests) do
      if (chestData.inventory) then
        for key, item in pairs(chestData.inventory) do
          if (item:isBasedOf(targetBase)) then
            items[key] = item
          end
        end
      end
    end
  end

  return items
end

-- Finds all items with the given id in any of the players inventories, including named ones.
function UNIT.findAllWithIDInAnyInventory(player, targetID)
  local items = {}

  local inventory = SERVER and player:getCharacter("inventory") or UNIT.stored
  for key, item in pairs(inventory) do
    if (item.itemID == targetID) then
      items[key] = item
    end
  end

  local data = player:getCharacter("data")
  if (data.storageChests) then
    for chestName, chestData in pairs(data.storageChests) do
      if (chestData.inventory) then
        for key, item in pairs(chestData.inventory) do
          if (item.itemID == targetID) then
            items[key] = item
          end
        end
      end
    end
  end

  return items
end
