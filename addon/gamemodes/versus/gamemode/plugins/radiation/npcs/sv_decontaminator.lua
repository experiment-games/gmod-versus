local NPC = {}

NPC.name = "Decontaminator"
NPC.description = "Removes radiation for a fee."
NPC.model = "models/Humans/Group03m/female_02.mdl"
NPC.bodygroups = {}
NPC.health = versus.npc.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  versus.npc.openNPCMenu(player, "versus_Decontaminator")
end

function NPC:onSetup(npcEntity)
  -- Give the npc a slight green effect as a joke
  npcEntity:SetColor(Color(222, 255, 222, 255))
end

versus.npc.registerNPC("decontaminator", NPC)
