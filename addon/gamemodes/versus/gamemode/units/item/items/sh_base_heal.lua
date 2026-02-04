local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Base Heal"
ITEM.size = 1
ITEM.category = "Health"
ITEM.model = "models/items/healthkit.mdl"
ITEM.description = "Restores health"

function ITEM:onUse(player)
  if (player:Health() >= player:GetMaxHealth()) then
    versus.message.notify(player, "You do not need any more health!", NOTIFY_ERROR)

    return false
  else
    local healAmount = self.healAmount

    -- Based on rarity, increase heal amount
    local rarity = UNIT.getRarity(self.rarity)

    if (rarity) then
      healAmount = math.floor(healAmount * (rarity.modifier or 1))
    end

    player:SetHealth(math.Clamp(player:Health() + healAmount, 0, player:GetMaxHealth()))
  end
end

function ITEM:onDrop(player, position) end
