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
  if (versus.team.hasFlags(player:Team(), access) and not default) then
    return true
  else
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

local firstNames, surnames = versus.includePrefixed("sh_names.lua")

function UNIT.getRandomName()
  return table.Random(firstNames) .. " " .. table.Random(surnames)
end
