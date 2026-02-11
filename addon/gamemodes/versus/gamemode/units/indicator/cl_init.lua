local UNIT = UNIT

UNIT.activeIndicators = UNIT.activeIndicators or {}

-- Configuration
local INDICATOR_SIZE = 48
local ICON_SIZE = 32
local DISTANCE_OFFSET = 16
local EDGE_PADDING = 80
local PULSE_SPEED = 2
local GLOW_INTENSITY = 0.9

-- Colors
local COLOR_TEXT = Color(220, 230, 240, 255)

-- Create a new indicator
function UNIT.create(data)
  local id = data.id
  UNIT.activeIndicators[id] = {
    id = id,
    pos = data.pos or Vector(0, 0, 0),
    text = data.text or "",
    icon = data.icon or nil,
    color = data.color or Color(80, 140, 220, 255),
    duration = data.duration or nil,
    createdTime = CurTime(),
    removeOnReach = data.removeOnReach or false,
    reachDistance = data.reachDistance or 100,
    fadeInTime = data.fadeInTime or 0.3,
    fadeOutTime = data.fadeOutTime or 0.3,
    scale = data.scale or 1,
    onRemove = data.onRemove,
    alpha = 0
  }

  return id
end

-- Remove an indicator by ID
function UNIT.remove(id)
  if UNIT.activeIndicators[id] then
    local indicator = UNIT.activeIndicators[id]

    if indicator.onRemove then
      indicator.onRemove(id)
    end

    UNIT.activeIndicators[id] = nil
  end
end

-- Update indicator position
function UNIT.updatePosition(id, pos)
  if UNIT.activeIndicators[id] then
    UNIT.activeIndicators[id].pos = pos
  end
end

-- Update indicator text
function UNIT.updateText(id, text)
  if UNIT.activeIndicators[id] then
    UNIT.activeIndicators[id].text = text
  end
end

-- Clear all indicators
function UNIT.clear()
  UNIT.activeIndicators = {}
end

-- Get indicator by ID
function UNIT.get(id)
  return UNIT.activeIndicators[id]
end

-- Get all indicators
function UNIT.getAll()
  return UNIT.activeIndicators
end

concommand.Add("versus_test_indicators", function()
  local indicatorID = UNIT.create({
    pos = LocalPlayer():GetPos() + Vector(0, 0, 200),
    text = "Objective Test",
    color = Color(80, 140, 220, 255),
    removeOnReach = true,
    reachDistance = 100,
    onRemove = function(id)
      print("Objective completed: test")
    end
  })
end)

-- Convert source units to meters (1 unit = 0.01905 meters approximately)
function UNIT.unitsToMeters(units)
  return math.Round(units * 0.01905)
end

-- Calculate screen position for indicator
function UNIT.calculateScreenPos(ply, targetPos)
  local scrW, scrH = ScrW(), ScrH()
  local screenCenter = Vector(scrW / 2, scrH / 2, 0)

  -- Convert world position to screen position
  local screenPos = targetPos:ToScreen()

  -- If behind or off-screen, clamp to screen edges
  local onScreen = screenPos.visible

  if (not onScreen) then
    -- Calculate angle to target in 2D screen space
    local angle = math.atan2(screenPos.y - screenCenter.y, screenPos.x - screenCenter.x)

    -- Calculate edge intersection
    local edgeX, edgeY
    local maxX = scrW - EDGE_PADDING
    local maxY = scrH - EDGE_PADDING
    local minX = EDGE_PADDING
    local minY = EDGE_PADDING

    -- Determine which edge to clamp to
    local aspectRatio = (maxX - minX) / (maxY - minY)
    local angleAspect = math.abs(math.cos(angle)) / math.abs(math.sin(angle))

    if (angleAspect > aspectRatio) then
      -- Clamp to left or right edge
      if (math.cos(angle) > 0) then
        edgeX = maxX
        edgeY = screenCenter.y + (maxX - screenCenter.x) * math.tan(angle)
      else
        edgeX = minX
        edgeY = screenCenter.y + (minX - screenCenter.x) * math.tan(angle)
      end
    else
      -- Clamp to top or bottom edge
      if (math.sin(angle) > 0) then
        edgeY = maxY
        edgeX = screenCenter.x + (maxY - screenCenter.y) / math.tan(angle)
      else
        edgeY = minY
        edgeX = screenCenter.x + (minY - screenCenter.y) / math.tan(angle)
      end
    end

    -- Clamp within bounds
    edgeX = math.Clamp(edgeX, minX, maxX)
    edgeY = math.Clamp(edgeY, minY, maxY)

    return edgeX, edgeY, false, angle
  end

  return screenPos.x, screenPos.y, true, 0
end

-- Draw a glowing circle indicator
function UNIT.drawIndicatorCircle(x, y, size, color, alpha, pulse)
  local glowSize = size + (math.sin(CurTime() * PULSE_SPEED) * 4 * pulse)

  -- Required since DrawCircle/DrawOutlinedCircle use DrawPoly which needs resetting of texture
  draw.NoTexture()

  -- Outer glow
  surface.SetDrawColor(ColorAlpha(color, alpha * GLOW_INTENSITY * 0.9))
  GAMEMODE:DrawOutlinedCircle(x, y, glowSize + 8, 3)

  surface.SetDrawColor(ColorAlpha(color, alpha * GLOW_INTENSITY))
  GAMEMODE:DrawOutlinedCircle(x, y, glowSize + 4, 2)

  -- Main circle background
  surface.SetDrawColor(color_background)
  GAMEMODE:DrawCircle(x, y, size)

  -- Inner circle ring
  surface.SetDrawColor(ColorAlpha(color, alpha))
  GAMEMODE:DrawOutlinedCircle(x, y, size, 3)

  -- Center dot with pulse
  local dotSize = 6 + (math.sin(CurTime() * PULSE_SPEED) * 2 * pulse)
  surface.SetDrawColor(ColorAlpha(color, alpha))
  GAMEMODE:DrawCircle(x, y, dotSize)
end

-- Draw directional arrow for off-screen indicators
function UNIT.drawDirectionalArrow(x, y, angle, color, alpha, size)
  -- Arrow points toward the target
  local arrowSize = size * 0.4

  -- Calculate arrow points
  local function rotatePoint(px, py, cx, cy, angle)
    local cos = math.cos(angle)
    local sin = math.sin(angle)
    local nx = cos * (px - cx) - sin * (py - cy) + cx
    local ny = sin * (px - cx) + cos * (py - cy) + cy
    return nx, ny
  end

  -- Arrow shape (pointing right initially)
  local points = {
    { x = x + arrowSize, y = y },
    { x = x - arrowSize, y = y + arrowSize },
    { x = x - arrowSize, y = y - arrowSize }
  }

  -- Rotate points and maintain proper table structure
  for i, point in ipairs(points) do
    local nx, ny = rotatePoint(point.x, point.y, x, y, angle)
    points[i].x = nx
    points[i].y = ny
  end

  -- Draw arrow
  surface.SetDrawColor(color.r, color.g, color.b, alpha)
  surface.DrawPoly(points)

  -- Draw arrow outline
  surface.SetDrawColor(color.r, color.g, color.b, alpha * 0.3)
  for i = 1, #points do
    local nextI = (i % #points) + 1
    surface.DrawLine(points[i].x, points[i].y, points[nextI].x, points[nextI].y)
  end
end

function UNIT.drawIndicatorText(x, y, text, color, alpha, font)
  font = font or "VersusDefault"

  surface.SetFont(font)
  local textW, textH = surface.GetTextSize(text)

  -- -- Background
  -- surface.SetDrawColor(color_background)
  -- surface.DrawRect(x - textW / 2 - 16, y - textH / 2 - 4, textW + 32, textH + 8)

  -- Text shadow
  surface.SetTextColor(0, 0, 0, alpha * 0.5)
  surface.SetTextPos(x - textW / 2 + 1, y - textH / 2 + 1)
  surface.DrawText(text)

  -- Main text
  surface.SetTextColor(color.r, color.g, color.b, alpha)
  surface.SetTextPos(x - textW / 2, y - textH / 2)
  surface.DrawText(text)

  return textW, textH
end

-- Draw distance below indicator
function UNIT.drawDistance(x, y, distance, alpha)
  local distanceText = UNIT.unitsToMeters(distance) .. "m"
  surface.SetFont("VersusDefault")
  local textW, textH = surface.GetTextSize(distanceText)

  -- Background
  surface.SetDrawColor(color_background)
  surface.DrawRect(x - textW / 2 - 16, y, textW + 32, textH + 8)

  -- Distance text
  surface.SetTextColor(ColorAlpha(color_white, alpha))
  surface.SetTextPos(x - textW / 2, y + 4)
  surface.DrawText(distanceText)
end

-- Main render function
function UNIT.hook:HUDPaint()
  local ply = LocalPlayer()
  if not IsValid(ply) then
    return
  end

  local eyePos = ply:EyePos()
  local curTime = CurTime()

  for id, indicator in pairs(UNIT.activeIndicators) do
    local position = versus.util.resolve(indicator.pos)
    local distance = eyePos:Distance(position)

    -- Check if player reached the indicator
    if indicator.removeOnReach and distance <= indicator.reachDistance then
      UNIT.remove(id)
      continue
    end

    -- Check duration
    local duration = versus.util.resolve(indicator.duration)
    if duration then
      local lifetime = curTime - indicator.createdTime
      if lifetime >= duration then
        UNIT.remove(id)
        continue
      end
    end

    -- Calculate alpha based on fade in/out
    local lifetime = curTime - indicator.createdTime
    local targetAlpha = 255

    if indicator.fadeInTime > 0 and lifetime < indicator.fadeInTime then
      targetAlpha = 255 * (lifetime / indicator.fadeInTime)
    end

    if duration and indicator.fadeOutTime > 0 then
      local timeRemaining = duration - lifetime
      if timeRemaining < indicator.fadeOutTime then
        targetAlpha = math.min(targetAlpha, 255 * (timeRemaining / indicator.fadeOutTime))
      end
    end

    indicator.alpha = Lerp(FrameTime() * 10, indicator.alpha, targetAlpha)
    local alpha = indicator.alpha

    if alpha < 1 then continue end

    -- Calculate screen position
    local x, y, onScreen, angle = UNIT.calculateScreenPos(ply, position)

    -- Calculate size with scale
    local size = INDICATOR_SIZE * indicator.scale
    local color = versus.util.resolve(indicator.color)

    -- Draw indicator
    local pulse = onScreen and 0.5 or 1
    UNIT.drawIndicatorCircle(x, y, size / 2, color, alpha, pulse)

    -- Draw directional arrow if off-screen and behind the player
    if not onScreen then
      UNIT.drawDirectionalArrow(x, y, angle, color, alpha, size / 2)
    end

    -- Draw icon if provided
    local icon = versus.util.resolve(indicator.icon)
    if icon then
      surface.SetMaterial(icon)
      surface.SetDrawColor(255, 255, 255, alpha)
      local iconSize = ICON_SIZE * indicator.scale
      surface.DrawTexturedRect(x - iconSize / 2, y - iconSize / 2, iconSize, iconSize)
    end

    -- Draw text above indicator
    local text = versus.util.resolve(indicator.text)
    if text and text ~= "" then
      local textY = y - size / 2 - 32 * indicator.scale
      UNIT.drawIndicatorText(x, textY, text:upper(), COLOR_TEXT, alpha)
    end

    -- Draw distance below indicator
    local distanceY = y + size / 2 + DISTANCE_OFFSET * indicator.scale
    UNIT.drawDistance(x, distanceY, distance, alpha)
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.indicator.create", function()
  local id = net.ReadString()
  local data = net.ReadTable()

  data.id = id

  UNIT.create(data)
end)

net.Receive("versus.indicator.remove", function()
  local id = net.ReadString()
  UNIT.remove(id)
end)
