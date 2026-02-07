local g_Player = player

---@class VersusCommand
local commandMeta = {}
commandMeta.__index = commandMeta

function commandMeta:init(command)
  self.command = command
  self:reset()

  return self
end

function commandMeta:reset()
  self.description = "No description specified"
  self.category = "Commands"
  self.requiredFlags = ""
  self.parameters = {}
  self.requiredParameters = 0
  self.parameterDescription = ""
end

function commandMeta:IsValid()
  return true
end

local function getFancyType(typeDescriptor)
  if (isstring(typeDescriptor)) then
    return typeDescriptor
  elseif (typeDescriptor == tostring) then
    return "text"
  elseif (typeDescriptor == tonumber) then
    return "number"
  elseif (typeDescriptor == tobool) then
    return "yes|no"
  elseif (typeDescriptor == Player) then
    return "player"
  elseif (typeDescriptor == Vector) then
    return "vector"
  elseif (typeDescriptor == Angle) then
    return "angle"
  elseif (istable(typeDescriptor)) then
    local fancyType = ""

    for _, alternativeType in pairs(typeDescriptor) do
      fancyType = fancyType .. (fancyType:len() ~= 0 and "/" or "") .. getFancyType(alternativeType)
    end

    return fancyType
  end
end

function commandMeta:addRequiredParameter(typeDescriptor, shortDescription, description)
  self.requiredParameters = self.requiredParameters + 1
  return self:addParameter(typeDescriptor, shortDescription, description, nil, true)
end

function commandMeta:addParameter(typeDescriptor, shortDescription, description, defaultValue, isRequired)
  if (isRequired) then
    if (defaultValue ~= nil) then
      ErrorNoHaltWithStack("Loading invalid command " .. self.command ..
        "! Required parameter can not have default value.\n")
    end

    local lastParameter = self.parameters[#self.parameters]

    if (lastParameter and not lastParameter.isRequired) then
      ErrorNoHaltWithStack("Loading invalid command " ..
        self.command .. "! Required parameter can not come after optional parameter.\n")
    end
  end

  local cachedEnums

  if (isstring(typeDescriptor)) then
    local enumCount = 0
    cachedEnums = {}

    -- enum1|enum2|enum3|etc...
    for part in string.gmatch(typeDescriptor, "([^|]*|-)") do
      cachedEnums[part:lower()] = true
      enumCount = enumCount + 1
    end

    if (enumCount == 1) then
      cachedEnums = nil
    end
  end

  if (self.parameterDescription:len() ~= 0) then
    self.parameterDescription = self.parameterDescription .. " "
  end

  local fancyType = getFancyType(typeDescriptor)

  if (isRequired) then
    fancyType = "<" .. fancyType .. " " .. shortDescription .. ">"
  else
    fancyType = "[" .. fancyType .. " " .. shortDescription .. "]"
  end

  self.parameterDescription = self.parameterDescription .. fancyType

  return table.insert(self.parameters, {
    typeDescriptor = typeDescriptor,
    _cachedEnums = cachedEnums,
    shortDescription = shortDescription,
    description = description,
    defaultValue = defaultValue,
    isRequired = isRequired,
  })
end

function commandMeta:processParameter(parameter, value, processed, alternativeType)
  local parameterType = alternativeType or parameter.typeDescriptor

  if (parameterType == tostring) then
    value = tostring(value)

    if (value == "") then
      return false, "Not enough text specified for " .. parameter.shortDescription .. "!"
    end

    table.insert(processed, value)
    return true
  end

  if (parameterType == tonumber) then
    value = tonumber(value)

    if (value == nil) then
      return false, "Invalid number (" .. tostring(value) .. ") specified for " .. parameter.shortDescription .. "!"
    end

    table.insert(processed, value)
    return true
  end

  if (parameterType == tobool) then
    value = value:lower()

    if (value == "yes") then
      value = true
    elseif (value == "no") then
      value = false
    else
      value = tobool(value)
    end

    table.insert(processed, value)
    return true
  end

  if (parameterType == Player) then
    local lowerValue = value:lower()

    for _, player in ipairs(g_Player.GetAll()) do
      if (
            player._VersusInitialized
            and (string.find(player:getCombinedName():lower(), lowerValue, nil, false)
              or string.find(player:getSteamID64(), value, nil, false)
              or string.find(player:SteamID():lower(), lowerValue, nil, false)
            )
          ) then
        table.insert(processed, player)
        return true
      end
    end

    return false, "No " .. parameter.shortDescription .. " could be found by the name or steamid " ..
        tostring(value) .. "!"
  end

  if (parameterType == Vector
        or parameterType == Angle) then
    local x, y, z = string.match(value, "^([%d.-]+) ([%d.-]+) ([%d.-]+)$")

    if (x == nil or y == nil or z == nil) then
      return false, "Invalid " .. parameter.shortDescription .. " specified!"
    end

    table.insert(processed, Vector(x, y, z))
    return true
  end

  if (isstring(parameterType)) then
    local cachedEnums = parameter._cachedEnums
    value = tostring(value)

    if (cachedEnums) then
      if (not cachedEnums[value:lower()]) then
        return false, value .. " is not a valid option for " .. parameter.shortDescription .. "!"
      end

      table.insert(processed, value)
      return true
    end

    if (value ~= parameterType) then
      return false, value .. " is not a valid option for " .. parameter.shortDescription .. "!"
    end

    table.insert(processed, value)
    return true
  end

  if (istable(parameterType)) then
    for index, alternativeType in pairs(parameterType) do
      local success, fault = self:processParameter(parameter, value, processed, alternativeType)

      if (success) then
        return true
      elseif (index == #parameterType) then
        return success, fault
      end
    end
  end
end

function commandMeta:run(player, parameters)
  local numParameters = #self.parameters
  local processed = {}

  if (#parameters < self.requiredParameters) then
    return false, "Not enough parameters specified! Expected " .. self.requiredParameters .. ", got " ..
        #parameters .. "."
  end

  for index, value in pairs(parameters) do
    local parameter = self.parameters[index]

    if (not parameter) then
      if (index > numParameters) then
        local lastParameter = self.parameters[numParameters]

        if (lastParameter.typeDescriptor ~= tostring) then
          return false, "Too many parameters specified!"
        end

        value = tostring(value)
        -- Keep appending strings to the last string parameter
        processed[#processed] = processed[#processed] .. " " .. value
      end
    else
      local success, fault = self:processParameter(parameter, value, processed)

      if (not success) then
        return success, fault
      end
    end
  end

  -- Fill in default values for missing optional parameters
  for i = #parameters + 1, numParameters do
    local parameter = self.parameters[i]

    if (not parameter.isRequired and parameter.defaultValue ~= nil) then
      table.insert(processed, parameter.defaultValue)
    end
  end

  return self:onRun(player, unpack(processed))
end

debug.getregistry()["VersusCommand"] = commandMeta
