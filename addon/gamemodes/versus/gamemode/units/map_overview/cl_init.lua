--[[
    Map Overview Library for Garry's Mod
    Based on Source SDK MapOverview.cpp
    https://github.com/ValveSoftware/source-sdk-2013/blob/11a677c349b149b2f77184dc903e6bb17f8df69b/src/game/client/game_controls/MapOverview.cpp#L769
--]]
local UNIT = UNIT

UNIT.libraryKey = "mapOverview"

--- @class MapOverview
--- @field mapOrigin Vector Map origin in world coordinates.
--- @field mapScale number Map scale factor.
--- @field mapTexture number|IMaterial Surface texture ID or material for the map image.
--- @field mapSize number Size of the map texture.
--- @field zoom number Current zoom level.
--- @field fullZoom number Full zoom level.
--- @field followAngle boolean Whether to rotate map with view angle.
--- @field rotateMap boolean Whether map should be rotated.
--- @field viewAngle number Current view angle in degrees.
--- @field mapCenter Vector Center of the map view in map coordinates.
--- @field renderCircular boolean Whether to render as a circular mini-map.
--- @field playerCenteredRotation boolean Whether to rotate map around player instead of player around map.
local MAP_OVERVIEW_META = {}
MAP_OVERVIEW_META.__index = MAP_OVERVIEW_META

-- Constants
local OVERVIEW_MAP_SIZE = 1024 -- Default map texture size

--- @class MapOverviewConfig
--- @field pos_x number Map origin X coordinate.
--- @field pos_y number Map origin Y coordinate.
--- @field scale number Map scale factor.
--- @field mapTexture number|IMaterial Optional. Surface texture ID or material for the map image.
--- @field mapSize number Optional. Size of the map texture. Default is 1024.
--- @field zoom number Optional. Zoom level. Default is 1.0.
--- @field fullZoom number Optional. Full zoom level. Default is 1.0.
--- @field followAngle boolean Optional. Whether to rotate map with view angle. Default is false.
--- @field rotateMap boolean Optional. Whether map should be rotated. Default is false.
--- @field renderCircular boolean Optional. Whether to render as circular mini-map. Default is false.
--- @field playerCenteredRotation boolean Optional. Whether to rotate map around player. Default is false.

--- Creates a new MapOverview instance.
--- @param config MapOverviewConfig Configuration table.
--- @return MapOverview # New MapOverview instance.
function UNIT.new(config)
  local overview = setmetatable({}, MAP_OVERVIEW_META)

  -- Map configuration from overview file
  overview.mapOrigin = Vector(config.pos_x or 0, config.pos_y or 0, 0)
  overview.mapScale = config.scale or 1.0
  overview.mapSize = config.mapSize or OVERVIEW_MAP_SIZE

  -- Map texture
  overview.mapTexture = config.mapTexture or nil

  -- View settings
  overview.zoom = config.zoom or 1.0
  overview.fullZoom = config.fullZoom or 1.0
  overview.followAngle = config.followAngle or false
  overview.rotateMap = config.rotateMap or false
  overview.viewAngle = 0

  -- Rendering mode
  overview.renderCircular = config.renderCircular or false
  overview.playerCenteredRotation = config.playerCenteredRotation or false

  -- Center of the map view (in map coordinates, not world)
  overview.mapCenter = Vector(overview.mapSize / 2, overview.mapSize / 2, 0)

  -- Panel dimensions (will be set when drawing)
  overview.panelWidth = 512
  overview.panelHeight = 512

  -- Screen offset (position where the map is drawn)
  overview.screenOffsetX = 0
  overview.screenOffsetY = 0

  return overview
end

--- Converts a world position to map coordinates.
--- @param worldPos Vector World position vector.
--- @return number, number # Map X and Y coordinates.
function MAP_OVERVIEW_META:WorldToMap(worldPos)
  -- Calculate offset from map origin
  local offsetX = worldPos.x - self.mapOrigin.x
  local offsetY = worldPos.y - self.mapOrigin.y

  -- Scale to map coordinates
  -- Note: Y is inverted in Source Engine (negative scale)
  local mapX = offsetX / self.mapScale
  local mapY = offsetY / -self.mapScale

  return mapX, mapY
end

--- Converts map coordinates back to world position.
--- @param mapX number Map X coordinate.
--- @param mapY number Map Y coordinate.
--- @return Vector # World position vector.
function MAP_OVERVIEW_META:MapToWorld(mapX, mapY)
  -- Inverse of WorldToMap calculation
  local worldX = (mapX * self.mapScale) + self.mapOrigin.x
  local worldY = (mapY * -self.mapScale) + self.mapOrigin.y

  return Vector(worldX, worldY, 0)
end

--- Gets the current view angle for rendering.
--- @return number # View angle in degrees.
function MAP_OVERVIEW_META:GetViewAngle()
  local viewAngle = self.viewAngle - 90.0

  if not self.followAngle then
    if self.rotateMap then
      viewAngle = 90.0
    else
      viewAngle = 0.0
    end
  end

  -- Player-centered rotation: invert the angle to rotate map around player
  if self.playerCenteredRotation then
    viewAngle = -viewAngle
  end

  return viewAngle
end

--- Rotates a 2D vector by a yaw angle.
--- @param x number Input X coordinate.
--- @param y number Input Y coordinate.
--- @param angle number Rotation angle in degrees.
--- @return number, number # Rotated X and Y coordinates.
local function VectorYawRotate(x, y, angle)
  local radians = math.rad(angle)
  local cosAngle = math.cos(radians)
  local sinAngle = math.sin(radians)

  local newX = x * cosAngle - y * sinAngle
  local newY = x * sinAngle + y * cosAngle

  return newX, newY
end

--- Converts map coordinates to panel/screen coordinates.
--- @param mapX number Map X coordinate.
--- @param mapY number Map Y coordinate.
--- @return number, number # Panel/screen X and Y coordinates.
function MAP_OVERVIEW_META:MapToPanel(mapX, mapY)
  local viewAngle = self:GetViewAngle()

  -- Calculate offset from map center
  local offsetX = mapX - self.mapCenter.x
  local offsetY = mapY - self.mapCenter.y

  -- Apply rotation
  offsetX, offsetY = VectorYawRotate(offsetX, offsetY, viewAngle)

  -- Calculate scale factor (combines zoom and map size)
  local scale = (self.zoom * self.fullZoom) / self.mapSize

  -- Apply scale to offsets
  offsetX = offsetX * scale
  offsetY = offsetY * scale

  -- Convert to panel coordinates (centered)
  local panelX = (self.panelWidth * 0.5) + (self.panelHeight * offsetX)
  local panelY = (self.panelHeight * 0.5) + (self.panelHeight * offsetY)

  return panelX, panelY
end

--- Converts world position to panel coordinates.
--- @param worldPos Vector World position vector.
--- @return number, number # Panel/screen X and Y coordinates.
function MAP_OVERVIEW_META:WorldToPanel(worldPos)
  local mapX, mapY = self:WorldToMap(worldPos)
  return self:MapToPanel(mapX, mapY)
end

--- Sets the panel dimensions for rendering.
--- @param width number Panel width in pixels.
--- @param height number Panel height in pixels.
function MAP_OVERVIEW_META:SetPanelSize(width, height)
  self.panelWidth = width
  self.panelHeight = height
end

--- Gets the panel dimensions for rendering.
--- @return number, number # Panel width and height in pixels.
function MAP_OVERVIEW_META:GetPanelSize()
  return self.panelWidth, self.panelHeight
end

--- Sets the center of the map view using map coordinates.
--- @param mapX number Map X coordinate.
--- @param mapY number Map Y coordinate.
function MAP_OVERVIEW_META:SetCenter(mapX, mapY)
  self.mapCenter.x = mapX
  self.mapCenter.y = mapY

  -- Apply boundaries (prevents viewing outside map)
  local halfSize = self.mapSize / (self.zoom * self.fullZoom * 2)

  if self.mapCenter.x < halfSize then
    self.mapCenter.x = halfSize
  end

  if self.mapCenter.x > (self.mapSize - halfSize) then
    self.mapCenter.x = self.mapSize - halfSize
  end

  if self.mapCenter.y < halfSize then
    self.mapCenter.y = halfSize
  end

  if self.mapCenter.y > (self.mapSize - halfSize) then
    self.mapCenter.y = self.mapSize - halfSize
  end

  -- Center if fully zoomed out
  if self.zoom <= 1.0 then
    self.mapCenter.x = self.mapSize / 2
    self.mapCenter.y = self.mapSize / 2
  end
end

--- Sets the center of the map view using world coordinates.
--- @param worldPos Vector World position vector.
function MAP_OVERVIEW_META:SetCenterWorld(worldPos)
  local mapX, mapY = self:WorldToMap(worldPos)
  self:SetCenter(mapX, mapY)
end

--- Sets the view angle for rendering.
--- @param angle number Angle in degrees.
function MAP_OVERVIEW_META:SetAngle(angle)
  self.viewAngle = angle
end

--- Sets the zoom level.
--- @param zoom number Zoom factor.
function MAP_OVERVIEW_META:SetZoom(zoom)
  self.zoom = zoom
end

--- Sets whether to render as a circular mini-map.
--- @param circular boolean True to render as circle, false for square.
function MAP_OVERVIEW_META:SetCircular(circular)
  self.renderCircular = circular
end

--- Sets whether to use player-centered rotation.
--- @param centered boolean True to rotate map around player, false to rotate player around map.
function MAP_OVERVIEW_META:SetPlayerCenteredRotation(centered)
  self.playerCenteredRotation = centered
end

--- Draws the map texture to the screen.
--- @param x number Screen X position.
--- @param y number Screen Y position.
--- @param width? number Render width, defaults to panel width.
--- @param height? number Render height, defaults to panel height.
function MAP_OVERVIEW_META:DrawMapTexture(x, y, width, height)
  if not self.mapTexture then
    return
  end

  -- Store screen offset for other drawing functions
  self.screenOffsetX = x
  self.screenOffsetY = y

  width, height = width or self.panelWidth, height or self.panelHeight

  -- Update panel size
  self:SetPanelSize(width, height)

  if self.renderCircular then
    self:DrawMapTextureCircular(x, y, width, height)
  else
    self:DrawMapTextureSquare(x, y, width, height)
  end
end

--- Draws the map texture as a circular mini-map.
--- @param x number Screen X position.
--- @param y number Screen Y position.
--- @param width? number Render width, defaults to panel width.
--- @param height? number Render height, defaults to panel height.
function MAP_OVERVIEW_META:DrawMapTextureCircular(x, y, width, height)
  width, height = width or self.panelWidth, height or self.panelHeight

  local radius = math.min(width, height) / 2
  local centerX = x + width / 2
  local centerY = y + height / 2
  local segments = 64 -- Number of segments for circle approximation

  local corners = {
    { 0,                0 },
    { self.mapSize - 1, 0 },
    { self.mapSize - 1, self.mapSize - 1 },
    { 0,                self.mapSize - 1 }
  }

  -- Convert corners to panel coordinates
  local cornerVertices = {}
  for i, corner in ipairs(corners) do
    local panelX, panelY = self:MapToPanel(corner[1], corner[2])
    cornerVertices[i] = {
      x = x + panelX,
      y = y + panelY,
      u = (i == 1 or i == 4) and 0 or 1,
      v = (i == 1 or i == 2) and 0 or 1
    }
  end

  -- Enable stencil to clip to circle
  render.ClearStencil()
  render.SetStencilEnable(true)
  render.SetStencilTestMask(0xFF)
  render.SetStencilWriteMask(0xFF)
  render.SetStencilReferenceValue(1)

  -- Write circle mask to stencil
  render.SetStencilCompareFunction(STENCIL_ALWAYS)
  render.SetStencilPassOperation(STENCIL_REPLACE)
  render.SetStencilFailOperation(STENCIL_KEEP)
  render.SetStencilZFailOperation(STENCIL_KEEP)

  -- Draw circle mask
  local circleVertices = {}
  for i = 0, segments do
    local angle = (i / segments) * math.pi * 2
    table.insert(circleVertices, {
      x = centerX + math.cos(angle) * radius,
      y = centerY + math.sin(angle) * radius
    })
  end

  surface.SetDrawColor(255, 255, 255, 255)
  draw.NoTexture()
  surface.DrawPoly(circleVertices)

  -- Only draw where stencil = 1
  render.SetStencilCompareFunction(STENCIL_EQUAL)
  render.SetStencilPassOperation(STENCIL_KEEP)

  -- Draw textured polygon (clipped to circle)
  if (isnumber(self.mapTexture)) then
    surface.SetTexture(self.mapTexture)
  else
    surface.SetMaterial(self.mapTexture)
  end

  surface.SetDrawColor(255, 255, 255, 255)
  surface.DrawPoly(cornerVertices)

  -- Disable stencil
  render.SetStencilEnable(false)

  -- Draw circle border (optional)
  surface.SetDrawColor(0, 0, 0, 200)
  draw.NoTexture()
  for i = 0, segments do
    local angle1 = (i / segments) * math.pi * 2
    local angle2 = ((i + 1) / segments) * math.pi * 2
    local x1 = centerX + math.cos(angle1) * radius
    local y1 = centerY + math.sin(angle1) * radius
    local x2 = centerX + math.cos(angle2) * radius
    local y2 = centerY + math.sin(angle2) * radius
    surface.DrawLine(x1, y1, x2, y2)
  end
end

--- Draws the map texture as a square (original behavior).
--- @param x number Screen X position.
--- @param y number Screen Y position.
--- @param width? number Render width, defaults to panel width.
--- @param height? number Render height, defaults to panel height.
function MAP_OVERVIEW_META:DrawMapTextureSquare(x, y, width, height)
  width, height = width or self.panelWidth, height or self.panelHeight

  local corners = {
    { 0,                0 },
    { self.mapSize - 1, 0 },
    { self.mapSize - 1, self.mapSize - 1 },
    { 0,                self.mapSize - 1 }
  }

  -- Convert corners to panel coordinates
  local vertices = {}
  for i, corner in ipairs(corners) do
    local panelX, panelY = self:MapToPanel(corner[1], corner[2])
    vertices[i] = {
      x = x + panelX,
      y = y + panelY,
      u = (i == 1 or i == 4) and 0 or 1,
      v = (i == 1 or i == 2) and 0 or 1
    }
  end

  -- Draw textured polygon
  if (isnumber(self.mapTexture)) then
    surface.SetTexture(self.mapTexture)
  else
    surface.SetMaterial(self.mapTexture)
  end

  surface.SetDrawColor(255, 255, 255, 255)
  surface.DrawPoly(vertices)
end

--- Draws a point on the map.
--- @param worldPos Vector World position vector.
--- @param color Color Optional. Point color.
--- @param size number Optional. Point size in pixels.
function MAP_OVERVIEW_META:DrawPoint(worldPos, color, size)
  color = color or Color(255, 0, 0, 255)
  size = size or 4

  local panelX, panelY = self:WorldToPanel(worldPos)

  -- Apply screen offset
  panelX = panelX + self.screenOffsetX
  panelY = panelY + self.screenOffsetY

  surface.SetDrawColor(color)
  surface.DrawRect(panelX - size / 2, panelY - size / 2, size, size)
end

--- Draws a player icon on the map.
--- @param worldPos Vector World position vector.
--- @param angle number Player yaw angle.
--- @param color Color Optional. Icon color.
--- @param size number Optional. Icon size.
function MAP_OVERVIEW_META:DrawPlayerIcon(worldPos, angle, color, size)
  color = color or Color(255, 255, 255, 255)
  size = size or 16

  local panelX, panelY = self:WorldToPanel(worldPos)

  -- Apply screen offset
  panelX = panelX + self.screenOffsetX
  panelY = panelY + self.screenOffsetY

  -- Calculate icon rotation (relative to view angle)
  -- In Source SDK: fAngle = (pPlayer->GetAngle() - m_fMapYaw) * -1
  local iconAngle = -(angle - self:GetViewAngle())

  -- Draw a simple triangle pointing in the direction
  local rad = math.rad(iconAngle)
  local points = {
    { x = panelX + math.cos(rad) * size,           y = panelY + math.sin(rad) * size },
    { x = panelX + math.cos(rad + 2) * size * 0.5, y = panelY + math.sin(rad + 2) * size * 0.5 },
    { x = panelX + math.cos(rad - 2) * size * 0.5, y = panelY + math.sin(rad - 2) * size * 0.5 }
  }

  surface.SetDrawColor(color)
  draw.NoTexture()
  surface.DrawPoly(points)
end

--- Checks if map coordinates are within the visible panel area.
--- @param mapX number Map X coordinate.
--- @param mapY number Map Y coordinate.
--- @return boolean # True if visible.
function MAP_OVERVIEW_META:IsInPanel(mapX, mapY)
  local panelX, panelY = self:MapToPanel(mapX, mapY)
  return panelX >= 0 and panelX < self.panelWidth and panelY >= 0 and panelY < self.panelHeight
end

local mapTexture = Material("versus/map_overviews/exp_c18_v1.png")

concommand.Add("versus_test_map_overview", function()
  if (not LocalPlayer():IsSuperAdmin()) then
    return
  end

  local overview = UNIT.new({
    scale = 12,
    pos_x = -5314,
    pos_y = 6662,
    mapTexture = mapTexture,
    mapSize = 1024,
    zoom = 1.0,
    followAngle = false,
    rotateMap = false
  })

  -- Example usage: Draw the map in a HUDPaint hook
  hook.Add("HUDPaint", "DrawMapOverview", function()
    overview:DrawMapTexture(110, 110, 512, 512)

    -- Draw a test point
    local testWorldPos = Vector(0, 0, 0)
    overview:DrawPoint(testWorldPos, Color(0, 255, 0, 255), 8)

    -- Draw a test player icon
    local playerWorldPos = LocalPlayer():GetPos()
    local playerAngle = LocalPlayer():EyeAngles().yaw
    overview:DrawPlayerIcon(playerWorldPos, playerAngle, Color(255, 255, 0, 255), 8)
  end)
end)

-- Example: Circular mini-map with player-centered rotation
concommand.Add("versus_test_circular_minimap", function()
  if (not LocalPlayer():IsSuperAdmin()) then
    return
  end

  local keepMinimapStatic = true
  local minimap = UNIT.new({
    scale = 12,
    pos_x = -5314,
    pos_y = 6662,
    mapTexture = mapTexture,
    mapSize = 1024,
    zoom = 2.0,
    followAngle = not keepMinimapStatic,
    renderCircular = true,
    playerCenteredRotation = keepMinimapStatic
  })

  hook.Add("HUDPaint", "DrawCircularMinimap", function()
    local player = LocalPlayer()
    local playerPos = player:GetPos()
    local playerAngle = player:EyeAngles().yaw

    -- Update map to follow player
    minimap:SetAngle(playerAngle)
    minimap:SetCenterWorld(playerPos)

    -- Draw circular mini-map in corner
    local size = 250
    local spacing = GAMEMODE.SPACING
    local x = ScrW() - (size + spacing)
    local y = spacing
    minimap:DrawMapTexture(x, y, size, size)

    -- Draw player icon (should always be in center when player-centered)
    minimap:DrawPlayerIcon(playerPos, playerAngle, Color(255, 255, 0, 255), 16)

    local PULSE_SPEED = 1
    local glowSize = (size * .5) + (math.sin(CurTime() * PULSE_SPEED) * 4)
    draw.NoTexture()

    -- Static thick black transparent ring
    surface.SetDrawColor(0, 0, 0, 200)
    GAMEMODE:DrawOutlinedCircle(
      x + (size / 2),
      y + (size / 2),
      size * .5,
      25
    )

    -- Soft outer glow (faint blue)
    for i = 3, 1, -1 do
      local alpha = 15 * i
      surface.SetDrawColor(0, 150, 255, alpha)
      GAMEMODE:DrawOutlinedCircle(
        x + (size / 2),
        y + (size / 2),
        glowSize + (i * 4),
        2
      )
    end

    -- Main bright glow ring
    surface.SetDrawColor(0, 200, 255, 120)
    GAMEMODE:DrawOutlinedCircle(
      x + (size / 2),
      y + (size / 2),
      glowSize + 2,
      3
    )

    -- Core bright outline
    surface.SetDrawColor(100, 220, 255, 200)
    GAMEMODE:DrawOutlinedCircle(
      x + (size / 2),
      y + (size / 2),
      glowSize,
      2
    )

    -- Inner accent line (cyan)
    surface.SetDrawColor(150, 255, 255, 180)
    GAMEMODE:DrawOutlinedCircle(
      x + (size / 2),
      y + (size / 2),
      glowSize - 2,
      1
    )

    -- Optional: Dark inner border for contrast
    surface.SetDrawColor(0, 0, 0, 150)
    GAMEMODE:DrawOutlinedCircle(
      x + (size / 2),
      y + (size / 2),
      glowSize - 4,
      1
    )
  end)
end)
