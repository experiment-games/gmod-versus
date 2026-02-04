local UNIT = UNIT

-- Entity Info Builder Metatable
local INFO = {}
INFO.__index = INFO

function INFO:addTitle(text)
  self.title = text
  return self
end

function INFO:addDescription(text)
  table.insert(self.descriptions, text)
  return self
end

function INFO:addRow(text, color)
  table.insert(self.rows, {
    text = text,
    color = color
  })
  return self
end

function INFO:setColor(color)
  self.accentColor = color
  return self
end

function INFO:hasContent()
  return self.title ~= nil or #self.descriptions > 0 or #self.rows > 0
end

debug.getregistry()["EntityInfo"] = INFO

-- Create a new info builder
function UNIT:createEntityInfo()
  local info = {
    title = nil,
    descriptions = {},
    rows = {},
    accentColor = Color(80, 140, 220, 255)
  }

  setmetatable(info, INFO)
  return info
end
