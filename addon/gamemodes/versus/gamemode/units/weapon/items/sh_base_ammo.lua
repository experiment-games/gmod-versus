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
  local ammoAmount = self.amount

  -- Based on rarity, increase ammo amount
  local rarity = versus.item.getRarity(self.rarity)

  if (rarity) then
    ammoAmount = math.floor(ammoAmount * (rarity.modifier or 1))
  end

  player:GiveAmmo(ammoAmount, self.ammoType, true)
  player:EmitSound("items/ammo_pickup.wav", 75, 100, 1, CHAN_ITEM)
end

function ITEM:onDrop(player, position) end

-- If the player has a weapon equipped that can use this ammo, we show a hint to load it.
function ITEM:onPaintOver(panel, width, height)
  if (self.amount) then
    draw.SimpleText(
      string.format("(%d %s)", self.amount, self.roundsText or "rounds"),
      "VersusSmall",
      width * .5,
      panel.textHeight + 10,
      Color(255, 255, 255, 100),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
  end

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
