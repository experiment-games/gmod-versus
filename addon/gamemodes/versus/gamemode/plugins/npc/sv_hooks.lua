local PLUGIN = PLUGIN

local DOOR_CLASSES = {
  ["prop_door_rotating"] = true,
  ["func_door"]          = true,
  ["func_door_rotating"] = true,
}

local PLAYER_INVULNERABILITY_DISTANCE_SQR = 128 * 128

-- How close an antlion must be to a door to trigger it (units)
local TRIGGER_RADIUS = 200

-- Sounds played when a door is "broken" open
local BREAK_SOUNDS = {
  "physics/wood/wood_box_impact_hard1.wav",
  "physics/wood/wood_plank_break1.wav",
  "physics/wood/wood_plank_break2.wav",
  "physics/wood/wood_plank_break3.wav",
  "physics/wood/wood_plank_break4.wav",
}

local function playBreakSound(pos)
  local snd = BREAK_SOUNDS[math.random(#BREAK_SOUNDS)]
  sound.Play(snd, pos, 75, math.random(90, 110), 1)
end

local function isDoorOpen(door)
  -- prop_door_rotating exposes an m_eDoorState datamap value:
  --   0 = closed, 1 = opening, 2 = open, 3 = closing
  local cls = door:GetClass()
  if cls == "prop_door_rotating" then
    local state = door:GetInternalVariable("m_eDoorState")
    return state ~= nil and state ~= 0
  end

  -- TODO: Test this:
  -- func_door / func_door_rotating use m_toggle_state:
  --   0 = at_top, 1 = at_bottom, 2 = going_up, 3 = going_down
  local state = door:GetInternalVariable("m_toggle_state")
  return state ~= nil and state == 0
end

function PLUGIN.hook:SomeUnitInitialized(unit)
  -- Have all units load their npcs
  versus.includeDirectory(unit.fullPath .. "/npcs/")
end

function PLUGIN.hook:Think()
  self.updateChases()

  self.director.think()

  -- Antlions have issues opening doors on their own, so we check for nearby antlions and open doors for them if needed
  local antlions = ents.FindByClass("npc_antlion")
  if not antlions or #antlions == 0 then return end

  for _, antlion in ipairs(antlions) do
    if not IsValid(antlion) then continue end

    local aPos = antlion:GetPos()

    for _, door in ipairs(ents.FindInSphere(aPos, TRIGGER_RADIUS)) do
      if not IsValid(door) or not DOOR_CLASSES[door:GetClass()] or isDoorOpen(door) then
        continue
      end

      playBreakSound(door:GetPos())

      door:OpenDoorAwayFrom(aPos, nil, true)
    end
  end
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

-- Called when a player spawns.
function PLUGIN.hook:PlayerSpawn(player)
  if (player._LightSpawn) then
    -- Player restoring from being knocked down
    return
  end

  -- Start as undetectable until they move or attack to avoid NPCs immediately aggroing on them
  player:SetNoTarget(true)
  player._VersusInvulnerable = true

  local startPos = player:GetPos()
  local timerName = "Versus.PlayerInvul_" .. player:SteamID64()

  timer.Create(timerName, 0.1, 0, function()
    if not IsValid(player) then
      timer.Remove(timerName)
      return
    end

    -- If they've attacked.
    if (not player._VersusInvulnerable) then
      player:SetNoTarget(false)
      timer.Remove(timerName)
      return
    end

    -- Check if the player has moved too far from their spawn point. If they have, we remove
    -- their invulnerability.
    local currentPos = player:GetPos()
    local distance = currentPos:DistToSqr(startPos)

    if distance > PLAYER_INVULNERABILITY_DISTANCE_SQR then
      player._VersusInvulnerable = false
      player:SetNoTarget(false)
      timer.Remove(timerName)
    end
  end)
end

function PLUGIN.hook:PostEntityTakeDamage(ent, damageInfo, wasDamageTaken)
  if (not wasDamageTaken) then return end

  local attacker = damageInfo:GetAttacker()

  -- If the player was invulnerable, we block the damage and remove their invulnerability
  if (IsValid(attacker) and attacker:IsPlayer() and attacker._VersusInvulnerable) then
    attacker._VersusInvulnerable = false
  end
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

--[[
  Console Commands
--]]

concommand.Add("versus_npc_walk_here", function(ply, cmd, args)
  if (not ply:IsSuperAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  -- Get the position the player is aiming at
  local trace = ply:GetEyeTrace()
  local targetPos = trace.HitPos

  local count = 0

  -- Loop through all NPCs in the map
  for _, npc in ipairs(ents.FindByClass("npc_*")) do
    if IsValid(npc) and npc:IsNPC() then
      -- Make the NPC walk to the traced position
      npc:SetSchedule(SCHED_NONE)
      npc:TaskComplete()
      npc:ClearGoal()
      npc:SetLastPosition(targetPos)
      npc:SetSchedule(SCHED_FORCED_GO)
      count = count + 1
    end
  end

  ply:ChatPrint("[NPC Walk] Sending " .. count .. " NPC(s) to your aim position.")
end)

concommand.Add("versus_npc_spawn_chase", function(ply, cmd, args)
  if (not ply:IsSuperAdmin()) then
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

concommand.Add("versus_npc_spawn_assault", function(ply, cmd, args)
  if (not ply:IsSuperAdmin()) then
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

concommand.Add("versus_npc_spawn_follow", function(ply, cmd, args)
  if (not ply:IsSuperAdmin()) then
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

concommand.Add("versus_npc_spawn_lead", function(ply, cmd, args)
  if (not ply:IsSuperAdmin()) then
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

concommand.Add("versus_npc_spawn_defend", function(ply, cmd, args)
  if (not ply:IsSuperAdmin()) then
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

concommand.Add("versus_npc_clear", function(ply, cmd, args)
  if (not ply:IsSuperAdmin()) then
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

-- Quickly spawn versus_npc_spawn_point entities at all nodegraph nodes.
concommand.Add("versus_npc_spawn_points_from_nodes", function(ply, cmd, args)
  if (not ply:IsSuperAdmin()) then
    versus.message.notify(ply, "You do not have permission to use this command.", NOTIFY_ERROR)
    return
  end

  local graph = versus.nodeGraph.getForCurrentMap()

  if not graph then
    versus.message.notify(ply, "Nodegraph not loaded for current map.", NOTIFY_ERROR)
    return
  end

  local existing = ents.FindByClass("versus_npc_spawn_point")

  for _, ent in pairs(existing) do
    if IsValid(ent) then
      ent:Remove()
    end
  end

  local count = 0
  for _, node in pairs(graph:GetNodes(versus.nodeGraph.nodeTypes.NODE_TYPE_GROUND)) do
    local spawnPoint = ents.Create("versus_npc_spawn_point")
    spawnPoint:SetPos(node.pos)
    spawnPoint:Spawn()
    count = count + 1
  end

  versus.message.notify(
    ply,
    "Spawned " .. count
    .. " NPC spawn points based on nodegraph nodes (removed " .. #existing
    .. " existing spawn points first)."
  )
end)
