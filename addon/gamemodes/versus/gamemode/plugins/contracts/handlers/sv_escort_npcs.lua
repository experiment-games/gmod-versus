local PLUGIN = PLUGIN

--- Handler: escortNPCs
---
--- Spawns one or more escort NPCs that stand idle until a player uses (interacts with) them.
--- Once interacted with, the NPC begins following the player and calls `followCallback`.
--- If the NPC is killed at any point, `deathCallback` is fired.
---
--- Schema per entry:
--- {
---   npcClass       = string,               -- NPC class to spawn (e.g. "npc_citizen")
---   location       = PLUGIN.referToContractLocation("someKey"), -- spawn location reference
---   model          = string?,              -- optional custom model
---   skin           = number?,              -- optional skin index
---   health         = number|{min,max}?,   -- optional health value or range
---   weapons        = string[]?,           -- optional weapon class names
---   interactionName = string?,            -- text shown on the USE prompt (default: "Talk")
---   followCallback = {"funcID", ...}?,    -- called when the player interacts and the NPC starts following
---   deathCallback  = {"funcID", ...}?,    -- called if the NPC is killed
--- }
PLUGIN.registerContractPhaseKeyHandler("escortNPCs", function(player, bag, data)
  if not istable(data) then
    error("Data for contract phase escortNPCs key is not a table: " .. tostring(data))
    return
  end

  bag.phase.escortNPCs = bag.phase.escortNPCs or {}

  for index, escortData in ipairs(data) do
    local npcClass = escortData.npcClass

    if not npcClass then
      ErrorNoHalt("[Contract] escortNPCs: No npcClass specified for entry " .. index .. "\n")
      continue
    end

    if not escortData.location then
      ErrorNoHalt("[Contract] escortNPCs: No location specified for entry " .. index .. "\n")
      continue
    end

    -- Resolve spawn position
    local spawnEntity = PLUGIN.getEntityFromReference(player, escortData.location)

    if not IsValid(spawnEntity) then
      ErrorNoHalt("[Contract] escortNPCs: Failed to find entity for spawn location at entry " .. index .. "\n")
      continue
    end

    -- Spawn the NPC (single, no primary enemy — they start idle)
    local spawnedNPCs = versus.npc.spawnNPCsAroundPoint(
      npcClass,
      spawnEntity:GetPos(),
      1,
      escortData.weapons,
      nil
    )

    local npc = spawnedNPCs[1]

    if not IsValid(npc) then
      ErrorNoHalt("[Contract] escortNPCs: Failed to spawn NPC for entry " .. index .. "\n")
      continue
    end

    -- Register NPC for contract cleanup
    PLUGIN.registerContractNPC(player, bag, npc)

    -- Apply optional properties
    if escortData.model then
      npc:SetModel(escortData.model)
    end

    if escortData.skin then
      npc:SetSkin(escortData.skin)
    end

    if escortData.health then
      local health = escortData.health
      if istable(health) then
        health = math.random(health[1], health[2])
      end
      npc:SetHealth(health)
      npc:SetMaxHealth(health)
    end

    -- Flag the NPC as an escort NPC so the client can identify it for rendering a health bar
    npc:SetNWString("VersusEscortNPC", escortData.interactionName or "Escort")

    -- Allow players to USE (interact with) the NPC
    npc:SetUseType(SIMPLE_USE)

    -- Tag NPC with the callbacks and the owning player so hooks can look it up
    npc._VersusEscortOwner     = player
    npc._VersusEscortBag       = bag
    npc._VersusEscortFollow    = escortData.followCallback
    npc._VersusEscortDeath     = escortData.deathCallback
    npc._VersusEscortFollowing = false

    -- If the entry has a tag, store it on the NPC and in the persistent contract bag so
    -- it can be looked up across phases (e.g. by isEntityNear).
    if escortData.tag then
      npc._VersusContractTag = escortData.tag
      bag.contract.taggedNPCs = bag.contract.taggedNPCs or {}
      bag.contract.taggedNPCs[escortData.tag] = npc
    end

    -- Track in phase so hooks can look up the correct entry quickly
    table.insert(bag.phase.escortNPCs, npc)
  end
end)
