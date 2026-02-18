versus.util = versus.util or {}
versus.util.activeThrottles = versus.util.activeThrottles or {}

local random = math.random
local spinnerFrames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function versus.util.getUniqueID()
  return tostring({})
end

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

--- Waits a frame before calling the provided function, granted that
--- all provided arguments are still valid.
--- @param func fun(...) The function to call
function versus.util.nextFrame(func, ...)
  local testValid = { ... }
  timer.Simple(0, function()
    for _, v in pairs(testValid) do
      if (not IsValid(v)) then
        return
      end
    end

    func()
  end)
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

--- Draws a rounded rectangle outline with specified corner radius and thickness
--- ! NOTE: This works poorly with alpha values, since the borders are drawn with individual pixels in multiple passes.
--- @param cornerRadius number The radius of the corners
--- @param x number The x position of the rectangle
--- @param y number The y position of the rectangle
--- @param w number The width of the rectangle
--- @param h number The height of the rectangle
--- @param thickness number The thickness of the outline
--- @param shouldRoundTopLeft boolean Whether to round the top-left corner
--- @param shouldRoundTopRight boolean Whether to round the top-right corner
--- @param shouldRoundBottomRight boolean Whether to round the bottom-right corner
--- @param shouldRoundBottomLeft boolean Whether to round the bottom-left corner
function versus.util.drawRoundedOutlineEx(cornerRadius, x, y, w, h, thickness, shouldRoundTopLeft,
                                          shouldRoundTopRight,
                                          shouldRoundBottomRight, shouldRoundBottomLeft)
  thickness = thickness or 1
  local r = math.max(cornerRadius, thickness)
  local x2 = x + w
  local y2 = y + h

  -- Draw the four straight edges
  surface.DrawRect(x + r, y, w - (r * 2), thickness)              -- Top edge
  surface.DrawRect(x + r, y2 - thickness, w - (r * 2), thickness) -- Bottom edge
  surface.DrawRect(x, y + r, thickness, h - (r * 2))              -- Left edge
  surface.DrawRect(x2 - thickness, y + r, thickness, h - (r * 2)) -- Right edge

  -- Draw corner arcs with thickness
  local function DrawCornerArc(centerX, centerY, startAngle, endAngle)
    local steps = r * 6
    local angleStep = (endAngle - startAngle) / steps

    for i = 0, steps do
      local angle = startAngle + (angleStep * i)

      -- Draw multiple pixels for thickness
      for t = 0, thickness - 1 do
        local radius = r - t

        if (radius > 0) then
          local px = math.floor(centerX + math.cos(angle) * radius + 0.5)
          local py = math.floor(centerY + math.sin(angle) * radius + 0.5)
          surface.DrawRect(px, py, 1, 1)
        end
      end
    end
  end

  -- Draw each corner with adjusted centers
  if (shouldRoundTopLeft) then
    DrawCornerArc(x + r, y + r, math.pi, math.pi * 1.5) -- Top-left
  else
    surface.DrawRect(x, y, r, thickness)                -- Top edge
    surface.DrawRect(x, y, thickness, r)                -- Left edge
  end

  if (shouldRoundTopRight) then
    DrawCornerArc(x2 - r - 1, y + r, math.pi * 1.5, math.pi * 2) -- Top-right
  else
    surface.DrawRect(x2 - r - 1, y, r + 1, thickness)            -- Top edge
    surface.DrawRect(x2 - thickness, y, thickness, r)            -- Right edge
  end

  if (shouldRoundBottomRight) then
    DrawCornerArc(x2 - r - 1, y2 - r - 1, 0, math.pi * 0.5)        -- Bottom-right
  else
    surface.DrawRect(x2 - r - 1, y2 - thickness, r + 1, thickness) -- Bottom edge
    surface.DrawRect(x2 - thickness, y2 - r - 1, thickness, r + 1) -- Right edge
  end

  if (shouldRoundBottomLeft) then
    DrawCornerArc(x + r, y2 - r - 1, math.pi * 0.5, math.pi) -- Bottom-left
  else
    surface.DrawRect(x, y2 - thickness, r, thickness)        -- Bottom edge
    surface.DrawRect(x, y2 - r - 1, thickness, r + 1)        -- Left edge
  end
end

--- Draws a rounded rectangle outline with specified corner radius and thickness
--- ! NOTE: This works poorly with alpha values, since the borders are drawn with individual pixels in multiple passes.
--- @param cornerRadius number The radius of the corners
--- @param x number The x position of the rectangle
--- @param y number The y position of the rectangle
--- @param w number The width of the rectangle
--- @param h number The height of the rectangle
--- @param thickness number The thickness of the outline
function versus.util.drawRoundedOutline(cornerRadius, x, y, w, h, thickness)
  versus.util.drawRoundedOutlineEx(cornerRadius, x, y, w, h, thickness, true, true, true, true)
end

function versus.util.impactEffect(position, scale, withSound)
  local effectData = EffectData()

  effectData:SetStart(position)
  effectData:SetOrigin(position)
  effectData:SetScale(scale)

  util.Effect("GlassImpact", effectData, true, true)

  if (withSound) then
    sound.Play("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", position)
  end
end

function versus.util.decayEntity(entity, seconds, callback)
  local color = entity:GetColor()
  local alpha = color.a
  local subtract = math.ceil(alpha / seconds)
  local index

  if (entity.decaying) then
    index = entity.decaying
  else
    index = versus.util.getUniqueID() -- will be unique
    entity.decaying = index
  end

  entity:SetRenderMode(RENDERMODE_TRANSALPHA)

  local name = "Decay: " .. index

  timer.Create(name, 1, 0, function()
    alpha = alpha - subtract

    if (not IsValid(entity)) then
      timer.Remove(name)
      return
    end

    local decayed = math.Clamp(math.ceil(alpha), 0, 255)

    if (decayed > 0) then
      entity:SetColor(Color(color.r, color.g, color.b, decayed))
      return
    end

    if (callback) then
      callback()
    end

    entity:Remove()
    timer.Remove(name)
  end)
end

if (CLIENT) then
  local blur = Material("pp/blurscreen")

  --- Creates a UV mapper function that maps panel coordinates to texture UVs using "cover" fit.
  --- The image is scaled to fill the display area while maintaining aspect ratio and centered,
  --- cropping any overflow — equivalent to CSS `background-size: cover`.
  --- @param imageWidth number The native width of the image/texture
  --- @param imageHeight number The native height of the image/texture
  --- @param displayWidth number The width of the display area
  --- @param displayHeight number The height of the display area
  --- @return fun(px: number, py: number): (number, number) # Maps panel-space coordinates to UV coordinates
  function versus.util.newCoverUVMapper(imageWidth, imageHeight, displayWidth, displayHeight)
    local scale = math.max(displayWidth / imageWidth, displayHeight / imageHeight)
    local uRange = displayWidth / (imageWidth * scale)
    local vRange = displayHeight / (imageHeight * scale)
    local uMin = (1 - uRange) * 0.5
    local vMin = (1 - vRange) * 0.5

    return function(px, py)
      return uMin + (px / displayWidth) * uRange,
          vMin + (py / displayHeight) * vRange
    end
  end

  --- Blurs the content underneath the given panel.
  --- Source: https://github.com/NebulousCloud/helix/blob/f97adac5df18c69eaee2944c8ae029ee29327503/gamemode/core/sh_util.lua#L406
  --- @param panel Panel Panel to draw the blur for
  --- @param amount? number Intensity of the blur. This should be kept between 0 and 10 for performance reasons
  --- @param passes? number Quality of the blur. This should be kept as default
  --- @param alpha? number Opacity of the blur
  function versus.util.drawBlur(panel, amount, passes, alpha)
    --[[
		Original License:

		The MIT License (MIT)

		Copyright (c) 2015 Brian Hang, Kyu Yeon Lee
		Copyright (c) 2018-2021 Alexander Grist-Hucker, Igor Radovanovic

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.
	]]
    amount = amount or 5

    surface.SetMaterial(blur)
    surface.SetDrawColor(255, 255, 255, alpha or 255)

    local x, y = panel:LocalToScreen(0, 0)

    ---@diagnostic disable-next-line: count-down-loop
    for i = -(passes or 0.2), 1, 0.2 do
      -- Do things to the blur material to make it blurry.
      blur:SetFloat("$blur", i * amount)
      blur:Recompute()

      -- Draw the blur material over the screen.
      render.UpdateScreenEffectTexture()
      surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
    end
  end
end
