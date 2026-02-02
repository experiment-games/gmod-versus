versus.util = versus.util or {}
versus.util.activeThrottles = versus.util.activeThrottles or {}

local random = math.random
local spinnerFrames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- Either returns the value if it's not a function, or calls the function and returns its result.
--- @param value any The value or function to resolve
--- @vararg any Arguments to pass to the function if `value` is a function
--- @return any # The resolved value
function versus.util.resolve(value, ...)
  if (type(value) == "function") then
    return value(...)
  end

  return value
end

-- Turns 1000 into 1,000
-- Source: https://stackoverflow.com/a/10992898
function versus.util.formatHuman(number, unitPrefix)
  local _, __, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')

  -- reverse the int-string and append a comma to all blocks of 3 digits
  int = int:reverse():gsub("(%d%d%d)", "%1,")

  -- reverse the int-string back remove an optional comma and put the
  -- optional minus and fractional part back
  return minus .. (unitPrefix and unitPrefix or "") .. int:reverse():gsub("^,", "") .. fraction
end

--- Formats money values into a human-readable string.
--- @param amount number The amount of money
--- @return string # The formatted money string
function versus.util.formatMoney(amount)
  local absAmount = math.abs(amount)
  local formatted = versus.util.formatHuman(absAmount, versus.config["Money Symbol"])

  return string.format("%s%s", amount < 0 and "-" or "", formatted)
end

-- Returns a UUID which is highly likely to be unique
-- Source: https://gist.github.com/jrus/3197011
function versus.util.uuid()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    return string.format('%x', v)
  end)
end

function versus.util.spinnerText(elapsed)
  local frameIndex = math.floor(elapsed * 8) % #spinnerFrames + 1

  return spinnerFrames[frameIndex]
end

--- Creates a queue from a table which provides enqueue and dequeue operations.
--- @generic T: any
--- @param source? T[]
--- @param fixedSize? number If set, the queue will be limited to this size and will dequeue the oldest value when full
--- @return Queue<T> # The queue
--- @realm shared
function versus.util.newQueue(source, fixedSize)
  source = source or {}

  --- @realm shared
  --- @class Queue<T>
  local queue = {}

  --- Enqueues a value to the end of the queue.
  --- @param value any
  function queue:enqueue(value)
    table.insert(source, value)

    if (fixedSize and #source > fixedSize) then
      table.remove(source, 1)
    end
  end

  --- Dequeues a value from the front of the queue.
  --- @return any # The dequeued value
  function queue:dequeue()
    return table.remove(source, 1)
  end

  --- Peeks at the given index or front value of the queue.
  --- @param index? number
  --- @return any # The front value
  function queue:peek(index)
    return source[index or 1]
  end

  --- Returns the size of the queue.
  --- @return number # The size
  function queue:size()
    return #source
  end

  --- Checks if the queue is empty.
  --- @return boolean # Whether the queue is empty
  function queue:isEmpty()
    return #source == 0
  end

  --- Checks if the queue contains a value.
  --- @param value any
  --- @return boolean # Whether the queue contains the value
  function queue:contains(value)
    for _, v in pairs(source) do
      if (v == value) then
        return true
      end
    end

    return false
  end

  --- Gets all the values in the queue.
  --- @return table
  function queue:getAll()
    return table.Copy(source)
  end

  --- Clears the queue, removing all values.
  function queue:clear()
    table.Empty(source)
  end

  return queue
end

--- Returns true if the throttle is active, otherwise false.
--- @param scope string
--- @param delay number
--- @param entity Entity? If provided, the throttle will be unique to the entity.
--- @return boolean, number?
--- @realm shared
function versus.util.throttled(scope, delay, entity)
  local scopeTable = versus.util.activeThrottles

  if (entity) then
    scopeTable = entity._VersusThrottles or {}
    entity._VersusThrottles = scopeTable
  end

  if (scopeTable[scope] == nil) then
    scopeTable[scope] = CurTime() + delay

    return false
  end

  local throttled = scopeTable[scope] > CurTime()

  if (not throttled) then
    scopeTable[scope] = CurTime() + delay

    return false
  end

  return throttled, math.ceil(scopeTable[scope] - CurTime())
end
