local PLUGIN = PLUGIN

PLUGIN.contracts = PLUGIN.contracts or {}
PLUGIN.contractFunctions = PLUGIN.contractFunctions or {}
PLUGIN.contractPhaseKeyHandlers = PLUGIN.contractPhaseKeyHandlers or {}

PLUGIN.EXACT = 0
PLUGIN.NEAR_TO_LOCATION = 1
PLUGIN.FAR_FROM_LOCATION = 2

--- Creates a location definition for use in the contract's "locations" table.
--- @param class string The entity class to search for
--- @param tag any The tag of the specific entity to find (can be nil for random selection)
--- @param hidden? boolean Optional. If true, this location won't be shown on the map preview. Defaults to false.
--- @return table # A location definition table
function PLUGIN.defineLocation(class, tag, hidden)
  return {
    class = class,
    tag = tag,
    hidden = hidden or false,
  }
end

--- Creates a relative location definition that will be resolved based on another location.
--- @param class string The entity class to search for
--- @param relativeToKey string The key of the location this should be relative to
--- @param distance number Distance modifier (NEAR_TO_LOCATION or FAR_FROM_LOCATION)
--- @param hidden? boolean Optional. If true, this location won't be shown on the map preview. Defaults to false.
--- @return table # A relative location definition table
function PLUGIN.defineRelativeLocation(class, relativeToKey, distance, hidden)
  return {
    class = class,
    relativeToKey = relativeToKey,
    distance = distance,
    hidden = hidden or false,
  }
end

--- References a location from the contract's locations table.
--- @param locationKey string The key of the location in the contract's locations table
--- @param distance number Optional distance modifier (EXACT, NEAR_TO_LOCATION, or FAR_FROM_LOCATION). Defaults to EXACT.
--- @return table # A location reference table
function PLUGIN.referToContractLocation(locationKey, distance)
  distance = distance or PLUGIN.EXACT

  return {
    locationKey = locationKey,
    distance = distance,
  }
end

--- Registers a contract so it can be assigned to a player and they can move
--- through its phases.
--- @param contractID string Unique identifier for the contract. Used when assigning the contract to a player.
--- @param contractTable table The contract definition table. Should contain a "locations" key (a table of named location definitions) and a "phases" key (a list of phases that the player will progress through).
function PLUGIN.register(contractID, contractTable)
  PLUGIN.contracts[contractID] = contractTable
end

--- Gets a contract definition table by its ID.
--- @param contractID string Unique identifier for the contract.
--- @return table The contract definition table, or nil if no contract with the given ID exists.
function PLUGIN.getContract(contractID)
  return PLUGIN.contracts[contractID]
end

--- Registers a contract phase key handler. Contract phases have various keys with data. When a player progresses to a new phase, the contract system
--- goes through all these keys and handles them accordingly. For example, if a phase has assigned
--- a "spawnWaves" key, the contract system will spawn the defined enemy waves. This function allows you to define custom keys and how the contract system should handle them.
--- @param key string The name of the key to handle. For example, "spawnWaves".
--- @param handlerFunction fun(player: Player, bag: table, data: table) A function that takes in the player and the key's data, and handles it accordingly. This function will be called whenever a player progresses to a new contract phase that contains the specified key.
function PLUGIN.registerContractPhaseKeyHandler(key, handlerFunction)
  PLUGIN.contractPhaseKeyHandlers[key] = handlerFunction
end

--- Gets a contract phase key handler function by the key name.
--- @param key string The name of the key to handle. For example, "spawnWaves".
--- @return fun(player: Player, bag: table, data: table)? # The handler function for the specified key, or nil if no handler is registered for that key.
function PLUGIN.getContractPhaseKeyHandler(key)
  return PLUGIN.contractPhaseKeyHandlers[key]
end

--- Registers a contract function that can be used in contract phase definitions (e.g: in the "completeCallback" key to check for phase completion).
--- @param funcID string Unique identifier for the function. This is what you will reference in the contract phase definitions.
--- @param func fun(player: Player, bag: table, ...):(any) The function that implements the desired behavior. This can take any arguments you want, but typically the first argument will be the player and the rest will be defined by the contract phase.
function PLUGIN.registerContractFunction(funcID, func)
  PLUGIN.contractFunctions[funcID] = func
end

--- Gets a registered contract function by its ID.
--- @param funcID string Unique identifier for the function.
--- @return fun(player: Player, bag: table, ...):(any)? # The registered function, or nil if no function is registered with the given ID.
function PLUGIN.getContractFunction(funcID)
  return PLUGIN.contractFunctions[funcID]
end

--- Gets a location definition from a contract by its key.
--- @param contractID string The ID of the contract
--- @param locationKey string The key of the location in the contract's locations table
--- @return table? # The location definition table, or nil if the contract or location doesn't exist
function PLUGIN.getContractLocation(contractID, locationKey)
  local contract = PLUGIN.getContract(contractID)
  if not contract or not contract.locations then
    return nil
  end

  return contract.locations[locationKey]
end

--- Gets all visible locations from a contract for map preview.
--- Locations with hidden=true are excluded.
--- @param contractID string The ID of the contract
--- @return table # A table of location keys to location definitions that should be shown on the map preview
function PLUGIN.getVisibleContractLocations(contractID)
  local contract = PLUGIN.getContract(contractID)
  if not contract or not contract.locations then
    return {}
  end

  local visibleLocations = {}

  for locationKey, locationDef in pairs(contract.locations) do
    if not locationDef.hidden then
      visibleLocations[locationKey] = locationDef
    end
  end

  return visibleLocations
end

--- Prepares a contract instance for a specific player by resolving all location references.
--- This handles random entity selection and relative location positioning.
--- @param player Player The player for whom to prepare the contract
--- @param contractID string The ID of the contract to prepare
--- @return table # The prepared contract instance with resolved locations
function PLUGIN.prepareContractForPlayer(player, contractID)
  local contract = PLUGIN.getContract(contractID)

  if (not contract) then
    error("Attempted to prepare invalid contract ID: " .. tostring(contractID))
  end

  -- Initialize the player's contract storage if needed
  player._VersusAvailableContracts = player._VersusAvailableContracts or {}

  -- Create a copy of the contract's locations to resolve
  local resolvedLocations = {}
  local pendingRelative = {}

  -- First pass: resolve non-relative locations
  for locationKey, locationDef in pairs(contract.locations) do
    if locationDef.relativeToKey then
      -- This is a relative location, handle it in the second pass
      table.insert(pendingRelative, { key = locationKey, def = locationDef })
    else
      -- This is a direct location
      local entity = nil

      if locationDef.tag == nil then
        -- Random selection: pick a random entity of this class
        local entities = ents.FindByClass(locationDef.class)
        if #entities > 0 then
          entity = entities[math.random(1, #entities)]
        end
      else
        -- Specific tag: find the exact entity
        local entities = ents.FindByClass(locationDef.class)
        for _, ent in ipairs(entities) do
          if not locationDef.tag or (ent.GetTag and ent:GetTag() == locationDef.tag) then
            entity = ent
            break
          end
        end
      end

      if IsValid(entity) then
        resolvedLocations[locationKey] = {
          class = locationDef.class,
          tag = entity.GetTag and entity:GetTag() or nil,
          entity = entity,
          position = entity:GetPos(),
          hidden = locationDef.hidden,
        }
      else
        ErrorNoHaltWithStack("Failed to resolve location '" .. locationKey .. "' for contract " .. contractID .. "\n")
      end
    end
  end

  -- Second pass: resolve relative locations
  for _, relativeInfo in ipairs(pendingRelative) do
    local locationKey = relativeInfo.key
    local locationDef = relativeInfo.def

    local baseLocation = resolvedLocations[locationDef.relativeToKey]
    if not baseLocation then
      ErrorNoHaltWithStack("Cannot resolve relative location '" ..
        locationKey .. "': base location '" .. locationDef.relativeToKey .. "' not found\n")
      continue
    end

    local entities = ents.FindByClass(locationDef.class)
    local selectedEntity = nil

    if locationDef.distance == PLUGIN.NEAR_TO_LOCATION then
      -- Find closest entity
      local closestDistance = math.huge
      for _, entity in ipairs(entities) do
        local distance = baseLocation.position:Distance(entity:GetPos())
        if distance < closestDistance then
          closestDistance = distance
          selectedEntity = entity
        end
      end
    elseif locationDef.distance == PLUGIN.FAR_FROM_LOCATION then
      -- Find farthest entity
      local farthestDistance = -math.huge
      for _, entity in ipairs(entities) do
        local distance = baseLocation.position:Distance(entity:GetPos())
        if distance > farthestDistance then
          farthestDistance = distance
          selectedEntity = entity
        end
      end
    end

    if IsValid(selectedEntity) then
      resolvedLocations[locationKey] = {
        class = locationDef.class,
        tag = selectedEntity.GetTag and selectedEntity:GetTag() or nil,
        entity = selectedEntity,
        position = selectedEntity:GetPos(),
        hidden = locationDef.hidden,
      }
    else
      ErrorNoHaltWithStack("Failed to resolve relative location '" ..
        locationKey .. "' for contract " .. contractID .. "\n")
    end
  end

  -- Store the prepared contract instance
  local preparedContract = {
    id = contractID,
    name = PLUGIN.resolveContractName(contract.name),
    locations = resolvedLocations,
    phases = contract.phases,
  }

  player._VersusAvailableContracts[contractID] = preparedContract

  return preparedContract
end

--- Resolves a contract name based on the options defined in the contract. If the name is a string, it is
--- returned directly. If it is a table, a random entry is selected and returned.
--- @param nameOption string|table The name option defined in the contract. Can be a string or a table of strings.
--- @return string # The resolved contract name.
function PLUGIN.resolveContractName(nameOption)
  if type(nameOption) == "string" then
    return nameOption
  elseif type(nameOption) == "table" and #nameOption > 0 then
    return nameOption[math.random(1, #nameOption)]
  else
    return "Unnamed Contract"
  end
end

--- Assigns a contract to a player. This will set the player's current contract to the specified contract and initialize their progress to the first phase.
--- @param player Player The player to assign the contract to.
--- @param preparedContract table The prepared contract instance to assign to the player. This should be the result of PLUGIN.prepareContractForPlayer.
function PLUGIN.assignContractToPlayer(player, preparedContract)
  if not preparedContract then
    error("Failed to assign contract to player: preparedContract is nil")
    return
  end

  player._VersusCurrentContract = {
    id = preparedContract.id,
    phaseIndex = 1,
    bag = {
      -- This bag is cleared every time a new phase is assigned.
      phase = {},

      -- This bag persists across all phases of the same contract, and can be used to store any data you want related to the player's overall progress in the contract. For example, if the player needs to collect certain items across multiple phases, you could store that information here.
      contract = {},
    },
  }

  PLUGIN.handleContractPhase(player, preparedContract.phases[1])
end

--- Makes the given contracts available to the player. This should be called when the player first becomes
--- eligible for these contracts (e.g: upon joining the game or completing a previous contract).
--- @param player Player The player to make the contracts available for.
--- @param contractIDs table A list of contract IDs to make available to the player.
function PLUGIN.makeContractsAvailableToPlayer(player, contractIDs)
  player._VersusAvailableContracts = player._VersusAvailableContracts or {}

  for _, contractID in ipairs(contractIDs) do
    local preparedContract = PLUGIN.prepareContractForPlayer(player, contractID)
    player._VersusAvailableContracts[contractID] = preparedContract
  end
end

--- Handles a contract phase for a player. This function goes through all the keys in the phase and calls the corresponding handlers for each key.
--- @param player Player The player whose contract phase is being handled.
--- @param phase table The contract phase definition table. This should contain various keys that define what happens during this phase, such as "objective", "lore", "spawnWaves", etc.
function PLUGIN.handleContractPhase(player, phase)
  for key, data in pairs(phase) do
    local handler = PLUGIN.getContractPhaseKeyHandler(key)

    if (handler) then
      handler(player, player._VersusCurrentContract.bag, data)
    else
      ErrorNoHaltWithStack("No handler registered for contract phase key: " .. tostring(key) .. "\n")
    end
  end
end

--- Finishes a contract for a player. This should be called when a player completes the final phase of a contract. This function can handle giving rewards, marking the contract as completed, and any other cleanup or progression logic needed upon contract completion.
--- @param player Player The player who completed the contract.
--- @param contract table The contract definition table for the completed contract.
function PLUGIN.handleContractCompletion(player, contract)
  -- TODO: implementation for giving rewards, marking contract as completed, etc.
  ErrorNoHaltWithStack("Not yet implemented! Player " .. player:Nick() .. " completed contract: " .. contract.id .. "\n")
end

--- Gets an entity based on a location reference. A location reference is a table that contains a locationKey
--- and a distance modifier (e.g: NEAR_TO_LOCATION, FAR_FROM_LOCATION, or EXACT). This function will resolve
--- the location from the player's prepared contract and return the entity.
--- @see PLUGIN.referToContractLocation for creating location references
--- @param player Player The player for whom we are trying to get the entity.
--- @param locationReference table The location reference table created with PLUGIN.referToContractLocation
--- @return Entity? # The entity that matches the location reference, or nil if no matching entity is found.
function PLUGIN.getEntityFromReference(player, locationReference)
  -- Get the prepared contract instance for this player
  local preparedContract = player._VersusAvailableContracts and
      player._VersusAvailableContracts[player._VersusCurrentContract.id]

  if not preparedContract or not preparedContract.locations then
    error("Player does not have a prepared contract or contract has no locations")
    return nil
  end

  local locationDef = preparedContract.locations[locationReference.locationKey]
  if not locationDef then
    error("Location key not found in prepared contract: " .. tostring(locationReference.locationKey))
    return nil
  end

  -- For prepared contracts, we can directly find the entity by its tag
  -- The distance modifier should be EXACT since locations are already resolved
  if locationReference.distance == PLUGIN.EXACT then
    for _, location in pairs(preparedContract.locations) do
      if location.class == locationDef.class and location.tag == locationDef.tag then
        return location.entity
      end
    end
  elseif locationReference.distance == PLUGIN.NEAR_TO_LOCATION then
    -- Find nearest entity of this class to the player
    local entities = ents.FindByClass(locationDef.class)
    local closestEntity = nil
    local closestDistance = math.huge

    for _, entity in ipairs(entities) do
      local distance = player:GetPos():Distance(entity:GetPos())
      if distance < closestDistance then
        closestDistance = distance
        closestEntity = entity
      end
    end

    return closestEntity
  elseif locationReference.distance == PLUGIN.FAR_FROM_LOCATION then
    -- Find farthest entity of this class from the player
    local entities = ents.FindByClass(locationDef.class)
    local farthestEntity = nil
    local farthestDistance = -math.huge

    for _, entity in ipairs(entities) do
      local distance = player:GetPos():Distance(entity:GetPos())
      if distance > farthestDistance then
        farthestDistance = distance
        farthestEntity = entity
      end
    end

    return farthestEntity
  end

  return nil
end

--[[
  Hooks
--]]

-- On think, we check if players in a certain contract phase should progress to the next phase based on the
-- contract's 'completeCallback' key. This key holds a table where the first value is the function that checks for
-- completion and the other values are arguments to pass to that function.
-- If the function returns true, the player progresses to the next phase.
function PLUGIN.hook:Think()
  for _, player in player.Iterator() do
    if not player._VersusCurrentContract then
      continue
    end

    local contract = player._VersusCurrentContract and PLUGIN.getContract(player._VersusCurrentContract.id)

    if not contract then
      continue
    end

    local currentPhase = contract.phases[player._VersusCurrentContract.phaseIndex]

    if not currentPhase.completeCallback then
      continue
    end

    local completionFunc = PLUGIN.getContractFunction(currentPhase.completeCallback[1])

    if (not completionFunc) then
      error("Contract phase has 'completeCallback' key but completion function is not registered: " ..
        tostring(currentPhase.completeCallback[1]))
    end

    local args = { unpack(currentPhase.completeCallback, 2) }

    if not completionFunc(player, player._VersusCurrentContract.bag, unpack(args)) then
      continue
    end

    -- Progress to next phase
    player._VersusCurrentContract.phaseIndex = player._VersusCurrentContract.phaseIndex + 1

    -- Check if there is a next phase to progress to
    if contract.phases[player._VersusCurrentContract.phaseIndex] then
      PLUGIN.handleContractPhase(player, contract.phases[player._VersusCurrentContract.phaseIndex])
    else
      -- Contract completed, handle completion (e.g: give rewards, mark as completed, etc.)
      PLUGIN.handleContractCompletion(player, contract)
      player._VersusCurrentContract = nil -- Clear current contract
    end
  end
end

--[[
  Contract Functions
--]]

-- Waits for a certain amount of time (in seconds) before allowing the player to progress to the next phase.
PLUGIN.registerContractFunction("wait", function(player, bag, timeInSeconds)
  bag.phase.waitStartTime = bag.phase.waitStartTime or CurTime()

  if CurTime() - bag.phase.waitStartTime >= timeInSeconds then
    return true
  end

  return false
end)

-- Sets a value in the player's contract bag. This can be used to track progress or state across phases.
PLUGIN.registerContractFunction("setContractValue", function(player, bag, key, value)
  bag.contract[key] = value
end)

-- Checks if a value in the player's contract bag equals a specified value. This can be used in completeCallback to check for phase completion based on contract state.
PLUGIN.registerContractFunction("checkContractValueEquals", function(player, bag, key, expectedValue)
  return bag.contract[key] == expectedValue
end)

-- Checks if the value in the player's contract bag does not equal a specified value. This can be used in completeCallback to check for phase completion based on contract state.
PLUGIN.registerContractFunction("checkContractValueNotEquals", function(player, bag, key, unexpectedValue)
  return bag.contract[key] ~= unexpectedValue
end)

-- Sets a value in the player's current phase bag. This can be used to track progress or state within the current phase.
PLUGIN.registerContractFunction("setPhaseValue", function(player, bag, key, value)
  bag.phase[key] = value
end)

-- Checks if the value in the player's phase bag equals a specified value. This can be used in completeCallback to check for phase completion based on phase-specific state.
PLUGIN.registerContractFunction("checkPhaseValueEquals", function(player, bag, key, expectedValue)
  return bag.phase[key] == expectedValue
end)

--[[
  Contract Phase Key Handlers
--]]

-- Handled in Think hook
PLUGIN.registerContractPhaseKeyHandler("completeCallback", function(player, bag, callbackData)
  -- This key is handled in the Think hook by calling the specified completion function with the provided arguments.
end)

-- Spawns the player at a location defined in the contract's locations table.
PLUGIN.registerContractPhaseKeyHandler("spawn", function(player, bag, data)
  local locationReference = data.location
  local entity = PLUGIN.getEntityFromReference(player, locationReference)

  if (IsValid(entity)) then
    local spawnPoint = PLUGIN.findFurthestSpawnPoint(entity:GetPos())
    player:Spawn()
    player:SetPos(spawnPoint:GetPos())
    player:SetEyeAngles(spawnPoint:GetAngles())
  else
    error(
      "Failed to find entity for contract phase spawn key with location reference: "
      .. util.TableToJSON(locationReference)
    )
  end
end)

-- Outputs lore to the player based on the data defined in the contract phase's "lore" key.
-- Currently only supports chat radio messages, but can be expanded in the future to support different types of lore delivery (e.g: audio through earpiece, mission brief panels, etc.)
PLUGIN.registerContractPhaseKeyHandler("lore", function(player, bag, data)
  if data.type == "chat_radio" then
    local totalDelay = 0

    for _, loreEntry in ipairs(data.texts) do
      totalDelay = totalDelay + loreEntry.delayInSeconds

      timer.Simple(totalDelay, function()
        if not IsValid(player) then return end

        local content = loreEntry.content
        if type(content) == "table" then
          content = content[math.random(1, #content)]
        end

        content = string.Replace(content, "%PLAYER_NAME%", player:Nick())

        versus.message.addChat(player, nil, "radio", data.author .. ": " .. content)
      end)
    end
  else
    error("Unsupported lore type: " .. tostring(data.type))
  end
end)

PLUGIN.registerContractPhaseKeyHandler("indicators", function(player, bag, data)
  versus.indicator.removeAll(player)

  for _, indicatorData in ipairs(data) do
    local locationReference = indicatorData.location
    local entity = PLUGIN.getEntityFromReference(player, locationReference)

    if not IsValid(entity) then
      error("Failed to find entity for contract phase indicators key with location reference: " ..
        util.TableToJSON(locationReference))
      continue
    end

    versus.indicator.create(player, indicatorData.name, {
      pos = entity:GetPos(),
      text = indicatorData.text,
      icon = indicatorData.icon,
      color = indicatorData.color,
      removeOnReach = indicatorData.removeOnReach,
    })
  end
end)

PLUGIN.registerContractPhaseKeyHandler("objective", function(player, bag, data)
  versus.objectives.setObjective(player, data.title, data.description)
end)

PLUGIN.registerContractPhaseKeyHandler("enemies", function(player, bag, data)
  -- TODO: implement enemies based on the data defined in the contract phase's "enemies" key
  --[[
  data = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("combineRelay", PLUGIN.NEAR_TO_LOCATION),

          -- The behavior can be:
          -- - defending: they stay around the location, waiting for a player to defend against.
          -- - attacking: they actively chase down the player (current NPC behavior in this plugin)
          behavior = "defending",
          health = 50,
          count = 8,
          weapons = { "weapon_smg1" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractLocation("combineRelay", PLUGIN.NEAR_TO_LOCATION),
          behavior = "defending",
          count = 2,
        },
      },
    --]]
end)

-- TODO: We need to reserve entities so other players cannot get in the way. Now if player A and
-- TODO: player B both have a contract with entity X, one could SetInteractionName to 'Combine Relay' and the other might set it to 'Secret Stash'.
-- TODO: In that case the last one would override the other, while we might want both to exist? Nah we should just reserve it so others cannot use it.
PLUGIN.registerContractPhaseKeyHandler("entities", function(player, bag, data)
  local setupEntity = function(entityData)
    local entity = PLUGIN.getEntityFromReference(player, entityData.entity)

    if not IsValid(entity) then
      error("Failed to find entity for contract phase entities key with location reference: " ..
        util.TableToJSON(entityData.entity))
      return
    end

    if istable(entityData.accessors) then
      for accessorKey, accessorData in pairs(entityData.accessors) do
        -- Special case for InteractionCallback since it needs the player injected as the first parameter to the callback function
        if accessorKey == "InteractionCallback" then
          local callbackFunc = PLUGIN.getContractFunction(accessorData[1])

          if not callbackFunc then
            error("Contract phase entities key has InteractionCallback accessor but function is not registered: " ..
              tostring(accessorData[1]))
            continue
          end

          local args = { unpack(accessorData, 2) }

          entity:SetInteractionCallback(function()
            callbackFunc(player, bag, unpack(args))
          end)
        else
          local setter = entity["Set" .. accessorKey]

          if not setter or type(setter) ~= "function" then
            error("Entity does not have a setter function for accessor: " .. accessorKey)
            continue
          end

          setter(entity, accessorData)
        end
      end
    end
  end

  if (not istable(data)) then
    error("Data for contract phase entities key is not a table: " .. tostring(data))
  end

  for _, entityData in ipairs(data) do
    setupEntity(entityData)
  end
end)

PLUGIN.registerContractPhaseKeyHandler("progressBar", function(player, bag, data)
  -- TODO: Show progress bar on client
  --[[
  data = {
        -- Other types can be "decrement" to have the bar go downwards instead of upwards
        type = "increment",

        -- Label to show above the progress bar
        label = "Downloading Signal Data",

        -- Duration in seconds for the progress bar to fill (should match completes wait time)
        duration = 90,

        shouldProgressCallback = {
          -- Function name and parameters called in Think to determine if the progress bar should progress
          "checkContractValueNotEquals",
          "download_paused",
          true
        },
      },
  --]]
end)

PLUGIN.registerContractPhaseKeyHandler("proximityRequirement", function(player, bag, data)
  local locationReference = data.location
  local entity = PLUGIN.getEntityFromReference(player, locationReference)

  if not IsValid(entity) then
    error(
      "Failed to find entity for contract phase proximityRequirement key with location reference: "
      .. util.TableToJSON(locationReference)
    )
    return
  end

  -- Ensure the player is within the required distance from the entity
  local playerPos = player:GetPos()
  local entityPos = entity:GetPos()
  local distance = playerPos:Distance(entityPos)

  if (not bag.phase.networkedProximityRequirement) then
    bag.phase.networkedProximityRequirement = true
    -- Show range we commented in: addon/gamemodes/versus/gamemode/plugins/objectives/cl_hooks.lua
  end

  if (distance <= data.maxDistance) then
    -- Reset warning
    bag.phase.proximityWarningGiven = false

    return
  end

  -- Only warn once while out of range
  if bag.phase.proximityWarningGiven then
    return
  end

  bag.phase.proximityWarningGiven = true

  -- Player is out of range, show warning and call failure callback
  versus.message.addChat(player, nil, "warning", data.warningMessage)

  local callbackFunc = PLUGIN.getContractFunction(data.callbackOnFail[1])

  if not callbackFunc then
    error("Contract phase proximityRequirement key has callbackOnFail but function is not registered: " ..
      tostring(data.callbackOnFail[1]))
    return
  end

  local args = { unpack(data.callbackOnFail, 2) }
  callbackFunc(player, bag, unpack(args))
end)

PLUGIN.registerContractPhaseKeyHandler("spawnWaves", function(player, bag, data)
  -- TODO: Spawn enemy waves based on the data defined in the contract phase's "spawnWaves" key
  --[[
  data = {
        {
          -- Spawn timing relative to phase start
          delayInSeconds = 0,

          enemies = {
            {
              class = "npc_combine_s",
              location = PLUGIN.referToContractLocation("combineRelay", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 50,
              count = 4,
              weapons = { "weapon_ar2", "weapon_smg1" },
              lootTable = combineLootTable,
            },
            {
              class = "npc_manhack",
              location = PLUGIN.referToContractLocation("combineRelay", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              count = 3,
            }
          }
        },
        {
          delayInSeconds = 30,

          enemies = {
            {
              class = "npc_combine_s",
              location = PLUGIN.referToContractLocation("combineRelay", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 75,
              count = 6,
              weapons = { "weapon_ar2", "weapon_smg1" },
              lootTable = combineLootTable,
            },
            {
              class = "npc_manhack",
              location = PLUGIN.referToContractLocation("combineRelay", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              count = 4,
            }
          }
        },
        {
          delayInSeconds = 60,

          enemies = {
            {
              class = "npc_combine_s",
              location = PLUGIN.referToContractLocation("combineRelay", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 100,
              count = 8,
              weapons = { "weapon_ar2", "weapon_smg1" },
              lootTable = combineLootTable,
            },
            {
              class = "npc_manhack",
              location = PLUGIN.referToContractLocation("combineRelay", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              count = 6,
            },
          }
        },
      },
  --]]
end)

PLUGIN.registerContractPhaseKeyHandler("giveItems", function(player, bag, data)
  for _, itemData in ipairs(data) do
    versus.inventory.giveItem(player, itemData.itemID, itemData.quantity)
  end
end)

--[[
  Console Commands for Testing
--]]

concommand.Add("versus_test_contracts", function(player, cmd, args)
  if not player:IsAdmin() then return end

  local testContracts = { "signal_intercept" }
  PLUGIN.makeContractsAvailableToPlayer(player, testContracts)
  PLUGIN.assignContractToPlayer(player, player._VersusAvailableContracts["signal_intercept"])
end)
