local PLUGIN = PLUGIN

PLUGIN.libraryKey = "npc"

versus.includePrefixed("sv_hooks.lua")

--- Don't have NPC's collide with each other
function PLUGIN.hook:ShouldCollide(ent1, ent2)
  if (ent1:GetClass():StartWith("npc_") and ent2:GetClass():StartWith("npc_")) then
    return false
  end
end
