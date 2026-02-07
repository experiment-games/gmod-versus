local PLUGIN = PLUGIN

PLUGIN.director = PLUGIN.director or {}
local director = PLUGIN.director

-- Configuration
director.config = {
  -- Per-player threat settings
  playerThreatCheckInterval = 10, -- How often to check each player's threat
  playerThreatRadius = 2000,      -- Radius around player to count NPCs
  minNPCsPerPlayer = 0,           -- Minimum NPCs threatening each player
  maxNPCsPerPlayer = 25,          -- Maximum NPCs threatening each player

  -- Wave settings (per player/group)
  waveInterval = 90,    -- Time between waves per player
  waveSize = 4,         -- Base wave size
  waveSizeVariance = 2, -- +/- random variance

  -- Spawn settings
  spawnMinDistance = 800,  -- Min distance from target player
  spawnMaxDistance = 1500, -- Max distance from target player

  -- Difficulty scaling
  difficultyIncreaseRate = 0.1, -- Per minute
  maxDifficulty = 3.0,

  -- Global limits
  absoluteMaxNPCs = 50, -- Hard cap on total NPCs
}

-- Per-player tracking
director.playerStates = director.playerStates or {}

-- Global state
director.state = {
  currentDifficulty = 1.0,
  totalNPCsSpawned = 0,
  lastThinkTime = 0,
}

-- NPC templates for different difficulties
director.npcTemplates = {
  easy = {
    { class = "npc_zombie",   weight = 5 },
    { class = "npc_headcrab", weight = 3 },
  },
  medium = {
    { class = "npc_zombie",        weight = 3 },
    { class = "npc_zombine",       weight = 2 },
    { class = "npc_combine_s",     weight = 2 },
    { class = "npc_headcrab_fast", weight = 1 },
  },
  hard = {
    { class = "npc_combine_s", weight = 4 },
    { class = "npc_manhack",   weight = 2 },
    { class = "npc_hunter",    weight = 1 },
    { class = "npc_zombine",   weight = 2 },
  },
  veryhard = {
    { class = "npc_combine_s",  weight = 3 },
    { class = "npc_hunter",     weight = 2 },
    { class = "npc_strider",    weight = 1 },
    { class = "npc_rollermine", weight = 2 },
  }
}

--[[
  Utility Functions
--]]

-- Get a random NPC class based on current difficulty
function director.getRandomNPCClass()
  local diff = director.state.currentDifficulty
  local templateKey

  if diff < 1.3 then
    templateKey = "easy"
  elseif diff < 1.8 then
    templateKey = "medium"
  elseif diff < 2.5 then
    templateKey = "hard"
  else
    templateKey = "veryhard"
  end

  local template = director.npcTemplates[templateKey]
  local totalWeight = 0
  for _, npc in ipairs(template) do
    totalWeight = totalWeight + npc.weight
  end

  local rand = math.random() * totalWeight
  local cumulative = 0
  for _, npc in ipairs(template) do
    cumulative = cumulative + npc.weight
    if rand <= cumulative then
      return npc.class
    end
  end

  return template[1].class
end

-- Get all spawn points
function director.getSpawnPoints()
  return ents.FindByClass("versus_npc_spawn_point")
end

-- Get all patrol points
function director.getPatrolPoints()
  return ents.FindByClass("versus_npc_patrol_point")
end

-- Get nearby patrol points for a position
function director.getNearbyPatrolPoints(pos, radius)
  radius = radius or 2000
  local allPatrolPoints = director.getPatrolPoints()
  local nearby = {}

  for _, point in ipairs(allPatrolPoints) do
    if point:GetPos():Distance(pos) <= radius then
      table.insert(nearby, point)
    end
  end

  return nearby
end

-- Get current player count
function director.getActivePlayerCount()
  local count = 0
  for _, ply in ipairs(player.GetAll()) do
    if ply:Alive() then
      count = count + 1
    end
  end
  return count
end

-- Get current NPC count
function director.getCurrentNPCCount()
  local count = 0
  for _, npc in ipairs(ents.FindByClass("npc_*")) do
    if IsValid(npc) and npc:Health() > 0 then
      count = count + 1
    end
  end
  return count
end

--[[
  Per-Player State Management
--]]

-- Initialize or get player state
function director.getPlayerState(ply)
  if not IsValid(ply) then return nil end

  local sid = ply:SteamID()
  if not director.playerStates[sid] then
    director.playerStates[sid] = {
      player = ply,
      lastWaveTime = 0,
      lastThreatCheck = 0,
      threateningNPCs = {}, -- Table of NPC entity indices
      waveNumber = 0,
      inCombat = false,
    }
  end

  return director.playerStates[sid]
end

-- Clean up disconnected players
function director.cleanupPlayerStates()
  for sid, state in pairs(director.playerStates) do
    if not IsValid(state.player) or not state.player:IsPlayer() then
      director.playerStates[sid] = nil
    end
  end
end

--[[
  Threat Assessment
--]]

-- Count NPCs threatening a specific player
function director.countThreatsNearPlayer(ply, radius)
  if not IsValid(ply) then return 0 end

  radius = radius or director.config.playerThreatRadius
  local playerPos = ply:GetPos()
  local count = 0
  local threats = {}

  for _, npc in ipairs(ents.FindByClass("npc_*")) do
    if IsValid(npc) and npc:Health() > 0 then
      local dist = npc:GetPos():Distance(playerPos)
      if dist <= radius then
        -- Check if NPC is targeting this player or just nearby
        local enemy = npc:GetEnemy()
        if IsValid(enemy) and enemy == ply then
          count = count + 1
          table.insert(threats, npc:EntIndex())
        elseif dist <= radius * 0.5 then
          -- Close enough to be a threat even if not targeting
          count = count + 1
          table.insert(threats, npc:EntIndex())
        end
      end
    end
  end

  return count, threats
end

-- Check if player needs more threats
function director.assessPlayerThreat(ply)
  local state = director.getPlayerState(ply)
  if not state then return false end

  local threatCount, threats = director.countThreatsNearPlayer(ply)
  state.threateningNPCs = threats
  state.lastThreatCheck = CurTime()

  -- Update combat status
  state.inCombat = threatCount > 0

  -- Does player need more threats?
  local minThreats = director.config.minNPCsPerPlayer
  local maxThreats = director.config.maxNPCsPerPlayer

  if threatCount < minThreats then
    return true, minThreats - threatCount -- Needs more
  elseif threatCount > maxThreats then
    return false, 0                       -- Too many already
  end

  return false, 0 -- Just right
end

--[[
  Spawn Location Selection
--]]

-- Find spawn points near a player (within range)
function director.getSpawnPointsNearPlayer(ply, minDist, maxDist)
  if not IsValid(ply) then return {} end

  minDist = minDist or director.config.spawnMinDistance
  maxDist = maxDist or director.config.spawnMaxDistance

  local playerPos = ply:GetPos()
  local allSpawnPoints = director.getSpawnPoints()
  local validPoints = {}

  for _, point in ipairs(allSpawnPoints) do
    local dist = point:GetPos():Distance(playerPos)
    if dist >= minDist and dist <= maxDist then
      table.insert(validPoints, point)
    end
  end

  return validPoints
end

-- Get best spawn point for threatening a specific player
function director.getBestSpawnForPlayer(ply)
  local validPoints = director.getSpawnPointsNearPlayer(ply)

  if #validPoints == 0 then
    -- Try expanding search radius
    validPoints = director.getSpawnPointsNearPlayer(ply, 500, 2500)
  end

  if #validPoints == 0 then
    return nil
  end

  -- Prefer points that aren't visible to the player
  -- For now, just return random valid point
  return validPoints[math.random(#validPoints)]
end

--[[
  Per-Player Wave System
--]]

function director.spawnWaveForPlayer(ply, waveSize)
  if not IsValid(ply) then
    ErrorNoHalt("Attempted to spawn wave for invalid player\n")
    return
  end

  local state = director.getPlayerState(ply)
  if not state then
    ErrorNoHalt("Attempted to spawn wave for player with no state\n")
    return
  end

  waveSize = waveSize or
      director.config.waveSize + math.random(-director.config.waveSizeVariance, director.config.waveSizeVariance)
  waveSize = math.max(1, waveSize)

  state.waveNumber = state.waveNumber + 1
  state.lastWaveTime = CurTime()

  -- Spawn wave over time
  local waveId = ply:SteamID() .. "_wave_" .. state.waveNumber
  timer.Create(waveId, 1.5, waveSize, function()
    if not IsValid(ply) or director.getCurrentNPCCount() >= director.config.absoluteMaxNPCs then
      timer.Remove(waveId)
      ErrorNoHalt("Stopping wave spawn: player invalid or max NPCs reached\n")
      return
    end

    local spawnPoint = director.getBestSpawnForPlayer(ply)
    if not spawnPoint then
      ErrorNoHalt("No valid spawn point found for player " .. ply:Nick() .. "\n")
      return
    end

    local npcClass = director.getRandomNPCClass()
    local npc = PLUGIN.spawnNPC(npcClass, spawnPoint:GetPos(), Angle(0, math.random(0, 360), 0))

    if IsValid(npc) then
      director.state.totalNPCsSpawned = director.state.totalNPCsSpawned + 1

      -- TODO: This is a cool way to make sure NPCs drop loot on death:
      if PLUGIN.attachLootSpawner then
        PLUGIN.attachLootSpawner(npc)
      end

      -- Set to chase this specific player
      npc:SetUnforgettable(ply)
      if PLUGIN.setChase then
        PLUGIN.setChase(npc, ply)
      end

      -- Damage doors if they get in the way
      npc:AddRelationship("prop_door_rotating D_HT 1")

      -- Tag NPC with target player for tracking
      npc._DirectorTargetPlayer = ply
    end
  end)
end

-- Check all players and spawn waves where needed
function director.updatePlayerThreats()
  local curTime = CurTime()

  for _, ply in ipairs(player.GetAll()) do
    if ply:Alive() then
      local state = director.getPlayerState(ply)

      -- Check if player needs more threats
      local needsMore, deficit = director.assessPlayerThreat(ply)

      -- Should we spawn a wave for this player?
      local timeSinceWave = curTime - state.lastWaveTime

      if needsMore and timeSinceWave >= director.config.waveInterval then
        -- Spawn wave based on deficit
        local waveSize = math.ceil(deficit * 1.5) -- Spawn a bit more than needed
        director.spawnWaveForPlayer(ply, waveSize)

        -- Notify player
        ply:ChatPrint("[AI Director] Hostiles approaching your position...")
      elseif needsMore and timeSinceWave >= director.config.waveInterval * 0.5 then
        -- Half-way through, spawn a few if really needed
        if deficit >= 3 then
          director.spawnWaveForPlayer(ply, 2)
        end
      end
    end
  end
end

--[[
  Difficulty Scaling
--]]

function director.updateDifficulty()
  local minutesElapsed = CurTime() / 60
  local playerCount = director.getActivePlayerCount()

  -- Base difficulty increases over time
  local timeDifficulty = 1.0 + (minutesElapsed * director.config.difficultyIncreaseRate)

  -- Scale with players (more players = slightly harder)
  local playerScale = 1.0 + (playerCount * 0.1)

  director.state.currentDifficulty = math.min(
    director.config.maxDifficulty,
    timeDifficulty * playerScale
  )
end

--[[
  Main Director Loop
--]]

function director.think()
  local curTime = CurTime()

  -- Throttle to once per second
  if curTime - director.state.lastThinkTime < 1 then
    return
  end
  director.state.lastThinkTime = curTime

  -- Clean up disconnected players
  director.cleanupPlayerStates()

  -- Update difficulty
  director.updateDifficulty()

  -- Check each player's threat level and spawn waves as needed
  director.updatePlayerThreats()
end

--[[
  Admin Commands
--]]

concommand.Add("versus_director_force_wave", function(ply, cmd, args)
  if not ply:IsAdmin() then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local targetPly = ply
  local waveSize = tonumber(args[1]) or director.config.waveSize

  -- If specified, target another player
  if args[2] then
    for _, p in ipairs(player.GetAll()) do
      if p:Nick():lower():find(args[2]:lower()) then
        targetPly = p
        break
      end
    end
  end

  director.spawnWaveForPlayer(targetPly, waveSize)
  ply:ChatPrint("Spawned wave of " .. waveSize .. " targeting " .. targetPly:Nick())
end)

concommand.Add("versus_director_info", function(ply, cmd, args)
  if not ply:IsAdmin() then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  ply:ChatPrint("=== AI Director Status ===")
  ply:ChatPrint("Difficulty: " .. string.format("%.2f", director.state.currentDifficulty))
  ply:ChatPrint("Total NPCs: " .. director.getCurrentNPCCount() .. "/" .. director.config.absoluteMaxNPCs)
  ply:ChatPrint("Total Spawned: " .. director.state.totalNPCsSpawned)
  ply:ChatPrint("")
  ply:ChatPrint("=== Per-Player Threats ===")

  for _, p in ipairs(player.GetAll()) do
    if p:Alive() then
      local state = director.getPlayerState(p)
      local threatCount = director.countThreatsNearPlayer(p)
      local timeSinceWave = CurTime() - state.lastWaveTime

      ply:ChatPrint(p:Nick() .. ":")
      ply:ChatPrint("  Threats: " .. threatCount .. "/" .. director.config.maxNPCsPerPlayer)
      ply:ChatPrint("  Waves: " .. state.waveNumber)
      ply:ChatPrint("  Combat: " .. tostring(state.inCombat))
      ply:ChatPrint("  Next wave: " ..
        string.format("%.0f", math.max(0, director.config.waveInterval - timeSinceWave)) .. "s")
    end
  end
end)

concommand.Add("versus_director_player_info", function(ply, cmd, args)
  if not ply:IsAdmin() then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local targetPly = ply
  if args[1] then
    for _, p in ipairs(player.GetAll()) do
      if p:Nick():lower():find(args[1]:lower()) then
        targetPly = p
        break
      end
    end
  end

  if not targetPly:Alive() then
    ply:ChatPrint(targetPly:Nick() .. " is not alive")
    return
  end

  local state = director.getPlayerState(targetPly)
  local threatCount, threats = director.countThreatsNearPlayer(targetPly)

  ply:ChatPrint("=== " .. targetPly:Nick() .. " ===")
  ply:ChatPrint("Threats within range: " .. threatCount)
  ply:ChatPrint("Wave number: " .. state.waveNumber)
  ply:ChatPrint("Time since last wave: " .. string.format("%.1f", CurTime() - state.lastWaveTime) .. "s")
  ply:ChatPrint("In combat: " .. tostring(state.inCombat))

  -- List threatening NPCs
  if #threats > 0 then
    ply:ChatPrint("Threatening NPCs:")
    for _, npcIdx in ipairs(threats) do
      local npc = Entity(npcIdx)
      if IsValid(npc) then
        local dist = npc:GetPos():Distance(targetPly:GetPos())
        ply:ChatPrint("  " .. npc:GetClass() .. " at " .. math.floor(dist) .. " units")
      end
    end
  end
end)

concommand.Add("versus_director_set_difficulty", function(ply, cmd, args)
  if not ply:IsAdmin() then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local diff = tonumber(args[1])
  if diff then
    director.state.currentDifficulty = math.Clamp(diff, 0.5, director.config.maxDifficulty)
    ply:ChatPrint("Set difficulty to " .. director.state.currentDifficulty)
  else
    ply:ChatPrint("Usage: director_set_difficulty <number>")
  end
end)

concommand.Add("versus_director_set_player_threats", function(ply, cmd, args)
  if not ply:IsAdmin() then
    versus.message.notify(ply, "You do not have permission to use this command.")
    return
  end

  local min = tonumber(args[1])
  local max = tonumber(args[2])

  if min and max then
    director.config.minNPCsPerPlayer = min
    director.config.maxNPCsPerPlayer = max
    ply:ChatPrint("Set threat range to " .. min .. "-" .. max .. " per player")
  else
    ply:ChatPrint("Usage: director_set_player_threats <min> <max>")
  end
end)
