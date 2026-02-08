local UNIT = UNIT

util.AddNetworkString("versus.inventory.performItemAction")
util.AddNetworkString("versus.inventory.takeItem")
util.AddNetworkString("versus.inventory.refresh")

--- Give a player an item
--- @param player Player
--- @param item VersusItemInstance|string An item or its item ID
--- @param amount? number The amount to give of this item. Only works when item is a string
--- @param noNetworking? boolean Whether to skip networking the item to the player (use this when giving multiple items at once)
--- @return number|number[] # The key or keys of the given item(s) in the player's inventory
function UNIT.giveItem(player, item, amount, noNetworking)
  if (isstring(item)) then
    amount = amount or 1

    local keys = {}
    local instances = {}

    for i = 1, amount do
      local itemInstance = versus.item.createInstance(item)

      instances[i] = itemInstance
      keys[i] = UNIT.giveItem(player, itemInstance, nil, noNetworking)
    end

    if (noNetworking) then
      return keys
    end

    -- TODO: Don't we want to force noNetworking in giveItem above and then here network the keys? Like this:
    -- local message = versus.network.startUnboundedMessage("versus.inventory.giveItems")
    -- message:writeUInt(#keys, 16)
    -- for i, key in ipairs(keys) do
    --   local instance = instances[i]
    --
    --   UNIT.networkMessageWriteItem(message, instance, key)
    -- end
    -- message:send(player)

    return keys
  end

  if (amount ~= nil) then
    ErrorNoHaltWithStack(
      "Invalid argument! You can not provide inventory.giveItem with both an instance and an amount! Use a loop with versus.item.createInstance!")
  end

  local inventory = player:getCharacter("inventory")
  local key = table.insert(inventory, item)

  player:setCharacterDirty(true)

  hook.Run("PlayerItemGiven", player, item)

  if (noNetworking) then
    return key
  end

  local message = versus.network.startUnboundedMessage("versus.inventory.giveItem")
  UNIT.networkMessageWriteItem(message, item, key)
  message:send(player)

  return key
end

--- When giving a large amount of items at once, use this to network the entire
--- inventory to the player in one go.
--- @param player Player
function UNIT.networkEntireInventory(player)
  local inventory = player:getCharacter("inventory")

  local message = versus.network.startUnboundedMessage("versus.inventory.entireInventory")
  UNIT.networkMessageWriteInventory(message, inventory)
  message:send(player)
end

function UNIT.networkMessageWriteItem(message, item, key)
  local overrides = item:getNetworkData()

  message:writeString(item.itemID)
  message:writeUInt(key, UNIT.bitSizeItemKeys)
  message:writeTable(overrides)
end

function UNIT.networkMessageWriteInventory(message, inventory)
  message:writeUInt(#inventory, 16)

  for key, item in pairs(inventory) do
    UNIT.networkMessageWriteItem(message, item, key)
  end
end

--- Take an item from a player
--- @param player Player
--- @param item VersusItemInstance|string The item to take or its item ID
function UNIT.takeItem(player, item)
  local inventory = player:getCharacter("inventory")
  local key

  if (isstring(item)) then
    item, key = UNIT.getAnyItem(player, item)
  else
    key = UNIT.getItemKey(player, item)
  end

  if (not key) then
    -- Can only result from a bug elsewhere
    ErrorNoHaltWithStack("Tried to take an item the player does not have!\n")
    return
  end

  table.remove(inventory, key)

  player._ItemTakeCount = (player._ItemTakeCount or 0) + 1

  net.Start("versus.inventory.takeItem")
  net.WriteUInt(key, UNIT.bitSizeItemKeys)
  -- The number is used to keep track of the order in which items are taken
  -- This is neccessary to synchronize the way keys shift down using
  -- table.remove
  -- TODO: Is it?
  -- net.WriteUInt(player._ItemTakeCount, 8) -- the number will overflow, but we will consider that clientside
  net.Send(player)

  player:setCharacterDirty(true)

  hook.Run("PlayerItemTaken", player, item)
end

function UNIT.dropItem(player, item, position, option, versusID)
  option = tostring(option)

  local takeItem, itemEntity = versus.item.spawn(player, item, position)

  return true, takeItem
end

function UNIT.refreshInventory(player)
  net.Start("versus.inventory.refresh")
  net.Send(player)
end

--- Tries to perform an item action on behalf of a player.
--- @param player Player
--- @param item VersusItemInstance
--- @param action string The action to perform ("destroy", "drop", "use")
--- @param option? string An optional option for the action
--- @param silent? boolean Whether to suppress error messages to the player
--- @return boolean # Whether the action was performed
--- @return boolean? # Whether to take the item from the player's inventory
function UNIT.tryPerformItemAction(player, item, action, option, silent)
  local actionPerformed = false
  local takeItem = true

  if (action == "destroy") then
    if (not versus.item.destroy(player, item)) then
      takeItem = false
    end

    actionPerformed = true
  end

  if (action == "drop") then
    local position = player:GetEyeTraceNoCursor().HitPos + Vector(0, 0, 10)

    if (not versus.entity.isNearPosition(player, position, 256)) then
      if (not silent) then
        versus.message.notify(player, "You cannot drop the item that far away!", NOTIFY_ERROR)
      end

      return false
    end

    local success
    success, takeItem = UNIT.dropItem(player, item, position, option)

    if (not success) then
      return false
    end

    actionPerformed = true
  end

  if (action == "use") then
    if (not player:IsAdmin() and player._NextUseItem and player._NextUseItem > CurTime()) then
      if (not silent) then
        versus.message.notify(
          player,
          "You cannot use another item for " .. math.ceil(player._NextUseItem - CurTime()) .. " second(s)!", NOTIFY_ERROR
        )
      end

      return false
    end

    if (hook.Run("PlayerCanUseItem", player, item) == false) then
      return false
    end

    player._NextUseItem = CurTime() + 2
    if (item.weapon) then
      player._NextHolsterWeapon = CurTime() + 5
    end

    if (not versus.item.use(player, item)) then
      takeItem = false
    end

    actionPerformed = true
  end

  local overrideActionPerformed, overrideTakeItem = hook.Run(
    "PlayerInventoryAction",
    player,
    item,
    action,
    takeItem
  )

  if (overrideActionPerformed ~= nil) then
    actionPerformed = overrideActionPerformed

    if (overrideTakeItem ~= nil) then
      takeItem = overrideTakeItem
    end
  end

  if (not actionPerformed) then
    if (not silent) then
      versus.message.notify(player, action .. " is an invalid action for this item!", NOTIFY_ERROR)
    end

    return false
  end

  return true, takeItem
end

--- @param player Player
--- @param item VersusItemInstance
--- @param specificOverride? string The specific override to network (DOES NOT WORK WITH TABLES!)
function UNIT.networkItemOverrides(player, item, specificOverride)
  local key = UNIT.getItemKey(player, item)
  local overrides

  if (specificOverride) then
    overrides = {}
    overrides[specificOverride] = item:getNetworkData()[specificOverride]
  else
    overrides = item:getNetworkData()
  end

  local message = versus.network.startUnboundedMessage("versus.inventory.itemOverrides")
  message:writeUInt(key, UNIT.bitSizeItemKeys)
  message:writeTable(overrides)
  message:writeBool(specificOverride ~= nil)
  message:send(player)
end

-- Make an inventory string safe for saving to the database.
function UNIT.makeSafeInventoryString(inventory)
  local cleanInventory = {}

  for index, item in pairs(inventory) do
    cleanInventory[index] = item:getSafeData()
  end

  return util.TableToJSON(cleanInventory)
end

-- Convert an inventory string to a table.
function UNIT.convertInventoryString(inventoryString)
  local rawInventory = util.JSONToTable(inventoryString)
  local inventory = {}

  for _, itemData in pairs(rawInventory) do
    local itemID = itemData.itemID
    local item = versus.item.get(itemID)

    -- Note that item data isn't initialized into an instance at this point
    -- yet!
    local dontFail = hook.Run("AdjustInventoryItemLoadData", rawInventory, item, itemData) == true

    if (not dontFail and not item) then
      ErrorNoHaltWithStack("inventoryString contained invalid item '" .. tostring(itemID) .. "'.")
    else
      table.insert(inventory, itemData)
    end
  end

  return inventory
end

--- Initialize a new named inventory for a player, this is an inventory that is
--- separated from the main inventory and can be used for storage chests and the like.
--- @param player Player
--- @param chestName string The name of the chest/storage
--- @param maxSize number The maximum size of the inventory
function UNIT.createNamedInventory(player, chestName, maxSize)
  local data = player:getCharacter("data")

  if (not data.storageChests) then
    data.storageChests = {}
  end

  if (data.storageChests[chestName]) then
    ErrorNoHaltWithStack("Named inventory '" .. chestName .. "' already exists for this player!")
    return false
  end

  data.storageChests[chestName] = {
    maxSize = maxSize,
    inventory = {}
  }

  player:setCharacterDirty(true)

  return true
end

--- Add an item to a named inventory
--- @param player Player
--- @param chestName string The name of the chest/storage
--- @param item VersusItemInstance The item instance to add
--- @return number|nil # The key of the added item, or nil if failed
function UNIT.giveItemToNamedInventory(player, chestName, item)
  local namedInventory = UNIT.getNamedInventory(player, chestName)

  if (not namedInventory) then
    ErrorNoHaltWithStack("Named inventory '" .. chestName .. "' does not exist!")
    return nil
  end

  -- Check if item fits
  if (item.size and not UNIT.namedInventoryCanFit(player, chestName, item.size)) then
    return nil
  end

  local key = table.insert(namedInventory.inventory, item)

  player:setCharacterDirty(true)

  hook.Run("PlayerItemGivenToNamedInventory", player, chestName, item)

  return key
end

--- Remove an item from a named inventory
--- @param player Player
--- @param chestName string The name of the chest/storage
--- @param itemOrKey VersusItemInstance|number The item instance or its key
--- @return boolean # Whether the item was successfully taken
function UNIT.takeItemFromNamedInventory(player, chestName, itemOrKey)
  local namedInventory = UNIT.getNamedInventory(player, chestName)

  if (not namedInventory or not namedInventory.inventory) then
    ErrorNoHaltWithStack("Named inventory '" .. chestName .. "' does not exist!")
    return false
  end

  local key

  if (isnumber(itemOrKey)) then
    key = itemOrKey
  else
    key = table.KeyFromValue(namedInventory.inventory, itemOrKey)
  end

  if (not key) then
    ErrorNoHaltWithStack("Tried to take an item from named inventory that doesn't exist!")
    return false
  end

  local item = namedInventory.inventory[key]

  table.remove(namedInventory.inventory, key)

  player:setCharacterDirty(true)

  hook.Run("PlayerItemTakenFromNamedInventory", player, chestName, item)

  return true
end

--- Move an item from main inventory to named inventory
--- @param player Player
--- @param itemOrKey VersusItemInstance|number The item or its key in main inventory
--- @param chestName string The name of the chest/storage
--- @param position? Vector The position to validate against (for distance check)
--- @return boolean # Whether the move was successful
function UNIT.moveItemToNamedInventory(player, itemOrKey, chestName, position)
  local item, key

  if (isnumber(itemOrKey)) then
    key = itemOrKey
    item = UNIT.getItem(player, key)
  else
    item = itemOrKey
    key = UNIT.getItemKey(player, item)
  end

  if (not item or not key) then
    return false
  end

  -- Validate distance if position is provided
  if (position and not versus.entity.isNearPosition(player, position, 256)) then
    versus.message.notify(player, "You are too far away from the storage!", NOTIFY_ERROR)
    return false
  end

  -- Check if item fits in named inventory
  if (item.size and not UNIT.namedInventoryCanFit(player, chestName, item.size)) then
    versus.message.notify(player, "The storage is full!", NOTIFY_ERROR)
    return false
  end

  -- Add to named inventory first
  local newKey = UNIT.giveItemToNamedInventory(player, chestName, item)

  if (not newKey) then
    return false
  end

  -- Remove from main inventory
  UNIT.takeItem(player, item)

  -- Network the change
  UNIT.networkNamedInventoryItem(player, chestName, item, newKey, "give")

  return true
end

--- Move an item from named inventory to main inventory
--- @param player Player
--- @param chestName string The name of the chest/storage
--- @param itemOrKey VersusItemInstance|number The item or its key in named inventory
--- @param position? Vector The position to validate against (for distance check)
--- @return boolean # Whether the move was successful
function UNIT.moveItemFromNamedInventory(player, chestName, itemOrKey, position)
  local item, key

  if (isnumber(itemOrKey)) then
    key = itemOrKey
    item = UNIT.getNamedInventoryItem(player, chestName, key)
  else
    item = itemOrKey
    key = table.KeyFromValue(UNIT.getNamedInventory(player, chestName).inventory, item)
  end

  if (not item or not key) then
    return false
  end

  -- Validate distance if position is provided
  if (position and not versus.entity.isNearPosition(player, position, UNIT.namedInventoryMaxDistance)) then
    versus.message.notify(player, "You are too far away from the storage!", NOTIFY_ERROR)
    return false
  end

  -- Check if item fits in main inventory
  if (item.size and not UNIT.canFit(player, item.size)) then
    versus.message.notify(player, "Your inventory is full!", NOTIFY_ERROR)
    return false
  end

  -- Add to main inventory first
  local newKey = UNIT.giveItem(player, item)

  if (not newKey) then
    return false
  end

  -- Remove from named inventory
  UNIT.takeItemFromNamedInventory(player, chestName, key)

  -- Network the change
  net.Start("versus.inventory.namedInventory.takeItem")
  net.WriteString(chestName)
  net.WriteUInt(key, UNIT.bitSizeItemKeys)
  net.Send(player)

  return true
end

--- Network entire named inventory to client
--- @param player Player
--- @param chestName string The name of the chest/storage
--- @param position? Vector The position of the chest (for distance validation)
function UNIT.networkNamedInventory(player, chestName, position)
  local namedInventory = UNIT.getNamedInventory(player, chestName)

  if (not namedInventory) then
    ErrorNoHaltWithStack("Named inventory '" .. chestName .. "' does not exist!")
    return
  end

  -- Store the position on the player for later validation
  if (not player._NamedInventoryPositions) then
    player._NamedInventoryPositions = {}
  end
  player._NamedInventoryPositions[chestName] = position

  local message = versus.network.startUnboundedMessage("versus.inventory.namedInventory.full")
  message:writeString(chestName)
  message:writeUInt(namedInventory.maxSize, 16)
  message:writeBool(position ~= nil)
  if (position) then
    message:writeVector(position)
  end
  UNIT.networkMessageWriteInventory(message, namedInventory.inventory)
  message:send(player)
end

--- Network a single item change to a named inventory
--- @param player Player
--- @param chestName string The name of the chest/storage
--- @param item VersusItemInstance The item instance
--- @param key number The key of the item in the inventory
--- @param action string The action performed ("give" or "take")
function UNIT.networkNamedInventoryItem(player, chestName, item, key, action)
  if (action == "give") then
    local message = versus.network.startUnboundedMessage("versus.inventory.namedInventory.giveItem")
    message:writeString(chestName)
    UNIT.networkMessageWriteItem(message, item, key)
    message:send(player)
  elseif (action == "take") then
    net.Start("versus.inventory.namedInventory.takeItem")
    net.WriteString(chestName)
    net.WriteUInt(key, UNIT.bitSizeItemKeys)
    net.Send(player)
  end
end
