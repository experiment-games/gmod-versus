local UNIT = UNIT
local g_Player = player

UNIT.libraryKey = "player"
UNIT.characterTabLabel = "Character"

UNIT.playerNextSecond = UNIT.playerNextSecond or 0
UNIT.playerNextTenthSecond = UNIT.playerNextTenthSecond or 0

versus.includePrefixed("sv_hooks.lua")
versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("cl_hooks.lua")

-- Get a player by their versus ID
function UNIT.getByVersusID(versusID)
  for _, player in ipairs(g_Player.GetAll()) do
    if (player:getVersusID() == versusID) then
      return player
    end
  end
end

-- Get all versus IDs of connected players
function UNIT.getVersusIDs()
  local versusIDs = {}

  for _, player in ipairs(g_Player.GetAll()) do
    table.insert(versusIDs, player:getVersusID())
  end

  return versusIDs
end

-- Check to see if a player has access.
function UNIT.hasFlags(player, access, default)
  for i = 1, string.len(access) do
    local flag = string.sub(access, i, i)

    -- Check if the flag is a or s.
    if (flag == "s") then
      if (not player:IsSuperAdmin()) then
        return false
      end
    elseif (flag == "a") then
      if (not player:IsAdmin()) then
        return false
      end
    else
      if (SERVER) then
        if (not string.find(player:getCharacter("flags"), flag, nil, false)) then
          return false
        end
      elseif (not string.find(player:GetNWString("versus_Flags"), flag, nil, false)) then
        return false
      end
    end
  end

  -- We haven't failed yet so we must have all the required access.
  return true
end

function UNIT.getBaseModelNameFromModel(modelName)
  local _, __, match = string.find(modelName, "/([%w_-]*)%.mdl")

  return match
end

function UNIT.getBaseModelName(player)
  local model = SERVER and player:getCharacter("appearance").model or player.appearanceModel

  return UNIT.getBaseModelNameFromModel(model)
end

function UNIT.getDefaultModelList()
  local defaultModels = {}

  hook.Run("BuildDefaultModelList", defaultModels)

  return defaultModels
end

function UNIT.getDefaultBodygroupOptions()
  local allBodygroups = {}

  hook.Run("BuildBodygroupOptions", allBodygroups)

  return allBodygroups
end

function UNIT.getDefaultBodygroups()
  local defaultBodygroups = {}

  hook.Run("BuildDefaultBodygroups", defaultBodygroups)

  return defaultBodygroups
end

function UNIT.getRandomName()
  local firstNames, surnames = versus.includePrefixed("sh_names.lua")

  return table.Random(firstNames) .. " " .. table.Random(surnames)
end

--- Finds a player by their name, SteamID, or SteamID64. Returns NULL if no match is found.
--- @param value string The name or SteamID to search for.
--- @return Player # The player that was found, or NULL if no match was found.
function UNIT.findBestMatch(value)
  local lowerValue = value:lower()

  for _, player in ipairs(g_Player.GetAll()) do
    if (
          player:getSteamID64() == value
          or string.find(player:SteamID():lower(), lowerValue, nil, true)
          or string.find(player:Nick():lower(), lowerValue, nil, true)
        ) then
      return player
    end
  end

  return NULL
end

--- Finds the best way to identify a player so they're uniquely found by findBestMatch.
--- For example, if a player has a unique name, that will be returned. If not, their
--- SteamID will be returned.
--- @param player Player The player to get an identifier for.
--- @return string # The identifier for the player.
function UNIT.getBestIdentifier(player)
  local name = player:Nick()
  local steamID = player:SteamID()

  local match = UNIT.findBestMatch(name)
  if (match == player) then
    return name
  end

  return steamID
end
