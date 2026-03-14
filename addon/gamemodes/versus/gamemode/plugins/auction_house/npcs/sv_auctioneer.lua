local NPC       = {}

NPC.name        = "Auctioneer"
NPC.description = "Lists items for auction and handles bids on behalf of players."
NPC.model       = "models/humans/group03/male_07.mdl"
NPC.health      = versus.npc.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  versus.npc.openNPCMenu(player, "versus_Auction")
end

versus.npc.registerNPC("auctioneer", NPC)
