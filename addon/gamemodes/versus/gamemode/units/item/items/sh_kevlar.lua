local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Kevlar"
ITEM.category = "Armor"
ITEM.size = 2
ITEM.cost = 450
ITEM.seller = { "armoury" }
ITEM.model = "models/props_c17/suitcase_passenger_physics.mdl"
ITEM.description = "Reduces damage the player receives by 50%."

function ITEM:onUse(player)
  if (player._ScaleDamage == 0.5) then
    versus.message.notify(player, "You are already wearing Kevlar!", NOTIFY_ERROR)

    return false
  else
    player._ScaleDamage = 0.5
  end
end

function ITEM:onDrop(player, position) end
