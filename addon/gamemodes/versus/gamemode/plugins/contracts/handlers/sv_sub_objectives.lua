local PLUGIN = PLUGIN

--- Handler: subObjectives
---
--- Adds a list of named sub-objectives to the player's HUD at the start of a phase.
--- Sub-objectives are automatically removed from the HUD when the phase ends.
---
--- Schema per entry:
--- {
---   id   = string,   -- unique key used to mark this sub-objective done
---   text = string,   -- label shown on the HUD
--- }
---
--- Companion contract functions:
---   { "markSubObjectiveDone", "some_id" }   -- tick one sub-objective as complete
---   { "allSubObjectivesComplete" }           -- returns true when every sub-objective is done (use as completeCallback)
PLUGIN.registerContractPhaseKeyHandler("subObjectives", function(player, bag, data)
  if not istable(data) then
    error("Data for contract phase subObjectives key is not a table: " .. tostring(data))
    return
  end

  bag.phase.subObjectiveIDs    = {}
  bag.phase.subObjectiveStates = {}

  for _, entry in ipairs(data) do
    if not entry.id or not entry.text then
      ErrorNoHalt("[Contract] subObjectives: entry is missing 'id' or 'text' field\n")
      continue
    end

    versus.objectives.addSubObjective(player, entry.id, entry.text, false)
    bag.phase.subObjectiveIDs[entry.id]    = true
    bag.phase.subObjectiveStates[entry.id] = false
  end
end)

--- Marks a single sub-objective as completed and ticks it on the player's HUD.
--- Silently does nothing if the sub-objective is already done or doesn't exist.
--- Usage: { "markSubObjectiveDone", "cache_1" }
PLUGIN.registerContractFunction("markSubObjectiveDone", function(player, bag, id)
  if not bag.phase.subObjectiveStates then
    ErrorNoHalt("[Contract] markSubObjectiveDone: no active sub-objectives in current phase\n")
    return
  end

  if bag.phase.subObjectiveStates[id] == nil then
    ErrorNoHalt("[Contract] markSubObjectiveDone: unknown sub-objective id '" .. tostring(id) .. "'\n")
    return
  end

  if bag.phase.subObjectiveStates[id] then
    return -- Already marked done
  end

  bag.phase.subObjectiveStates[id] = true
  versus.objectives.updateSubObjective(player, id, nil, true)
end)

--- Returns true when every sub-objective in the current phase has been marked done.
--- Intended for use as completeCallback: { "allSubObjectivesComplete" }
PLUGIN.registerContractFunction("allSubObjectivesComplete", function(player, bag)
  if not bag.phase.subObjectiveStates then
    return false
  end

  for _, done in pairs(bag.phase.subObjectiveStates) do
    if not done then
      return false
    end
  end

  -- Return false (not complete) if there are no sub-objectives at all
  if not next(bag.phase.subObjectiveStates) then
    return false
  end

  return true
end)
