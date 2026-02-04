local PLUGIN = PLUGIN

function PLUGIN.hook:OnNPCDropItem(npc, itemEntity)
  -- Removes the item an NPC drops upon it spawning
  itemEntity:Remove()
end

function PLUGIN.hook:OnNPCKilled(npc, attacker, inflictor)
  -- If the NPC has a loot spawner function, call it to produce loot
  if (npc._VersusLootSpawner) then
    npc._VersusLootSpawner()
  end
end

-- Roll and see if we should upgrade the item rarity
function PLUGIN.hook:VersusNPCSpawnerLootProduced(spawner, item, itemEntity)
  local rarity = versus.item.rollRarity()

  if (not rarity) then
    return
  end

  item.rarity = rarity.id
end

concommand.Add("versus_npc_adjust_loot", function(ply)
  if (not ply:IsAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  -- Find nearby NPC Spawner
  local spawner = nil
  local searchRadius = 200

  for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), searchRadius)) do
    if (IsValid(ent) and ent:GetClass() == "versus_npc_spawner") then
      spawner = ent
      break
    end
  end

  if (not IsValid(spawner)) then
    versus.message.notify(ply, "No NPC Spawner found within " .. searchRadius .. " units.")
    return
  end

  net.Start("versus.npc.startAdjustLootTable")
  net.WriteEntity(spawner)
  net.WriteTable(spawner:GetLootTable() or {})
  net.Send(ply)
end)
