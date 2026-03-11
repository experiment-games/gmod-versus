local UNIT = UNIT

function UNIT.hook:SomeUnitInitialized(unit)
  -- Have all units load their items
  UNIT.loadItems(unit.fullPath .. "/items/")
end

local function isInFront(player, entity)
  local playerForward = player:GetForward()
  local toEntity = (entity:GetPos() - player:GetPos()):GetNormalized()
  local dotProduct = playerForward:Dot(toEntity)

  return dotProduct > 0.6
end

-- If we're not looking directly at an entity, find nearby items and pick them up (nearest first).
function UNIT.hook:FindUseEntity(player, entity)
  if (IsValid(entity)) then
    return
  end

  local playerPosition = player:GetPos()
  local nearbyItems = {}

  for _, item in ipairs(ents.FindInSphere(playerPosition, 100)) do
    if (item:GetClass() == "versus_item" and isInFront(player, item)) then
      table.insert(nearbyItems, item)
    end
  end

  if (#nearbyItems == 0) then
    return
  end

  table.sort(nearbyItems, function(a, b)
    return a:GetPos():DistToSqr(playerPosition) < b:GetPos():DistToSqr(playerPosition)
  end)

  return nearbyItems[1]
end

-- Called when a player attempts to drop an item.
function UNIT.hook:PlayerCanDropItem(player, item, silent)
  if (item.undroppable) then
    if (not silent) then
      versus.message.notify(player, "This item cannot be dropped!", NOTIFY_ERROR)
    end

    return false
  end
end

-- Exclude base items and hidden items from item pools by default
function UNIT.hook:VersusShouldExcludeItemFromPool(item)
  if (item.isBaseItem or item.hidden) then
    return true
  end
end
