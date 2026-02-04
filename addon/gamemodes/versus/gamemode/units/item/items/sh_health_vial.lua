local ITEM = ITEM

ITEM.name = "Health Vial"
ITEM.size = 1
ITEM.batch = 10
ITEM.cost = 100
ITEM.category = "Health"
ITEM.model = "models/healthvial.mdl"
ITEM.description = "A health vial which restores 25 health."

function ITEM:onUse(player)
  if (player:Health() >= 100) then
    versus.message.notify(player, "You do not need any more health!", NOTIFY_ERROR)

    return false
  else
    player:SetHealth(math.Clamp(player:Health() + 25, 0, 100))
  end
end

function ITEM:onDrop(player, position) end
