local UNIT = UNIT

function UNIT.hook:SomeUnitInitialized(unit)
  -- Have all units load their missions
  UNIT.loadMissions(unit.fullPath .. "/missions/")
end
