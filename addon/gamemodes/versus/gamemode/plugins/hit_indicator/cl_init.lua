local PLUGIN = PLUGIN

PLUGIN.hitIndicators = PLUGIN.hitIndicators or {}

-- Create a new hit indicator
function PLUGIN.createHitIndicator(damage, isHeadshot, isCritical, isKill, worldPos)
  local indicator = {
    damage = math.Round(damage),
    isHeadshot = isHeadshot,
    isCritical = isCritical,
    isKill = isKill,
    worldPos = worldPos,
    startTime = CurTime(),
    lifetime = 1.5,
    alpha = 255,
    offsetX = math.random(-30, 30),
    offsetY = math.random(-20, 20),
  }

  table.insert(PLUGIN.hitIndicators, indicator)
end

-- Clean up old indicators
function PLUGIN.cleanupHitIndicators()
  for i = #PLUGIN.hitIndicators, 1, -1 do
    local indicator = PLUGIN.hitIndicators[i]
    local elapsed = CurTime() - indicator.startTime

    if elapsed >= indicator.lifetime then
      table.remove(PLUGIN.hitIndicators, i)
    end
  end
end

-- Draw all hit indicators
function PLUGIN.hook:HUDPaint()
  PLUGIN.cleanupHitIndicators()

  for _, indicator in ipairs(PLUGIN.hitIndicators) do
    PLUGIN.drawHitIndicator(indicator)
  end
end

-- Draw a single hit indicator
function PLUGIN.drawHitIndicator(indicator)
  local elapsed = CurTime() - indicator.startTime
  local progress = math.Clamp(elapsed / indicator.lifetime, 0, 1)

  -- Convert world position to screen position
  local screenPos = indicator.worldPos:ToScreen()

  if not screenPos.visible then return end

  -- Animation: rise up and fade out
  local riseDistance = 80
  local animY = math.ease.OutCubic(progress) * riseDistance

  -- Alpha fade out in last 30% of lifetime
  local alpha = 255
  if progress > 0.7 then
    alpha = 255 * (1 - ((progress - 0.7) / 0.3))
  end

  -- Cross indicator fades twice as fast (fully gone by 50% of lifetime)
  local crossAlpha = math.Clamp(255 * (1 - progress * 2), 0, 255)

  -- Scale animation: pop in, then slight shrink
  local scale = 1
  if progress < 0.15 then
    scale = math.ease.OutBack(progress / 0.15)
  else
    scale = 1 - (progress * 0.1)
  end

  local x = screenPos.x + indicator.offsetX
  local y = screenPos.y + indicator.offsetY - animY

  -- Determine color based on hit type
  local color = Color(220, 230, 240, alpha)
  local accentColor = Color(141, 153, 174, alpha)

  if indicator.isKill then
    color = Color(242, 95, 92, alpha) -- Red for kills
    accentColor = Color(255, 100, 100, alpha)
  elseif indicator.isHeadshot then
    color = Color(255, 224, 102, alpha) -- Yellow for headshots
    accentColor = Color(255, 200, 80, alpha)
  elseif indicator.isCritical then
    color = Color(235, 94, 40, alpha) -- Orange for crits
    accentColor = Color(255, 120, 60, alpha)
  end

  -- Draw 4 diagonal arms around the screen-center crosshair (gap in the middle)
  local cx = ScrW() / 2
  local cy = ScrH() / 2

  local gap = 32 * scale
  local armLen = 16 * scale
  local hw = 1 * scale

  local function drawArm(dx, dy)
    local px, py = -dy, dx -- perpendicular to direction
    local ax = cx + dx * gap
    local ay = cy + dy * gap
    local bx = cx + dx * (gap + armLen)
    local by = cy + dy * (gap + armLen)
    surface.DrawPoly({
      { x = ax + px * hw, y = ay + py * hw },
      { x = ax - px * hw, y = ay - py * hw },
      { x = bx - px * hw, y = by - py * hw },
      { x = bx + px * hw, y = by + py * hw },
    })
  end

  local d = 0.7071 -- 1/sqrt(2)
  draw.NoTexture()
  surface.SetDrawColor(color.r, color.g, color.b, crossAlpha)
  drawArm(d, -d)  -- top-right
  drawArm(-d, -d) -- top-left
  drawArm(d, d)   -- bottom-right
  drawArm(-d, d)  -- bottom-left

  -- Draw with scale
  local matrix = Matrix()
  matrix:Translate(Vector(x, y, 0))
  matrix:Scale(Vector(scale, scale, 1))
  matrix:Translate(Vector(-x, -y, 0))

  cam.PushModelMatrix(matrix)

  -- Draw damage number
  local damageText = tostring(indicator.damage)
  local font = "VersusHeading2"

  if indicator.isKill or indicator.isHeadshot then
    font = "VersusHeading1"
  end

  surface.SetFont(font)
  local textW, textH = surface.GetTextSize(damageText)

  -- Shadow for depth
  draw.SimpleText(
    damageText,
    font,
    x + 2,
    y + 2,
    Color(0, 0, 0, alpha * 0.6),
    TEXT_ALIGN_CENTER,
    TEXT_ALIGN_CENTER
  )

  -- Main damage number
  draw.SimpleText(
    damageText,
    font,
    x,
    y,
    color,
    TEXT_ALIGN_CENTER,
    TEXT_ALIGN_CENTER
  )

  -- Label for special hits
  if indicator.isKill then
    surface.SetFont("VersusDefault")
    local labelW, labelH = surface.GetTextSize("ELIMINATED")

    draw.SimpleText(
      "ELIMINATED",
      "VersusDefault",
      x,
      y + textH / 2 + 8,
      accentColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
  elseif indicator.isHeadshot then
    surface.SetFont("VersusDefault")
    local labelW, labelH = surface.GetTextSize("HEADSHOT")

    draw.SimpleText(
      "HEADSHOT",
      "VersusDefault",
      x,
      y + textH / 2 + 8,
      accentColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
  elseif indicator.isCritical then
    surface.SetFont("VersusDefault")
    local labelW, labelH = surface.GetTextSize("CRITICAL")

    draw.SimpleText(
      "CRITICAL",
      "VersusDefault",
      x,
      y + textH / 2 + 8,
      accentColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
  end

  cam.PopModelMatrix()
end

--- Plays addon/sound/versus/impact.wav, with different pitch and volume based on hit type
--- This is bearably hearable over gun shots, but I'll leave it in anyway.
function PLUGIN.playHitImpactSound(isKill, isHeadshot, isCritical)
  local soundPath = "versus/impact.wav"
  local pitch = 100
  local volume = 0.5

  if isKill then
    pitch = 120
    volume = 1
  elseif isHeadshot then
    pitch = 110
    volume = 0.9
  elseif isCritical then
    pitch = 115
    volume = 0.8
  end

  local sound = CreateSound(LocalPlayer(), soundPath)
  sound:PlayEx(volume, pitch)
end

--[[
  Net Messages
--]]

net.Receive("versus.hitindicator.showHit", function()
  local damage = net.ReadFloat()
  local isHeadshot = net.ReadBool()
  local isCritical = net.ReadBool()
  local isKill = net.ReadBool()
  local worldPos = net.ReadVector()

  PLUGIN.createHitIndicator(damage, isHeadshot, isCritical, isKill, worldPos)

  PLUGIN.playHitImpactSound(isKill, isHeadshot, isCritical)
end)
