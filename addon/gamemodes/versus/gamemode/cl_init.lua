local g_Player = player

-- TODO: Move colors from addon/gamemodes/versus/gamemode/units/panel/panels/cl*.lua to here
color_background = Color(18, 25, 38, 150)

color_green = Color(112, 193, 179)
color_red = Color(242, 95, 92)
color_orange = Color(235, 94, 40)
color_brightgreen = Color(177, 204, 116)
color_purpleblue = Color(34, 46, 80)
color_purple = Color(208, 196, 223)
color_lightblue = Color(141, 153, 174)
color_pink = Color(18, 25, 38)
color_darkgray = Color(45, 45, 42)
color_lightgray = Color(76, 76, 71)
color_yellow = Color(255, 224, 102)
color_blue = Color(36, 123, 160)

color_lightblue_alpha = Color(141, 153, 174, 200)
color_darkgray_alpha = Color(45, 45, 42, 150)

include("sh_init.lua")

GM.topTextGradient = GM.topTextGradient or {}
GM.variableQueue = GM.variableQueue or {}

GM.SPACING = 42
GM.BAR_WIDTH = 400
GM.BAR_HEIGHT = 42

--[[
  Fonts
--]]

surface.CreateFont("VersusHeadingHuge", {
  font = "Lexend Black",
  size = 100,
  weight = 800,
  antialias = true,
})

surface.CreateFont("VersusHeading1", {
  font = "Lexend Black",
  size = 64,
  weight = 800,
  antialias = true,
})

surface.CreateFont("VersusHeading2", {
  font = "Lexend Medium",
  size = 32,
  weight = 600,
  antialias = true,
})

surface.CreateFont("VersusHeading3", {
  font = "Lexend Medium",
  size = 28,
  weight = 600,
  antialias = true,
})

surface.CreateFont("VersusButton", {
  font = "Lexend Medium",
  size = 24,
  weight = 600,
  antialias = true,
})

surface.CreateFont("VersusButtonSmall", {
  font = "Lexend Medium",
  size = 20,
  weight = 600,
  antialias = true,
})

surface.CreateFont("VersusDefault3D2D", {
  font = "Lexend",
  size = 28,
  weight = 600,
  antialias = true,
})

surface.CreateFont("VersusDefault", {
  font = "Lexend Regular",
  size = 22,
  weight = 400,
  antialias = true,
})

surface.CreateFont("VersusSmall", {
  font = "Lexend Regular",
  size = 18,
  weight = 400,
  antialias = true,
})

surface.CreateFont("VersusDefaultOutlined", {
  font = "Lexend SemiBold",
  size = 22,
  weight = 400,
  antialias = true,
  -- outline = true, -- Commented because it messes with legibility at all sizes (needs wider kerning)
})

surface.CreateFont("versus_Chatbox_MainText", {
  font = "Lexend",
  size = 22,
  weight = 600,
  antialias = true,
  additive = false,
})

surface.CreateFont("VersusAmmoLarge", {
  font = "Lexend Black",
  size = 48,
  weight = 800,
  antialias = true,
})

surface.CreateFont("VersusAmmoSmall", {
  font = "Lexend Medium",
  size = 20,
  weight = 600,
  antialias = true,
})

-- Override the weapon pickup function.
function GM:HUDWeaponPickedUp(...) end

-- Override the item pickup function.
function GM:HUDItemPickedUp(...) end

-- Override the ammo pickup function.
function GM:HUDAmmoPickedUp(...) end

-- Called when an entity is created.
function GM:OnEntityCreated(entity)
  -- Call the base class function.
  return self.BaseClass:OnEntityCreated(entity)
end

-- Called when a player presses a bind.
function GM:PlayerBindPress(player, bind, press)
  -- Call the base class function.
  return self.BaseClass:PlayerBindPress(player, bind, press)
end

-- Check if the local player is using the camera.
function GM:IsUsingCamera()
  if (IsValid(LocalPlayer():GetActiveWeapon())
        and LocalPlayer():GetActiveWeapon():GetClass() == "gmod_camera") then
    return true
  else
    return false
  end
end

-- Only allow administrators to NoClip
function GM:PlayerNoClip(player, desiredState) end

-- Sets the scoreboard to visible
function GM:ScoreboardShow() end

-- Hides the scoreboard
function GM:ScoreboardHide() end

-- A function to override whether a HUD element should draw.
function GM:HUDShouldDraw(name)
  if (not self.playerInitialized) then
    if (name ~= "CHudGMod") then
      return false
    end
  else
    if (
          name == "CHudHealth"
          or name == "CHudBattery"
          or name == "CHudSuitPower"
          or name == "CHudAmmo"
          or name == "CHudSecondaryAmmo"
          or name == "CHudPoisonDamageIndicator"
        ) then
      return false
    end

    return true
  end

  -- Call the base class function.
  return self.BaseClass:HUDShouldDraw(name)
end

-- A function to adjust the width of something by making it slightly more than the width of a text.
function GM:AdjustMaximumWidth(font, text, width, addition, extra)
  surface.SetFont(font)

  -- Get the width of the text.
  local textWidth = surface.GetTextSize(tostring(string.Replace(text, "&", "U"))) + (extra or 0)

  -- Check if the width of the text is greater than our current width.
  if (textWidth > width) then
    width = textWidth + (addition or 0)
  end

  return width
end

-- Draws a background box
function GM:DrawBackgroundBox(x, y, width, height, color)
  surface.SetDrawColor(color)
  surface.DrawRect(x, y, width, height)
end

-- A function to draw a bar with a maximum and a variable.
function GM:DrawBar(font, x, y, width, height, color, text, maximum, variable, bar)
  self:DrawBackgroundBox(x, y, width, height, color_background)
  self:DrawBackgroundBox(x + 2, y + 2, width - 4, height - 4, color_darkgray_alpha)
  self:DrawBackgroundBox(x + 2, y + 2, math.Clamp(((width - 4) / maximum) * variable, 0, width - 4), height - 4, color)

  -- Set the font of the text to this one.
  surface.SetFont(font)

  -- Center the text on the bar.
  local textW, textH = surface.GetTextSize(text)
  x = x + (width * .5) - (textW * .5)
  y = y + (height * .5) - (textH * .5)

  -- Draw text on the bar.
  draw.DrawText(text, font, x + 1, y + 1, color_black)
  draw.DrawText(text, font, x, y, color_white)

  -- Check if a bar table was specified.
  if (bar) then
    bar.y = bar.y - (height + 4)
  end
end

-- Get the bouncing position of the screen's center.
function GM:GetScreenCenterBounce(bounce)
  return ScrW() * .5, (ScrH() * .5) + 32 + (math.sin(CurTime()) * (bounce or 8))
end

function GM:HUDDrawTargetID() end

-- Called when screen space effects should be rendered.
function GM:RenderScreenspaceEffects()
  local modify = {}
  local color = 0.8
  local health = LocalPlayer():Health()

  if (health < 50 and not LocalPlayer()._HideHealthEffects) then
    if (LocalPlayer():Alive()) then
      color = math.Clamp(color - ((50 - health) * 0.025), 0, color)
    else
      color = 0
    end

    DrawMotionBlur(math.Clamp(1 - ((50 - health) * 0.025), 0.1, 1), 1, 0)
  end

  modify["$pp_colour_addr"] = 0
  modify["$pp_colour_addg"] = 0
  modify["$pp_colour_addb"] = 0
  modify["$pp_colour_brightness"] = 0
  modify["$pp_colour_contrast"] = 1
  modify["$pp_colour_colour"] = color
  modify["$pp_colour_mulr"] = 0
  modify["$pp_colour_mulg"] = 0
  modify["$pp_colour_mulb"] = 0

  DrawColorModify(modify)
end

-- Called when the scoreboard should be drawn.
function GM:HUDDrawScoreBoard()
  if (self.playerInitialized) then
    return
  end

  surface.SetDrawColor(color_black)
  surface.DrawRect(0, 0, ScrW(), ScrH())

  if (versus.menu.open) then
    return
  end

  draw.SimpleText(
    "Please wait a second while we load your data...",
    "VersusDefaultOutlined",
    ScrW() * .5,
    ScrH() * .5,
    color_white,
    TEXT_ALIGN_CENTER,
    TEXT_ALIGN_CENTER
  )
end

function GM:DrawInformation(text, font, x, y, color, alpha, left, callback, shadow)
  surface.SetFont(font)

  local width, height = surface.GetTextSize(text)

  if (not left) then
    x = x - (width * .5)
  end
  if (callback) then
    x, y = callback(x, y, width, height)
  end
  if (shadow) then
    draw.DrawText(text, font, x + 1, y + 1, Color(0, 0, 0, alpha or 255))
  end

  draw.DrawText(text, font, x, y, ColorAlpha(color, alpha or 255))

  return y + height + 4
end

function GM:DrawCircle(x, y, radius)
  local segmentCount = math.max(16, math.Round(radius / 2))
  local vertices = {}

  -- Build vertex list
  table.insert(vertices, { x = x, y = y }) -- Center point
  for i = 0, segmentCount do
    local angle = math.rad(i * 360 / segmentCount)
    table.insert(vertices, {
      x = x + math.cos(angle) * radius,
      y = y + math.sin(angle) * radius
    })
  end

  -- Draw as single polygon instead of multiple triangles
  surface.DrawPoly(vertices)
end

function GM:DrawOutlinedCircle(x, y, radius, thickness)
  local segmentCount = math.max(16, math.Round(radius / 2))

  for i = 0, segmentCount - 1 do
    local angle1 = math.rad(i * 360 / segmentCount)
    local angle2 = math.rad((i + 1) * 360 / segmentCount)

    local x1Outer = x + math.cos(angle1) * radius
    local y1Outer = y + math.sin(angle1) * radius
    local x2Outer = x + math.cos(angle2) * radius
    local y2Outer = y + math.sin(angle2) * radius

    local x1Inner = x + math.cos(angle1) * (radius - thickness)
    local y1Inner = y + math.sin(angle1) * (radius - thickness)
    local x2Inner = x + math.cos(angle2) * (radius - thickness)
    local y2Inner = y + math.sin(angle2) * (radius - thickness)

    -- Correct winding order: counter-clockwise
    local poly = {
      { x = x1Inner, y = y1Inner },
      { x = x1Outer, y = y1Outer },
      { x = x2Outer, y = y2Outer },
      { x = x2Inner, y = y2Inner }
    }
    surface.DrawPoly(poly)
  end
end

function GM:DrawShadowText(text, x, y, color)
  surface.SetTextColor(ColorAlpha(color_black, color.a))
  surface.SetTextPos(x + 1, y + 1)
  surface.DrawText(text)
  surface.SetTextColor(color)
  surface.SetTextPos(x, y)
  surface.DrawText(text)
end

function GM:DrawHealthBar(bar)
  local health = LocalPlayer():Health()
  local maxHealth = LocalPlayer():GetMaxHealth()

  if (maxHealth <= 0) then
    maxHealth = 100
  end

  local healthPercent = math.Clamp(health / maxHealth, 0, 1)

  -- Modern styling colors
  local bgColor = Color(25, 35, 50, 220)
  local bgDark = Color(20, 28, 40, 200)
  local healthColor = color_red
  local textColor = Color(220, 230, 240, 255)
  local accentColor = healthColor

  -- Background
  surface.SetDrawColor(bgColor)
  surface.DrawRect(bar.x, bar.y, bar.width, bar.height)

  -- Left accent bar
  surface.SetDrawColor(accentColor)
  surface.DrawRect(bar.x, bar.y, 4, bar.height)

  -- Inner dark background for progress
  local innerPadding = 4
  local innerX = bar.x + innerPadding + 4
  local innerY = bar.y + innerPadding
  local innerWidth = bar.width - (innerPadding * 2) - 4
  local innerHeight = bar.height - (innerPadding * 2)

  surface.SetDrawColor(bgDark)
  surface.DrawRect(innerX, innerY, innerWidth, innerHeight)

  -- Health fill
  local fillWidth = innerWidth * healthPercent
  surface.SetDrawColor(accentColor)
  surface.DrawRect(innerX, innerY, fillWidth, innerHeight)

  -- Health text
  surface.SetFont("VersusDefault")
  local healthText = "HEALTH"
  local healthValue = tostring(math.floor(health))

  local labelW, labelH = surface.GetTextSize(healthText)
  local valueW, valueH = surface.GetTextSize(healthValue)

  -- Label on left
  self:DrawShadowText(healthText, bar.x + 16, bar.y + (bar.height / 2) - (labelH / 2), textColor)

  -- Value on right
  self:DrawShadowText(healthValue, bar.x + bar.width - valueW - 16, bar.y + (bar.height / 2) - (valueH / 2), textColor)

  hook.Run("PostDrawHealthBar", bar, health, maxHealth, bar)

  -- Update bar Y position for next element
  if (bar) then
    bar.y = bar.y - (bar.height + 8)
  end
end

-- Draw the ammo display
function GM:DrawAmmoBar(bar)
  local weapon = LocalPlayer():GetActiveWeapon()

  if not IsValid(weapon) then
    return
  end

  local itemID = weapon:GetNWString("versus_ItemID", "")

  local clipOne = weapon:Clip1()
  local clipMaximum = weapon.Primary and weapon.Primary.ClipSize or 0
  local clipAmount = LocalPlayer():GetAmmoCount(weapon:GetPrimaryAmmoType())
  local itemTable = itemID ~= "" and versus.item.get(itemID) or nil

  local data = {}
  data.displayText = ""
  data.currentAmmo = clipOne
  data.reserveAmmo = clipAmount
  data.maxAmmo = clipMaximum
  data.isGrenade = false

  if (itemTable and itemTable.isGrenadeWeapon) then
    local fullClip = clipOne + clipAmount
    data.displayText = "GRENADES"
    data.currentAmmo = fullClip
    data.reserveAmmo = 0
    data.maxAmmo = fullClip
    data.isGrenade = true
  elseif (clipMaximum > 0) then
    data.displayText = "AMMO"
    data.currentAmmo = clipOne
    data.reserveAmmo = clipAmount
    data.maxAmmo = clipMaximum
  elseif (clipOne == 0) then
    data.displayText = "AMMO"
    data.currentAmmo = 0
    data.reserveAmmo = 0
    data.maxAmmo = 1
  else
    return
  end

  -- Colors
  local bgColor = Color(25, 35, 50, 220)
  local accentColor = Color(112, 193, 179, 255)
  local textColor = Color(220, 230, 240, 255)
  local dimColor = Color(160, 170, 180, 255)

  -- Low ammo warning
  if data.currentAmmo <= data.maxAmmo * 0.25 and data.currentAmmo > 0 then
    accentColor = Color(235, 165, 40, 255)
  elseif data.currentAmmo == 0 then
    accentColor = Color(242, 95, 92, 255)
  end

  hook.Run("PreDrawAmmoBar", bar, data)

  -- Larger display box
  local displayHeight = 80
  local displayWidth = bar.width

  -- Adjust Y position since ammo is taller than standard bars
  -- Move it up by the difference between its height and standard bar height
  local adjustedY = bar.y - (displayHeight - bar.height)

  -- Background
  surface.SetDrawColor(bgColor)
  surface.DrawRect(bar.x, adjustedY, displayWidth, displayHeight)

  -- Left accent
  surface.SetDrawColor(accentColor)
  surface.DrawRect(bar.x, adjustedY, 4, displayHeight)

  -- Label at top
  surface.SetFont("VersusAmmoSmall")
  local labelW, labelH = surface.GetTextSize(data.displayText)
  surface.SetTextColor(ColorAlpha(dimColor, 200))
  surface.SetTextPos(bar.x + 16, adjustedY + 10)
  surface.DrawText(data.displayText)

  -- Large ammo count
  surface.SetFont("VersusAmmoLarge")
  local ammoText = tostring(data.currentAmmo)
  local ammoW, ammoH = surface.GetTextSize(ammoText)

  surface.SetTextColor(accentColor)
  surface.SetTextPos(bar.x + 16, adjustedY + 28)
  surface.DrawText(ammoText)

  -- Reserve/max ammo on the right
  if not data.isGrenade then
    surface.SetFont("VersusAmmoSmall")
    local reserveText = string.format("/ %s", data.reserveAmmo)
    local reserveW, reserveH = surface.GetTextSize(reserveText)

    surface.SetTextColor(ColorAlpha(textColor, 200))
    surface.SetTextPos(bar.x + displayWidth - reserveW - 16, adjustedY + displayHeight - reserveH - 12)
    surface.DrawText(reserveText)
  end

  -- Magazine visualization (small bullets/segments)
  if not data.isGrenade and data.maxAmmo > 0 then
    local segmentCount = math.min(data.maxAmmo, 30) -- Cap at 30 for visual clarity
    local segmentWidth = 6
    local segmentHeight = 12
    local segmentSpacing = 2
    local segmentStartX = bar.x + 16 + ammoW + 20
    local segmentY = adjustedY + 44

    local totalSegmentWidth = (segmentWidth + segmentSpacing) * segmentCount - segmentSpacing

    -- Don't draw if it would overflow
    if segmentStartX + totalSegmentWidth < bar.x + displayWidth - 16 then
      for i = 1, segmentCount do
        local segX = segmentStartX + (i - 1) * (segmentWidth + segmentSpacing)
        local filled = i <= (data.currentAmmo / data.maxAmmo * segmentCount)

        if filled then
          surface.SetDrawColor(accentColor)
          surface.DrawRect(segX, segmentY, segmentWidth, segmentHeight)
        else
          surface.SetDrawColor(Color(40, 50, 65, 200))
          surface.DrawRect(segX, segmentY, segmentWidth, segmentHeight)
          surface.SetDrawColor(Color(60, 70, 85, 150))
          surface.DrawRect(segX + 1, segmentY + 1, segmentWidth - 2, segmentHeight - 2)
        end
      end
    end
  end

  if (bar) then
    bar.y = bar.y - (displayHeight + 8)
  end
end

-- Draw the armor bar as 5 segmented thin bars
function GM:DrawArmorBar(bar)
  local armor = LocalPlayer():Armor()

  if armor <= 0 then return end

  local maxArmor = LocalPlayer():GetMaxArmor()
  local segmentCount = 5
  local armorPerSegment = maxArmor / segmentCount

  -- Colors
  local bgColor = Color(25, 35, 50, 220)
  local bgDark = Color(20, 28, 40, 200)
  local armorColor = Color(80, 140, 220, 255)
  local textColor = Color(220, 230, 240, 255)

  -- Main background
  surface.SetDrawColor(bgColor)
  surface.DrawRect(bar.x, bar.y, bar.width, bar.height)

  -- Left accent
  surface.SetDrawColor(armorColor)
  surface.DrawRect(bar.x, bar.y, 4, bar.height)

  -- Label
  surface.SetFont("VersusDefault")
  local armorText = "ARMOR"
  local armorValue = tostring(math.floor(armor))
  local labelW, labelH = surface.GetTextSize(armorText)
  local valueW, valueH = surface.GetTextSize(armorValue)

  surface.SetTextColor(ColorAlpha(textColor, 180))
  surface.SetTextPos(bar.x + 16, bar.y + (bar.height / 2) - (labelH / 2))
  surface.DrawText(armorText)

  surface.SetTextColor(textColor)
  surface.SetTextPos(bar.x + bar.width - valueW - 16, bar.y + (bar.height / 2) - (valueH / 2))
  surface.DrawText(armorValue)

  -- Draw 5 horizontal segments side by side
  local segmentAreaStart = bar.x + 110          -- Start after label
  local segmentAreaEnd = bar.x + bar.width - 70 -- End before value
  local segmentAreaWidth = segmentAreaEnd - segmentAreaStart

  local segmentSpacing = 4
  local totalSpacing = segmentSpacing * (segmentCount - 1)
  local segmentWidth = (segmentAreaWidth - totalSpacing) / segmentCount
  local segmentHeight = 18 -- Thin bars

  local segmentY = bar.y + (bar.height / 2) - (segmentHeight / 2)

  for i = 1, segmentCount do
    local segX = segmentAreaStart + ((i - 1) * (segmentWidth + segmentSpacing))

    -- Background for segment
    surface.SetDrawColor(bgDark)
    surface.DrawRect(segX, segmentY, segmentWidth, segmentHeight)

    -- Calculate fill for this segment
    local segmentMin = (i - 1) * armorPerSegment
    local segmentMax = i * armorPerSegment

    if armor > segmentMin then
      local fillPercent = math.Clamp((armor - segmentMin) / armorPerSegment, 0, 1)
      local fillWidth = segmentWidth * fillPercent

      -- Filled portion
      surface.SetDrawColor(armorColor)
      surface.DrawRect(segX, segmentY, fillWidth, segmentHeight)

      -- Inner glow
      local glowColor = Color(armorColor.r, armorColor.g, armorColor.b, 80)
      surface.SetDrawColor(glowColor)
      surface.DrawRect(segX + 1, segmentY + 2, math.max(0, fillWidth - 2), segmentHeight - 4)
    end

    -- Segment border
    surface.SetDrawColor(Color(50, 60, 75, 100))
    surface.DrawOutlinedRect(segX, segmentY, segmentWidth, segmentHeight)
  end

  if (bar) then
    bar.y = bar.y - (bar.height + 8)
  end
end

-- Called when the bottom bars should be drawn.
function GM:DrawBottomBars(bar) end

-- Called when the top text should be drawn.
function GM:DrawTopText(text) end

-- Called every time the HUD should be painted.
function GM:HUDPaint()
  if (self:IsUsingCamera()) then
    return
  end

  local scrW, scrH = ScrW(), ScrH()

  self:DrawInformation(versus.config["Website URL"], "VersusDefault", scrW, scrH, color_white, 255, true,
    function(x, y, width, height)
      return x - width - 8, y - height - 8
    end)

  local bar = {
    x = self.SPACING,
    y = scrH - self.BAR_HEIGHT - self.SPACING,
    width = self.BAR_WIDTH,
    height = self.BAR_HEIGHT
  }
  local text = { x = scrW, y = 8 }

  self:DrawHealthBar(bar)
  self:DrawArmorBar(bar)
  self:DrawAmmoBar(bar)

  hook.Run("DrawBottomBars", bar)
  hook.Run("DrawTopText", text)

  versus.message.position = { x = self.SPACING, y = math.min(bar.y + 20, scrH - 8) - self.SPACING }

  local nextSpawnTime = LocalPlayer()._VersusNextSpawnTime
  nextSpawnTime = nextSpawnTime and nextSpawnTime + 1 or 0

  if (not LocalPlayer():Alive()) then
    self:DrawBackgroundBox(0, 0, scrW, scrH, color_black)

    local y = 0

    if (nextSpawnTime >= CurTime()) then
      local seconds = math.max(1, math.floor(nextSpawnTime - CurTime()))
      local message = "You will respawn in " .. seconds .. " second"

      if (seconds == 0) then
        message = "You will respawn any second now"
      elseif (seconds > 1) then
        message = message .. "s"
      end

      self:DrawInformation(message .. ".", "VersusDefault", scrW * .5, y, color_white, 255)
      RunConsoleCommand("stopsound")
    end
  elseif (LocalPlayer():GetNWBool("versus_KnockedOut")) then
    local becomeConsciousTime = LocalPlayer()._VersusBecomeConsciousTime or 0
    local curTime = CurTime()

    self:DrawBackgroundBox(0, 0, scrW, scrH, color_black)

    if (becomeConsciousTime > curTime) then
      local seconds = math.floor(becomeConsciousTime - curTime)

      if (seconds >= 0) then
        local message = "You will become conscious in " .. seconds .. " second"

        if (seconds == 0) then
          message = "You will become conscious any second now"
        elseif (seconds > 1) then
          message = message .. "s"
        end

        self:DrawInformation(message .. ".", "VersusDefault", scrW * .5, (scrH * .5) + 16, color_white, 255)
      end
    end
  end

  local stuckInWorld = LocalPlayer()._StuckInWorld

  if (stuckInWorld) then
    self:DrawInformation(
      string.format("You are stuck! Press %s to holster your weapons and respawn.", versus.message.lookupBinding("jump")),
      "VersusDefault", scrW * .5, (scrH * .5) - 16, Color(255, 50, 25, 255), 255)
  end

  for _, player in ipairs(g_Player.GetAll()) do
    hook.Run("PlayerHUDPaint", player)
  end

  -- Call the base class function.
  self.BaseClass:HUDPaint()
end

-- Called when a player begins typing.
function GM:StartChat(team)
  return true
end

-- Called when a player says something or a message is received from the server.
function GM:ChatText(index, name, text, filter)
  if (filter == "none" or filter == "joinleave" or (filter == "chat" and name == "Console")) then
    versus.message.chatText(index, name, text, filter)
  end

  -- We handle this our own way.
  return true
end

-- Override drawing the death notice and don't draw it
function GM:AddDeathNotice(attacker, team1, inflictor, victim, team2) end
