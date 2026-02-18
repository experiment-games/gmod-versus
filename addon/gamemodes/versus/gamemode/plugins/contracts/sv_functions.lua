local PLUGIN = PLUGIN

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

-- Fails the contract with a reason
PLUGIN.registerContractFunction("failContract", function(player, bag, reason)
  if not player._VersusCurrentContract then
    ErrorNoHaltWithStack("Attempted to fail contract for player who does not have an active contract")
    return
  end

  PLUGIN.failContract(player, reason)
end)
