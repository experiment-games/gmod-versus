local ITEM = ITEM

ITEM.name = "Health Kit"
ITEM.size = 1
ITEM.batch = 10
ITEM.cost = 300
ITEM.category = "Health"
ITEM.model = "models/items/healthkit.mdl"
ITEM.description = "A health kit which restores 50 health."

function ITEM:onUse(player)
  if (player:Health() >= 100) then
    versus.message.notify(player, "You do not need any more health!", NOTIFY_ERROR)

    return false
  else
    player:SetHealth(math.Clamp(player:Health() + 50, 0, 100))
  end
end

function ITEM:onDrop(player, position) end

function ITEM:onDestroy(player) end
