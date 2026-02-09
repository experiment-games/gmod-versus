local PLUGIN = PLUGIN

function PLUGIN.hook:Think()
  self.updateChases()

  self.director.think()
end

function PLUGIN.hook:OnNPCDropItem(npc, itemEntity)
  -- Removes the item an NPC drops upon it spawning
  itemEntity:Remove()
end

function PLUGIN.hook:OnNPCKilled(npc, attacker, inflictor)
  -- If the NPC has a loot spawner function, call it to produce loot
  if (npc._VersusLootSpawner) then
    npc._VersusLootSpawner(npc, attacker, inflictor)
  end
end

-- Roll and see if we should upgrade the item rarity
function PLUGIN.hook:VersusNPCLootProduced(item, itemEntity)
  local rarity = versus.item.rollRarity()

  if (not rarity) then
    return
  end

  item.rarity = rarity.id
end

-- When the player dies, we remove any NPC we spawned specifically for them
function PLUGIN.hook:PostPlayerDeath(player)
  self.clearNPCsForPlayer(player)
end

--[[
  Net Messages
--]]

net.Receive("versus.npc.shopPurchase", function(len, player)
  local itemID = net.ReadString()
  local item = versus.item.get(itemID)
  local amount = 1

  if (not item) then
    versus.message.notify(player, "Invalid item selected.")
    return
  end

  if (not versus.inventory.canFit(player, item.size * amount)) then
    versus.message.notify(
      player,
      "You do not have enough space for this item!",
      NOTIFY_ERROR
    )

    return
  end

  -- Check if player can afford the item
  local canAfford, deficit = versus.finance.canAfford(player, item.cost)

  if (not canAfford) then
    versus.message.notify(player, "You cannot afford this item. You need " .. versus.finance.format(deficit) .. " more.")
    return
  end

  versus.finance.takeMoney(player, item.cost, "Purchased " .. item.name .. ".")

  versus.inventory.giveItem(player, item.itemID)
end)

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

--[[
  Console Commands
--]]

concommand.Add("npc_spawn_chase", function(ply, cmd, args)
  if (not ply:IsAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local npcClass = args[1] or "npc_zombie"
  local spawnPos = ply:GetEyeTrace().HitPos

  local npc = PLUGIN.spawnNPC(npcClass, spawnPos, Angle(0, 0, 0))
  if IsValid(npc) then
    npc:SetUnforgettable(ply)
    PLUGIN.setChase(npc, ply)
    ply:ChatPrint("Spawned " .. npcClass .. " - it's chasing you!")
  end
end)

concommand.Add("npc_spawn_assault", function(ply, cmd, args)
  if (not ply:IsAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local npcClass = args[1] or "npc_combine_s"
  local count = tonumber(args[2]) or 3
  local spawnPos = ply:GetPos() - ply:GetForward() * 500

  local npcs = {}
  for i = 1, count do
    local offsetPos = spawnPos + Vector(math.random(-200, 200), math.random(-200, 200), 0)
    local npc = PLUGIN.spawnNPC(npcClass, offsetPos, Angle(0, 0, 0))
    if IsValid(npc) then
      npc:Give("weapon_ar2")
      npc:SetUnforgettable(ply)
      table.insert(npcs, npc)
    end
  end

  if #npcs > 0 then
    -- Use ai_goal_assault with rally point
    local rallyPoint = spawnPos + Vector(0, 0, 10)
    PLUGIN.setAssault(npcs, ply:GetPos(), rallyPoint, { urgent = true })
    ply:ChatPrint("Spawned " .. #npcs .. " " .. npcClass .. "(s) assaulting! (using ai_goal_assault)")
  end
end)

concommand.Add("npc_spawn_follow", function(ply, cmd, args)
  if (not ply:IsAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local npcClass = args[1] or "npc_citizen"
  local spawnPos = ply:GetEyeTrace().HitPos

  local npc = PLUGIN.spawnNPC(npcClass, spawnPos, Angle(0, 0, 0))
  if IsValid(npc) then
    PLUGIN.setFollow(npc, ply, { formation = true })
    ply:ChatPrint("Spawned " .. npcClass .. " - it will follow you! (using ai_goal_follow)")
  end
end)

concommand.Add("npc_spawn_lead", function(ply, cmd, args)
  if (not ply:IsAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local npcClass = args[1] or "npc_citizen"
  local spawnPos = ply:GetPos() + ply:GetForward() * 100

  local npc = PLUGIN.spawnNPC(npcClass, spawnPos, Angle(0, 0, 0))
  if IsValid(npc) then
    -- Lead player to a point ahead
    local destination = ply:GetPos() + ply:GetForward() * 800
    PLUGIN.setLead(npc, ply, destination, { retrievePlayer = true })
    ply:ChatPrint("Spawned " .. npcClass .. " - follow it! (using ai_goal_lead)")
  end
end)

concommand.Add("npc_spawn_defend", function(ply, cmd, args)
  if (not ply:IsAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local npcClass = args[1] or "npc_combine_s"
  local defendPos = ply:GetEyeTrace().HitPos

  local npc = PLUGIN.spawnNPC(npcClass, defendPos, Angle(0, 0, 0))
  if IsValid(npc) then
    PLUGIN.setDefendPoint(npc, defendPos, 2048)
    ply:ChatPrint("Spawned " .. npcClass .. " defending this position (using info_node_hint)")
  end
end)

concommand.Add("npc_clear", function(ply, cmd, args)
  if (not ply:IsAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local count = 0
  for _, npc in ipairs(ents.FindByClass("npc_*")) do
    if IsValid(npc) then
      npc:Remove()
      count = count + 1
    end
  end

  ply:ChatPrint("Removed " .. count .. " NPCs")
end)
