local PLUGIN = PLUGIN

PLUGIN.camps = PLUGIN.camps or {}
PLUGIN.activeCamps = PLUGIN.activeCamps or {}

util.AddNetworkString("versus.encounters.sendCampPositions")

--- Sends the positions of all active camps to the given player.
--- Called when the player's contract selection screen opens.
--- @param player Player The player to send positions to
function PLUGIN.sendCampPositionsToPlayer(player)
  local positions = {}

  for _, instance in ipairs(PLUGIN.activeCamps) do
    table.insert(positions, instance.position)
  end

  net.Start("versus.encounters.sendCampPositions")
  net.WriteUInt(#positions, 8)

  for _, pos in ipairs(positions) do
    net.WriteVector(pos)
  end

  net.Send(player)
end

-- How long to wait before retrying a world camp spawn when no suitable
-- position is available (e.g. all spawn points are currently observed by players).
local SPAWN_RETRY_DELAY = 15

-- Minimum distance (in units) a world camp must keep from any versus_spawn_point.
-- Prevents camps from spawning on top of players who just joined or respawned.
local MAXIMUM_RANGE_NEAR_SPAWN_SQR = 900 * 900 -- squared for distance check optimization

-- Minimum clearance (in units) on each side perpendicular to a wall.
-- Prevents props from blocking narrow passages.
local MIN_SIDE_CLEARANCE = 80

-- Maximum distance a prop or loot crate is allowed to drop from a candidate
-- position to the floor.
local MAX_GROUND_DROP = 160

-- Minimum horizontal clearance (in units) required around a camp origin.
-- Ensures NPCs have room to engage players and do not spawn inside tight spaces.
local MIN_CAMP_CLEARANCE = 150

-- Minimum distance (in units) a placed prop or loot crate must keep from any
-- door entity.  Prevents crates from landing in doorways and blocking NPCs.
local MIN_DOOR_CLEARANCE_SQR = 120 * 120 -- squared for distance check optimization

--- Registers a monster camp definition so it can be spawned in the world.
--- @param id string Unique identifier for this camp type
--- @param data table The camp definition table
function PLUGIN.register(id, data)
  data.id = id
  PLUGIN.camps[id] = data
end

--[[
  Position helpers (shared with world spawning and prop placement)
--]]

--- Returns true if the origin has at least MIN_CAMP_CLEARANCE units of open
--- horizontal space in the four cardinal directions.  Rejects positions inside
--- narrow corridors or alcoves that are too cramped for a monster camp.
--- @param origin Vector
--- @return boolean
local function hasCampClearance(origin)
  local checkPos = origin + Vector(0, 0, 36)

  for i = 0, 3 do
    local dir = Vector(math.cos(math.rad(i * 90)), math.sin(math.rad(i * 90)), 0)
    local t   = util.TraceLine({
      start  = checkPos,
      endpos = checkPos + dir * MIN_CAMP_CLEARANCE,
      mask   = MASK_SOLID_BRUSHONLY,
    })

    if (t.Hit) then
      return false
    end
  end

  return true
end

--- Returns true if pos is within MIN_DOOR_CLEARANCE of any door entity.
--- Used to prevent props and loot crates from blocking doorways.
--- @param pos Vector
--- @return boolean
local function isNearDoor(pos)
  local doorClasses = { "func_door", "func_door_rotating", "prop_door_rotating" }

  for _, class in ipairs(doorClasses) do
    for _, door in ipairs(ents.FindByClass(class)) do
      if (pos:DistToSqr(door:GetPos()) < MIN_DOOR_CLEARANCE_SQR) then
        return true
      end
    end
  end

  return false
end

--- Returns true if any alive player has line-of-sight to pos.
--- @param pos Vector
--- @return boolean
local function canAnyPlayerSeePosition(pos)
  for _, ply in player.Iterator() do
    if (not ply:Alive()) then
      continue
    end

    local trace = util.TraceLine({
      start  = ply:EyePos(),
      endpos = pos,
      filter = ply,
      mask   = MASK_NPCWORLDSTATIC,
    })

    if (not trace.Hit) then
      return true
    end
  end

  return false
end

--- Traces outward from origin in 8 compass directions and returns the position
--- and angle for placing an object against the nearest wall, or nil if no
--- suitable wall is found.  Positions that would block a narrow passage are
--- rejected using a perpendicular clearance check.
--- @param origin Vector
--- @return Vector?, Angle?
local function findWallPosition(origin)
  local bestDist = math.huge
  local bestPos  = nil
  local bestAng  = nil

  for i = 0, 7 do
    local radAngle = math.rad(i * 45)
    local dir = Vector(math.cos(radAngle), math.sin(radAngle), 0)

    local wallTrace = util.TraceLine({
      start  = origin + Vector(0, 0, 20),
      endpos = origin + dir * 512,
      mask   = MASK_SOLID_BRUSHONLY,
    })

    if (not wallTrace.Hit or wallTrace.HitSky) then
      continue
    end

    local dist = wallTrace.Fraction * 512

    if (dist >= bestDist) then
      continue
    end

    -- Pull back so the object sits against the wall rather than inside it.
    local candidatePos = wallTrace.HitPos - dir * 32

    local groundTrace = util.TraceLine({
      start  = candidatePos + Vector(0, 0, 64),
      endpos = candidatePos - Vector(0, 0, MAX_GROUND_DROP),
      mask   = MASK_SOLID_BRUSHONLY,
    })

    if (not groundTrace.Hit) then
      continue
    end

    local finalPos    = groundTrace.HitPos + Vector(0, 0, 1)

    -- Reject positions that are too close to a door to avoid blocking NPCs.
    if (isNearDoor(finalPos)) then
      continue
    end

    -- Reject positions that would block a narrow passage.
    local perpDir     = Vector(-dir.y, dir.x, 0)
    local checkOrigin = finalPos + Vector(0, 0, 36)

    local leftTrace   = util.TraceLine({
      start  = checkOrigin,
      endpos = checkOrigin + perpDir * MIN_SIDE_CLEARANCE,
      mask   = MASK_SOLID_BRUSHONLY,
    })

    local rightTrace  = util.TraceLine({
      start  = checkOrigin,
      endpos = checkOrigin - perpDir * MIN_SIDE_CLEARANCE,
      mask   = MASK_SOLID_BRUSHONLY,
    })

    if (leftTrace.Hit or rightTrace.Hit) then
      continue
    end

    bestDist     = dist
    bestPos      = finalPos

    local normal = wallTrace.HitNormal
    bestAng      = Angle(0, math.deg(math.atan2(normal.y, normal.x)), 0)
  end

  return bestPos, bestAng
end

--- Finds the midpoint between two opposing walls along the axis that gives the
--- best (widest) corridor, and returns a floor-dropped position there.
--- @param origin Vector
--- @return Vector?, Angle?
local function findBetweenWallsPosition(origin)
  local axes      = {
    Vector(1, 0, 0),
    Vector(0, 1, 0),
  }

  local bestWidth = 0
  local bestPos   = nil
  local bestAng   = nil

  for _, dir in ipairs(axes) do
    local traceA = util.TraceLine({
      start  = origin + Vector(0, 0, 20),
      endpos = origin + dir * 512,
      mask   = MASK_SOLID_BRUSHONLY,
    })

    local traceB = util.TraceLine({
      start  = origin + Vector(0, 0, 20),
      endpos = origin - dir * 512,
      mask   = MASK_SOLID_BRUSHONLY,
    })

    if (not traceA.Hit or not traceB.Hit or traceA.HitSky or traceB.HitSky) then
      continue
    end

    local width = traceA.HitPos:Distance(traceB.HitPos)

    if (width <= bestWidth) then
      continue
    end

    local midPos = (traceA.HitPos + traceB.HitPos) * 0.5

    local groundTrace = util.TraceLine({
      start  = midPos + Vector(0, 0, 64),
      endpos = midPos - Vector(0, 0, MAX_GROUND_DROP),
      mask   = MASK_SOLID_BRUSHONLY,
    })

    if (not groundTrace.Hit) then
      continue
    end

    bestWidth = width
    bestPos   = groundTrace.HitPos + Vector(0, 0, 1)
    bestAng   = Angle(0, math.deg(math.atan2(dir.y, dir.x)), 0)
  end

  return bestPos, bestAng
end

--[[
  Spawning helpers
--]]

--- Builds a full item pool from all registered non-base items.
--- @return table
local function buildDefaultItemPool()
  local pool = {}

  for itemID, item in pairs(versus.item.all()) do
    if (item.isBaseItem) then
      continue
    end

    table.insert(pool, {
      itemID = itemID,
      size   = 1,
      weight = item.lootWeight or 0.2,
    })
  end

  return pool
end

--- Spawns and returns an NPC for a monster camp.
--- Applies custom health, model, weapons, and boss indicator as defined.
--- @param monsterDef table A single entry from the camp's `monsters` array
--- @param pos Vector Spawn position
--- @param angle Angle Spawn angle
--- @return Entity?
local function spawnCampNPC(monsterDef, pos, angle)
  local npc = ents.Create(monsterDef.class)

  if (not IsValid(npc)) then
    return nil
  end

  -- Set custom model before Spawn() so it takes effect.
  if (monsterDef.model) then
    npc:SetModel(monsterDef.model)
  end

  npc:SetCustomCollisionCheck(true)
  npc:SetPos(pos)
  npc:SetAngles(angle)
  npc:Spawn()
  npc:Activate()

  npc:CapabilitiesAdd(CAP_OPEN_DOORS)
  npc:CapabilitiesAdd(CAP_AUTO_DOORS)
  npc:SetHullType(HULL_HUMAN)

  npc.BehaviorEntities = {}
  npc.BehaviorMode     = "idle"

  if (monsterDef.health and monsterDef.health ~= versus.npc.NO_HEALTH) then
    npc:SetHealth(monsterDef.health)
    npc:SetMaxHealth(monsterDef.health)
  end

  if (monsterDef.weapons) then
    for _, weapon in ipairs(monsterDef.weapons) do
      npc:Give(weapon)
    end
  end

  -- Apply custom class-based relationships if specified.
  if (monsterDef.relationships) then
    for _, relationship in ipairs(monsterDef.relationships) do
      npc:AddRelationship(relationship)
    end
  end

  -- Mark bosses with the NW string rendered by the npc plugin's cl_init.lua.
  if (monsterDef.isBoss and monsterDef.bossName) then
    npc:SetNWString("VersusBossNPC", monsterDef.bossName)
  end

  -- Register in the global NPC registry so this NPC becomes neutral to all
  -- other versus-spawned NPCs (including those from other camps).
  versus.npc.trackNPC(npc)

  return npc
end

--- Spawns a decorative prop for a monster camp.
--- Placement modes:
---   "against_wall"  – snaps to the nearest wall
---   "between_walls" – centres between two opposing walls
---   nil / other     – spawns at origin with a random yaw
--- @param origin Vector Camp origin
--- @param propDef table A single entry from the camp's `props` array
--- @return Entity?
local function spawnCampProp(origin, propDef)
  local pos, ang

  if (propDef.placement == "against_wall") then
    pos, ang = findWallPosition(origin)
  elseif (propDef.placement == "between_walls") then
    pos, ang = findBetweenWallsPosition(origin)
  end

  if (not pos) then
    pos = origin
    ang = Angle(0, math.random(0, 360), 0)
  end

  local prop = ents.Create("prop_physics")

  if (not IsValid(prop)) then
    return nil
  end

  prop:SetModel(propDef.model)
  prop:SetPos(pos)
  prop:SetAngles(ang)
  prop:Spawn()

  -- Freeze in place so the prop doesn't topple or slide.
  local physObj = prop:GetPhysicsObject()

  if (IsValid(physObj)) then
    physObj:EnableMotion(false)
  end

  return prop
end

--- Spawns a loot crate at a wall position near the camp origin (or at the
--- origin itself if no wall is found).
--- @param itemPool table Weighted item pool (see versus_lootcrate_random)
--- @param origin Vector Camp origin
--- @return Entity?
local function spawnCampLootCrate(itemPool, origin)
  local pos, ang = findWallPosition(origin)
  pos = (pos or origin) + Vector(0, 0, 24)
  ang = ang or Angle(0, 0, 0)

  local crate = ents.Create("versus_lootcrate_random")

  if (not IsValid(crate)) then
    return nil
  end

  crate:SetItemPool(itemPool)
  crate:SetPos(pos)
  crate:SetAngles(ang)
  crate:Spawn()
  crate:DropToFloor()

  -- Freeze in place so the crate stays upright and does not tumble.
  local physObj = crate:GetPhysicsObject()

  if (IsValid(physObj)) then
    physObj:EnableMotion(false)
  end

  return crate
end

--[[
  Camp spawning
--]]

--- Spawns a monster camp of the given type at the specified world position.
--- Returns the active camp instance, or nil if spawning failed (e.g. no
--- monsters were created).
--- @param campID string Registered camp ID
--- @param origin Vector World position for the camp
--- @param isWorld? boolean True when managed by the world spawner (will be respawned on clearance)
--- @return table?
function PLUGIN.spawnCampAt(campID, origin, isWorld)
  local definition = PLUGIN.camps[campID]

  if (not definition) then
    ErrorNoHalt("encounters: unknown camp type '" .. tostring(campID) .. "'\n")
    return nil
  end

  local instance = {
    id           = campID,
    position     = origin,
    isWorld      = isWorld or false,
    spawnedNPCs  = {},
    spawnedProps = {},
    lootcrate    = nil,
    totalNPCs    = 0,
    killedNPCs   = 0,
  }

  -- Spawn monsters.
  if (definition.monsters) then
    for _, monsterDef in ipairs(definition.monsters) do
      local count = monsterDef.count or 1

      for i = 1, count do
        -- Spread NPCs evenly around the origin using the loop index so
        -- they don't all stack at the same position.
        local spreadAngle = math.rad((i / count) * 360)
        local offset      = Vector(math.cos(spreadAngle) * 80, math.sin(spreadAngle) * 80, 0)
        local spawnPos    = origin + offset
        local faceAngle   = Angle(0, math.random(0, 360), 0)

        local npc         = spawnCampNPC(monsterDef, spawnPos, faceAngle)

        if (not IsValid(npc)) then
          continue
        end

        npc._VersusCampInstance = instance
        table.insert(instance.spawnedNPCs, npc)
        instance.totalNPCs = instance.totalNPCs + 1
      end
    end
  end

  -- Nothing spawned – don't add an empty camp.
  if (instance.totalNPCs == 0) then
    return nil
  end

  -- Apply optional camp-level class-based relationships to all spawned NPCs.
  if (definition.relationships) then
    for _, npc in ipairs(instance.spawnedNPCs) do
      if (IsValid(npc)) then
        for _, relationship in ipairs(definition.relationships) do
          npc:AddRelationship(relationship)
        end
      end
    end
  end

  -- Spawn decorative props.
  if (definition.props) then
    for _, propDef in ipairs(definition.props) do
      local prop = spawnCampProp(origin, propDef)

      if (IsValid(prop)) then
        table.insert(instance.spawnedProps, prop)
      end
    end
  end

  -- Spawn loot crate.
  if (definition.lootcrate) then
    local itemPool = definition.lootcrate.itemPool or buildDefaultItemPool()
    local crate    = spawnCampLootCrate(itemPool, origin)

    if (IsValid(crate)) then
      crate._VersusCampInstance = instance
      instance.lootcrate        = crate
    end
  end

  table.insert(PLUGIN.activeCamps, instance)

  return instance
end

--- Removes an active camp from the tracking table and optionally removes all
--- of its remaining entities immediately.
--- @param instance table Active camp instance
--- @param removeEntities? boolean When true, all entities are removed immediately
function PLUGIN.removeCamp(instance, removeEntities)
  for i, active in ipairs(PLUGIN.activeCamps) do
    if (active == instance) then
      table.remove(PLUGIN.activeCamps, i)
      break
    end
  end

  if (not removeEntities) then
    return
  end

  for _, npc in ipairs(instance.spawnedNPCs) do
    if (IsValid(npc)) then
      npc:Remove()
    end
  end

  for _, prop in ipairs(instance.spawnedProps) do
    if (IsValid(prop)) then
      prop:Remove()
    end
  end

  if (IsValid(instance.lootcrate)) then
    instance.lootcrate:Remove()
  end
end

--[[
  World camp spawner  (mirrors the pattern in random_lootcrate/sv_init.lua)
--]]

--- Tries to spawn one world camp at an unobserved versus_npc_spawn_point.
--- Schedules a retry if no suitable position is currently available.
function PLUGIN.spawnWorldCamp()
  local campIDs = table.GetKeys(PLUGIN.camps)

  if (#campIDs == 0) then
    return
  end

  local spawnPoints = ents.FindByClass("versus_npc_spawn_point")

  if (#spawnPoints == 0) then
    return
  end

  -- Cache player spawn points once for the proximity check below.
  local playerSpawnPoints = ents.FindByClass("versus_spawn_point")

  -- Collect spawn points not currently observed by any player.
  local candidates = {}

  for _, sp in ipairs(spawnPoints) do
    if (canAnyPlayerSeePosition(sp:GetPos())) then
      continue
    end

    -- Reject positions that are too close to any player spawn point.
    local tooClose = false

    for _, psp in ipairs(playerSpawnPoints) do
      if (sp:GetPos():DistToSqr(psp:GetPos()) < MAXIMUM_RANGE_NEAR_SPAWN_SQR) then
        tooClose = true
        break
      end
    end

    if (not tooClose) then
      table.insert(candidates, sp)
    end
  end

  if (#candidates == 0) then
    timer.Simple(SPAWN_RETRY_DELAY, function()
      PLUGIN.spawnWorldCamp()
    end)

    return
  end

  table.Shuffle(candidates)

  local campID = campIDs[math.random(#campIDs)]

  for _, sp in ipairs(candidates) do
    if (not hasCampClearance(sp:GetPos())) then
      continue
    end

    local instance = PLUGIN.spawnCampAt(campID, sp:GetPos(), true)

    if (instance) then
      return
    end
  end

  -- No suitable position found; retry later.
  timer.Simple(SPAWN_RETRY_DELAY, function()
    PLUGIN.spawnWorldCamp()
  end)
end

--- Ensures the number of active world camps matches the configured target.
function PLUGIN.updateWorldCampSpawns()
  if (GetGlobalBool("VersusHideoutMap", false)) then
    return
  end

  local target     = PLUGIN.convarWorldCount:GetInt()
  local worldCount = 0

  for _, instance in ipairs(PLUGIN.activeCamps) do
    if (instance.isWorld) then
      worldCount = worldCount + 1
    end
  end

  local needed = target - worldCount

  for _ = 1, needed do
    PLUGIN.spawnWorldCamp()
  end
end

-- Load all camp definitions.
versus.includeDirectory(PLUGIN.fullPath .. "/encounters")
