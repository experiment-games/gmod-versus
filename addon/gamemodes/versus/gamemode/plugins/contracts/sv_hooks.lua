local PLUGIN = PLUGIN

local playerIterator = player.Iterator

util.AddNetworkString("versus.contracts.selectContract")
util.AddNetworkString("versus.contracts.selectedContract")
util.AddNetworkString("versus.contracts.forceReselectContract")
util.AddNetworkString("versus.contracts.playerEliminated")

--[[
  Hooks
--]]

-- On think, we check if players in a certain contract phase should progress to the next phase based on the
-- contract's 'completeCallback' key. This key holds a table where the first value is the function that checks for
-- completion and the other values are arguments to pass to that function.
-- If the function returns true, the player progresses to the next phase.
function PLUGIN.hook:Think()
  for _, player in playerIterator() do
    if not player._VersusCurrentContract then
      continue
    end

    local contract = player._VersusCurrentContract and PLUGIN.getContract(player._VersusCurrentContract.id)

    if not contract then
      continue
    end

    local currentPhase = contract.phases[player._VersusCurrentContract.phaseIndex]

    -- Get the role-appropriate phase
    local role = player._VersusContractRole or "first"
    local actualPhase = PLUGIN.getPhaseForRole(currentPhase, role)

    if not actualPhase.completeCallback then
      -- Some handler will probably force with the 'completePhase' function
      continue
    end

    local isComplete = PLUGIN.callContractFunction(
      player,
      player._VersusCurrentContract.bag,
      actualPhase.completeCallback,
      "Contract phase has 'completeCallback' key but completion function is not registered"
    )

    if not isComplete then
      continue
    end

    PLUGIN.handleContractPhaseCompletion(player)
  end

  -- Auto-progress bots through contract phases for testing
  for _, bot in playerIterator() do
    if not bot:IsBot() or not bot._VersusCurrentContract then
      continue
    end

    -- Skip if already in progress or waiting for something
    if bot._VersusBotContractWaitUntil and CurTime() < bot._VersusBotContractWaitUntil then
      continue
    end

    -- Get current phase
    local contract = PLUGIN.getContract(bot._VersusCurrentContract.id)
    if not contract then continue end

    local phase = contract.phases[bot._VersusCurrentContract.phaseIndex]
    if not phase then continue end

    local role = bot._VersusContractRole or "first"
    local actualPhase = PLUGIN.getPhaseForRole(phase, role)

    -- Auto-complete phases that have completeCallback after a delay
    if actualPhase.completeCallback then
      -- Let the normal Think completion handler deal with it
      continue
    end

    -- For phases without auto-completion, simulate interaction
    -- Look for entities handler and auto-interact
    if actualPhase.entities then
      for _, entityConfig in ipairs(actualPhase.entities) do
        if entityConfig.InteractionCallback then
          local locationRef = entityConfig.location
          local entity = PLUGIN.getEntityFromReference(bot, locationRef)

          if IsValid(entity) and entity:GetPos():Distance(bot:GetPos()) < 200 then
            -- Bot is near, trigger interaction
            PLUGIN.callContractFunction(bot, bot._VersusCurrentContract.bag, entityConfig.InteractionCallback)
            bot._VersusBotContractWaitUntil = CurTime() + 2 -- Wait 2 seconds before next action
            break
          end
        end
      end
    end
  end
end

function PLUGIN.hook:PlayerSelectSpawn(player)
  if (not player._VersusPreferedSpawnPoint) then
    return
  end

  local spawnPoint = player._VersusPreferedSpawnPoint
  player._VersusPreferedSpawnPoint = nil -- Clear it so it doesn't interfere with future spawns

  return spawnPoint
end

-- We stop the player from spawning, up until they select a contract and are ready to play.
-- We must still call :Spawn() on the player to spawn them after setting _VersusCurrentContract.
function PLUGIN.hook:PlayerDeathThink(player)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  if (not player._VersusCurrentContract) then
    return false
  end
end

-- On initialization we generate contracts for the player to select from, and show the contract selection UI.
function PLUGIN.hook:PlayerInitialized(player)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  PLUGIN.generateContractsForPlayer(player)
end

-- For now players cannot try again after death, but will have to take up a new contract.
function PLUGIN.hook:CanPlayerRespawnInTime(player, attacker)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  return false
end

-- When the player dies, we fade and remove any items we spawned specifically for them
function PLUGIN.hook:PostPlayerDeath(player, attacker, inflictor)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  for _, item in ipairs(player._VersusLootItems or {}) do
    if (IsValid(item)) then
      versus.util.decayEntity(item, 5)
    end
  end

  player._VersusLootItems = nil
end

function PLUGIN.hook:PlayerDeath(player, inflictor, attacker)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  -- Clean up entity reservations
  PLUGIN.cleanupContractReservations(player)

  -- Fail the player's contract if they have one
  -- This will handle cleanup of linked players, timers, objectives, NPCs, etc.
  if player._VersusCurrentContract then
    -- Send elimination notification to client
    net.Start("versus.contracts.playerEliminated")
    net.WriteBool(IsValid(attacker))
    if IsValid(attacker) then
      net.WriteBool(attacker:IsPlayer())
      if attacker:IsPlayer() then
        net.WriteString(attacker:Nick())
      else
        net.WriteBool(attacker:IsNPC())
      end
    end
    net.Send(player)

    PLUGIN.failContract(player, "You died.")

    timer.Simple(PLUGIN.respawnDelay, function()
      if IsValid(player) then
        PLUGIN.forceReselectContract(player)
      end
    end)
  end
end

-- Clean up contract linkages on player disconnect
function PLUGIN.hook:PlayerDisconnected(player)
  -- Clean up entity reservations
  PLUGIN.cleanupContractReservations(player)

  -- Fail the player's contract if they have one
  -- This will handle cleanup of linked players, timers, objectives, NPCs, etc.
  if player._VersusCurrentContract then
    -- Don't notify the disconnecting player (they won't see it anyway)
    -- But failContract will still handle all the cleanup and notify linked players
    PLUGIN.failContract(player, "disconnected")
  end
end

--[[
  Console Commands
--]]

concommand.Add("versus_debug_points_between", function(player, command, args)
  if (not player:IsAdmin()) then
    return
  end

  if (not player._VersusContract) then
    versus.message.notify(player, "You must select a contract first to use this command.", NOTIFY_ERROR)
    return
  end

  local start = player._VersusContract.spawnPoint:GetPos()
  local extraction = player._VersusContract.extractionPoint:GetPos()
  local points = PLUGIN.getSpawnNPCPointsBetween(start, extraction)

  -- Draw debug lines to the points for 10 seconds
  for _, npcSpawn in ipairs(points) do
    local pos = npcSpawn:GetPos()
    debugoverlay.Cross(pos, 16, 10, Color(255, 0, 0), true)
  end

  local sortedPoints = PLUGIN.categorizeSpawnPoints(points, start, extraction)
  PrintTable(sortedPoints)
end)

concommand.Add("versus_skip_selection", function(player, command, args)
  if (not player:IsAdmin()) then
    return
  end

  player._VersusContract = {
    extractionPoint = nil,
  }
  player:Spawn()
end)

-- Bot testing commands
concommand.Add("versus_bot_assign_contract", function(player, command, args)
  if not player:IsAdmin() then return end

  local botName = args[1]
  local contractID = args[2]

  if not botName or not contractID then
    versus.message.notify(player, "Usage: versus_bot_assign_contract <botname> <contractID>", NOTIFY_ERROR)
    return
  end

  -- Find bot by name
  local bot = nil
  for _, ply in playerIterator() do
    if ply:IsBot() and string.find(string.lower(ply:Nick()), string.lower(botName)) then
      bot = ply
      break
    end
  end

  if not bot then
    versus.message.notify(player, "Bot not found: " .. botName, NOTIFY_ERROR)
    return
  end

  -- Verify contract exists
  local contract = PLUGIN.getContract(contractID)
  if not contract then
    versus.message.notify(player, "Contract not found: " .. contractID, NOTIFY_ERROR)
    return
  end

  -- Prepare and assign the contract
  local preparedContract = PLUGIN.prepareContractForPlayer(bot, contractID)
  if not preparedContract then
    versus.message.notify(player, "Failed to prepare contract (entities unavailable)", NOTIFY_ERROR)
    return
  end

  -- Reserve locations
  local reserved = PLUGIN.reserveContractLocations(bot, contractID, preparedContract.locations)
  if not reserved then
    versus.message.notify(player, "Failed to reserve contract locations", NOTIFY_ERROR)
    return
  end

  -- Assign and spawn
  PLUGIN.assignContractToPlayer(bot, preparedContract, "first", nil)

  versus.message.notify(player, "Assigned contract '" .. contractID .. "' to bot: " .. bot:Nick(), NOTIFY_GENERIC)
end)

concommand.Add("versus_bot_progress_phase", function(player, command, args)
  if not player:IsAdmin() then return end

  local botName = args[1]

  if not botName then
    versus.message.notify(player, "Usage: versus_bot_progress_phase <botname>", NOTIFY_ERROR)
    return
  end

  -- Find bot
  local bot = nil
  for _, ply in playerIterator() do
    if ply:IsBot() and string.find(string.lower(ply:Nick()), string.lower(botName)) then
      bot = ply
      break
    end
  end

  if not bot or not bot._VersusCurrentContract then
    versus.message.notify(player, "Bot not found or has no active contract", NOTIFY_ERROR)
    return
  end

  -- Manually trigger phase completion
  PLUGIN.handleContractPhaseCompletion(bot)

  versus.message.notify(player, "Advanced bot to phase " .. bot._VersusCurrentContract.phaseIndex, NOTIFY_GENERIC)
end)

concommand.Add("versus_bot_contract_status", function(player, command, args)
  if not player:IsAdmin() then return end

  local botName = args[1]

  -- Find bot
  for _, bot in playerIterator() do
    if bot:IsBot() and (not botName or string.find(string.lower(bot:Nick()), string.lower(botName))) then
      if bot._VersusCurrentContract then
        local contract = PLUGIN.getContract(bot._VersusCurrentContract.id)
        local role = bot._VersusContractRole or "first"
        local phase = contract.phases[bot._VersusCurrentContract.phaseIndex]
        local actualPhase = PLUGIN.getPhaseForRole(phase, role)

        print(string.format(
          "Bot: %s | Contract: %s | Role: %s | Phase: %d/%d | Interferable: %s",
          bot:Nick(),
          bot._VersusCurrentContract.id,
          role,
          bot._VersusCurrentContract.phaseIndex,
          #contract.phases,
          PLUGIN.isPhaseInterferable(phase) and "YES" or "NO"
        ))

        if PLUGIN.isPhaseInterferable(phase) then
          print("  - maxSubsequent: " .. (phase.maxSubsequent or 1))
          print("  - Current subsequent count: " .. #(bot._VersusContractSubsequents or {}))
        end
      else
        print(string.format("Bot: %s | No active contract", bot:Nick()))
      end

      if not botName then continue else break end
    end
  end
end)

concommand.Add("versus_regenerate_contracts", function(player, command, args)
  if not player:IsAdmin() then return end

  -- Clear existing contracts
  player._VersusAvailableContracts = nil
  player._VersusSubsequentContractData = nil
  player._VersusContractIDMap = nil

  -- Regenerate (will include subsequent contracts from bot contracts)
  PLUGIN.generateContractsForPlayer(player)

  versus.message.notify(player, "Contracts regenerated", NOTIFY_GENERIC)
end)

concommand.Add("versus_progress_phase", function(player, command, args)
  if (not player:IsAdmin()) then
    return
  end

  if (not player._VersusCurrentContract) then
    versus.message.notify(player, "You must have an active contract to use this command.", NOTIFY_ERROR)
    return
  end

  PLUGIN.handleContractPhaseCompletion(player)
end)

concommand.Add("versus_list_contracts", function(player, command, args)
  if not player:IsAdmin() then return end

  print("\n=== Registered Contracts ===")
  local contractList = {}
  for contractID, _ in pairs(PLUGIN.contracts) do
    table.insert(contractList, contractID)
  end
  table.sort(contractList)

  for _, contractID in ipairs(contractList) do
    local contract = PLUGIN.getContract(contractID)
    local difficulty = contract.difficulty == PLUGIN.DIFFICULTY_EASY and "EASY" or
        (contract.difficulty == PLUGIN.DIFFICULTY_HARD and "HARD" or "MEDIUM")
    local reward = contract.reward == PLUGIN.REWARD_HIGH and "HIGH" or
        (contract.reward == PLUGIN.REWARD_MEDIUM and "MEDIUM" or "LOW")
    local name = type(contract.name) == "table" and contract.name[1] or contract.name
    print(string.format("  %s - %s [Difficulty: %s, Reward: %s, Phases: %d]", contractID, name, difficulty, reward,
      #contract.phases))
  end
  print("===========================\n")
end)

--[[
  Net Messages
--]]

net.Receive("versus.contracts.selectContract", function(len, player)
  local numericContractID = net.ReadUInt(PLUGIN.bitCountContractID)

  -- Convert numeric ID back to string ID
  local contractID = player._VersusContractIDMap and player._VersusContractIDMap[numericContractID]

  if not contractID then
    ErrorNoHalt("Player selected invalid contract ID: " .. tostring(numericContractID) .. "\n")
    return
  end

  -- Get the prepared contract for this player
  local preparedContract = player._VersusAvailableContracts and player._VersusAvailableContracts[contractID]

  if not preparedContract then
    ErrorNoHalt("Player does not have prepared contract: " .. contractID .. "\n")
    return
  end

  -- Check if this is a subsequent contract
  local subsequentData = player._VersusSubsequentContractData and player._VersusSubsequentContractData[contractID]
  local role = subsequentData and "subsequent" or "first"
  local linkedToPlayer = subsequentData and subsequentData.firstPlayer or nil

  -- Verify the first player is still valid for subsequent contracts
  if role == "subsequent" then
    if not IsValid(linkedToPlayer) or not linkedToPlayer._VersusCurrentContract then
      versus.message.notify(player, "This interference contract is no longer available.", NOTIFY_ERROR)
      PLUGIN.generateContractsForPlayer(player) -- Refresh contracts
      return
    end

    -- Subsequent contracts share the first player's entities, so we don't need to reserve
  elseif role == "first" then
    -- NOW we reserve the entities for this player
    local reserved = PLUGIN.reserveContractLocations(player, contractID, preparedContract.locations)

    if not reserved then
      -- Some entities are no longer available (another player took them)
      versus.message.notify(player, "This contract is no longer available. Entities are in use.", NOTIFY_ERROR)
      PLUGIN.generateContractsForPlayer(player) -- Refresh contracts with newly available options
      return
    end
  end

  -- Assign the contract to the player
  PLUGIN.assignContractToPlayer(player, preparedContract, role, linkedToPlayer)

  -- Network the selection back to client
  net.Start("versus.contracts.selectedContract")
  net.WriteUInt(numericContractID, PLUGIN.bitCountContractID)
  net.Send(player)

  hook.Run("PlayerSelectedContract", player, preparedContract, contractID)
end)
