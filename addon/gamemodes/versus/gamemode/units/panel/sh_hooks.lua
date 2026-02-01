local UNIT = UNIT

function UNIT.hook:SomeUnitInitialized(unit)
  -- Have all units load their panels
  UNIT.loadPanels(unit.fullPath .. "/panels/")
end
