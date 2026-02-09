local PLUGIN = PLUGIN
local NPC = PLUGIN.get("medic") or {}

NPC.name = "Medic"
NPC.description = "Buys and sells health and medical supplies."
NPC.model = "models/Humans/Group03m/Female_04.mdl"
NPC.bodygroups = {}
NPC.health = PLUGIN.NO_HEALTH

function NPC:onInteract(client, npcEntity)
  print("Interacted with Medic NPC")
end

PLUGIN.registerNPC("medic", NPC)
