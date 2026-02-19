local UNIT = UNIT

-- Server-side storage for world (unsaved) named inventories, keyed by chestName.
-- These are not tied to any player and are not persisted between sessions.
UNIT.worldNamedInventories = UNIT.worldNamedInventories or {}
UNIT._worldNextItemKey = UNIT._worldNextItemKey or 0

--- Returns the list of players who currently have the named inventory open.
--- @param chestName string The name of the chest/storage
--- @return Player[] # Players watching this inventory
function UNIT.getPlayersWatchingInventory(chestName)
  local watching = {}

  for _, p in ipairs(player.GetAll()) do
    if (p._VersusOpenNamedInventory and p._VersusOpenNamedInventory.chestName == chestName) then
      table.insert(watching, p)
    end
  end

  return watching
end

util.AddNetworkString("versus.inventory.performItemAction")
util.AddNetworkString("versus.inventory.takeItem")
util.AddNetworkString("versus.inventory.refresh")
util.AddNetworkString("versus.inventory.namedInventory.open")
util.AddNetworkString("versus.inventory.namedInventory.close")

--- Creates a new item key for the player's inventory. This is used to maintain
--- a consistent non-shifting key for each item in the inventory. The result is
--- that the inventory is NOT a sequential table. This simplifies operations as
--- we don't have to worry about the client and server having different keys for
--- the same item due to shifting when items are added or removed.
--- @param player Player
--- @return number # The new item key (between 0 and 4000000000)
function UNIT.createItemKey(player)
  player._VersusNextItemKey = (player._VersusNextItemKey or 0) + 1

  -- Limit due to 32 bit size of item keys in networking, we want to prevent overflow and unrealistically large inventories that could cause performance issues
  -- ! Note that this will also hit the limit if a player picks up and drops items repeatedly to increase the key.
  if (player._VersusNextItemKey > 4000000000) then
    player:Kick("Inventory management issue, please reconnect or contact an admin if this persists!")
    -- The below will not work, because if we reset to 1, other items in the inventory will be overwritten
    -- as the keys increment. We would have to check for existing keys and find the next available key,
    -- but that would be a costly operation and is a sign of an inventory management issue in itself,
    -- so we just kick the player and have them reconnect to reset their inventory keys.
    -- ErrorNoHaltWithStack(
    --   string.format(
    --     "Player %s's inventory has too many items! Finding next item key by iterating through inventory for first available key. This is a sign of an inventory management issue and can cause performance issues, please investigate! (Current key: %d)",
    --     player:getCombinedName(),
    --     player._VersusNextItemKey
    --   )
    -- )

    -- -- Iterate once through the entire inventory to find the first available key starting from 1, this is a costly operation but we have no choice at this point
    -- local inventory = player:getCharacter("inventory")

    -- for key = 1, 4000000001 do
    --   if (not inventory[key]) then
    --     print("Found available item key", key, "after iterating through inventory") --- IGNORE ---
    --     player._VersusNextItemKey = key
    --     break
    --   end
    -- end

    -- if (player._VersusNextItemKey > 4000000000) then
    --   error(
    --     string.format(
    --       "Player %s's inventory is completely full and can not accept any more items! This is a sign of an inventory management issue and can cause performance issues, please investigate!",
    --       player:getCombinedName()
    --     )
    --   )
    --   player:Kick("Inventory management issue, please reconnect or contact an admin if this persists!")
    -- end
  end

  return player._VersusNextItemKey
end

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
  local key = UNIT.createItemKey(player)
  inventory[key] = item

  player:setCharacterDirty(true)

  hook.Run("PlayerItemGiven", player, item)

  UNIT.debugItemKeys(inventory)

  if (noNetworking) then
    return key
  end

  local message = versus.network.startUnboundedMessage("versus.inventory.giveItem")
  UNIT.networkMessageWriteItem(message, item, key)
  message:send(player)

  return key
end

-- --- Take an item from a player
--- @param player Player
--- @param item VersusItemInstance|string An item or its item ID
--- @param amount? number The amount to take of this item. Only works when item is a string
--- @param noNetworking? boolean Whether to skip networking the item to the player (use this when taking multiple items at once)
--- @return number|number[] # The key or keys of the taken item(s) in the player's inventory
function UNIT.takeItem(player, item, amount, noNetworking)
  if (isstring(item)) then
    amount = amount or 1

    local keys = {}
    local instances = {}

    for i = 1, amount do
      local itemInstance, key = UNIT.getAnyItem(player, item)

      if (not key) then
        versus.message.notify(player, "You do not have enough of this item to take!", NOTIFY_ERROR)
        break
      end

      instances[i] = itemInstance
      keys[i] = key

      UNIT.takeItem(player, itemInstance, nil, noNetworking)
    end

    if (noNetworking) then
      return keys
    end

    -- TODO: See giveItem comment. Do we need something similar here?

    return keys
  end

  local inventory = player:getCharacter("inventory")
  local key

  if (isstring(item)) then
    item, key = UNIT.getAnyItem(player, item)
  else
    key = UNIT.getItemKey(player, item)
  end

  if (not key) then
    versus.message.notify(player, "You do not have this item to take!", NOTIFY_ERROR)
    return nil
  end

  inventory[key] = nil

  player:setCharacterDirty(true)

  hook.Run("PlayerItemTaken", player, item)

  UNIT.debugItemKeys(inventory)

  if (noNetworking) then
    return key
  end

  net.Start("versus.inventory.takeItem")
  net.WriteUInt(key, UNIT.bitSizeItemKeys)
  net.Send(player)

  return key
end

function UNIT.dropItem(player, item, position, option, versusID)
  option = tostring(option)

  local takeItem, itemEntity = versus.item.spawn(player, item, position)

  return true, takeItem
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
  message:writeUInt(table.Count(inventory), 16)

  for key, item in pairs(inventory) do
    UNIT.networkMessageWriteItem(message, item, key)
  end
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

    local value = item:getNetworkData()[specificOverride]

    -- If the value is already the nil replacement, log a warning so we can investigate why this is happening.
    if (value == UNIT.nilReplacement) then
      ErrorNoHaltWithStack(
        string.format(
          "Player %s's item '%s' has a network override '%s' that is already set to the nil replacement value! This is a sign of an issue with how item overrides are being handled, please investigate!",
          player:getCombinedName(),
          item.name,
          specificOverride
        )
      )
    end

    if (value == nil) then
      value = UNIT.nilReplacement
    end

    overrides[specificOverride] = value
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
  local index = 1

  for i, item in pairs(inventory) do
    if (item.dontSave) then
      continue
    end

    cleanInventory[index] = item:getSafeData()

    index = index + 1
  end

  return util.TableToJSON(cleanInventory)
end

-- Convert an inventory string to a table.
function UNIT.convertInventoryString(player, inventoryString)
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
      local itemKey = UNIT.createItemKey(player)
      inventory[itemKey] = itemData
    end
  end

  UNIT.debugItemKeys(inventory)

  return inventory
end

--- Opens a named inventory for a player, creating it if it doesn't exist. An optional
--- entity can be provided which is considered the "source" of the inventory, and the
--- player must be near this entity to open the inventory or perform actions in it.
--- When owner is nil the inventory belongs to the world: it is not saved and any
--- player can access it.
--- @param player Player The player opening the inventory
--- @param chestName string The name of the chest/storage
--- @param namedInventoryEntity? Entity The entity considered the "source" of the inventory
--- @param owner? Player The owner of the inventory, or nil for a world (unsaved) inventory
function UNIT.openOrCreateNamedInventory(player, chestName, namedInventoryEntity, owner)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

  -- Create the inventory if it doesn't exist
  if not namedInventory then
    local maxSize = versus.config["Chest Inventory Size"]
    UNIT.createNamedInventory(owner, chestName, maxSize)
  end

  -- Register the player as watching this inventory. For world inventories, this
  -- ensures they are included in broadcasts when we network the inventory below.
  player._VersusOpenNamedInventory = {
    chestName = chestName,
    entity = namedInventoryEntity,
    owner = owner,
  }

  -- Network the inventory and open it for the player
  UNIT.networkNamedInventory(player, chestName, owner)

  net.Start("versus.inventory.namedInventory.open")
  net.WriteString(chestName)
  net.Send(player)
end

--- Closes the currently open named inventory for the player, if any.
--- @param player Player
function UNIT.closeNamedInventory(player)
  player._VersusOpenNamedInventory = nil
end

--- Initialize a new named inventory. When owner is nil the inventory belongs to the
--- world: it is stored in UNIT.worldNamedInventories, is not saved between sessions,
--- and is accessible to any player. When owner is a player the inventory is stored in
--- that player's character data and is saved normally.
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
--- @param maxSize number The maximum size of the inventory
function UNIT.createNamedInventory(owner, chestName, maxSize)
  if (owner == nil) then
    if (UNIT.worldNamedInventories[chestName]) then
      ErrorNoHaltWithStack("World named inventory '" .. chestName .. "' already exists!")
      return false
    end

    UNIT.worldNamedInventories[chestName] = {
      maxSize = maxSize,
      inventory = {}
    }

    return true
  end

  local data = owner:getCharacter("data")

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

  owner:setCharacterDirty(true)

  return true
end

--- Add an item to a named inventory.
--- When owner is nil the item is added to a world inventory (not saved).
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
--- @param item VersusItemInstance The item instance to add
--- @return number|nil # The key of the added item, or nil if failed
function UNIT.giveItemToNamedInventory(owner, chestName, item)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

  if (not namedInventory) then
    ErrorNoHaltWithStack("Named inventory '" .. chestName .. "' does not exist!")
    return nil
  end

  -- Check if item fits
  if (item.size and not UNIT.namedInventoryCanFit(owner, chestName, item.size)) then
    return nil
  end

  local key

  if (owner == nil) then
    UNIT._worldNextItemKey = UNIT._worldNextItemKey + 1
    key = UNIT._worldNextItemKey
  else
    key = UNIT.createItemKey(owner)
    owner:setCharacterDirty(true)
  end

  namedInventory.inventory[key] = item

  hook.Run("PlayerItemGivenToNamedInventory", owner, chestName, item)

  return key
end

--- Remove an item from a named inventory.
--- When owner is nil the item is removed from a world inventory (not saved).
--- @param owner Player|nil The owner of the inventory, or nil for a world inventory
--- @param chestName string The name of the chest/storage
--- @param itemOrKey VersusItemInstance|number The item instance or its key
--- @return boolean # Whether the item was successfully taken
function UNIT.takeItemFromNamedInventory(owner, chestName, itemOrKey)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

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

  namedInventory.inventory[key] = nil

  if (owner ~= nil) then
    owner:setCharacterDirty(true)
  end

  hook.Run("PlayerItemTakenFromNamedInventory", owner, chestName, item)

  return true
end

--- Move an item from main inventory to named inventory.
--- When owner is nil the item is moved to a world (unsaved) inventory and all players
--- currently watching that inventory are notified of the change.
--- @param player Player The player whose main inventory to take from
--- @param itemOrKey VersusItemInstance|number The item or its key in main inventory
--- @param chestName string The name of the chest/storage
--- @param owner? Player The owner of the named inventory, or nil for a world inventory
--- @return boolean # Whether the move was successful
function UNIT.moveItemToNamedInventory(player, itemOrKey, chestName, owner)
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

  -- Check if item fits in named inventory
  if (item.size and not UNIT.namedInventoryCanFit(owner, chestName, item.size)) then
    versus.message.notify(player, "The storage is full!", NOTIFY_ERROR)
    return false
  end

  -- Add to named inventory first
  local newKey = UNIT.giveItemToNamedInventory(owner, chestName, item)

  if (not newKey) then
    return false
  end

  -- Remove from main inventory
  UNIT.takeItem(player, item)

  -- Network the change
  UNIT.networkNamedInventoryItem(player, chestName, item, newKey, "give", owner)

  return true
end

--- Move all items matching an itemID from main inventory to named inventory.
--- When owner is nil the items are moved to a world (unsaved) inventory.
--- @param player Player The player whose main inventory to take from
--- @param itemKeyOrID string|number The itemID to match
--- @param chestName string The name of the chest/storage
--- @param amount? number The maximum amount to move (if nil, move all)
--- @param owner? Player The owner of the named inventory, or nil for a world inventory
--- @return number # The number of items successfully moved
function UNIT.moveCountMatchingToNamedInventory(player, itemKeyOrID, chestName, amount, owner)
  local inventory = player:getCharacter("inventory")
  local movedCount = 0

  -- First find the item with the given key so we can get its safe data
  local itemToMatch = UNIT.getItem(player, itemKeyOrID)

  if (not itemToMatch) then
    versus.message.notify(player, "No item found with the given key or ID!", NOTIFY_ERROR)
    return 0
  end

  local itemDataToMatch = itemToMatch:getSafeData()

  for key, item in pairs(inventory) do
    if (item and versus.item.dataEqual(item:getSafeData(), itemDataToMatch)) then
      -- Check if item fits in named inventory
      if (item.size and not UNIT.namedInventoryCanFit(owner, chestName, item.size)) then
        versus.message.notify(player, "Storage is full!", NOTIFY_ERROR)
        break
      end

      -- Add to named inventory first
      local newKey = UNIT.giveItemToNamedInventory(owner, chestName, item)

      if (newKey) then
        -- Remove from main inventory
        UNIT.takeItem(player, item, nil, true)

        movedCount = movedCount + 1

        if (amount and movedCount >= amount) then
          break
        end
      end
    end
  end

  UNIT.networkNamedInventory(player, chestName, owner)
  UNIT.networkEntireInventory(player)

  return movedCount
end

--- Move all items matching an itemID from named inventory to main inventory.
--- When owner is nil the items are taken from a world (unsaved) inventory.
--- @param player Player The player to give the items to
--- @param chestName string The name of the chest/storage
--- @param itemID string The itemID to match
--- @param amount? number The maximum amount to move (if nil, move all)
--- @param owner? Player The owner of the named inventory, or nil for a world inventory
--- @return number # The number of items successfully moved
function UNIT.moveCountMatchingFromNamedInventory(player, chestName, itemID, amount, owner)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

  if (not namedInventory or not namedInventory.inventory) then
    return 0
  end

  local movedCount = 0

  -- First find the item with the given key so we can get its safe data
  local itemToMatch = UNIT.getNamedInventoryItem(owner, chestName, itemID)

  if (not itemToMatch) then
    versus.message.notify(player, "No item found with the given key or ID!", NOTIFY_ERROR)
    return 0
  end

  local itemDataToMatch = itemToMatch:getSafeData()

  for itemKey, item in pairs(namedInventory.inventory) do
    if (item and versus.item.dataEqual(item:getSafeData(), itemDataToMatch)) then
      -- Check if item fits in main inventory
      if (item.size and not UNIT.canFit(player, item.size)) then
        versus.message.notify(player, "Your inventory is full!", NOTIFY_ERROR)
        break
      end

      -- Add to main inventory first
      local newKey = UNIT.giveItem(player, item, nil, true)

      if (newKey) then
        -- Remove from named inventory (use the current index since we're iterating backwards)
        UNIT.takeItemFromNamedInventory(owner, chestName, itemKey)

        movedCount = movedCount + 1

        if (amount and movedCount >= amount) then
          break
        end
      end
    end
  end

  UNIT.networkNamedInventory(player, chestName, owner)
  UNIT.networkEntireInventory(player)

  return movedCount
end

--- Move an item from named inventory to main inventory.
--- When owner is nil the item is taken from a world (unsaved) inventory and all players
--- currently watching that inventory are notified of the change.
--- @param player Player The player to give the item to
--- @param chestName string The name of the chest/storage
--- @param itemOrKey VersusItemInstance|number The item or its key in named inventory
--- @param owner? Player The owner of the named inventory, or nil for a world inventory
--- @return boolean # Whether the move was successful
function UNIT.moveItemFromNamedInventory(player, chestName, itemOrKey, owner)
  local item, key

  if (isnumber(itemOrKey)) then
    key = itemOrKey
    item = UNIT.getNamedInventoryItem(owner, chestName, key)
  else
    item = itemOrKey
    key = table.KeyFromValue(UNIT.getNamedInventory(owner, chestName).inventory, item)
  end

  if (not item or not key) then
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
  UNIT.takeItemFromNamedInventory(owner, chestName, key)

  -- Network the change to all relevant players
  UNIT.networkNamedInventoryItem(player, chestName, item, key, "take", owner)

  return true
end

--- Network entire named inventory to client(s).
--- When owner is nil (world inventory) the inventory is sent to all players currently
--- watching it; otherwise it is sent only to the specified player.
--- @param player Player The player to send to (used as primary recipient for player-owned inventories)
--- @param chestName string The name of the chest/storage
--- @param owner? Player The owner of the inventory, or nil for a world inventory
function UNIT.networkNamedInventory(player, chestName, owner)
  local namedInventory = UNIT.getNamedInventory(owner, chestName)

  if (not namedInventory) then
    ErrorNoHaltWithStack("Named inventory '" .. chestName .. "' does not exist!")
    return
  end

  local recipients = owner == nil and UNIT.getPlayersWatchingInventory(chestName) or {player}

  local message = versus.network.startUnboundedMessage("versus.inventory.namedInventory.full")
  message:writeString(chestName)
  message:writeUInt(namedInventory.maxSize, 16)
  UNIT.networkMessageWriteInventory(message, namedInventory.inventory)
  message:send(recipients)
end

--- Network a single item change to a named inventory.
--- When owner is nil (world inventory) the change is broadcast to all watchers; the
--- interacting player always receives the update as well.
--- @param player Player The player who performed the action
--- @param chestName string The name of the chest/storage
--- @param item VersusItemInstance The item instance
--- @param key number The key of the item in the inventory
--- @param action string The action performed ("give" or "take")
--- @param owner? Player The owner of the inventory, or nil for a world inventory
function UNIT.networkNamedInventoryItem(player, chestName, item, key, action, owner)
  local recipients

  if (owner == nil) then
    -- World inventory: broadcast to all watchers and ensure the interacting player
    -- is always included (e.g. if their watcher state was cleared unexpectedly).
    recipients = UNIT.getPlayersWatchingInventory(chestName)

    if (not table.HasValue(recipients, player)) then
      table.insert(recipients, player)
    end
  else
    recipients = {player}
  end

  if (action == "give") then
    local message = versus.network.startUnboundedMessage("versus.inventory.namedInventory.giveItem")
    message:writeString(chestName)
    UNIT.networkMessageWriteItem(message, item, key)
    message:send(recipients)
  elseif (action == "take") then
    net.Start("versus.inventory.namedInventory.takeItem")
    net.WriteString(chestName)
    net.WriteUInt(key, UNIT.bitSizeItemKeys)
    net.Send(recipients)
  end
end
