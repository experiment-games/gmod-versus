local UNIT = UNIT

UNIT.libraryKey = "weapon"
UNIT.weaponSwitchDelay = 1

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

if (CLIENT) then
  UNIT.convarHints = CreateClientConVar("versus_weapon_hints", "1", true, false)
end
