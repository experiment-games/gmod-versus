local UNIT = UNIT
local playerIterator = player.Iterator

util.AddNetworkString("versus.equipment.unequip")
util.AddNetworkString("versus.equipment.drop")

-- PAC3 (https://steamcommunity.com/sharedfiles/filedetails/?id=104691717)
resource.AddWorkshop("104691717")

--- Equips an item instance into its designated slot. If the slot is already occupied,
--- the previously equipped item is returned to the player's inventory first.
--- @param player Player The player equipping the item
--- @param item VersusItemInstance The item instance to equip (must have an equipSlot field)
--- @param returnToInventory? boolean If false, the item will not be returned to the player's inventory (used for when an item breaks instead of being manually unequipped), defaults to true
function UNIT.equipItem(player, item, returnToInventory)
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

    if (returnToInventory ~= false) then
      versus.inventory.giveItem(player, existingItem)
    end
  end

  data.equippedItems[slot] = item
  player:setCharacterDirty(true)

  UNIT.sendEquipMessage(player, slot, item)

  if (item.onEquip) then
    item.onEquip(item, player)
  end
end

--- Removes an equipped item from a slot and returns the instance to the player's inventory.
--- @param player Player The player unequipping the item
--- @param slot string The equipment slot to clear
--- @param returnToInventory? boolean If false, the item will not be returned to the player's inventory (used for when an item breaks instead of being manually unequipped), defaults to true
function UNIT.unequipItem(player, slot, returnToInventory)
  local data = player:getCharacter("data")
  data.equippedItems = data.equippedItems or {}

  local item = data.equippedItems[slot]

  if (not item) then
    return
  end

  if (item.onUnequip) then
    item.onUnequip(item, player)
  end

  data.equippedItems[slot] = nil
  player:setCharacterDirty(true)

  UNIT.sendUnequipMessage(player, slot)

  if (returnToInventory ~= false) then
    versus.inventory.giveItem(player, item)
  end
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

--- Networks overrides information for an equipped item to all clients, so they can update the item's appearance or other info based on the overrides.
--- @param player Player The player who has the item equipped
--- @param item VersusItemInstance The equipped item instance (must already be equipped, so the server knows which slot it's in)
--- @param specificOverride? string If specified, only this specific override will be sent instead of all of them (used for when only one value changes, to save bandwidth)
function UNIT.networkEquippedItem(player, item, specificOverride)
  local slot = nil
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

  -- Find the slot this item is equipped in, so clients know which item to update. This is needed in case the item is equipped in multiple slots (e.g. rings), or if we're sending an update for an item that's not currently equipped but will be when the player respawns.
  local equippedItems = UNIT.getEquippedItems(player)

  for equippedSlot, equippedItem in pairs(equippedItems) do
    if (equippedItem == item) then
      slot = equippedSlot
      break
    end
  end

  if (not slot) then
    ErrorNoHaltWithStack(string.format(
      "Tried to network equipped item '%s' for player %s, but couldn't find the slot it's equipped in! This is a sign of an issue with how items are being equipped or how overrides are being handled, please investigate!",
      item.name, player:getCombinedName()))
    return
  end

  local message = versus.network.startUnboundedMessage("versus.equipment.itemOverrides")
  message:writePlayer(player)
  message:writeString(slot)
  message:writeTable(overrides)
  message:writeBool(specificOverride ~= nil)
  message:send(player)
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
  message:writeString(player:GetModel())
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

-- Re-equip all equipped items when a player spawns (handles weapons being given back, etc.).
function UNIT.hook:PostPlayerSpawn(player)
  for slot, item in pairs(UNIT.getEquippedItems(player)) do
    if (item.onEquip) then
      item.onEquip(item, player)
    end
  end

  -- We used to do this when a player initializes their character, however since their player model
  -- is only set after that, any pac outfits that rely on the player model (for adjustments) would
  -- be wrong until they re-equipped them. By doingit post-spawn, we ensure the correct model is set.
  -- However, we may be sending this info redundantly to all other players, since a network message
  -- is also sent when items are equipped.
  -- TODO: Perhaps PlayerInitialSpawn with a delay could be used for the following code instead.
  UNIT.networkEquippedItems(player)
end

-- Also network items to the player upon loading, such that the contract selection screen knows if
-- any weapons are equipped, if not a warning is shown.
function UNIT.hook:PlayerDataLoaded(player, isExisting)
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

-- Called as a player dies (not called for KillSilent).
function UNIT.hook:DoPlayerDeath(player, attacker, damageInfo)
  local equippedItems = UNIT.getEquippedItems(player)

  for slot, item in pairs(equippedItems) do
    if (item and hook.Run("PlayerCanDrop", player, item, true, attacker) ~= false) then
      UNIT.unequipItem(player, slot, false)

      local entity = versus.item.spawn(
        player,
        item,
        player:GetPos() + Vector(math.random(-32, 32), math.random(-32, 32), 0),
        Angle(0, math.random(0, 360), 0)
      )

      if (item.onDropped) then
        item:onDropped(player, entity)
      end
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

  if (hook.Run("PlayerCanUnequipItem", player, slot) == false) then
    return
  end

  UNIT.unequipItem(player, slot)
end)

--- Unequips an item from a slot and drops it on the ground at the player's feet.
--- @param player Player The player dropping the item
--- @param slot string The equipment slot to clear
function UNIT.dropItem(player, slot)
  local data = player:getCharacter("data")
  data.equippedItems = data.equippedItems or {}

  local item = data.equippedItems[slot]

  if (not item) then
    return
  end

  -- Unequip without returning the item to inventory so we can spawn it ourselves
  UNIT.unequipItem(player, slot, false)

  -- Spawn the item entity on the ground
  versus.item.spawn(player, item)
end

net.Receive("versus.equipment.drop", function(len, player)
  local slot = net.ReadString()

  if (not slot or slot == "") then
    return
  end

  UNIT.dropItem(player, slot)
end)
