---@class VersusWaypoint
---@field vector Vector
---@field angle Angle
---@field name string
---@field icon string
local waypointMeta = {}
waypointMeta.__index = waypointMeta
waypointMeta._waypointIndex = -1

function waypointMeta:init()
  self.isWaypoint = true
  self.vector = nil
  self.angle = Angle()
  self.name = "no name"
  self.icon = nil

  return self
end

function waypointMeta:IsValid()
  return true
end

function waypointMeta:getIndex()
  return self._waypointIndex
end

function waypointMeta:getName()
  return self.name
end

--- Returns an array containing data on the waypoint safe for storing
function waypointMeta:getDataCopy()
  return {
    vector = self.vector,
    angle = self.angle,
    name = self.name,
    icon = self.icon,
  }
end

-- Restores waypoint information from a data copy
function waypointMeta:restoreDataCopy(data)
  table.Merge(self, data)
end

debug.getregistry()["VersusWaypoint"] = waypointMeta
