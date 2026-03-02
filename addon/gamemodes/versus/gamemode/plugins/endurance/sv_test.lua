local PLUGIN = PLUGIN

local playerGetAll = player.GetAll

--[[
  Admin testing commands for Endurance mode.

  These commands let a superadmin manually start and stop waves without going
  through the normal hideout matchmaking flow.  They only work on servers where
  VersusEnduranceMap is set to true.

  Usage (server console or RCON):
    versus_endurance_test_start [spawnID]
      Starts waves for the spawn entity whose SpawnID matches the given value.
      If no spawnID is supplied the spawn entity closest to the calling player
      (or, in the server console, the first one found) is used.
      All players currently on the server become the squad members.

    versus_endurance_test_stop [spawnID]
      Stops the active wave run for the given spawn (or the first active one
      when no spawnID is supplied).  Does NOT touch the database.
--]]

--- Returns the versus_squad_spawn entity whose SpawnID matches `spawnID`, or nil.
--- @param spawnID string
--- @return Entity?
local function findSpawnByID(spawnID)
  for _, ent in ipairs(ents.FindByClass("versus_squad_spawn")) do
    if ent:GetSpawnID() == spawnID then
      return ent
    end
  end
end

--- Returns the versus_squad_spawn entity closest to `origin`, or nil.
--- @param origin Vector
--- @return Entity?
local function findNearestSpawn(origin)
  local best, bestDist = nil, math.huge

  for _, ent in ipairs(ents.FindByClass("versus_squad_spawn")) do
    if ent:GetSpawnID() == "" then continue end

    local dist = origin:Distance(ent:GetPos())

    if dist < bestDist then
      best     = ent
      bestDist = dist
    end
  end

  return best
end

--- Prints `msg` to the server console and, if `player` is valid, to that player's console.
--- @param player Player|nil
--- @param msg string
local function output(player, msg)
  print("[Endurance Test] " .. msg)

  if IsValid(player) then
    player:PrintMessage(HUD_PRINTCONSOLE, "[Endurance Test] " .. msg)
  end
end

concommand.Add("versus_endurance_test_start", function(player, _, args)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    output(player, "This command only works on endurance maps (VersusEnduranceMap must be true).")
    return
  end

  -- Allow both superadmins in-game and the server console (player == NULL).
  if IsValid(player) and not player:IsSuperAdmin() then
    output(player, "You must be a superadmin to use this command.")
    return
  end

  -- Resolve the spawn entity.
  local spawnEntity

  if args[1] and args[1] ~= "" then
    spawnEntity = findSpawnByID(args[1])

    if not IsValid(spawnEntity) then
      output(player, "No versus_squad_spawn found with SpawnID '" .. args[1] .. "'.")
      return
    end
  elseif IsValid(player) then
    spawnEntity = findNearestSpawn(player:GetPos())
  else
    -- Server console: pick the first available spawn.
    spawnEntity = ents.FindByClass("versus_squad_spawn")[1]
  end

  if not IsValid(spawnEntity) then
    output(player, "No versus_squad_spawn entities found in this map.")
    return
  end

  local spawnID = spawnEntity:GetSpawnID()

  if spawnID == "" then
    output(player, "The selected spawn entity has no SpawnID set.")
    return
  end

  if PLUGIN.activeSquads[spawnID] then
    output(player, "Waves are already active for spawn '" .. spawnID .. "'. " ..
      "Use 'versus_endurance_test_stop " .. spawnID .. "' to stop them first.")
    return
  end

  -- Teleport the calling player (if in-game) to the spawn point.
  if IsValid(player) then
    player:SetPos(spawnEntity:GetSpawnPosition())
    player:SetAngles(spawnEntity:GetSpawnAngles())
  end

  -- Collect every connected player's Steam ID as the squad.
  local steamIDs = {}

  for _, ply in ipairs(playerGetAll()) do
    table.insert(steamIDs, ply:SteamID64())
  end

  if #steamIDs == 0 then
    output(player, "No players are connected; waves will start with no squad members tracked.")
    steamIDs = IsValid(player) and { player:SteamID64() } or {}
  end

  PLUGIN.startWavesForArena(spawnEntity, steamIDs)

  output(player,
    string.format("Test waves started for spawn '%s' with %d player(s): %s",
      spawnID, #steamIDs, table.concat(steamIDs, ", ")))
end, nil, "Start endurance test waves at a spawn (superadmin only). Usage: versus_endurance_test_start [spawnID]")

concommand.Add("versus_endurance_test_stop", function(player, _, args)
  if not GetGlobalBool("VersusEnduranceMap", false) then
    output(player, "This command only works on endurance maps (VersusEnduranceMap must be true).")
    return
  end

  if IsValid(player) and not player:IsSuperAdmin() then
    output(player, "You must be a superadmin to use this command.")
    return
  end

  -- Resolve which arena to stop.
  local spawnID

  if args[1] and args[1] ~= "" then
    spawnID = args[1]

    if not PLUGIN.activeSquads[spawnID] then
      output(player, "No active wave run found for spawn '" .. spawnID .. "'.")
      return
    end
  else
    -- Default to the first active arena.
    spawnID = next(PLUGIN.activeSquads)

    if not spawnID then
      output(player, "No active wave runs to stop.")
      return
    end
  end

  local state = PLUGIN.activeSquads[spawnID]

  -- Remove any pending NPCs that belong to this arena.
  for _, npc in ipairs(state.spawnedNPCs or {}) do
    if IsValid(npc) then
      npc:Remove()
    end
  end

  -- Skip the DB cleanup (freeSquadSpawn) because test runs have no DB entry.
  PLUGIN.activeSquads[spawnID] = nil

  output(player, string.format("Stopped test waves for spawn '%s' (was on wave %d).",
    spawnID, state.wave or 0))
end, nil, "Stop endurance test waves at a spawn (superadmin only). Usage: versus_endurance_test_stop [spawnID]")
