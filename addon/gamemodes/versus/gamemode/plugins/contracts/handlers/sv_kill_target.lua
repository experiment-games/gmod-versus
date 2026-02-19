local PLUGIN = PLUGIN

--- Handler: killTarget
---
--- Spawns a single high-value NPC that the player must eliminate.
--- When the NPC is killed, `killCallback` is fired.
--- If the NPC is killed by someone other than the contract's owner the callback still fires,
--- so design your callback accordingly (e.g. simply completePhase).
---
--- Schema:
--- {
---   npcClass     = string,              -- NPC class to spawn (e.g. "npc_combine_s")
---   location     = PLUGIN.referToContractLocation("someKey"), -- spawn location
---   health       = number|{min,max}?,  -- optional health value or random range
---   weapons      = string[]?,          -- optional weapon class names
---   model        = string?,            -- optional custom model
---   skin         = number?,            -- optional skin index
---   bodygroups   = table?,             -- optional { [group] = value } table
---   relationships = string[]?,         -- optional relationship overrides (e.g. "npc_citizen D_NU 99")
---   lootTable    = table?,             -- optional loot table for drops on death
---   killCallback = {"funcID", ...},    -- called when the NPC is killed
--- }
PLUGIN.registerContractPhaseKeyHandler("killTarget", function(player, bag, data)
  if not istable(data) then
    error("Data for contract phase killTarget key is not a table: " .. tostring(data))
    return
  end

  if not data.npcClass then
    ErrorNoHalt("[Contract] killTarget: No npcClass specified\n")
    return
  end

  if not data.location then
    ErrorNoHalt("[Contract] killTarget: No location specified\n")
    return
  end

  -- Resolve spawn position
  local spawnEntity = PLUGIN.getEntityFromReference(player, data.location)

  if not IsValid(spawnEntity) then
    ErrorNoHalt("[Contract] killTarget: Failed to find entity for spawn location\n")
    return
  end

  -- Spawn the target NPC (single unit, player is primary enemy)
  local spawnedNPCs = versus.npc.spawnNPCsAroundPoint(
    data.npcClass,
    spawnEntity:GetPos(),
    1,
    data.weapons,
    player
  )

  local npc = spawnedNPCs[1]

  if not IsValid(npc) then
    ErrorNoHalt("[Contract] killTarget: Failed to spawn target NPC\n")
    return
  end

  -- Register for contract-wide cleanup
  PLUGIN.registerContractNPC(player, bag, npc)

  -- Apply optional properties
  if data.model then
    npc:SetModel(data.model)
  end

  if data.skin then
    npc:SetSkin(data.skin)
  end

  if data.bodygroups then
    for group, value in pairs(data.bodygroups) do
      npc:SetBodygroup(group, value)
    end
  end

  if data.health then
    local health = data.health
    if istable(health) then
      health = math.random(health[1], health[2])
    end
    npc:SetHealth(health)
    npc:SetMaxHealth(health)
  end

  if data.relationships then
    for _, relationship in ipairs(data.relationships) do
      npc:AddRelationship(relationship)
    end
  end

  -- Attach loot spawner if provided
  if data.lootTable then
    versus.npc.attachLootSpawner(npc, function(npcEntity, attacker, inflictor)
      PLUGIN.produceLootAtPosition(npc, attacker, data.lootTable, npc:GetPos())
    end)
  end

  -- Tag the NPC so OnNPCKilled can dispatch the callback
  npc._VersusKillTargetOwner    = player
  npc._VersusKillTargetBag      = bag
  npc._VersusKillTargetCallback = data.killCallback
end)
