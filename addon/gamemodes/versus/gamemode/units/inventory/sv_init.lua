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
end

function UNIT.dropItem(player, item, position, option, priceOrVersusID)
  option = tostring(option)

  local target
  local pickupPrice

  if (option == "restrict") then
    local versusID = priceOrVersusID
    target = versus.player.getByVersusID(versusID)

    if (not target) then
      versus.message.notify(player, versusID .. " is not a valid player SteamID64 to drop the item for!",
        NOTIFY_ERROR)
      return false
    end
  end

  if (option == "charge") then
    pickupPrice = priceOrVersusID

    if (not pickupPrice or pickupPrice <= 0) then
      versus.message.notify(player, pickupPrice .. " is not a valid price to drop the item for! Make it higher than 0",
        NOTIFY_ERROR)
      return false
    end
  end

  local takeItem, itemEntity = versus.item.spawn(player, item, position)

  if (IsValid(itemEntity)) then
    if (IsValid(target)) then
      -- TODO: Set timer to expire this so players need to hurry and not
      -- TODO:  leave items laying around
      itemEntity.allowedPlayers = {
        player,
        target,
      }
    end

    if (pickupPrice) then
      itemEntity:SetNWInt("versus_PickupCharge", pickupPrice)
      itemEntity.chargeOnPickup = {
        amount = pickupPrice,
        receiver = player
      }
    end
  end

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
--- @param priceOrVersusID? number|string An optional price or versus ID for the action
--- @return boolean # Whether the action was performed
--- @return boolean? # Whether to take the item from the player's inventory
function UNIT.tryPerformItemAction(player, item, action, option, priceOrVersusID)
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
      versus.message.notify(player, "You cannot drop the item that far away!", NOTIFY_ERROR)
      return false
    end

    local success
    success, takeItem = UNIT.dropItem(player, item, position, option, priceOrVersusID)

    if (not success) then
      return false
    end

    actionPerformed = true
  end

  if (action == "use") then
    if (not player:IsAdmin() and player._NextUseItem and player._NextUseItem > CurTime()) then
      versus.message.notify(player,
        "You cannot use another item for " .. math.ceil(player._NextUseItem - CurTime()) .. " second(s)!", NOTIFY_ERROR)
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
    versus.message.notify(player, action .. " is an invalid action for this item!", NOTIFY_ERROR)
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
