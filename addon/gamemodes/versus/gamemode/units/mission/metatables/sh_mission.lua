local gamemodeFolder = GM.FolderName

---@class VersusMission
---@field name string The mission name
---@field description string A description for this mission
local missionMeta = {}
missionMeta.__index = missionMeta

function missionMeta:init()
  self:reset()

  return self
end

function missionMeta:reset()
  self._files = {}
  self._stages = {}

  -- TODO: Check the data/ folder and load the waypoints
  self._waypoints = {}

  self.name = "No name"
  self.description = "No description"
end

function missionMeta:IsValid()
  return true
end

function missionMeta:getDataDir()
  return gamemodeFolder .. "/missions/" .. self.missionID .. "/"
end

---@param player Player
function missionMeta:isEngaged(player)
  return versus.mission.getPlayerProgress(self, player) ~= nil
end

---@param player Player
function missionMeta:hasCompleted(player)
  local progress = versus.mission.getPlayerProgress(self, player)

  if (progress == nil) then
    return false
  end

  return progress.completedAt ~= nil
end

---@param player Player
function missionMeta:isRelevant(player)
  return player._Initialized and player:Alive() and self:isEngaged(player) and not self:hasCompleted(player)
end

function missionMeta:registerWaypoint(name, icon)
  -- TODO: Add this waypoint to an in-game "TODO-List" for admins to set the position
  local waypointIndex = #self._waypoints + 1
  local waypoint = setmetatable({}, FindMetaTable("VersusWaypoint")):init()
  waypoint._waypointIndex = waypointIndex
  waypoint.name = name
  waypoint.icon = icon

  self._waypoints[waypointIndex] = waypoint

  return waypoint
end

function missionMeta:getWaypoint(waypointIndex)
  return self._waypoints[waypointIndex]
end

function missionMeta:getWaypoints()
  return self._waypoints
end

--- Returns the stage by it's index
---@return VersusStage
function missionMeta:getStage(index)
  return self._stages[index]
end

function missionMeta:getStages()
  return self._stages
end

--- Creates a stage within the mission that can be reached
function missionMeta:addStage(stageTitle, completesOn)
  local stageIndex = #self._stages + 1
  local stage = setmetatable({}, FindMetaTable("VersusStage")):init()
  stage._stageIndex = stageIndex
  stage.stageTitle = stageTitle
  stage.completesOn = completesOn

  self._stages[stageIndex] = stage

  return stage
end

function missionMeta:runStageCallback(stage, player)
  local completionCallback = stage:getCallback()

  if (not completionCallback) then
    return false
  end

  local success, message = completionCallback(self, player)

  if (isstring(message)) then
    versus.mission.notifyPlayer(self, player, message, success and NOTIFY_CHAT_LIGHTBULB or NOTIFY_ERROR)
  end

  if (success) then
    self:nextStage(player)
  end

  return true
end

---@param player Player
function missionMeta:start(player)
  local stage, message = self:onStart()

  if (not stage) then
    stage = self._stages[1] or nil
  end

  if (isstring(message)) then
    versus.mission.notifyPlayer(self, player, message, NOTIFY_CHAT_LIGHTBULB)
  end

  versus.mission.setPlayerProgress(self, player, stage)
end

--- Returns the stage this player is currently at
---@param player Player
function missionMeta:getPlayerStage(player)
  return versus.mission.getPlayerStage(self, player)
end

---@param player Player
function missionMeta:nextStage(player)
  local stage = self:getPlayerStage(player)
  local nextStage = self:getStage(stage:getIndex() + 1)
  local message

  nextStage, message = self:onStageReached(player, stage, nextStage)

  if (isstring(message)) then
    versus.mission.notifyPlayer(self, player, message, NOTIFY_CHAT_LIGHTBULB)
  end

  if (nextStage == nil) then
    self:complete(player)

    return
  end

  versus.mission.setPlayerProgress(self, player, nextStage)
end

function missionMeta:getFiles()
  return self._files
end

---@param player Player
function missionMeta:complete(player)
  local message = self:onComplete(player)

  versus.mission.setPlayerProgress(self, player, true)

  if (isstring(message)) then
    versus.mission.notifyPlayer(self, player, message, NOTIFY_CHAT_LIGHTBULB)
  end
end

--- Override this method from your mission.
---@param player Player
---@return boolean, string
function missionMeta:canStart(player)
  return true
end

--- Override this method from your mission.
--- Can return the first stage and an optional message to the player.
--- The message must logically complete these sentences:
--- You have...
--- You cannot start this mission because you have...
--- This player has...
--- If you provide nil the first stage added with addStage is chosen, or if
--- no stages are added the mission will rely on a manual call to
--- MISSION:complete(player)
---@param player Player
---@return VersusStage|nil, string
function missionMeta:onStart(player) end

--- Override this method from your mission.
--- Can return the next stage and an optional message to the player
--- If you provide nil the `nextStage` will be chosen or if that is nil the
--- mission will complete
---@param player Player
---@param stage VersusStage The stage that was just finished
---@param nextStage VersusStage|nil The stage registered after `stage`
---       using addStage. If this is nil the mission will end after this.
---@return VersusStage|nil, string
function missionMeta:onStageReached(player, stage, nextStage) end

-- Not yet implemented
-- --- Called after a stage has been finished
-- --- Return nil for default behaviour: Complete when all stages have
-- --- finished.
-- --- Return false to indicate the mission is not yet completed
-- --- (you must manually indicate the next step for the player as there may
-- --- be no stages)
-- --- Return true to indicate the mission ended sooner (you
-- --- must manually show a completion text)
-- ---@param player Player
-- ---@return boolean|nil, string
-- function missionMeta:shouldComplete(player) end

--- Override this method from your mission.
--- Can return with an optional message to the player.
---@param player Player
---@return string|nil
function missionMeta:onComplete(player) end

debug.getregistry()["VersusMission"] = missionMeta
