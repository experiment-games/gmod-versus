---@class VersusDrawQueue
local drawQueueMeta = {}
drawQueueMeta.__index = drawQueueMeta

function drawQueueMeta:init()
  self.queue = {}

  return self
end

function drawQueueMeta:IsValid()
  return true
end

function drawQueueMeta:add(callback, x, y, width, height)
  table.insert(self.queue, function()
    callback(x, y, width, height)
  end)
end

function drawQueueMeta:process()
  for _, callback in pairs(self.queue) do
    callback()
  end
end

debug.getregistry()["VersusDrawQueue"] = drawQueueMeta
