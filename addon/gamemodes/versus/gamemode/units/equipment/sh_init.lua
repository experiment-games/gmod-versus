local UNIT = UNIT

UNIT.libraryKey = "equipment"

function UNIT.hook:InventoryGetMaximumSpace(player, data)
  local equippedItems = UNIT.getEquippedItems(player)

  for slot, item in pairs(equippedItems) do
    if (item.sizeEquipped) then
      data.size = data.size + math.abs(item.sizeEquipped)
    end
  end
end
