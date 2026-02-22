local PLUGIN = PLUGIN

local NOTICE_LIFETIME = 6
local NOTICE_FADE_IN = 0.3
local NOTICE_FADE_OUT = 0.5
local NOTICE_HEIGHT = 28
local NOTICE_SPACING = 4
local NOTICE_PADDING_X = 10
local NOTICE_ICON_PADDING = 8
local NOTICE_MAX = 5

-- Target display height for kill icons so they fit neatly in a notice row
local ICON_DISPLAY_HEIGHT = NOTICE_HEIGHT - 8

PLUGIN.killNotices = PLUGIN.killNotices or {}

local function addKillNotice(attackerName, isAttackerPlayer, victimName, inflictorClass)
  table.insert(PLUGIN.killNotices, {
    attackerName = attackerName,
    isAttackerPlayer = isAttackerPlayer,
    victimName = victimName,
    inflictorClass = inflictorClass,
    startTime = CurTime(),
  })

  -- Keep only the most recent notices
  while #PLUGIN.killNotices > NOTICE_MAX do
    table.remove(PLUGIN.killNotices, 1)
  end
end

local function getNoticeAlpha(notice)
  local elapsed = CurTime() - notice.startTime

  if elapsed < NOTICE_FADE_IN then
    return 255 * (elapsed / NOTICE_FADE_IN), elapsed
  elseif elapsed > NOTICE_LIFETIME - NOTICE_FADE_OUT then
    return 255 * ((NOTICE_LIFETIME - elapsed) / NOTICE_FADE_OUT), elapsed
  end

  return 255, elapsed
end

-- Draw a single kill notice centered at (centerX, y)
local function drawKillNotice(notice, centerX, y, alpha)
  local font = "VersusDefault"
  surface.SetFont(font)

  local attackerW = surface.GetTextSize(notice.attackerName)
  local victimW = surface.GetTextSize(notice.victimName)

  -- Determine kill icon dimensions, scaling to fit the notice height
  local iconW = 0
  local iconScaleX = 1
  local iconScaleY = 1
  local rawIconW, rawIconH = 0, 0

  if notice.inflictorClass ~= "" then
    rawIconW, rawIconH = killicon.GetSize(notice.inflictorClass)

    if rawIconW and rawIconH and rawIconW > 0 and rawIconH > 0 then
      local scale = ICON_DISPLAY_HEIGHT / rawIconH
      iconW = rawIconW * scale
      iconScaleX = scale
      iconScaleY = scale
    end
  end

  local iconGap = (iconW > 0) and NOTICE_ICON_PADDING or 0
  local totalW = NOTICE_PADDING_X + attackerW + iconGap + iconW + iconGap + victimW + NOTICE_PADDING_X

  local bgX = centerX - totalW / 2
  local bgY = y

  -- Semi-transparent dark background
  surface.SetDrawColor(15, 15, 20, alpha * 0.75)
  surface.DrawRect(bgX, bgY, totalW, NOTICE_HEIGHT)

  local textY = bgY + NOTICE_HEIGHT / 2
  local localPlayer = LocalPlayer()
  local localPlayerName = IsValid(localPlayer) and localPlayer:Nick() or ""

  -- Highlight attacker when it is the local player
  local attackerColor
  if notice.isAttackerPlayer and notice.attackerName == localPlayerName then
    attackerColor = Color(255, 224, 102, alpha)
  else
    attackerColor = Color(220, 230, 240, alpha)
  end

  -- Highlight victim when it is the local player
  local victimColor
  if notice.victimName == localPlayerName then
    victimColor = Color(242, 95, 92, alpha)
  else
    victimColor = Color(220, 230, 240, alpha)
  end

  local textX = bgX + NOTICE_PADDING_X

  draw.SimpleText(
    language.GetPhrase(notice.attackerName),
    font,
    textX,
    textY,
    attackerColor,
    TEXT_ALIGN_LEFT,
    TEXT_ALIGN_CENTER
  )
  textX = textX + attackerW + iconGap

  -- Render the kill icon scaled to fit within the notice height
  if iconW > 0 then
    local iconY = bgY + (NOTICE_HEIGHT - ICON_DISPLAY_HEIGHT) / 2

    local matrix = Matrix()
    matrix:Translate(Vector(textX, iconY, 0))
    matrix:Scale(Vector(iconScaleX, iconScaleY, 1))

    cam.PushModelMatrix(matrix)
    killicon.Render(0, 0, notice.inflictorClass, alpha)
    cam.PopModelMatrix()

    textX = textX + iconW + iconGap
  end

  draw.SimpleText(notice.victimName, font, textX, textY, victimColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PLUGIN.hook:HUDPaint()
  local centerX = ScrW() / 2

  -- Top-center starting position; leave room for typical HUD elements above
  local y = 40

  local toRemove = {}

  for i, notice in ipairs(PLUGIN.killNotices) do
    local alpha, elapsed = getNoticeAlpha(notice)

    if elapsed >= NOTICE_LIFETIME then
      table.insert(toRemove, i)
    else
      drawKillNotice(notice, centerX, y, alpha)
      y = y + NOTICE_HEIGHT + NOTICE_SPACING
    end
  end

  for i = #toRemove, 1, -1 do
    table.remove(PLUGIN.killNotices, toRemove[i])
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.killicons.notice", function()
  local attackerName = net.ReadString()
  local isAttackerPlayer = net.ReadBool()
  local victimName = net.ReadString()
  local inflictorClass = net.ReadString()

  addKillNotice(attackerName, isAttackerPlayer, victimName, inflictorClass)
end)
