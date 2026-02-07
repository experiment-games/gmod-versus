local PLUGIN = PLUGIN

PLUGIN.enemiesChased = PLUGIN.enemiesChased or {}

--- Register chase for cleanup and to keep track of targets
--- @param npc Entity The NPC entity
--- @param target Entity The target entity being chased
function PLUGIN.registerChase(npc, target)
  if not IsValid(npc) or not IsValid(target) then return end

  PLUGIN.enemiesChased[npc] = target
end

--- Unregisters a chase when behavior is cleared
--- @param npc Entity The NPC entity
function PLUGIN.unregisterChase(npc)
  if not IsValid(npc) then return end

  PLUGIN.clearBehavior(npc)
  PLUGIN.enemiesChased[npc] = nil
end

--- Ensures the NPC either keeps chasing the target or clears behavior if target is lost
--- @param npc Entity The NPC entity
--- @param target Entity The target entity being chased
function PLUGIN.updateChase(npc, target)
  if not IsValid(npc) then return end

  if IsValid(target) then
    npc:SetEnemy(target, false)
    npc:UpdateEnemyMemory(target, target:GetPos())
    npc:AddEntityRelationship(target, D_HT, 99)
  else
    PLUGIN.unregisterChase(npc)
  end
end

--- Call all chase updates on Think to ensure NPCs react to target loss
function PLUGIN.updateChases()
  for npc, target in pairs(PLUGIN.enemiesChased) do
    if IsValid(npc) then
      PLUGIN.updateChase(npc, target)
    else
      PLUGIN.enemiesChased[npc] = nil
    end
  end
end

--- Spawn an NPC with basic setup
--- @param class string NPC class name (npc_combine_s, npc_zombie, etc.)
--- @param pos Vector position to spawn at
--- @param angle Angle to face
--- @return Entity # The spawned NPC entity (or NULL if failed)
function PLUGIN.spawnNPC(class, pos, angle)
  local npc = ents.Create(class)
  if not IsValid(npc) then
    print("Failed to create NPC: " .. class)
    return npc
  end

  npc:SetPos(pos)
  npc:SetAngles(angle or Angle(0, 0, 0))
  npc:Spawn()
  npc:Activate()

  -- Store behavior entities for cleanup
  npc.BehaviorEntities = {}
  npc.BehaviorMode = "idle"

  return npc
end

--- CHASE BEHAVIOR
--- Makes NPC chase and attack a target
--- Simply sets the target as enemy - Source Engine handles the rest
--- @param npc Entity The NPC entity
--- @param target Entity The entity to chase
function PLUGIN.setChase(npc, target)
  if not IsValid(npc) or not IsValid(target) then return end

  PLUGIN.clearBehavior(npc)
  npc.BehaviorMode = "chase"

  -- Set enemy - Source AI will handle chasing
  npc:SetEnemy(target)
  npc:UpdateEnemyMemory(target, target:GetPos())
  npc:AddEntityRelationship(target, D_HT, 99)

  PLUGIN.registerChase(npc, target)
end

--- ASSAULT BEHAVIOR
--- Uses ai_goal_assault to make NPCs assault a position
--- @param npcs Entity[] Table of NPC entities or single NPC
--- @param assaultPoint Vector position to assault
--- @param rallyPoint? Vector position to rally at before assault
--- @param options? { repel: boolean, urgent: boolean, forceClear: boolean } assault options
function PLUGIN.SetAssault(npcs, assaultPoint, rallyPoint, options)
  if not istable(npcs) then npcs = { npcs } end
  options = options or {}

  -- Create the assault destination entity
  local assaultEnt = ents.Create("info_target")
  if not IsValid(assaultEnt) then return end

  assaultEnt:SetPos(assaultPoint)
  assaultEnt:SetName("assault_point_" .. CurTime())
  assaultEnt:Spawn()
  assaultEnt:Activate()

  -- Create rally point if provided
  local rallyEnt = nil
  if rallyPoint then
    rallyEnt = ents.Create("info_target")
    if IsValid(rallyEnt) then
      rallyEnt:SetPos(rallyPoint)
      rallyEnt:SetName("rally_point_" .. CurTime())
      rallyEnt:Spawn()
      rallyEnt:Activate()
    end
  end

  -- Create ai_goal_assault for each NPC
  for _, npc in ipairs(npcs) do
    if IsValid(npc) then
      PLUGIN.clearBehavior(npc)
      npc.BehaviorMode = "assault"

      -- Give NPC a name if it doesn't have one
      if npc:GetName() == "" then
        npc:SetName("npc_assault_" .. npc:EntIndex())
      end

      -- Create the assault goal
      local assaultGoal = ents.Create("ai_goal_assault")
      if IsValid(assaultGoal) then
        assaultGoal:SetPos(npc:GetPos())
        assaultGoal:SetKeyValue("actor", npc:GetName())
        assaultGoal:SetKeyValue("goal", assaultEnt:GetName())

        if rallyEnt then
          assaultGoal:SetKeyValue("rally", rallyEnt:GetName())
        end

        -- Set flags
        local flags = 0
        if options.repel then flags = flags + 1 end      -- SF_ASSAULT_RALLY
        if options.urgent then flags = flags + 2 end     -- SF_ASSAULT_URGENT
        if options.forceClear then flags = flags + 4 end -- SF_ASSAULT_CLEAR
        assaultGoal:SetKeyValue("spawnflags", tostring(flags))

        assaultGoal:Spawn()
        assaultGoal:Activate()
        assaultGoal:Fire("Activate", "", 0)

        table.insert(npc.BehaviorEntities, assaultGoal)
      end
    end
  end

  -- Store for cleanup
  npcs[1].AssaultSharedEnts = { assaultEnt, rallyEnt }
end

--- FOLLOW BEHAVIOR
--- Uses ai_goal_follow to make NPC follow a target
--- @param npc Entity The NPC entity
--- @param target Entity Entity to follow (usually a player)
--- @param options? { formation: boolean, waitForSpeak: boolean, successDist: number } follow options
function PLUGIN.SetFollow(npc, target, options)
  if not IsValid(npc) or not IsValid(target) then return end

  PLUGIN.clearBehavior(npc)
  npc.BehaviorMode = "follow"
  options = options or {}

  -- Give NPC a name if needed
  if npc:GetName() == "" then
    npc:SetName("npc_follow_" .. npc:EntIndex())
  end

  -- Give target a name if needed
  if target:GetName() == "" then
    target:SetName("follow_target_" .. target:EntIndex())
  end

  -- Make NPC friendly to target if it's a player
  if target:IsPlayer() then
    npc:AddEntityRelationship(target, D_LI, 99)
  end

  -- Create ai_goal_follow
  local followGoal = ents.Create("ai_goal_follow")
  if IsValid(followGoal) then
    followGoal:SetPos(npc:GetPos())
    followGoal:SetKeyValue("actor", npc:GetName())
    followGoal:SetKeyValue("goal", target:GetName())
    followGoal:SetKeyValue("SearchType", "0")   -- Default search
    followGoal:SetKeyValue("MaximumState", "1") -- ACTIVE

    -- Set flags
    local flags = 0
    if options.formation ~= false then flags = flags + 1 end -- SF_FOLLOW_FORMATION
    if options.waitForSpeak then flags = flags + 2 end       -- SF_FOLLOW_WAIT_FOR_SPEAK
    followGoal:SetKeyValue("spawnflags", tostring(flags))

    if options.successDist then
      followGoal:SetKeyValue("SuccessDistance", tostring(options.successDist))
    end

    followGoal:Spawn()
    followGoal:Activate()
    followGoal:Fire("Activate", "", 0)

    table.insert(npc.BehaviorEntities, followGoal)
  end
end

--- LEAD BEHAVIOR (Bonus!)
--- Uses ai_goal_lead to make NPC lead a player to a destination
--- @param npc Entity The NPC entity
--- @param player Entity Player to lead
--- @param destination Vector Vector position to lead to
--- @param options { waitDistance: number, leadDistance: number, retrievePlayer: boolean, dontSpeakStart: boolean } lead options
function PLUGIN.SetLead(npc, player, destination, options)
  if not IsValid(npc) or not IsValid(player) then return end

  PLUGIN.clearBehavior(npc)
  npc.BehaviorMode = "lead"
  options = options or {}

  -- Give NPC a name if needed
  if npc:GetName() == "" then
    npc:SetName("npc_lead_" .. npc:EntIndex())
  end

  -- Give player a name if needed
  if player:GetName() == "" then
    player:SetName("lead_player_" .. player:EntIndex())
  end

  -- Create destination entity
  local destEnt = ents.Create("info_target")
  if IsValid(destEnt) then
    destEnt:SetPos(destination)
    destEnt:SetName("lead_dest_" .. CurTime())
    destEnt:Spawn()
    destEnt:Activate()

    table.insert(npc.BehaviorEntities, destEnt)

    -- Create ai_goal_lead
    local leadGoal = ents.Create("ai_goal_lead")
    if IsValid(leadGoal) then
      leadGoal:SetPos(npc:GetPos())
      leadGoal:SetKeyValue("actor", npc:GetName())
      leadGoal:SetKeyValue("goal", destEnt:GetName())
      leadGoal:SetKeyValue("SearchType", player:GetName())
      leadGoal:SetKeyValue("WaitDistance", tostring(options.waitDistance or 128))
      leadGoal:SetKeyValue("LeadDistance", tostring(options.leadDistance or 64))

      -- Set flags
      local flags = 0
      if options.retrievePlayer then flags = flags + 1 end -- SF_LEAD_RETRIEVE
      if options.dontSpeakStart then flags = flags + 2 end -- SF_LEAD_DONT_SPEAK_START
      leadGoal:SetKeyValue("spawnflags", tostring(flags))

      leadGoal:Spawn()
      leadGoal:Activate()
      leadGoal:Fire("Activate", "", 0)

      table.insert(npc.BehaviorEntities, leadGoal)
    end
  end
end

--- SCRIPTED SEQUENCE
--- Make NPC perform a scripted sequence at a location
--- @param npc Entity The NPC entity
--- @param targetPos Vector Position to move to
--- @param sequence string Animation sequence name (e.g., "sit", "wave")
--- @param options { loop: boolean, moveToPosition: boolean, idle: string, entry: string, exit: string } Table of options
function PLUGIN.SetScriptedSequence(npc, targetPos, sequence, options)
  if not IsValid(npc) then return end

  PLUGIN.clearBehavior(npc)
  npc.BehaviorMode = "scripted"
  options = options or {}

  -- Give NPC a name if needed
  if npc:GetName() == "" then
    npc:SetName("npc_scripted_" .. npc:EntIndex())
  end

  local scriptSeq = ents.Create("scripted_sequence")
  if IsValid(scriptSeq) then
    scriptSeq:SetPos(targetPos)
    scriptSeq:SetKeyValue("m_iszEntity", npc:GetName())

    if sequence then
      scriptSeq:SetKeyValue("m_iszPlay", sequence)
    end

    if options.idle then
      scriptSeq:SetKeyValue("m_iszIdle", options.idle)
    end

    if options.entry then
      scriptSeq:SetKeyValue("m_iszEntry", options.entry)
    end

    if options.exit then
      scriptSeq:SetKeyValue("m_iszPostIdle", options.exit)
    end

    -- Move to position
    if options.moveToPosition ~= false then
      scriptSeq:SetKeyValue("m_fMoveTo", "5") -- Walk/Run to position
    else
      scriptSeq:SetKeyValue("m_fMoveTo", "0") -- No movement
    end

    -- Set flags
    local flags = 0
    if options.loop then flags = flags + 32 end      -- SF_SCRIPT_LOOP
    if options.repeatable then flags = flags + 4 end -- SF_SCRIPT_REPEATABLE
    flags = flags + 64                               -- SF_SCRIPT_SEARCH_CYCLICALLY
    scriptSeq:SetKeyValue("spawnflags", tostring(flags))

    scriptSeq:Spawn()
    scriptSeq:Activate()
    scriptSeq:Fire("BeginSequence", "", 0)

    table.insert(npc.BehaviorEntities, scriptSeq)
  end
end

--- DEFEND POINT
--- Make NPC defend a specific point using ai_goal_actbusy
--- @param npc Entity The NPC entity
--- @param defendPos Vector Position to defend
--- @param sightDist number How far NPC can see enemies (default 2048)
function PLUGIN.SetDefendPoint(npc, defendPos, sightDist)
  if not IsValid(npc) then return end

  PLUGIN.clearBehavior(npc)
  npc.BehaviorMode = "defend"

  -- Move NPC to position first
  npc:SetPos(defendPos)

  -- Set sight distance
  if sightDist then
    npc:SetKeyValue("sensedist", tostring(sightDist))
  end

  -- Create a hint node at the position
  local hint = ents.Create("info_node_hint")
  if IsValid(hint) then
    hint:SetPos(defendPos)
    hint:SetKeyValue("hinttype", "2") -- Combat hint
    hint:SetKeyValue("nodeFOV", "360")
    hint:Spawn()
    hint:Activate()

    table.insert(npc.BehaviorEntities, hint)
  end
end

--- Clear all behaviors from NPC
--- @param npc Entity The NPC entity
function PLUGIN.clearBehavior(npc)
  if not IsValid(npc) then return end

  -- Remove all behavior entities
  if npc.BehaviorEntities then
    for _, ent in ipairs(npc.BehaviorEntities) do
      if IsValid(ent) then
        ent:Remove()
      end
    end
    npc.BehaviorEntities = {}
  end

  -- Clean up shared entities
  if npc.AssaultSharedEnts then
    for _, ent in ipairs(npc.AssaultSharedEnts) do
      if IsValid(ent) then
        ent:Remove()
      end
    end
    npc.AssaultSharedEnts = nil
  end

  -- Remove timers
  timer.Remove("Chase_" .. npc:EntIndex())

  npc.BehaviorMode = "idle"
end

-- Cleanup when NPC is removed
hook.Add("EntityRemoved", "NPCBehavior_Cleanup", function(ent)
  if ent:IsNPC() then
    PLUGIN.clearBehavior(ent)
  end
end)

--- Scenario: Combine Squad Assault with ai_goal_assault
function PLUGIN.createCombineAssault(rallyPoint, assaultPoint, squadSize)
  squadSize = squadSize or 6

  local npcs = {}
  for i = 1, squadSize do
    local angle = (i / squadSize) * 360
    local spawnPos = rallyPoint + Vector(
      math.cos(math.rad(angle)) * 150,
      math.sin(math.rad(angle)) * 150,
      0
    )

    local npc = PLUGIN.spawnNPC("npc_combine_s", spawnPos, Angle(0, 0, 0))
    if IsValid(npc) then
      table.insert(npcs, npc)
    end
  end

  -- Use ai_goal_assault with urgent flag
  PLUGIN.SetAssault(npcs, assaultPoint, rallyPoint, {
    urgent = true,
    forceClear = true
  })

  return npcs
end

--- Scenario: Escort Mission using ai_goal_follow
function PLUGIN.createEscortMission(player, bodyguardClass, count)
  bodyguardClass = bodyguardClass or "npc_citizen"
  count = count or 2

  local npcs = {}
  for i = 1, count do
    local angle = (i / count) * 360
    local spawnPos = player:GetPos() + Vector(
      math.cos(math.rad(angle)) * 120,
      math.sin(math.rad(angle)) * 120,
      0
    )

    local npc = PLUGIN.spawnNPC(bodyguardClass, spawnPos, Angle(0, 0, 0))
    if IsValid(npc) then
      -- Give them a weapon
      if bodyguardClass == "npc_citizen" then
        npc:Give("weapon_ar2")
      end

      -- Use ai_goal_follow with formation
      PLUGIN.SetFollow(npc, player, {
        formation = true,
        successDist = 96
      })

      table.insert(npcs, npc)
    end
  end

  return npcs
end

--- Scenario: Guard Post with Defenders
function PLUGIN.createGuardPost(centerPos, guardClass, count)
  guardClass = guardClass or "npc_metropolice"
  count = count or 4

  local npcs = {}
  for i = 1, count do
    local angle = (i / count) * 360
    local defendPos = centerPos + Vector(
      math.cos(math.rad(angle)) * 200,
      math.sin(math.rad(angle)) * 200,
      0
    )

    local npc = PLUGIN.spawnNPC(guardClass, defendPos, Angle(0, angle, 0))
    if IsValid(npc) then
      PLUGIN.SetDefendPoint(npc, defendPos, 1500)
      table.insert(npcs, npc)
    end
  end

  return npcs
end

--- Scenario: Scripted Ambush
function PLUGIN.createScriptedAmbush(ambushPositions, targetPlayer)
  local npcs = {}

  for i, pos in ipairs(ambushPositions) do
    local npc = PLUGIN.spawnNPC("npc_combine_s", pos, Angle(0, 0, 0))
    if IsValid(npc) then
      -- Start crouched and waiting
      PLUGIN.SetScriptedSequence(npc, pos, "crouch_aim", {
        loop = true,
        moveToPosition = false,
        idle = "crouch_idle"
      })

      table.insert(npcs, npc)

      -- When player gets close, switch to chase
      timer.Create("Ambush_" .. npc:EntIndex(), 0.5, 0, function()
        if not IsValid(npc) or not IsValid(targetPlayer) then
          timer.Remove("Ambush_" .. npc:EntIndex())
          return
        end

        local dist = npc:GetPos():Distance(targetPlayer:GetPos())
        if dist < 400 then
          PLUGIN.setChase(npc, targetPlayer)
          timer.Remove("Ambush_" .. npc:EntIndex())
        end
      end)
    end
  end

  return npcs
end

--- Scenario: Multi-Wave Defense
function PLUGIN.createWaveDefense(defensePoint, waveCount, npcsPerWave)
  npcsPerWave = npcsPerWave or 5
  local currentWave = 1

  local function SpawnWave()
    if currentWave > waveCount then
      print("All waves complete!")
      return
    end

    print("Spawning wave " .. currentWave .. " of " .. waveCount)

    local spawnPoint = defensePoint + Vector(1000, 1000, 0)
    local npcs = {}

    for i = 1, npcsPerWave do
      local offset = Vector(math.random(-200, 200), math.random(-200, 200), 0)
      local npc = PLUGIN.spawnNPC("npc_zombie", spawnPoint + offset, Angle(0, 0, 0))
      if IsValid(npc) then
        table.insert(npcs, npc)
      end
    end

    -- Assault the defense point
    PLUGIN.SetAssault(npcs, defensePoint, spawnPoint, { urgent = true })

    currentWave = currentWave + 1

    -- Spawn next wave after delay
    timer.Simple(30, function()
      SpawnWave()
    end)
  end

  SpawnWave()
end
