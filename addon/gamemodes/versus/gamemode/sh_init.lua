GM.Name = "Versus"
GM.Email = ""
GM.Author = "joker"
GM.Website = ""

-- Derive the gamemode from sandbox.
DeriveGamemode("Sandbox")

versus = versus or {}

function versus.includePrefixed(fileName, directory)
  local prefix = fileName:sub(1, 3)
  directory = directory and (directory:Trim("/") .. "/") or ""

  if (SERVER) then
    if (prefix == "cl_" or prefix == "sh_") then
      AddCSLuaFile(directory .. fileName)
    end

    if (prefix == "sv_" or prefix == "sh_") then
      return include(directory .. fileName)
    end

    if (prefix ~= "cl_") then
      ErrorNoHaltWithStack("Error on includePrefixed: File not prefixed with cl_, sh_ or sv_! File was: " ..
        fileName .. " (" .. directory .. ")")
    end
  else
    if (prefix == "cl_" or prefix == "sh_") then
      return include(directory .. fileName)
    end

    if (prefix ~= "sv_") then
      ErrorNoHaltWithStack("Error on includePrefixed: File not prefixed with cl_, sh_ or sv_! File was: " ..
        fileName .. " (" .. directory .. ")")
    end
  end
end

local gamemodeFolder = GM.FolderName
function versus.ensurePathAbsolute(path)
  local gamemodePath = gamemodeFolder .. "/gamemode/"
  path = path:Trim("/") .. "/"

  if (not path:StartWith(gamemodePath)) then
    path = gamemodePath .. path
  end

  return path
end

function versus.includeDirectory(fullPath)
  fullPath = versus.ensurePathAbsolute(fullPath)

  for _, fileName in pairs(file.Find(fullPath .. "*.lua", "LUA")) do
    versus.includePrefixed(fileName, fullPath)
  end
end

-- Common utilities that all depend on
versus.includePrefixed("sh_util.lua", "core/")

-- Include the configuration and enumeration files.
versus.includePrefixed("sh_configuration.lua", "core/")
versus.includePrefixed("sh_enumerations.lua", "core/")
versus.includePrefixed("sv_configuration.lua", "core/")

-- First load unit and network libraries. All that follow will depend on these
versus.includePrefixed("sh_unit.lua", "core/")
versus.includePrefixed("sh_network.lua", "core/")

versus.includeDirectory("core/metatables/")

-- Load all units which are self contained packages that supply the gamemode with features and logic
versus.unit.loadUnits("units/")

-- Plugins are loaded last so they can have insight of and override default behaviour.
versus.unit.loadUnits("plugins/", "PLUGIN")

-- Content is just items and missions that do not add any additional complex features to the gamemode
versus.unit.loadUnits("content/", "CONTENT")

hook.Run("VersusInitialized", versus)
