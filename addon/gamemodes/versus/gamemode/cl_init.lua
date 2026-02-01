local g_Player = player

-- Taken from Lexi's Applejack: https://github.com/Lexicality/applejack/blob/master/gamemode/cl_init.lua#L7
color_green = Color(50, 255, 50)
color_red = Color(255, 50, 50)
color_orange = Color(255, 125, 0)
color_brightgreen = Color(125, 255, 50)
color_purpleblue = Color(125, 50, 255)
color_purple = Color(150, 75, 200)
color_lightblue = Color(75, 150, 255)
color_pink = Color(255, 75, 150)
color_darkgray = Color(25, 25, 25)
color_lightgray = Color(150, 150, 150)
color_yellow = Color(250, 230, 70)
color_blue = Color(15, 45, 230)
-- Alpha'd
color_red_alpha = Color(255, 50, 50, 200)
color_orange_alpha = Color(240, 190, 60, 200)
color_lightblue_alpha = Color(100, 100, 255, 200)
color_darkgray_alpha = Color(25, 25, 25, 150)
color_black_alpha = Color(0, 0, 0, 200)

include("sh_init.lua")

-- Set some information for the gamemode.
GM.topTextGradient = GM.topTextGradient or {}
GM.variableQueue = GM.variableQueue or {}
GM.ammoCount = GM.ammoCount or {}
GM.playerJoinTime = GM.playerJoinTime or CurTime()

surface.CreateFont("Trebuchet16_Outlined", {
  font = "Trebuchet MS",
  size = 16,
  weight = 700,
  antialias = false,
  outline = true
})
surface.CreateFont("Trebuchet20_Outlined", {
  font = "Trebuchet MS",
  size = 20,
  weight = 900,
  antialias = false,
  outline = true
})
surface.CreateFont("Trebuchet20", {
  font = "Trebuchet MS",
  size = 20,
  weight = 900,
  antialias = false,
  outline = false
})
surface.CreateFont("Trebuchet20_Bolder", {
  font = "Trebuchet MS",
  size = 20,
  weight = 1200,
  antialias = false,
  outline = false
})
surface.CreateFont("Trebuchet24_Bolder", {
  font = "Trebuchet MS",
  size = 24,
  weight = 1200,
  antialias = false,
  outline = false
})
surface.CreateFont("Trebuchet18_Outlined", {
  font = "Trebuchet MS",
  size = 18,
  weight = 900,
  antialias = false,
  outline = true
})
surface.CreateFont("Trebuchet18_Bolder", {
  font = "Trebuchet MS",
  size = 18,
  weight = 1200,
  antialias = false,
  outline = false
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
    if (name == "CHudHealth" or name == "CHudBattery" or name == "CHudSuitPower"
          or name == "CHudAmmo" or name == "CHudSecondaryAmmo" or name == "CHudWeaponSelection") then
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

-- Draws a rounded box (ensures consistent corner radius everywhere)
function GM:DrawRoundedBox(x, y, width, height, color)
  draw.RoundedBox(4, x, y, width, height, color)
end

-- A function to draw a bar with a maximum and a variable.
function GM:DrawBar(font, x, y, width, height, color, text, maximum, variable, bar)
  self:DrawRoundedBox(x, y, width, height, color_black_alpha)
  self:DrawRoundedBox(x + 2, y + 2, width - 4, height - 4, color_darkgray_alpha)
  self:DrawRoundedBox(x + 2, y + 2, math.Clamp(((width - 4) / maximum) * variable, 0, width - 4), height - 4, color)

  -- Set the font of the text to this one.
  surface.SetFont(font)

  -- Adjust the x and y positions so that they don't screw up.
  x = math.floor(x + (width * .5))
  y = math.floor(y + 1)

  -- Draw text on the bar.
  draw.DrawText(text, font, x + 1, y + 1, color_black, 1)
  draw.DrawText(text, font, x, y, color_white, 1)

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

  -- Check if the player is low on health.
  if (LocalPlayer():Health() < 50 and not LocalPlayer()._HideHealthEffects) then
    if (LocalPlayer():Alive()) then
      color = math.Clamp(color - ((50 - LocalPlayer():Health()) * 0.025), 0, color)
    else
      color = 0
    end

    -- Draw the motion blur.
    DrawMotionBlur(math.Clamp(1 - ((50 - LocalPlayer():Health()) * 0.025), 0.1, 1), 1, 0)
  end

  -- Set some color modify settings.
  modify["$pp_colour_addr"] = 0
  modify["$pp_colour_addg"] = 0
  modify["$pp_colour_addb"] = 0
  modify["$pp_colour_brightness"] = 0
  modify["$pp_colour_contrast"] = 1
  modify["$pp_colour_colour"] = color
  modify["$pp_colour_mulr"] = 0
  modify["$pp_colour_mulg"] = 0
  modify["$pp_colour_mulb"] = 0

  -- Draw the modified color.
  DrawColorModify(modify)
end

-- Called when the scoreboard should be drawn.
function GM:HUDDrawScoreBoard()
  if (not self.playerInitialized) then
    surface.SetDrawColor(color_black)
    surface.DrawRect(0, 0, ScrW(), ScrH())
    surface.SetFont("ChatFont")

    local width, height = surface.GetTextSize("Loading!")
    local x, y = self:GetScreenCenterBounce()

    self:DrawRoundedBox((ScrW() * .5) - (width * .5) - 8, (ScrH() * .5) - 8, width + 16, 30, color_darkgray)
    draw.DrawText("Please wait a second while we load your data...", "ChatFont", ScrW() * .5, ScrH() * .5, color_white, 1,
      1)

    if (self.playerJoinTime and (CurTime() - self.playerJoinTime) >= 5) then
      draw.DrawText(
        string.format("Press %s to rejoin if you are stuck on this screen!", versus.message.lookupBinding("jump")),
        "ChatFont", ScrW() * .5, ScrH() * .5 + 32, Color(255, 50, 25, 255), 1, 1)
    end
  end
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
    draw.DrawText(text, font, x + 1, y + 1, Color(0, 0, 0, alpha or color.a))
  end

  draw.DrawText(text, font, x, y, Color(color.r, color.g, color.b, alpha or color.a))

  return y + height + 8
end

function GM:DrawInformationBar(value, max, text, font, x, y, color, textColor, alpha, left, callback)
  surface.SetFont(font)

  local width, height = surface.GetTextSize(text)
  local barWidth = math.max(width + 40, 128)
  local barHeight = height + 4
  local barX = x
  local barY = y

  y = y + 1

  if (not left) then
    x = x - (width * .5)
  end

  if (callback) then
    x, y = callback(x, y, width, height)
  end

  -- Bar background and fill
  self:DrawRoundedBox(barX - (barWidth * .5), barY, barWidth, barHeight, color_black_alpha)
  self:DrawRoundedBox(barX - (barWidth * .5) + 2, barY + 2, math.Clamp(((barWidth - 4) / max) * value, 0, barWidth - 4),
    barHeight - 4, color)

  -- Text shadow and text
  draw.DrawText(text, font, x + 1, y + 1, Color(0, 0, 0, alpha or textColor.a))
  draw.DrawText(text, font, x, y, Color(textColor.r, textColor.g, textColor.b, alpha or textColor.a))

  return y + height + 8
end

function GM:DrawLabeledInformation(label, value, font, x, y, color, alpha, left, callback, shadow)
  surface.SetFont(font)

  label = string.format("%s: ", label)
  local labelWidth = surface.GetTextSize(label)
  local width, height = surface.GetTextSize(value)
  width = labelWidth + width

  if (not left) then
    x = x - (width * .5)
  end
  if (callback) then
    x, y = callback(x, y, width, height)
  end
  if (shadow) then
    draw.DrawText(value, font, x + 1, y + 1, Color(0, 0, 0, alpha or color.a))
  end

  draw.DrawText(label, font, x, y, Color(color.r, color.g, color.b, (alpha or color.a) * .4))
  draw.DrawText(value, font, x + labelWidth, y, Color(color.r, color.g, color.b, alpha or color.a))

  return y + height + 8
end

local icons = {
  name = Material("icon16/user.png"),
}

-- Draw the player's information.
function GM:DrawPlayerInformation()
  local width = 0
  local height = 0
  local information = setmetatable({}, FindMetaTable("VersusOrderedList")):init()
  local informationFiltered = {}

  hook.Run("BuildPlayerInformation", information)

  information:add(1, {
    label = "Name",
    value = LocalPlayer():GetNWString("versus_Name"),
    icon = icons.name
  })

  for _, infoData in pairs(information:getSorted()) do
    infoData.shown = infoData.value ~= ""

    if (infoData.shown) then
      width = self:AdjustMaximumWidth("ChatFont", string.format("%s: %s", infoData.label, infoData.value), width, nil,
        infoData.icon and 24 or nil)

      table.insert(informationFiltered, infoData)
    end
  end

  width = width + 16
  height = (18 * #informationFiltered) + 14

  local x = 8
  local y = ScrH() - height - 8

  self:DrawRoundedBox(x, y, width, height, color_black_alpha)

  x = x + 8
  y = y + 8

  for _, infoData in pairs(informationFiltered) do
    infoData.x = x
    infoData.y = y

    if (infoData.icon) then
      self:DrawLabeledInformation(infoData.label, infoData.value, "ChatFont", x + 24, y, infoData.color or color_white,
        255, true)

      surface.SetMaterial(infoData.icon)
      surface.SetDrawColor(255, 255, 255, 255)
      surface.DrawTexturedRect(x, y - 1, 16, 16)
    else
      self:DrawLabeledInformation(infoData.label, infoData.value, "ChatFont", x, y, color_white, 255, true)
    end

    y = y + 18
  end

  hook.Run("PostDrawPlayerInformation", information)

  return width, height
end

-- Draw the health bar.
function GM:DrawHealthBar(bar)
  local health = math.Clamp(LocalPlayer():Health(), 0, 100)

  -- Draw the health and ammo bars.
  self:DrawBar("Default", bar.x, bar.y, bar.width, bar.height, color_red, "Health: " .. health, 100, health, bar)
end

-- Draw the ammo bar.
function GM:DrawAmmoBar(bar)
  local weapon = LocalPlayer():GetActiveWeapon()

  -- Check if the weapon is valid.
  if (IsValid(weapon)) then
    if (not self.ammoCount[weapon:GetClass()]) then
      self.ammoCount[weapon:GetClass()] = weapon:Clip1()
    end

    -- Check if the weapon's first clip is bigger than the amount we have stored for clip one.
    if (weapon:Clip1() > self.ammoCount[weapon:GetClass()]) then
      self.ammoCount[weapon:GetClass()] = weapon:Clip1()
    end

    -- Get the amount of ammo the weapon has in it's first clip.
    local clipOne = weapon:Clip1()
    local clipMaximum = self.ammoCount[weapon:GetClass()]
    local clipAmount = LocalPlayer():GetAmmoCount(weapon:GetPrimaryAmmoType())

    -- Check if the maximum clip if above 0.
    if (clipMaximum > 0) then
      self:DrawBar("Default", bar.x, bar.y, bar.width, bar.height, color_lightblue_alpha,
        "Ammo: " .. clipOne .. " [" .. clipAmount .. "]", clipMaximum, clipOne, bar)
    end
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

  self:DrawInformation(versus.config["Website URL"], "ChatFont", scrW, scrH, color_white, 255, true,
    function(x, y, width, height)
      return x - width - 8, y - height - 8
    end)

  local width, height = self:DrawPlayerInformation()
  local bar = { x = width + 16, y = scrH - 24, width = 144, height = 16 }
  local text = { x = scrW, y = 8 }

  self:DrawHealthBar(bar)
  self:DrawAmmoBar(bar)

  hook.Run("DrawBottomBars", bar)
  hook.Run("DrawTopText", text)

  versus.message.position = { x = 8, y = math.min(bar.y + 20, scrH - height - 8) - 40 }

  local nextSpawnTime = LocalPlayer().nextSpawnTime
  nextSpawnTime = nextSpawnTime and nextSpawnTime + 1 or 0

  if (not LocalPlayer():Alive() and nextSpawnTime >= CurTime()) then
    local seconds = math.floor(nextSpawnTime - CurTime())

    self:DrawRoundedBox(0, 0, scrW, scrH, color_black)

    if (seconds >= 0) then
      local message = "You will respawn in " .. seconds .. " second"

      if (seconds == 0) then
        message = "You will respawn any second now"
      elseif (seconds > 1) then
        message = message .. "s"
      end

      self:DrawInformation("You fainted...", "ChatFont", scrW * .5, (scrH * .5), color_red, 255)
      self:DrawInformation(message .. ".", "ChatFont", scrW * .5, (scrH * .5) + 16, color_white, 255)
      RunConsoleCommand("stopsound")
    end
  elseif (LocalPlayer():GetNWBool("versus_KnockedOut")) then
    local _BecomeConsciousTime = LocalPlayer()._BecomeConsciousTime or 0

    if (_BecomeConsciousTime > CurTime()) then
      local seconds = math.floor(_BecomeConsciousTime - CurTime())

      if (seconds >= 0) then
        local message = "You will become conscious in " .. seconds .. " second"

        if (seconds == 0) then
          message = "You will become conscious any second now"
        elseif (seconds > 1) then
          message = message .. "s"
        end

        self:DrawInformation(message .. ".", "ChatFont", scrW * .5, (scrH * .5) + 16, color_white, 255)
      end
    end
  end

  local stuckInWorld = LocalPlayer()._StuckInWorld

  if (stuckInWorld) then
    self:DrawInformation(
      string.format("You are stuck! Press %s to holster your weapons and respawn.", versus.message.lookupBinding("jump")),
      "ChatFont", scrW * .5, (scrH * .5) - 16, Color(255, 50, 25, 255), 255)
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
