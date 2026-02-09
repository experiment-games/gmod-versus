local UNIT = UNIT

--- Adds an item ID to the equipped items list, causing it to be equipped on clients.
--- @param player Player The player equipping the item
--- @param itemID string The ID of the item being equipped
function UNIT.addEquippedItem(player, itemID)
  local equippedItems = player._VersusEquippedItems or {}
  player._VersusEquippedItems = equippedItems

  if (pac) then
    local item = versus.item.get(itemID)

    if (not item) then
      ErrorNoHalt("Tried to equip invalid item ID " .. tostring(itemID) .. "\n")
      return
    end

    if (item.pacData) then
      if (not isfunction(player.AttachPACPart)) then
        pac.SetupENT(player)
      end

      player:AttachPACPart(item.pacData)
      player:SetPACDrawDistance(0) -- Always draw
    end
  end

  table.insert(equippedItems, itemID)
end

--- Removes an item ID from the equipped items list, causing it to be removed from clients.
--- @param player Player The player unequipping the item
--- @param itemID string The ID of the item being unequipped
function UNIT.removeEquippedItem(player, itemID)
  local equippedItems = player._VersusEquippedItems or {}
  player._VersusEquippedItems = equippedItems

  if (pac) then
    local item = versus.item.get(itemID)

    if (not item) then
      ErrorNoHalt("Tried to unequip invalid item ID " .. tostring(itemID) .. "\n")
      return
    end

    if (item.pacData) then
      if (not isfunction(player.DetachPACPart)) then
        pac.SetupENT(player)
      end

      player:RemovePACPart(item.pacData)
    end
  end

  table.RemoveByValue(equippedItems, itemID)
end

--[[
  Net Messages
--]]

net.Receive("versus.equipment.sendEquippedItem", function()
  local player = net.ReadPlayer()
  local itemID = net.ReadString()
  local equipped = net.ReadBool()

  if (equipped) then
    UNIT.addEquippedItem(player, itemID)
  else
    UNIT.removeEquippedItem(player, itemID)
  end
end)

net.Receive("versus.equipment.sendEquippedItems", function()
  local player = net.ReadPlayer()
  local itemCount = net.ReadUInt(16)
  local equippedItems = {}

  for i = 1, itemCount do
    table.insert(equippedItems, net.ReadString())
  end

  for _, itemID in ipairs(equippedItems) do
    UNIT.addEquippedItem(player, itemID)
  end
end)
