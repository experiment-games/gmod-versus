local UNIT = UNIT

UNIT.libraryKey = "entity"

-- TODO: Replace all instances of entity:Distance() with this function
function UNIT.isNearPosition(entity, position, distance)
  return entity:GetPos():DistToSqr(position) < (distance * distance)
end
