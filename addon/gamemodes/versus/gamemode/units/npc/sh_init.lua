local UNIT = UNIT

UNIT.libraryKey = "npc"

--- Don't have NPC's collide with each other
function UNIT.hook:ShouldCollide(ent1, ent2)
  if (ent1:GetClass():StartWith("npc_") and ent2:GetClass():StartWith("npc_")) then
    return false
  end
end
