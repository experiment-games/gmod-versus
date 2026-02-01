local UNIT = UNIT
local gamemodeFolder = GM.FolderName

UNIT.libraryKey = "mission"

UNIT.stored = UNIT.stored or {}
UNIT.index = UNIT.index or {}

UNIT.NO_PROGRESS = 0
UNIT.NO_STAGE = 0

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

-- Get a mission by it's exact missionID.
function UNIT.get(missionID)
  return UNIT.stored[missionID]
end

-- Get a mission by it's path.
function UNIT.getByPath(path)
  local missionID = UNIT.index[path:lower()]

  return UNIT.get(missionID)
end

function UNIT.loadMissions(missionsPath)
  missionsPath = missionsPath:Trim("/") .. "/"

  if (not missionsPath:StartWith(gamemodeFolder .. "/gamemode/")) then
    missionsPath = gamemodeFolder .. "/gamemode/" .. missionsPath
  end

  local oldMISSION = MISSION
  local fullPath = missionsPath

  local missionFiles, missionDirectories = file.Find(fullPath .. "*", "LUA")
  local stripFromMissionID = gamemodeFolder .. "_gamemode_"

  local function startMission(missionID, path, coreFileOrDirectory)
    MISSION = UNIT.getByPath(path)

    if (MISSION == nil) then
      MISSION = setmetatable({}, FindMetaTable("VersusMission")):init()
    else
      MISSION:reset()
    end

    MISSION.missionID = missionID:gsub("[\\/:\"*?<>|]+", "_")
    MISSION.fullPath = fullPath .. coreFileOrDirectory
    MISSION.path = path
    MISSION.hook = MISSION.hook or {}

    if (MISSION.missionID:sub(1, stripFromMissionID:len()) == stripFromMissionID) then
      MISSION.missionID = MISSION.missionID:sub(stripFromMissionID:len() + 1)
    end

    file.CreateDir(MISSION:getDataDir())
  end

  local function endMission()
    local mission = MISSION

    if (SERVER) then
      UNIT.loadMissionWaypoints(MISSION)
    end

    for eventName, callback in pairs(MISSION.hook) do
      -- Call hook callbacks in a protected manner so one mission doesn't break all others
      hook.Add(eventName, mission, function(...)
        local success, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z = xpcall(
          callback,
          function(errorMessage)
            ErrorNoHaltWithStack(
              string.format(
                "[Mission \"%s\"] %s Hook Failed! Error: %q\n",
                mission.missionID,
                eventName,
                errorMessage
              )
            )
          end,
          ...
        )

        if (not success) then
          return
        end

        if (x ~= nil or y ~= nil or z ~= nil) then
          ErrorNoHaltWithStack(
            string.format(
              "[Mission %q] %s Warning! Hook has unreasonable varargs count! Expect bugs.\n",
              mission.missionID,
              eventName
            )
          )
          print(success, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z)
        end

        return a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
      end)
    end

    UNIT.index[MISSION.path:lower()] = MISSION.missionID
    UNIT.stored[MISSION.missionID] = MISSION
  end

  -- Store the file contents for content managers (super admins) to see
  local registerFile = function(missionFile, missionDirectory)
    local fullPath = (missionDirectory:Trim("/") .. "/") .. missionFile
    MISSION._files[missionFile] = {
      fullPath = fullPath,
      content = file.Read(fullPath, "LUA")
    }
  end

  for _, missionFile in pairs(missionFiles) do
    startMission(missionsPath .. (missionFile:sub(4, -5)), missionsPath .. missionFile, missionFile)

    versus.includePrefixed(missionFile, missionsPath)
    registerFile(missionFile, missionsPath)

    endMission()
  end

  for _, missionDirectory in pairs(missionDirectories) do
    startMission(missionsPath .. missionDirectory, missionsPath .. missionDirectory, missionDirectory)

    if (file.Exists(missionsPath .. missionDirectory .. "/sh_init.lua", "LUA")) then
      versus.includePrefixed("sh_init.lua", missionsPath .. missionDirectory)
      registerFile("sh_init.lua", missionsPath .. missionDirectory)
    end

    if (file.Exists(missionsPath .. missionDirectory .. "/sv_init.lua", "LUA")) then
      versus.includePrefixed("sv_init.lua", missionsPath .. missionDirectory)
      registerFile("sv_init.lua", missionsPath .. missionDirectory)
    end

    if (file.Exists(missionsPath .. missionDirectory .. "/cl_init.lua", "LUA")) then
      versus.includePrefixed("cl_init.lua", missionsPath .. missionDirectory)
      registerFile("cl_init.lua", missionsPath .. missionDirectory)
    end

    -- Load specialized items or ui related to this mission
    versus.item.loadItems(MISSION.fullPath .. "/items/")
    versus.panel.loadPanels(MISSION.fullPath .. "/panels/")

    endMission()
  end

  MISSION = oldMISSION
end

--- Check if a player arrives at one of their active mission waypoints
function UNIT.checkPlayerArriveWaypoint(player)
  local missions, progress = UNIT.getPlayerMissions(player)

  for missionID, mission in pairs(missions) do
    local stage = mission:getPlayerStage(player)

    if (stage) then
      local waypoint = stage:getWaypoint()

      if (waypoint and versus.entity.isNearPosition(player, waypoint.vector, 128)) then
        mission:nextStage(player)
      end
    end
  end
end

--- Get the missions a player has accepted (and optionally completed)
--- Returns one table with the missions and secondly the players' progress
--- over all missions. In both cases the mission ID's form the keys in the
--- table.
---@return table<string, VersusMission>, table<string, VersusMission>
function UNIT.getPlayerMissions(player, withCompleted)
  local progress = SERVER and player.missions or UNIT.progress
  local missions = {}

  for missionID, missionProgress in pairs(progress) do
    if (withCompleted or missionProgress.completedAt == nil) then
      missions[missionID] = UNIT.get(missionID)
    end
  end

  return missions, table.Copy(progress)
end

--- Returns the stage this player is currently at for the given mission or
--- nil if this mission doesn't have stages.
---@return VersusStage|nil
function UNIT.getPlayerStage(mission, player)
  local progress = UNIT.getPlayerProgress(mission, player)

  if (not progress.stage) then
    return
  end

  return mission:getStage(progress.stage)
end

--- Returns the progress this player has made on the given mission.
function UNIT.getPlayerProgress(mission, player)
  local progressTable = SERVER and player.missions or UNIT.progress

  return progressTable[mission.missionID]
end
