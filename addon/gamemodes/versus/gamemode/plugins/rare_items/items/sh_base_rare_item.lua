local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Rare Item Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_rare_item"
ITEM.isRareItem = false
ITEM.category = "Rare Items"
ITEM.size = 1
ITEM.lootChance = 0.1

ITEM.model = "models/gibs/gunship_gibs_sensorarray.mdl"
ITEM.skin = 0

ITEM.description = "An item to be scrapped for resources. Valuable to the right buyer."

function ITEM:onDrop(player, position) end

function ITEM:getScrapFraction()
  local fraction = self.scrapFraction

  if (not fraction) then
    return 1
  end

  -- Based on rarity, increase scrap amount
  local rarity = versus.item.getRarity(self.rarity)

  if (rarity) then
    fraction = fraction * (rarity.modifier or 1)
  end

  return fraction
end
