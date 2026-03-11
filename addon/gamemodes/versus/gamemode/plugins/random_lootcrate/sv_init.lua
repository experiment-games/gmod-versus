local PLUGIN = PLUGIN

util.AddNetworkString("versus.lootcrate.beginUnlock")
util.AddNetworkString("versus.lootcrate.unlockComplete")

-- How many world crates to keep spawned at all times.
local convarWorldCount = CreateConVar(
  "versus_lootcrate_world_count",
  "10",
  FCVAR_NOTIFY,
  "Number of random loot crates to maintain in the world at all times",
  0,
  50
)

-- How long (in seconds) after unlock a crate lingers if no items are taken.
local IDLE_DESPAWN_DELAY = 5 * 60

-- How long to wait before retrying a world crate spawn when no suitable
-- position is visible (e.g. all spawn points are currently observed by players).
local SPAWN_RETRY_DELAY = 15

-- Minimum clearance (in units) on each side perpendicular to the wall.
-- Prevents crates from blocking narrow corridors or walkways.
local MIN_SIDE_CLEARANCE = 80

-- Maximum distance the crate is allowed to drop from the wall position to the
-- floor.  Keeping this small prevents crates from landing on thin ledges above
-- the void, which was the cause of the "crazy origin" / defuse log spam.
local MAX_GROUND_DROP = 160

-- Minimum distance (in units) a world crate must keep from any other crate
-- or active encounter camp.  Prevents crates from stacking inside each other
-- or spawning on top of monster camps.
local MIN_CRATE_DISTANCE_SQR = 700 * 700

--- Spawns a loot crate entity at the specified position.
--- @param itemPool VersusItemInstance[]
--- @param position Vector
--- @param angle? Angle
--- @return Entity
function PLUGIN.makeLootCrate(itemPool, position, angle)
  local entity = ents.Create("versus_lootcrate_random")

  entity:SetItemPool(itemPool)
  entity:SetPos(position)
  entity:SetAngles(angle or Angle(0, 0, 0))
  entity:Spawn()

  return entity
end

function PLUGIN.spawnLootCrate(player, itemPool, position)
  if (not position) then
    position = player:GetEyeTraceNoCursor().HitPos

    position.z = position.z + 16
  end

  local toPlayer = (player:GetPos() - position):Angle()
  local rotatedToPlayer = Angle(0, toPlayer.y, 0)
  local entity = PLUGIN.makeLootCrate(itemPool, position, rotatedToPlayer)

  return entity
end

--[[
  Net Messages
--]]

-- Receive the "animation done" confirmation from a client and open their inventory.
-- Pending state (activator, fallback timer name) is stored on the crate entity itself
-- because ENT methods run outside the plugin loader and cannot access PLUGIN.
net.Receive("versus.lootcrate.unlockComplete", function(len, ply)
  local crate = net.ReadEntity()

  if (not IsValid(crate) or not IsValid(ply)) then
    return
  end

  -- Only honour the response from the player who opened this crate.
  if (crate._pendingActivator ~= ply) then
    return
  end

  timer.Remove(crate._unlockTimerName)
  crate._pendingActivator = nil
  crate._unlockTimerName = nil
  crate._IsOpening = false

  -- Mark the crate as unlocked so subsequent players skip the animation.
  crate:SetNWBool("versus_IsUnlocked", true)

  -- Play the open sound and animation for everyone now.
  local openSeq = crate:LookupSequence("open")
  crate:ResetSequence(openSeq)
  crate:SetPlaybackRate(1)
  crate:EmitSound("items/ammocrate_open.wav", 75, 100, 0.8)

  -- Start the idle despawn timer.  If nothing is taken for IDLE_DESPAWN_DELAY
  -- seconds the crate is removed automatically.
  local idleTimerName = "versus_lootcrate_idle_" .. crate:EntIndex()
  crate._idleTimerName = idleTimerName

  timer.Create(idleTimerName, IDLE_DESPAWN_DELAY, 1, function()
    if (IsValid(crate)) then
      crate:EmitSound("items/ammocrate_close.wav", 75, 100, 0.6)

      timer.Simple(0.8, function()
        if (IsValid(crate)) then
          crate:Remove()
        end
      end)
    end
  end)

  versus.inventory.openOrCreateNamedInventory(ply, crate:GetChestName(), crate, nil)
end)

--[[
  World Crate Spawner
--]]

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

--- Traces outward from origin in 8 compass directions and returns the position and
--- angle for placing a crate against the nearest wall, or nil if none is found.
--- Only positions with sufficient perpendicular clearance on both sides are
--- considered, so the crate will never block a narrow walkway.
--- @param origin Vector
--- @return Vector|nil, Angle|nil
local function findWallPosition(origin)
  local bestDist = math.huge
  local bestPos = nil
  local bestAng = nil

  for i = 0, 7 do
    local radAngle = math.rad(i * 45)
    local dir = Vector(math.cos(radAngle), math.sin(radAngle), 0)

    local wallTrace = util.TraceLine({
      start = origin + Vector(0, 0, 20),
      endpos = origin + dir * 512,
      mask = MASK_SOLID_BRUSHONLY,
    })

    if (not wallTrace.Hit or wallTrace.HitSky) then
      continue
    end

    local dist = wallTrace.Fraction * 512

    if (dist >= bestDist) then
      continue
    end

    -- Pull back from wall so the crate sits against it rather than inside it.
    local cratePos = wallTrace.HitPos - dir * 32

    -- Drop to ground.  The range is intentionally short: if there is no solid
    -- floor within MAX_GROUND_DROP units the position is discarded so crates
    -- never end up falling into the void.
    local groundTrace = util.TraceLine({
      start = cratePos + Vector(0, 0, 64),
      endpos = cratePos - Vector(0, 0, MAX_GROUND_DROP),
      mask = MASK_SOLID_BRUSHONLY,
    })

    if (not groundTrace.Hit) then
      continue
    end

    local finalPos = groundTrace.HitPos + Vector(0, 0, 1)

    -- Check perpendicular clearance so the crate doesn't block a narrow passage.
    -- perp is a horizontal vector 90° to the approach direction.
    local perpDir = Vector(-dir.y, dir.x, 0)
    local checkOrigin = finalPos + Vector(0, 0, 36)

    local leftTrace = util.TraceLine({
      start = checkOrigin,
      endpos = checkOrigin + perpDir * MIN_SIDE_CLEARANCE,
      mask = MASK_SOLID_BRUSHONLY,
    })

    local rightTrace = util.TraceLine({
      start = checkOrigin,
      endpos = checkOrigin - perpDir * MIN_SIDE_CLEARANCE,
      mask = MASK_SOLID_BRUSHONLY,
    })

    -- Skip this candidate if either side is too close to a wall.
    if (leftTrace.Hit or rightTrace.Hit) then
      continue
    end

    bestDist = dist
    bestPos = finalPos

    -- Orient the crate so it faces away from the wall (open side toward room).
    local normal = wallTrace.HitNormal
    bestAng = Angle(0, math.deg(math.atan2(normal.y, normal.x)), 0)
  end

  return bestPos, bestAng
end

--- Builds a full item pool from all registered non-base items.
--- @return table
local function buildDefaultItemPool()
  local pool = {}

  for itemID, item in pairs(versus.item.all()) do
    if (hook.Run("VersusShouldExcludeItemFromPool", item) == true) then
      continue
    end

    table.insert(pool, {
      itemID = itemID,
      size = 1,
      weight = item.lootWeight or 0.2,
    })
  end

  return pool
end

--- Returns true if pos is within MIN_CRATE_DISTANCE_SQR of any existing loot
--- crate or any active encounter camp.  Prevents world crates from stacking on
--- top of each other or spawning on top of monster camps.
--- @param pos Vector
--- @param cachedCrates table Pre-fetched list of versus_lootcrate_random entities
--- @return boolean
local function isTooCloseToExistingCratesOrCamps(pos, cachedCrates)
  for _, crate in ipairs(cachedCrates) do
    if (pos:DistToSqr(crate:GetPos()) < MIN_CRATE_DISTANCE_SQR) then
      return true
    end
  end

  if (versus.encounters and versus.encounters.activeCamps) then
    for _, instance in ipairs(versus.encounters.activeCamps) do
      if (pos:DistToSqr(instance.position) < MIN_CRATE_DISTANCE_SQR) then
        return true
      end
    end
  end

  return false
end

--- Tries to spawn a single world crate at an unobserved spawn point near a wall.
--- Schedules a retry if no suitable position is available right now.
function PLUGIN.spawnWorldCrate()
  local spawnPoints = ents.FindByClass("versus_npc_spawn_point")

  if (#spawnPoints == 0) then
    return
  end

  -- Collect spawn points that are not currently visible to any player.
  local candidates = {}

  for _, sp in ipairs(spawnPoints) do
    if (not canAnyPlayerSeePosition(sp:GetPos())) then
      table.insert(candidates, sp)
    end
  end

  if (#candidates == 0) then
    -- All spawn points are currently visible; try again later.
    timer.Simple(SPAWN_RETRY_DELAY, function()
      PLUGIN.spawnWorldCrate()
    end)

    return
  end

  -- Pick a random unobserved candidate and find a wall position near it.
  table.Shuffle(candidates)

  local worldCrates = ents.FindByClass("versus_lootcrate_random")

  for _, sp in ipairs(candidates) do
    local pos, ang = findWallPosition(sp:GetPos())

    if (pos and not canAnyPlayerSeePosition(pos) and not isTooCloseToExistingCratesOrCamps(pos, worldCrates)) then
      local itemPool = buildDefaultItemPool()
      local entity = PLUGIN.makeLootCrate(itemPool, pos, ang)
      entity._isWorldCrate = true
      return
    end
  end

  -- No suitable wall found at any candidate; retry later.
  timer.Simple(SPAWN_RETRY_DELAY, function()
    PLUGIN.spawnWorldCrate()
  end)
end

--- Ensures the world crate count matches the configured target.
function PLUGIN.updateWorldCrateSpawns()
  if (GetGlobalBool("VersusHideoutMap", false) or GetGlobalBool("VersusEnduranceMap", false)) then
    -- Don't spawn world crates on the hideout map, nor in the endurance map.
    return
  end

  local target = convarWorldCount:GetInt()
  local current = ents.FindByClass("versus_lootcrate_random")
  local needed = target - #current

  for _ = 1, needed do
    PLUGIN.spawnWorldCrate()
  end
end

function PLUGIN.hook:InitPostEntity()
  -- Give the map a moment to finish loading before trying to read spawn points.
  timer.Simple(3, function()
    PLUGIN.updateWorldCrateSpawns()
  end)
end

function PLUGIN.hook:EntityRemoved(ent)
  if (ent:GetClass() ~= "versus_lootcrate_random") then
    return
  end

  -- Cancel the idle despawn timer if it is still running.
  if (ent._idleTimerName) then
    timer.Remove(ent._idleTimerName)
  end

  -- If this was a world-managed crate, schedule a replacement.
  if (not ent._isWorldCrate) then
    return
  end

  timer.Simple(30, function()
    local target = convarWorldCount:GetInt()
    local current = ents.FindByClass("versus_lootcrate_random")

    if (#current < target) then
      PLUGIN.spawnWorldCrate()
    end
  end)
end

-- Reset the idle despawn timer whenever a player takes an item from any named inventory
-- that belongs to a lootcrate.
function PLUGIN.hook:PlayerItemTakenFromNamedInventory(owner, chestName, item)
  for _, crate in ipairs(ents.FindByClass("versus_lootcrate_random")) do
    if (IsValid(crate) and crate:GetChestName() == chestName and crate._idleTimerName) then
      timer.Adjust(crate._idleTimerName, IDLE_DESPAWN_DELAY, 1)
      return
    end
  end
end
