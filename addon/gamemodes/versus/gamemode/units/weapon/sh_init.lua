local UNIT = UNIT

UNIT.libraryKey = "weapon"

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

function UNIT.getItemIDFromAmmoType(ammoType)
  local ammoName = game.GetAmmoName(ammoType)

  for itemID, itemTable in pairs(versus.item.all()) do
    if (itemTable.ammoType == ammoName) then
      return itemID
    end
  end

  return nil
end
