local UNIT = UNIT

function UNIT.hook:SomeUnitInitialized(unit)
  -- Have all units load their items
  UNIT.loadItems(unit.fullPath .. "/items/")
end
