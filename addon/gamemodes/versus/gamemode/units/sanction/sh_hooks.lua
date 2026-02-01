local UNIT = UNIT

function UNIT.hook:SomeUnitInitialized(unit)
  -- Have all units load their sanctions
  if (file.Exists(unit.fullPath .. "/sh_sanctions.lua", "LUA")) then
    versus.includePrefixed("sh_sanctions.lua", unit.fullPath)
  end

  versus.includeDirectory(unit.fullPath .. "/sanctions/")
end
