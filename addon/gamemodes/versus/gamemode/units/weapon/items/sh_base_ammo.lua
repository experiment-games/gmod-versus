local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Ammo Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_ammo"
ITEM.isAmmunition = true
ITEM.category = "Ammunition"
ITEM.size = 1

ITEM.model = "models/items/boxsrounds.mdl"

ITEM.description = "Used to fill up your weapons."
ITEM.actionTexts = {
  ["Use"] = "Load",
}

function ITEM:onUse(player)
  player:GiveAmmo(self.amount, self.ammoType, true)
  player:EmitSound("items/ammo_pickup.wav", 75, 100, 1, CHAN_ITEM)
end

function ITEM:onDrop(player, position) end

-- If the player has a weapon equipped that can use this ammo, we show a hint to load it.
function ITEM:onPaintOver(panel, width, height)
  for _, weapon in ipairs(LocalPlayer():GetWeapons()) do
    if (not IsValid(weapon)) then
      return
    end

    local ammoType1 = weapon:GetPrimaryAmmoType()
    local ammoName1 = game.GetAmmoName(ammoType1)

    local ammoType2 = weapon:GetSecondaryAmmoType()
    local ammoName2 = game.GetAmmoName(ammoType2)

    -- Outline the item if we have a weapon equipped that can use this ammo
    if (ammoName1 == self.ammoType or ammoName2 == self.ammoType) then
      surface.SetDrawColor(255, 200, 80, 55)
      surface.DrawOutlinedRect(0, 0, width, height, 4)
    end
  end
end
