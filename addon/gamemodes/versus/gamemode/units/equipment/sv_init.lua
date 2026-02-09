local UNIT = UNIT
local playerIterator = player.Iterator

util.AddNetworkString("versus.equipment.sendEquippedItem")
util.AddNetworkString("versus.equipment.sendEquippedItems")

--- Sets a item ID to be equipped, causing it to be networked to all clients
--- so they can setup any pacData that item has.
--- @param player Player The player equipping the item
--- @param itemID string The ID of the item being equipped
function UNIT.setEquippedItem(player, itemID)
  local data = player:getCharacter("data")
  data.equippedItems = data.equippedItems or {}

  if (table.HasValue(data.equippedItems, itemID)) then
    return
  end

  table.insert(data.equippedItems, itemID)

  net.Start("versus.equipment.sendEquippedItem")
  net.WritePlayer(player)
  net.WriteString(itemID)
  net.WriteBool(true)
  net.Broadcast()
end

--- Removes an item ID from the equipped items list, causing it to be removed from clients.
--- @param player Player The player unequipping the item
--- @param itemID string The ID of the item being unequipped
function UNIT.removeEquippedItem(player, itemID)
  local data = player:getCharacter("data")
  data.equippedItems = data.equippedItems or {}

  table.RemoveByValue(data.equippedItems, itemID)

  net.Start("versus.equipment.sendEquippedItem")
  net.WritePlayer(player)
  net.WriteString(itemID)
  net.WriteBool(false)
  net.Broadcast()
end

--- Gets a list of equipped item IDs for a player.
--- @param player Player The player whose equipped items we want to get
--- @return table # A list of item IDs that the player has equipped
function UNIT.getEquippedItems(player)
  local data = player:getCharacter("data")
  return data.equippedItems or {}
end

--- Networks all equipped items for a player to a specific client, or all
--- clients if no target is specified.
--- @param player Player The player whose equipped items we want to network
--- @param target Player? The player to network the equipped items to, or nil to network to all
function UNIT.networkEquippedItems(player, target)
  local equippedItems = UNIT.getEquippedItems(player)

  if (#equippedItems == 0) then
    return
  end

  net.Start("versus.equipment.sendEquippedItems")
  net.WritePlayer(player)
  net.WriteUInt(#equippedItems, 16)

  for _, itemID in ipairs(equippedItems) do
    net.WriteString(itemID)
  end

  if (target) then
    net.Send(target)
  else
    net.Broadcast()
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
