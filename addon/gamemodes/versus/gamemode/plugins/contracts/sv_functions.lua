local PLUGIN = PLUGIN

-- Waits for a certain amount of time (in seconds) before allowing the player to progress to the next phase.
PLUGIN.registerContractFunction("wait", function(player, bag, timeInSeconds)
  bag.phase.waitStartTime = bag.phase.waitStartTime or CurTime()

  if CurTime() - bag.phase.waitStartTime >= timeInSeconds then
    return true
  end

  return false
end)

-- Checksif the player is in range of the given location.
-- Usage: {
--  "checkInRange",
--  PLUGIN.referToContractLocation("researchOutpost"),
--  512,
--}
PLUGIN.registerContractFunction("checkInRange", function(player, bag, locationReference, range)
  local targetEntity = PLUGIN.getEntityFromReference(player, locationReference)

  if not IsValid(targetEntity) then
    ErrorNoHalt("Failed to find entity for checkInRange: " .. util.TableToJSON(locationReference) .. "\n")
    return false
  end

  local distance = player:GetPos():DistToSqr(targetEntity:GetPos())

  return distance <= range * range
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

-- Completes the current phase
PLUGIN.registerContractFunction("completePhase", function(player, bag)
  PLUGIN.handleContractPhaseCompletion(player)
end)

-- Completes the contract
PLUGIN.registerContractFunction("completeContract", function(player, bag)
  if not player._VersusCurrentContract then
    ErrorNoHaltWithStack("Attempted to complete contract for player who does not have an active contract")
    return
  end

  PLUGIN.handleContractCompletion(player, PLUGIN.getContract(player._VersusCurrentContract.id))
end)

-- Checks if the NPC with the given class and contract tag is within range of the player.
-- The NPC must have been registered with a matching tag in the escortNPCs handler.
-- Usage: { "isEntityNear", "npc_citizen", "prisoner" }
-- Usage with explicit range: { "isEntityNear", "npc_citizen", "prisoner", 512 }
PLUGIN.registerContractFunction("isEntityNear", function(player, bag, npcClass, tag, range)
  range = range or 256

  local taggedNPCs = bag.contract.taggedNPCs
  if not taggedNPCs then
    return false
  end

  local npc = taggedNPCs[tag]

  if not IsValid(npc) then
    return false
  end

  if npc:GetClass() ~= npcClass then
    return false
  end

  return npc:GetPos():DistToSqr(player:GetPos()) <= range * range
end)

-- Registers conditionallyCallN (for N = 0..6).
-- Each variant calls a contract function only if a condition function returns true.
-- N specifies how many extra arguments are passed to the function being called.
-- Arguments to the condition function follow after those N arguments.
--
-- Usage (N=0, function takes no extra args):
--   { "conditionallyCall0", "completeContract", "isEntityNear", "npc_citizen", "prisoner" }
--
-- Usage (N=2, function takes 2 extra args):
--   { "conditionallyCall2", "someFunc", "arg1", "arg2", "conditionFunc", "condArg1" }
local function registerConditionalCall(n)
  PLUGIN.registerContractFunction("conditionallyCall" .. n, function(player, bag, funcToCall, ...)
    local allArgs = { ... }

    -- First N values are the arguments to pass to funcToCall
    local funcArgs = {}
    for i = 1, n do
      funcArgs[i] = allArgs[i]
    end

    -- Remaining values are the condition function ID followed by its arguments
    local conditionCallback = {}
    for i = n + 1, #allArgs do
      conditionCallback[i - n] = allArgs[i]
    end

    if not PLUGIN.callContractFunction(player, bag, conditionCallback) then
      return
    end

    PLUGIN.callContractFunction(player, bag, { funcToCall, unpack(funcArgs) })
  end)
end

for i = 0, 6 do
  registerConditionalCall(i)
end

-- Fails the contract with a reason
PLUGIN.registerContractFunction("failContract", function(player, bag, reason)
  if not player._VersusCurrentContract then
    ErrorNoHaltWithStack("Attempted to fail contract for player who does not have an active contract")
    return
  end

  PLUGIN.failContract(player, reason)
end)

-- Calls multiple contract functions in sequence from a single callback slot.
-- Each argument after the function ID is a nested callback table.
-- Usage: { "chain", { "markSubObjectiveDone", "my_id" }, { "removeIndicator", "My Indicator" } }
PLUGIN.registerContractFunction("chain", function(player, bag, ...)
  for _, callbackData in ipairs({ ... }) do
    PLUGIN.callContractFunction(player, bag, callbackData)
  end
end)

-- Removes a world-space indicator by its id/name.
-- Usage: { "removeIndicator", "Junction A" }
PLUGIN.registerContractFunction("removeIndicator", function(player, bag, id)
  versus.indicator.remove(player, id)
end)
