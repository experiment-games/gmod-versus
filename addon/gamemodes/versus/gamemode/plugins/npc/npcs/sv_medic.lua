local PLUGIN = PLUGIN
local NPC = PLUGIN.get("medic") or {}

NPC.name = "Medic"
NPC.description = "Sells health and medical supplies."
NPC.model = "models/Humans/Group03m/Female_04.mdl"
NPC.bodygroups = {}
NPC.health = PLUGIN.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  PLUGIN.openNPCMenu(player, "versus_Shop", "medic")
end

PLUGIN.registerNPC("medic", NPC)
