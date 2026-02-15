local PLUGIN = PLUGIN
local NPC = PLUGIN.get("scrapper") or {}

NPC.name = "Scrapper"
NPC.description = "Buys unwanted items for cash."
NPC.model = "models/Humans/Group03/male_07.mdl"
NPC.bodygroups = {}
NPC.health = PLUGIN.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  PLUGIN.openNPCMenu(player, "versus_Scrapper")
end

PLUGIN.registerNPC("scrapper", NPC)

--[[
  Logic
--]]

util.AddNetworkString("versus.npc.scrapItem")

net.Receive("versus.npc.scrapItem", function(len, player)
  local itemKey = net.ReadUInt(16)
  local amount = net.ReadUInt(16)

  if not itemKey or not amount or amount <= 0 then
    return
  end

  -- Find the item in the inventory
  local item = versus.inventory.getItem(player, itemKey)

  if (not item) then
    versus.message.notify(player, "Item not found in inventory!", NOTIFY_ERROR)
    return
  end

  -- Calculate scrap value
  local scrapValuePerItem = PLUGIN.getScrapValue(item)

  if (not scrapValuePerItem) then
    versus.message.notify(player, "This item cannot be scrapped!", NOTIFY_ERROR)
    return
  end

  -- Determine how many items we can actually scrap
  local itemCount = versus.inventory.countItem(player, item)
  local actualAmount = math.min(amount, itemCount)
  local totalScrapValue = scrapValuePerItem * actualAmount

  versus.inventory.takeItem(player, item.itemID, actualAmount, true)

  versus.inventory.networkEntireInventory(player)

  versus.finance.giveMoney(player, totalScrapValue, "Scrapped " .. actualAmount .. "x " .. item.name .. ".")
end)
