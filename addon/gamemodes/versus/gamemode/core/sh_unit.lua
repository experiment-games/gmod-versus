versus.unit = versus.unit or {}
versus.unit.stored = versus.unit.stored or {}

local gamemodeFolder = GM.FolderName
local g_File = file

-- Get a unit by it's path.
function versus.unit.get(unitPath)
  return versus.unit.stored[unitPath]
end

local function includeInits(fullPath)
  if (g_File.Exists(fullPath .. "/sh_init.lua", "LUA")) then
    versus.includePrefixed("sh_init.lua", fullPath)
  end

  if (g_File.Exists(fullPath .. "/sv_init.lua", "LUA")) then
    versus.includePrefixed("sv_init.lua", fullPath)
  end

  if (g_File.Exists(fullPath .. "/cl_init.lua", "LUA")) then
    versus.includePrefixed("cl_init.lua", fullPath)
  end
end

function versus.unit.loadUnits(unitPath, unitGlobal)
  unitPath = unitPath:Trim("/") .. "/"

  unitGlobal = unitGlobal or "UNIT"

  local oldGlobal = _G[unitGlobal]
  local fullPath = gamemodeFolder .. "/gamemode/" .. unitPath
  local loadedUnits = {}

  for _, unitDirectory in pairs(select(2, g_File.Find(fullPath .. "*", "LUA"))) do
    if (unitDirectory ~= "." and unitDirectory ~= "..") then
      local path = fullPath .. unitDirectory

      -- If a sh_loader file exists, include it first so it can conditionally prevent loading.
      if (g_File.Exists(path .. "/sh_loader.lua", "LUA")) then
        local shouldLoad, faultMessage = versus.includePrefixed("sh_loader.lua", path)

        if (shouldLoad == false) then
          print(
            string.format(
              "Versus %s Loader: Skipping %s '%s' as per its sh_loader.lua: %s",
              unitGlobal,
              unitGlobal,
              tostring(unitDirectory),
              tostring(faultMessage or "No reason given")
            )
          )
          continue
        end
      end

      local unit = versus.unit.get(path)

      if (unit == nil) then
        unit = setmetatable({}, FindMetaTable("VersusUnit")):init(unitGlobal)
      else
        unit:reset()
      end

      unit.directoryName = unitDirectory
      unit.fullPath = path
      unit.path = unitPath

      _G[unitGlobal] = unit

      includeInits(path)

      -- Check if this unit wants a spot in the versus table (for
      -- libraries)
      local libraryKey = unit.libraryKey
      if (libraryKey) then
        if (versus[libraryKey] ~= nil and versus[libraryKey] ~= unit) then
          ErrorNoHaltWithStack(
            "Warning! Duplicate unit with libraryKey defined! Only one unit should claim a key in the versus table.")
        end

        versus[libraryKey] = unit
      end

      versus.includeDirectory(path .. "/metatables/")

      versus.unit.IncludeEntities(path .. "/entities/entities/")
      versus.unit.IncludeWeapons(path .. "/entities/weapons/")
      versus.unit.IncludeEffects(path .. "/entities/effects/")

      unit:registerHooks()

      versus.unit.stored[path] = unit
      table.insert(loadedUnits, versus.unit.stored[path])

      -- Called immediately after the unit is done loading.
      hook.Run("SomeUnitLoaded", unit)
    end
  end

  for _, unit in pairs(loadedUnits) do
    _G[unitGlobal] = unit

    -- Called after SomeUnitLoaded when all other units in this call to
    -- loadUnits have been successfully loaded
    hook.Run("SomeUnitInitialized", unit)
  end

  _G[unitGlobal] = oldGlobal

  return loadedUnits
end

local function includeEntityType(fullPath, global, setupCallback, registerFunction)
  fullPath = versus.ensurePathAbsolute(fullPath)

  local oldGlobal = _G[global]
  local files, directories = g_File.Find(fullPath .. "*", "LUA")

  for _, directory in pairs(directories) do
    if (directory ~= ".." and directory ~= ".") then
      _G[global] = setupCallback()

      includeInits(fullPath .. directory)

      registerFunction(_G[global], directory)
    end
  end

  for _, file in pairs(files) do
    if (file:EndsWith(".lua")) then
      _G[global] = setupCallback()

      versus.includePrefixed(file, fullPath)

      -- Strip the prefix and extension
      local className = file:sub(4, file:len() - 4)

      registerFunction(_G[global], className)
    end
  end

  _G[global] = oldGlobal
end

function versus.unit.IncludeEntities(fullPath)
  includeEntityType(fullPath, "ENT", function()
    return {
      Type = "anim"
    }
  end, scripted_ents.Register)
end

function versus.unit.IncludeWeapons(fullPath)
  includeEntityType(fullPath, "SWEP", function()
    return {
      Base = "weapon_base",
      Primary = {},
      Secondary = {}
    }
  end, weapons.Register)
end

function versus.unit.IncludeEffects(fullPath)
  includeEntityType(fullPath, "EFFECT", function()
    return {}
  end, function(...)
    if (SERVER) then
      return
    end

    effects.Register(...)
  end)
end
