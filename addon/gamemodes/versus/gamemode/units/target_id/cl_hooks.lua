local UNIT = UNIT

-- Configuration
local MAX_DISTANCE = 512          -- Maximum distance to show entity info
local VIEW_CONE_DOT = 0.8         -- How much the player needs to be looking at it (lower = wider cone)
local VIEW_CONE_FADE_START = 0.75 -- Angle where fade-in begins (should be less than VIEW_CONE_DOT)
local FADE_DISTANCE = 400         -- Distance where fade starts
local LINE_THICKNESS = 2
local DOT_RADIUS = 4

-- Colors
local TEXT_COLOR = Color(220, 230, 240, 255)
local DESCRIPTION_COLOR = Color(141, 153, 174, 255)

-- Active entity info
local activeEntityInfo = {}

-- Test if any of 3 parts of the entity are visible (so we show their info through narrow horizontal gaps)
local function canSeeAnyPartOfEntity(ent)
  if not IsValid(ent) then
    return false
  end

  local eyePos = LocalPlayer():EyePos()
  local mins, maxs = ent:GetCollisionBounds()
  local entPos = ent:GetPos()

  -- Hull half-extents: match the entity's width/depth but keep it slim vertically
  -- so we don't punch through floors. We shrink it a bit to avoid false positives
  -- on geometry that barely grazes the hull.
  local hullPad = Vector(
    math.abs(mins.x) * 0.5,
    math.abs(mins.y) * 0.5,
    0
  )

  local trace = util.TraceHull({
    start  = eyePos,
    endpos = ent:WorldSpaceCenter(),
    mins   = -hullPad,
    maxs   = hullPad,
    filter = LocalPlayer(),
    mask   = MASK_SHOT
  })

  if trace.Entity == ent then
    return true
  end

  -- Fallback point tests at bottom and top of collision bounds,
  -- in case the hull center trace misses a partially-visible entity
  -- (e.g. only their feet or head peek around a corner)
  local testPoints = {
    entPos + Vector(0, 0, mins.z * 0.6),
    entPos + Vector(0, 0, maxs.z * 0.6),
  }

  for _, point in ipairs(testPoints) do
    local tr = util.TraceLine({
      start  = eyePos,
      endpos = point,
      filter = LocalPlayer(),
      mask   = MASK_SHOT
    })
    if tr.Entity == ent then
      return true
    end
  end

  return false
end

-- Get all entities that support OnPopulateEntityInfo
local function getInfoEntities()
  local entities = {}

  for _, ent in ipairs(ents.FindInSphere(LocalPlayer():GetPos(), MAX_DISTANCE)) do
    local isVisible = canSeeAnyPartOfEntity(ent)
    if (IsValid(ent) and isVisible and (ent.OnPopulateEntityInfo or hook.Run("CanPopulateEntityInfo", ent))) then
      table.insert(entities, ent)
    end
  end

  return entities
end

-- Check if player is looking at entity (within cone)
-- Returns: isLooking (bool), dotProduct (number)
local function isLookingAt(ply, ent)
  local eyePos = ply:EyePos()
  local eyeAngles = ply:EyeAngles()
  local entPos = ent:WorldSpaceCenter()

  -- Get direction to entity
  local toEntity = (entPos - eyePos):GetNormalized()
  local lookDir = eyeAngles:Forward()

  -- Check dot product (cosine of angle)
  local dot = lookDir:Dot(toEntity)

  return dot >= VIEW_CONE_FADE_START, dot
end

-- Calculate alpha based on view cone angle
local function calculateViewConeAlpha(dotProduct)
  if dotProduct >= VIEW_CONE_DOT then
    return 1.0 -- Full visibility
  end

  if dotProduct <= VIEW_CONE_FADE_START then
    return 0.0 -- Not visible
  end

  -- Fade between VIEW_CONE_FADE_START and VIEW_CONE_DOT
  local fadeRange = VIEW_CONE_DOT - VIEW_CONE_FADE_START
  local fadeAmount = (dotProduct - VIEW_CONE_FADE_START) / fadeRange

  return math.Clamp(fadeAmount, 0, 1)
end

-- Calculate alpha fraction based on distance (returns 0-1)
local function calculateAlpha(distance)
  if distance >= MAX_DISTANCE then
    return 0
  end

  if distance <= FADE_DISTANCE then
    return 1.0
  end

  -- Fade between FADE_DISTANCE and MAX_DISTANCE
  local fadeRange = MAX_DISTANCE - FADE_DISTANCE
  local fadeAmount = (MAX_DISTANCE - distance) / fadeRange

  return math.Clamp(fadeAmount, 0, 1)
end

-- Update active entity info
local function updateEntityInfo()
  local ply = LocalPlayer()

  if not IsValid(ply) then
    return
  end

  activeEntityInfo = {}

  local eyePos = ply:EyePos()
  local infoEnts = getInfoEntities()

  for _, ent in ipairs(infoEnts) do
    if IsValid(ent) then
      local entPos = ent:GetPos()
      local distance = eyePos:Distance(entPos)

      -- Check distance and view cone
      local isLooking, dotProduct = isLookingAt(ply, ent)

      if distance <= MAX_DISTANCE and isLooking then
        -- Create info object
        local info = UNIT:createEntityInfo()

        -- Let the entity populate the info or let the hook do it
        if ent.OnPopulateEntityInfo then
          ent:OnPopulateEntityInfo(info)
        else
          hook.Run("OnPopulateEntityInfo", ent, info)
        end

        -- Only add if it has content
        if info:hasContent() then
          table.insert(activeEntityInfo, {
            entity = ent,
            info = info,
            distance = distance,
            dotProduct = dotProduct
          })
        end
      end
    end
  end

  -- Sort by distance (closest first)
  table.sort(activeEntityInfo, function(a, b)
    return a.distance < b.distance
  end)
end

-- Draw entity info panel
local function drawInfoPanel(info, screenPos, alphaFraction)
  local padding = 12
  local rowSpacing = 0

  -- Calculate panel dimensions
  local contentHeight = 0
  local actualWidth = 0

  surface.SetFont("VersusDefault")

  -- Title
  local titleHeight = 0
  if info.title then
    surface.SetFont("VersusHeading3")
    local titleW, titleH = surface.GetTextSize(info.title)
    titleHeight = titleH + rowSpacing * 2
    contentHeight = contentHeight + titleHeight
    actualWidth = math.max(actualWidth, titleW)
  end

  -- Descriptions
  surface.SetFont("VersusDefault")
  for _, desc in ipairs(info.descriptions) do
    local descW, descH = surface.GetTextSize(desc)
    contentHeight = contentHeight + descH + rowSpacing
    actualWidth = math.max(actualWidth, descW)
  end

  -- Rows
  for _, row in ipairs(info.rows) do
    local rowW, rowH = surface.GetTextSize(row.text)
    contentHeight = contentHeight + rowH + rowSpacing
    actualWidth = math.max(actualWidth, rowW)
  end

  -- Panel dimensions (add padding and accent line width)
  local panelWidth = actualWidth + (padding * 2) + 4
  local panelHeight = contentHeight + (padding * 2)

  local panelX = screenPos.x + GAMEMODE.SPACING
  local panelY = screenPos.y - panelHeight - GAMEMODE.SPACING

  -- Keep panel on screen
  if panelX + panelWidth > ScrW() then
    panelX = ScrW() - panelWidth - 10
  end
  if panelX < 10 then
    panelX = 10
  end
  if panelY < 10 then
    panelY = screenPos.y + GAMEMODE.SPACING
  end

  -- Draw background
  local bgColor = ColorAlpha(color_background, color_background.a * alphaFraction)
  surface.SetDrawColor(bgColor)
  surface.DrawRect(panelX, panelY, panelWidth, panelHeight)

  -- Draw accent line
  local accentColor = ColorAlpha(info.accentColor, info.accentColor.a * alphaFraction)
  surface.SetDrawColor(accentColor)
  surface.DrawRect(panelX, panelY, 4, panelHeight)

  -- Draw content
  local yOffset = panelY + padding

  -- Title
  if info.title then
    surface.SetFont("VersusHeading3")
    local titleW, titleH = surface.GetTextSize(info.title)
    surface.SetTextColor(ColorAlpha(TEXT_COLOR, TEXT_COLOR.a * alphaFraction))
    surface.SetTextPos(panelX + padding + 4, yOffset)
    surface.DrawText(info.title)
    yOffset = yOffset + titleH + rowSpacing * 2
  end

  -- Descriptions
  surface.SetFont("VersusDefault")
  for _, desc in ipairs(info.descriptions) do
    local descW, descH = surface.GetTextSize(desc)
    surface.SetTextColor(ColorAlpha(DESCRIPTION_COLOR, DESCRIPTION_COLOR.a * alphaFraction))
    surface.SetTextPos(panelX + padding + 4, yOffset)
    surface.DrawText(desc)
    yOffset = yOffset + descH + rowSpacing
  end

  -- Rows
  for _, row in ipairs(info.rows) do
    local rowW, rowH = surface.GetTextSize(row.text)
    local rowColor = row.color or DESCRIPTION_COLOR
    surface.SetTextColor(ColorAlpha(rowColor, rowColor.a * alphaFraction))
    surface.SetTextPos(panelX + padding + 4, yOffset)
    surface.DrawText(row.text)
    yOffset = yOffset + rowH + rowSpacing
  end

  return panelX, panelY, panelWidth, panelHeight
end

-- Main render hook
function UNIT.hook:HUDPaint()
  if not IsValid(LocalPlayer()) then
    return
  end

  if (not LocalPlayer():Alive() or LocalPlayer():GetNWBool("versus_KnockedOut")) then
    return
  end

  for _, data in ipairs(activeEntityInfo) do
    local ent = data.entity
    local info = data.info
    local distance = data.distance
    local dotProduct = data.dotProduct

    if IsValid(ent) then
      local entPos

      -- If we find a spine bone, use that for better positioning
      local spineBone = ent:LookupBone("ValveBiped.Bip01_L_UpperArm")
          -- For vortigaunts
          or ent:LookupBone("ValveBiped.spine4")
      if spineBone then
        entPos = ent:GetBonePosition(spineBone)
      else
        entPos = ent:WorldSpaceCenter()
      end

      local screenPos = entPos:ToScreen()

      if screenPos.visible then
        -- Combine distance fade and view cone fade (both are now fractions 0-1)
        local distanceAlpha = calculateAlpha(distance)
        local viewConeAlpha = calculateViewConeAlpha(dotProduct)
        local alphaFraction = distanceAlpha * viewConeAlpha

        if alphaFraction > 0.02 then -- Threshold as fraction (was 5/255 ≈ 0.02)
          -- Draw info panel
          local panelX, panelY, panelW, panelH = drawInfoPanel(info, screenPos, alphaFraction)

          -- Calculate connection point (center of left edge of panel)
          local connectionX = panelX
          local connectionY = panelY + (panelH / 2)

          -- Draw line from entity to panel (multiply accent color's alpha by fraction * 0.8)
          local lineColor = ColorAlpha(info.accentColor, info.accentColor.a * alphaFraction * 0.8)

          surface.SetDrawColor(lineColor)
          for i = -LINE_THICKNESS / 2, LINE_THICKNESS / 2 do
            surface.DrawLine(
              screenPos.x + i, screenPos.y,
              connectionX, connectionY + i
            )
          end

          -- Draw dot at entity position (multiply accent color's alpha by fraction)
          local dotColor = ColorAlpha(info.accentColor, info.accentColor.a * alphaFraction)
          surface.SetDrawColor(dotColor)
          GAMEMODE:DrawCircle(screenPos.x, screenPos.y, DOT_RADIUS)
        end
      end
    end
  end
end

-- Update entity info periodically
local nextUpdate = 0
function UNIT.hook:Think()
  if CurTime() >= nextUpdate then
    updateEntityInfo()
    nextUpdate = CurTime() + 0.1 -- Update 10 times per second
  end
end
