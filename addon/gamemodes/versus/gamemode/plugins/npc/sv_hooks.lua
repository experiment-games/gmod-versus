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
    PLUGIN.SetAssault(npcs, ply:GetPos(), rallyPoint, { urgent = true })
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
    PLUGIN.SetFollow(npc, ply, { formation = true })
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
    PLUGIN.SetLead(npc, ply, destination, { retrievePlayer = true })
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
    PLUGIN.SetDefendPoint(npc, defendPos, 2048)
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
