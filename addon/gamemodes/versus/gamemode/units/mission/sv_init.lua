local UNIT = UNIT

util.AddNetworkString("versus.mission.update")
util.AddNetworkString("versus.mission.updateStage")
util.AddNetworkString("versus.mission.updateCompletion")
util.AddNetworkString("versus.mission.requestHistory")
util.AddNetworkString("versus.mission.updateHistory")

file.CreateDir(GM.FolderName .. "/missions/")

--- Load mission progress from the database
function UNIT.loadPlayerProgress(player, callback)
  local playerMissionsStatement = string.format([[
		SELECT
			`id`,
			`mission_id`,
			`player_id`,
			`stage`,
			`data`,
			`messages`,
      UNIX_TIMESTAMP(`started_at`) as `started_at`,
      UNIX_TIMESTAMP(`completed_at`) as `completed_at`
		FROM `%s`
		WHERE `player_id` = %u
	]], versus.config["MySQL Player Missions Table"], player:getVersusID())

  versus.database.query(playerMissionsStatement, function(result)
    if (IsValid(player)) then
      local missions = {}

      for _, row in pairs(result) do
        if (UNIT.get(row.mission_id)) then
          missions[row.mission_id] = {
            _id = row.id,
            startedAt = row.started_at,
            completedAt = row.completed_at,
            stage = row.stage,
            data = util.JSONToTable(row.data),
            messages = util.JSONToTable(row.messages),
          }
        else
          ErrorNoHalt(player:getSteamID64(), " loaded with non-existant missionID: ", row.mission_id, ". Skipping.\n")
        end
      end

      player.missions = missions
      UNIT.networkPlayerMissions(player)

      if (callback) then
        callback(missions)
      end
    end
  end)
end

--- Save progress to the database
function UNIT.saveMissionProgress(player, mission, progress)
  local missionsTable = versus.config["MySQL Player Missions Table"]
  local statement = string.format([[
		REPLACE INTO `%s` (`id`, `mission_id`, `player_id`, `stage`, `data`, `messages`, `started_at`, `completed_at`)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?);
	]], missionsTable)
  local values = {
    versus.player.getValueTypeDefinition(progress._id),
    versus.player.getValueTypeDefinition(mission.missionID),
    versus.player.getValueTypeDefinition(player:getVersusID()),
    versus.player.getValueTypeDefinition(progress.stage),
    versus.player.getValueTypeDefinition(util.TableToJSON(progress.data)),
    versus.player.getValueTypeDefinition(util.TableToJSON(progress.messages)),
    versus.player.getValueTypeDefinition(progress.startedAt, true),
    versus.player.getValueTypeDefinition(progress.completedAt, true),
  }

  -- Fetch the id for later updating of this same progress
  versus.database.queryPrepared(statement, values, function(_, progressID)
    if (IsValid(player)) then
      player.missions[mission.missionID]._id = progressID
    end
  end, nil, true)
end

--- Start a mission for the player, performing the neccessary checks
function UNIT.start(mission, player)
  if (mission:isRelevant(player)) then
    return false, "already started the mission '" .. mission.name .. "'!"
  end

  local canStart, message = mission:canStart(player)

  if (not canStart) then
    return false, message
  end

  mission:start(player)

  return true
end

--- Sends the players' mission and progress for that mission to the client
function UNIT.networkPlayerMission(mission, player)
  local progress = UNIT.getPlayerProgress(mission, player)

  net.Start("versus.mission.update")
  net.WriteString(mission.missionID)
  -- TODO: These 32-bit numbers will no longer work after Sun Feb 07 2106 06:28:15 GMT+0000
  net.WriteUInt(progress.startedAt, 32)
  net.WriteUInt(progress.completedAt or UNIT.NO_PROGRESS, 32)
  -- * This 7 bits put a hard cap on the amount of possible stages: 127
  -- * If a mission has that many stages it should really be split up into
  -- * multiple missions anyway
  local stage = mission:getPlayerStage(player)
  net.WriteUInt(stage and stage:getIndex() or UNIT.NO_STAGE, 7)
  net.Send(player)
end

--- Sends the players' mission stage for that mission to the client
function UNIT.networkPlayerMissionStage(mission, player)
  local progress = UNIT.getPlayerProgress(mission, player)
  local stage = mission:getPlayerStage(player)

  net.Start("versus.mission.updateStage")
  net.WriteString(mission.missionID)
  net.WriteUInt(stage and stage:getIndex() or UNIT.NO_STAGE, 7)
  net.Send(player)
end

--- Sends the players' mission completed time for that mission to the client
function UNIT.networkPlayerMissionCompleted(mission, player)
  local progress = UNIT.getPlayerProgress(mission, player)

  net.Start("versus.mission.updateCompletion")
  net.WriteString(mission.missionID)
  net.WriteUInt(progress.completedAt or UNIT.NO_PROGRESS, 32)
  net.Send(player)
end

--- Sends the players' missions and progress to the client
function UNIT.networkPlayerMissions(player, withCompleted)
  local networkedCount = 0

  for missionID, progress in pairs(player.missions) do
    if (withCompleted or progress.completedAt == nil) then
      UNIT.networkPlayerMission(UNIT.get(missionID), player)
      networkedCount = networkedCount + 1
    end
  end

  return networkedCount
end

--- Sets the progress this player has made on the given mission
function UNIT.setPlayerProgress(mission, player, stageOrComplete, data)
  local progress = player.missions[mission.missionID] or {}
  local stage = istable(stageOrComplete) and stageOrComplete or nil

  player.missions[mission.missionID] = progress

  progress.startedAt = progress.startedAt or os.time()
  progress.messages = progress.messages or {}
  progress.data = progress.data or {}

  if (istable(data)) then
    -- This progress table can hold other info, say for example when
    -- a user does something like kill a mission npc, you could store it here
    -- and then later check if that happened to customize the ending.
    -- You would pass that data in an array as the 4th argument, e.g:
    -- { violent = true }
    table.Merge(progress.data, data)
  end

  if (stage) then
    progress.stage = stage:getIndex()

    UNIT.networkPlayerMissionStage(mission, player)
  end

  if (isbool(stageOrComplete) and stageOrComplete) then
    progress.completedAt = os.time()

    UNIT.networkPlayerMissionCompleted(mission, player)
  end

  UNIT.saveMissionProgress(player, mission, progress)
end

--- Show a message to the player and log it in their mission log
function UNIT.notifyPlayer(mission, player, message, class)
  versus.message.notify(player, message, class)

  local progress = player.missions[mission.missionID] or {}

  if (progress.messages == nil) then
    progress.messages = {}
  end

  -- Using an indexed array here so the order in which messages are
  -- received is maintained
  if (not table.HasValue(progress.messages, message)) then
    table.insert(progress.messages, message)
  end

  player.missions[mission.missionID] = progress
end

function UNIT.setMissionWaypoint(mission, waypointIndex, vector, angle)
  local waypoint = mission:getWaypoint(waypointIndex)

  waypoint.vector = vector
  waypoint.angle = angle

  UNIT.saveMissionWaypoints(mission)
end

function UNIT.saveMissionWaypoints(mission)
  local waypoints = mission:getWaypoints()
  local data = {}

  for waypointIndex, waypoint in pairs(waypoints) do
    data[waypointIndex] = waypoint:getDataCopy()
  end

  file.Write(mission:getDataDir() .. "waypoints.txt", util.TableToJSON(data))
end

function UNIT.loadMissionWaypoints(mission)
  local json = file.Read(mission:getDataDir() .. "waypoints.txt")

  if (not json) then
    return
  end

  local waypoints = mission:getWaypoints()
  local data = util.JSONToTable(json)

  for waypointIndex, waypoint in pairs(waypoints) do
    if (data[waypointIndex]) then
      waypoint:restoreDataCopy(data[waypointIndex])
    end
  end
end

--- Sends a player all missions (used for admins)
function UNIT.networkAllMissions(player)
  if (not player:IsSuperAdmin()) then
    ServerLog(player)
    ServerLog(player:getSteamID64())
    error("versus.mission.networkAllMissions: Player is not an admin!")
  end

  local json = util.TableToJSON(UNIT.stored)
  local compressed = util.Compress(json)
  local byteCount = #compressed

  print("Sending all missions to " .. player:Nick() .. " (" .. byteCount .. " bytes)")

  local message = versus.network.startUnboundedMessage("versus.mission.sendFullAll")
  message:writeUInt(byteCount, 32)
  message:writeData(compressed, byteCount)
  message:send(player)
end

--- Sends a players all info about a mission (used for admins)
function UNIT.networkMission(mission, player)
  if (not player:IsSuperAdmin()) then
    ServerLog(player)
    ServerLog(player:getSteamID64())
    error("versus.mission.networkMission: Player is not an admin!")
  end

  local json = util.TableToJSON(mission)
  local compressed = util.Compress(json)
  local byteCount = #compressed

  local message = versus.network.startUnboundedMessage("versus.mission.sendFull")
  message:writeString(mission.missionID)
  message:writeUInt(byteCount, 16)
  message:writeData(compressed, byteCount)
  message:send(player)
end

net.Receive("versus.mission.requestHistory", function(len, player)
  if (player._KnowsMissionHistory) then
    -- We only send the info once
    return
  end

  local networkedCount = UNIT.networkPlayerMissions(player, true)

  net.Start("versus.mission.updateHistory")
  net.WriteUInt(networkedCount, 10)
  net.Send(player)

  player._KnowsMissionHistory = true
end)
