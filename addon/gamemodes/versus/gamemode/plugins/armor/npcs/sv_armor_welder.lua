local PLUGIN = PLUGIN
local NPC = versus.npc.get("armor_welder") or {}

NPC.name = "Armor Welder"
NPC.description = "Repairs damaged armor back to full condition for a fee."
NPC.model = "models/Humans/Group03/male_05.mdl"
NPC.bodygroups = {}
NPC.health = versus.npc.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  versus.npc.openNPCMenu(player, "versus_ArmorWelder")
end

versus.npc.registerNPC("armor_welder", NPC)

--[[
  Logic
--]]

util.AddNetworkString("versus.npc.repairItem")

net.Receive("versus.npc.repairItem", function(len, player)
  local itemKey = net.ReadUInt(32)

  if not itemKey then
    return
  end

  -- Find the item in the inventory by its key
  local item = versus.inventory.getItem(player, itemKey)

  if not item then
    versus.message.notify(player, "Item not found in inventory!", NOTIFY_ERROR)
    return
  end

  if not item.maxHealth or item.maxHealth <= 0 then
    versus.message.notify(player, "This item cannot be repaired!", NOTIFY_ERROR)
    return
  end

  local damage = item.maxHealth - (item.health or item.maxHealth)

  if damage <= 0 then
    versus.message.notify(player, "This item is already fully repaired!", NOTIFY_GENERIC)
    return
  end

  local repairCost = damage * PLUGIN.armorHitPointCost

  local canAfford, deficit = versus.finance.canAfford(player, repairCost)

  if not canAfford then
    versus.message.notify(
      player,
      "You cannot afford this repair! You need " .. versus.util.formatMoney(deficit) .. " more.",
      NOTIFY_ERROR
    )
    return
  end

  -- Perform the repair
  item.health = item.maxHealth

  player:setCharacterDirty(true)

  versus.inventory.networkEntireInventory(player)

  versus.finance.takeMoney(player, repairCost, "Repaired " .. item.name)
end)
