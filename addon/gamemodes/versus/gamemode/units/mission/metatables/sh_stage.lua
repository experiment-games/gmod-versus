---@class VersusStage
local stageMeta = {}
stageMeta.__index = stageMeta
stageMeta._stageIndex = -1

function stageMeta:init()
  self.stageTitle = "no title"
  self.completesOn = nil

  return self
end

function stageMeta:IsValid()
  return true
end

function stageMeta:getWaypoint()
  if (not self.completesOn or not istable(self.completesOn)) then
    return
  end

  if (self.completesOn.isWaypoint) then
    return self.completesOn
  end
end

function stageMeta:getCallback()
  if (not self.completesOn or not isfunction(self.completesOn)) then
    return
  end

  return self.completesOn
end

function stageMeta:getIndex()
  return self._stageIndex
end

function stageMeta:getTitle()
  return self.stageTitle
end

debug.getregistry()["VersusStage"] = stageMeta
