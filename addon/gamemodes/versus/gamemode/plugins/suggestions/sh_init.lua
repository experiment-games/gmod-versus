local PLUGIN = PLUGIN

PLUGIN.libraryKey = "suggestions"

-- Validation constants shared between client and server
PLUGIN.MAX_SUGGESTION_SIZE = 60 * 1024 -- 60 KB, fits comfortably within GMod's 65533-byte net message limit
PLUGIN.MAX_FIELD_LENGTH    = 4096       -- Maximum characters per text field
PLUGIN.MAX_PHASES          = 10         -- Maximum contract phases

--- Validate a feature suggestion data table.
--- Returns true on success, or false plus an error message on failure.
---
--- @param data table  { featureText = string }
--- @return boolean, string|nil
function PLUGIN.validateFeatureSuggestion(data)
  if type(data) ~= "table" then
    return false, "Invalid data."
  end

  local text = tostring(data.featureText or "")

  if #text < 10 then
    return false, "Feature description must be at least 10 characters."
  end

  if #text > PLUGIN.MAX_FIELD_LENGTH then
    return false, "Feature description exceeds the maximum length of " .. PLUGIN.MAX_FIELD_LENGTH .. " characters."
  end

  return true
end

--- Validate a contract suggestion data table.
--- Returns true on success, or false plus an error message on failure.
---
--- @param data table  { map = string, phases = table[] }
--- @return boolean, string|nil
function PLUGIN.validateContractSuggestion(data)
  if type(data) ~= "table" then
    return false, "Invalid data."
  end

  local map = tostring(data.map or "")

  if #map < 1 then
    return false, "Map name is required."
  end

  if #map > PLUGIN.MAX_FIELD_LENGTH then
    return false, "Map name exceeds the maximum length of " .. PLUGIN.MAX_FIELD_LENGTH .. " characters."
  end

  if type(data.phases) ~= "table" then
    return false, "Phases must be a list."
  end

  if #data.phases < 1 then
    return false, "At least one phase is required."
  end

  if #data.phases > PLUGIN.MAX_PHASES then
    return false, "A contract may have at most " .. PLUGIN.MAX_PHASES .. " phases."
  end

  local phaseFields = { "lore", "goal", "monsters", "completion", "interference" }

  for i, phase in ipairs(data.phases) do
    if type(phase) ~= "table" then
      return false, "Phase " .. i .. " is invalid."
    end

    for _, field in ipairs(phaseFields) do
      local val = tostring(phase[field] or "")

      if #val > PLUGIN.MAX_FIELD_LENGTH then
        return false, "Phase " .. i .. " field '" .. field .. "' exceeds the maximum length of " .. PLUGIN.MAX_FIELD_LENGTH .. " characters."
      end
    end
  end

  return true
end
