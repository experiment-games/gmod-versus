local UNIT = UNIT

function UNIT.hook:SomeUnitInitialized(unit)
  -- Have all units load their commands
  if (not file.Exists(unit.fullPath .. "/sh_commands.lua", "LUA")) then
    return
  end

  versus.includePrefixed("sh_commands.lua", unit.fullPath)
end
