local PLUGIN = PLUGIN

PLUGIN.enemiesChased = PLUGIN.enemiesChased or {}
PLUGIN.npcs = PLUGIN.npcs or {}

util.AddNetworkString("versus.npc.openNPCMenu")
util.AddNetworkString("versus.npc.shopPurchase")

function PLUGIN.registerNPC(uniqueID, npc)
  npc.uniqueID = uniqueID

  PLUGIN.npcs[uniqueID] = npc
end

--- Gets an npc setup by name
--- @param npcID string The unique ID of the NPC to setup
--- @return table
function PLUGIN.get(npcID)
  return PLUGIN.npcs[npcID] or {
    uniqueID = npcID,
    name = npcID,
    description = "Test",
    model = nil, -- will be random
    bodygroups = {},
    health = PLUGIN.NO_HEALTH,
  }
end

function PLUGIN.tryPlayerInteractNPC(player, npcEntity, npcID)
  local npcData = PLUGIN.get(npcID)

  if (npcData and npcData.onInteract) then
    npcData:onInteract(player, npcEntity)
  else
    print("Player " .. player:Nick() .. " used NPC with ID: " .. npcID)
  end
end

--- Opens an NPC menu for the player with the specified menu class and arguments,
--- sends at most 7 arguments of any type to the client for menu setup.
--- @param player Player The player to open the menu for
--- @param menuClass string The class name of the menu to open (e.g., "armoury", "medic")
--- @param ... any Additional arguments to send to the client for menu setup (up to 7)
function PLUGIN.openNPCMenu(player, menuClass, ...)
  net.Start("versus.npc.openNPCMenu")
  net.WriteString(menuClass)
  net.WriteUInt(select("#", ...), 3)

  for i = 1, select("#", ...) do
    local arg = select(i, ...)
    net.WriteType(arg)
  end

  net.Send(player)
end

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

  -- Let any NPC open doors, so zombies and stuff can get through them
  npc:CapabilitiesAdd(CAP_OPEN_DOORS)
  npc:CapabilitiesAdd(CAP_AUTO_DOORS)

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
function PLUGIN.setAssault(npcs, assaultPoint, rallyPoint, options)
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
function PLUGIN.setFollow(npc, target, options)
  if not IsValid(npc) or not IsValid(target) then return end

  PLUGIN.clearBehavior(npc)
  npc.BehaviorEntities = npc.BehaviorEntities or {}
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
function PLUGIN.setLead(npc, player, destination, options)
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
function PLUGIN.setScriptedSequence(npc, targetPos, sequence, options)
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
function PLUGIN.setDefendPoint(npc, defendPos, sightDist)
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
  PLUGIN.setAssault(npcs, assaultPoint, rallyPoint, {
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
      PLUGIN.setFollow(npc, player, {
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
      PLUGIN.setDefendPoint(npc, defendPos, 1500)
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
      PLUGIN.setScriptedSequence(npc, pos, "crouch_aim", {
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
    PLUGIN.setAssault(npcs, defensePoint, spawnPoint, { urgent = true })

    currentWave = currentWave + 1

    -- Spawn next wave after delay
    timer.Simple(30, function()
      SpawnWave()
    end)
  end

  SpawnWave()
end

--- Finds a valid ground position by tracing from a point downward
--- @param position Vector # The position to trace from
--- @return table? # Trace result if valid ground found, nil otherwise
local function findGroundPosition(position)
  -- If we don't start in the world already, return nil immediately since we would be
  -- more likely to find ceilings below rather than the ground we're looking for
  if (not util.IsInWorld(position)) then
    return nil
  end

  local trace = util.TraceLine({
    start = position,
    endpos = position - Vector(0, 0, 1024),
    mask = MASK_NPCSOLID_BRUSHONLY,
  })

  debugoverlay.Line(position, trace.HitPos, 30, Color(0, 255, 255), true) -- Visualize ground trace

  if (trace.Hit and not trace.HitSky and util.IsInWorld(trace.HitPos)) then
    return trace
  end

  return nil
end

--- Checks if there's enough vertical space for an NPC at the given position
--- @param groundPos Vector # The ground position to check
--- @return boolean # True if there's enough space
local function hasVerticalSpace(groundPos)
  local hullTrace = util.TraceHull({
    start = groundPos + Vector(0, 0, 16),
    endpos = groundPos + Vector(0, 0, 72),
    mins = Vector(-16, -16, 0),
    maxs = Vector(16, 16, 72),
    mask = MASK_NPCSOLID_BRUSHONLY,
  })

  return not hullTrace.Hit
end

--- Traces outward from spawn point to find a valid position against a wall
--- @param spawnPoint Vector # The center point to trace from
--- @param angle number # The angle in radians to trace in
--- @param maxDistance number # Maximum distance to trace
--- @return Vector|nil # Valid spawn position or nil if none found
local function findWallSpawnPosition(spawnPoint, angle, maxDistance)
  local direction = Vector(math.cos(angle), math.sin(angle), 0)
  local traceEnd = spawnPoint + direction * maxDistance

  -- Trace outward to find a wall
  local wallTrace = util.TraceLine({
    start = spawnPoint,
    endpos = traceEnd,
    mask = MASK_NPCSOLID_BRUSHONLY,
  })

  -- If we hit something, move back a bit from the wall
  if wallTrace.Hit and not wallTrace.HitSky then
    local pullbackDistance = 96 -- Distance to move back from the wall
    local candidatePos = wallTrace.HitPos - direction * pullbackDistance

    -- Now find ground at this position
    local groundTrace = findGroundPosition(candidatePos)
    if groundTrace and hasVerticalSpace(groundTrace.HitPos) then
      return groundTrace.HitPos
    end
  end

  return nil
end

--- Configures an NPC with enemy and weapons
--- @param npc Entity # The NPC to configure
--- @param weapons table # The weapons to give
--- @param primaryEnemy? Entity # The primary enemy to target
local function configureNPC(npc, weapons, primaryEnemy)
  if IsValid(primaryEnemy) then
    npc:AddEntityRelationship(primaryEnemy, D_HT, 99)
    npc:SetEyeTarget(primaryEnemy:WorldSpaceCenter())
    npc._VersusPrimaryEnemy = primaryEnemy

    primaryEnemy._VersusNPCs = primaryEnemy._VersusNPCs or {}
    table.insert(primaryEnemy._VersusNPCs, npc)
  end

  if (weapons) then
    for _, weaponClass in ipairs(weapons) do
      npc:Give(weaponClass)
    end
  end

  -- Safety check: remove if spawned outside world
  timer.Simple(0, function()
    if not IsValid(npc) then
      return
    end

    if (not npc:IsInWorld()) then
      print("[Contract] NPC spawned below world, removing: " .. tostring(npc))
      npc:Remove()
      return
    end
  end)
end

--- Finds nearby versus_npc_spawn_point entities, preferring ones not visible to any player.
--- Falls back to a random observed one if all are visible, or nil if none are found nearby.
--- @param spawnPoint Vector # The center point to search from
--- @param searchRadius number # How far to search for spawn points
--- @return Entity? # A spawn point entity, or nil if none found nearby
--- @return Entity[] # Table of all nearby spawn point entities found
local function findBestSpawnPointEntity(spawnPoint, searchRadius)
  local spawnPoints = {}

  for _, ent in ipairs(ents.FindInSphere(spawnPoint, searchRadius)) do
    if ent:GetClass() == "versus_npc_spawn_point" then
      table.insert(spawnPoints, ent)
    end
  end

  if #spawnPoints == 0 then
    return nil, {}
  end

  local unobserved = {}
  local observed = {}
  local nearestUnobserved = nil
  local nearestUnobservedDist = math.huge

  for _, ent in ipairs(spawnPoints) do
    local seen = PLUGIN.canAnyPlayerSeeEntity(ent)

    if seen then
      -- debugoverlay.Line(spawnPoint, ent:GetPos(), 30, Color(255, 0, 0), true)
      table.insert(observed, ent)
    else
      -- debugoverlay.Line(spawnPoint, ent:GetPos(), 30, Color(0, 255, 0), true)
      table.insert(unobserved, ent)

      local dist = spawnPoint:Distance(ent:GetPos())
      if dist < nearestUnobservedDist then
        nearestUnobservedDist = dist
        nearestUnobserved = ent
      end
    end
  end

  if #unobserved == 0 then
    return observed[math.random(#observed)], {}
  end

  return nearestUnobserved, spawnPoints
end

--- Spawns NPCs around a specific point, automatically finding the largest open space nearby
--- if the point is blocked or near walls.
--- @param npcClass string # The class of NPC to spawn
--- @param spawnPoint Vector # The exact point to spawn around
--- @param count number # The number of NPCs to spawn
--- @param weapons table # The weapons to give to the NPCs
--- @param primaryEnemy? Entity # The primary enemy to target
--- @return Entity[] # Table of spawned NPC entities
function PLUGIN.spawnNPCsAtPoint(npcClass, spawnPoint, count, weapons, primaryEnemy)
  local spawned = {}
  local attempts = 0
  local maxAttempts = count * 60

  -- Now spawn NPCs around this open space
  while #spawned < count and attempts < maxAttempts do
    attempts = attempts + 1

    -- Use a combination of random and distributed positioning
    local spawnRadius = 96 + ((#spawned + attempts) * 16) -- Start tight, expand as we spawn more
    local angle = math.rad(math.random(0, 360))
    local distance = math.random(0, spawnRadius)

    -- Add some spiral distribution to avoid clustering
    if #spawned > 0 then
      angle = angle + (#spawned * 2.4) -- Golden angle approximation for even distribution
    end

    local testPos = spawnPoint + Vector(
      math.cos(angle) * distance,
      math.sin(angle) * distance,
      32 -- Slightly off the ground, so models at ground level don't trace down to ceilings below
    )

    -- Verify this specific position is valid
    local groundTrace = findGroundPosition(testPos)
    if groundTrace and hasVerticalSpace(groundTrace.HitPos) then
      local finalPos = groundTrace.HitPos

      -- Additional check: make sure NPCs aren't spawned too close to each other
      local tooClose = false
      for _, existingNPC in ipairs(spawned) do
        if IsValid(existingNPC) and existingNPC:GetPos():Distance(finalPos) < 48 then
          tooClose = true
          break
        end
      end

      if not tooClose then
        local npc = ents.Create(npcClass)
        if IsValid(npc) then
          -- Required so they don't collide with eachother
          npc:SetCustomCollisionCheck(true)

          npc:SetPos(finalPos)
          npc:Spawn()
          npc:Activate()
          npc:SetSchedule(SCHED_NONE)
          npc:TaskComplete()
          npc:ClearGoal()
          npc:SetLastPosition(spawnPoint)
          npc:SetSchedule(SCHED_FORCED_GO)

          debugoverlay.Sphere(finalPos, 16, 30, Color(0, 255, 0), true) -- Visualize spawn position

          configureNPC(npc, weapons, primaryEnemy)
          table.insert(spawned, npc)
        end
      end
    end
  end

  if #spawned < count then
    ErrorNoHalt(
      string.format(
        "[Versus] Spawned %d/%d NPCs of class %s. Could not find enough valid spawn positions near %s.\n",
        #spawned,
        count,
        npcClass,
        tostring(spawnPoint)
      )
    )
  else
    print(string.format("Successfully spawned %d NPCs in %d attempts", #spawned, attempts))
  end

  return spawned
end

--- Tries to spawn the given amount of NPCs around the spawn point. Searches for nearby
--- versus_npc_spawn_point entities and prefers ones not visible to any player. Falls back
--- to a random observed spawn point if all are visible, or to the raw spawnPoint vector
--- if no spawn point entities are found nearby.
--- @param npcClass string # The class of NPC to spawn
--- @param spawnPoint Vector # The reference point used to search for nearby spawn point entities
--- @param count number # The number of NPCs to spawn
--- @param weapons table # The weapons to give to the NPCs
--- @param primaryEnemy? Entity # The primary enemy to target
--- @return Entity[] # Table of spawned NPC entities
function PLUGIN.spawnNPCsAroundPoint(npcClass, spawnPoint, count, weapons, primaryEnemy)
  local spawnEnt = findBestSpawnPointEntity(spawnPoint, 2048)
  local actualPoint = spawnEnt and spawnEnt:GetPos() or spawnPoint

  debugoverlay.Sphere(actualPoint, 32, 30, Color(255, 255, 0), true) -- Visualize chosen spawn point

  return PLUGIN.spawnNPCsAtPoint(npcClass, actualPoint, count, weapons, primaryEnemy)
end

--- Checks if any alive player can see the given entity
--- @param npc Entity # The entity entity to check visibility for
--- @return boolean # True if at least one alive player can see the entity
--- @return Entity? # The first player that can see the entity, or nil if none
function PLUGIN.canAnyPlayerSeeEntity(npc)
  if not IsValid(npc) then
    return false, nil
  end

  local npcPos = npc:WorldSpaceCenter()

  for _, ply in player.Iterator() do
    if not ply:Alive() then
      continue
    end

    -- Check if player is facing the NPC (within their FOV)
    local plyEyePos = ply:EyePos()
    local plyEyeAngles = ply:EyeAngles()
    local directionToNPC = (npcPos - plyEyePos):GetNormalized()
    local plyForward = plyEyeAngles:Forward()

    local dot = directionToNPC:Dot(plyForward)
    local fovCosine = math.cos(math.rad(90)) -- 90 degree FOV on each side (180 total)

    if dot > fovCosine then
      -- Player is looking in the general direction, now check line of sight
      local trace = util.TraceLine({
        start = plyEyePos,
        endpos = npcPos,
        filter = { ply, npc },
        mask = MASK_VISIBLE_AND_NPCS,
      })

      if not trace.Hit or trace.Entity == npc then
        return true, ply
      end
    end
  end

  return false, nil
end

--- Gets the NPCs currently assigned to chase a specific player
--- @param player Entity # The player to check for
--- @return Entity[] # Table of NPC entities chasing the player
function PLUGIN.getNPCsForPlayer(player)
  return player._VersusNPCs or {}
end

--- Clears any NPCs currently assigned to the player
--- @param player Entity # The player to clear NPCs for
--- @param evenIfLookedAt? boolean # If true, will clear NPCs even if other players are looking at them. Use with caution to avoid NPCs disappearing while being observed.
function PLUGIN.clearNPCsForPlayer(player, evenIfLookedAt)
  if (evenIfLookedAt == nil) then
    evenIfLookedAt = true
  end

  -- Remove NPCs assigned to this player
  local npcs = PLUGIN.getNPCsForPlayer(player)
  for _, npc in ipairs(npcs) do
    if IsValid(npc) then
      if evenIfLookedAt or not PLUGIN.canAnyPlayerSeeEntity(npc) then
        npc:Remove()
      end
    end
  end

  player._VersusNPCs = {}
end

--- Attaches the loot spawner to the NPC which is used to spawn loot when the NPC dies.
--- This allows us to control the loot drops from NPCs.
--- @param npc Entity # The NPC entity to attach the loot spawner to
--- @param lootSpawner fun(npc: Entity, attacker: Entity, inflictor: Entity): table # A function that returns a loot table when the NPC dies. The function receives the NPC, the attacker, and the inflictor as arguments.
function PLUGIN.attachLootSpawner(npc, lootSpawner)
  if not IsValid(npc) then
    return
  end

  npc._VersusLootSpawner = lootSpawner
end
