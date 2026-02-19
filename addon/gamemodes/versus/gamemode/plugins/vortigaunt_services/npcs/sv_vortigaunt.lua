local NPC = {}

NPC.name = "Vortigaunt"
NPC.description = "Infuses weapons with raw Xen energy for a price."
NPC.model = "models/vortigaunt.mdl"
NPC.bodygroups = {}
NPC.health = versus.npc.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  versus.npc.openNPCMenu(player, "versus_Vortigaunt")
end

versus.npc.registerNPC("vortigaunt", NPC)
