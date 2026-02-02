local UNIT = UNIT
local g_Player = player

local WEAPON_SELECTION_WIDE = .2
local WEAPON_SELECTION_MIN_WIDE = 300
local PADDING = 8

function UNIT.hook:Think()
  if (not LocalPlayer():Alive()
        or LocalPlayer():GetNWBool("versus_KnockedOut")) then
    return
  end

  if (UNIT.switchingWeapon == nil) then
    return
  end

  if (UNIT.switchingWeapon.equipAt <= CurTime()) then
    UNIT.switchToWeapon(UNIT.switchingWeapon.weapon, true)
    return
  end
end

function UNIT.hook:HUDPaint()
  if (not LocalPlayer():Alive() or LocalPlayer():GetNWBool("versus_KnockedOut")) then
    return
  end

  local isShowingSelection = UNIT.lastTryWeaponSwitch + UNIT.weaponSwitchTimeSpan > CurTime()
  local screenWidth, screenHeight = ScrW(), ScrH()
  local width = math.max(WEAPON_SELECTION_MIN_WIDE, screenWidth * WEAPON_SELECTION_WIDE)
  local height = 0
  local weaponDrawers = {}
  local weaponHeight = 50 -- temp

  if (UNIT.switchingWeaponTo == nil) then
    UNIT.switchingWeaponTo = LocalPlayer():GetActiveWeapon()
  end

  for i, weapon in ipairs(LocalPlayer():GetWeapons()) do
    local weaponWidth = width
    local xOffset = 0

    if (UNIT.switchingWeaponTo ~= weapon) then
      weaponWidth = weaponWidth * .5
      xOffset = weaponWidth
    end

    weaponDrawers[i] = {
      isSwitchingTo = UNIT.switchingWeaponTo == weapon,
      onDraw = function(x, y, yOffset)
        local transparencyFactor = 1
        x = x + xOffset
        y = y + yOffset

        if (not isShowingSelection) then
          y = y - weaponHeight
          transparencyFactor = .5
        end

        local backgroundColor = UNIT.switchingWeaponTo == weapon
            and color_lightblue_alpha
            or color_black_alpha
        local foregroundColor = color_white

        if (weapon ~= LocalPlayer():GetActiveWeapon()) then
          transparencyFactor = transparencyFactor * .5
        end

        GAMEMODE:DrawBackgroundBox(x, y, weaponWidth, weaponHeight,
          ColorAlpha(backgroundColor, backgroundColor.a * transparencyFactor))

        if (UNIT.switchingWeapon ~= nil
              and UNIT.switchingWeapon.weapon == weapon) then
          local progress = math.Clamp((UNIT.switchingWeapon.equipAt - CurTime()) / UNIT.weaponSwitchDelay, 0, 1)
          local progressWidth = weaponWidth - (weaponWidth * progress)
          local progressColor = ColorAlpha(color_white, color_white.a * progress)
          local barHeight = weaponHeight * .25

          GAMEMODE:DrawBackgroundBox(x, y + weaponHeight - barHeight, progressWidth, barHeight, progressColor)
        else
          -- Hint to the player to click to switch
          if (UNIT.switchingWeaponTo == weapon and isShowingSelection and UNIT.switchingWeaponTo ~= LocalPlayer():GetActiveWeapon()) then
            draw.DrawText(
              string.format("[%s to Equip]", versus.message.lookupBinding("+attack")),
              "Default",
              x + weaponWidth - PADDING,
              y + weaponHeight - PADDING - 16,
              Color(255, 255, 255, 200 * transparencyFactor), TEXT_ALIGN_RIGHT
            )
          end
        end

        draw.DrawText(language.GetPhrase(weapon:GetPrintName()), "ChatFont", x + PADDING, y + PADDING,
          ColorAlpha(foregroundColor, foregroundColor.a * transparencyFactor))

        return weaponHeight
      end
    }

    height = height + (height > 0 and PADDING or 0) + weaponHeight
  end

  local x, y = screenWidth - PADDING - width, screenHeight - PADDING - (isShowingSelection and height or 0)
  local currentHeight = 0

  for _, weaponDrawer in ipairs(weaponDrawers) do
    if (isShowingSelection or weaponDrawer.isSwitchingTo) then
      currentHeight = currentHeight + PADDING + weaponDrawer.onDraw(x, y, currentHeight)
    end
  end

  -- TODO: Make the weapon selection at least as wide as the widest instructions
  if (UNIT.convarHints:GetBool() and UNIT.switchingWeaponTo.Instructions) then
    local parsed = markup.Parse(UNIT.switchingWeaponTo.Instructions)
    local hintHeight = parsed:GetHeight()

    if (hintHeight > 0) then
      hintHeight = hintHeight + (PADDING * 2)
    end

    local hintY = y - (isShowingSelection and PADDING or currentHeight) - hintHeight

    GAMEMODE:DrawBackgroundBox(x, hintY, width, hintHeight, color_black_alpha)
    parsed:Draw(x + PADDING, hintY + PADDING)
  end
end

function UNIT.hook:PlayerBindPress(player, bind, pressed)
  if (bind ~= "invnext" and bind ~= "invprev") then
    return
  end

  -- Ensure that we don't have attack pressed (could be physics gun)
  if (LocalPlayer():KeyDown(IN_ATTACK) or LocalPlayer():KeyDown(IN_ATTACK2)) then
    return
  end

  if (UNIT.lastTryWeaponSwitch + UNIT.minimumScrollInterval > CurTime()) then
    return
  end

  local weapons = LocalPlayer():GetWeapons()

  if (UNIT.lastTryWeaponSwitchIndex == nil) then
    for i, weapon in pairs(weapons) do
      if (weapon == LocalPlayer():GetActiveWeapon()) then
        UNIT.lastTryWeaponSwitchIndex = i
        break
      end
    end
  end

  if (UNIT.lastTryWeaponSwitchIndex == nil or #weapons == 0) then
    return
  end

  if (bind == "invnext") then
    UNIT.lastTryWeaponSwitchIndex = UNIT.lastTryWeaponSwitchIndex + 1

    if (UNIT.lastTryWeaponSwitchIndex > #weapons) then
      UNIT.lastTryWeaponSwitchIndex = 1
    end

    UNIT.switchingWeaponTo = weapons[UNIT.lastTryWeaponSwitchIndex]

    surface.PlaySound("ui/buttonrollover.wav")
  end

  if (bind == "invprev") then
    UNIT.lastTryWeaponSwitchIndex = UNIT.lastTryWeaponSwitchIndex - 1

    if (UNIT.lastTryWeaponSwitchIndex < 1) then
      UNIT.lastTryWeaponSwitchIndex = #weapons
    end

    UNIT.switchingWeaponTo = weapons[UNIT.lastTryWeaponSwitchIndex]

    surface.PlaySound("ui/buttonrollover.wav")
  end

  UNIT.lastTryWeaponSwitch = CurTime()
end

local function cancel()
  UNIT.lastTryWeaponSwitch = 0
  UNIT.switchingWeaponTo = nil
  UNIT.cancelSwitchToWeapon()
end

function UNIT.hook:CreateMove(userCommand)
  if (UNIT.switchingWeaponTo == nil
        or UNIT.lastTryWeaponSwitch + UNIT.weaponSwitchTimeSpan < CurTime()) then
    return
  end

  if (userCommand:KeyDown(IN_ATTACK)) then
    userCommand:RemoveKey(IN_ATTACK)
    UNIT.switchToWeapon(UNIT.switchingWeaponTo)
    return true
  elseif (userCommand:KeyDown(IN_ATTACK2)
        -- Workaround for toolgun (which would still respond even if we remove the attack2 key)
        and (not IsValid(LocalPlayer())
          or not IsValid(LocalPlayer():GetActiveWeapon())
          or LocalPlayer():GetActiveWeapon():GetClass() ~= "gmod_tool")) then
    userCommand:RemoveKey(IN_ATTACK2)
    cancel()
    return true
  end
end

-- Workaround for toolgun
function UNIT.hook:CanTool(ply, tr, toolname, tool, button)
  if (button ~= 2
        or not IsValid(ply)
        or not IsValid(LocalPlayer())
        or ply ~= LocalPlayer()
        or UNIT.switchingWeaponTo == nil
        or UNIT.lastTryWeaponSwitch + UNIT.weaponSwitchTimeSpan < CurTime()) then
    return
  end

  cancel()
  return false
end

net.Receive("versus.weapon.forceSelect", function()
  local weaponClass = net.ReadString()

  if (not IsValid(LocalPlayer())) then
    return
  end

  local weapon = LocalPlayer():GetWeapon(weaponClass)

  if (not IsValid(weapon)) then
    -- Retry until we get the weapon, with a timeout to avoid infinite loops.
    local timerName = "versus.weapon.forceSelect.retry"

    timer.Create(timerName, 0.1, 10, function()
      if (not IsValid(LocalPlayer())) then
        timer.Remove(timerName)
        return
      end

      weapon = LocalPlayer():GetWeapon(weaponClass)

      if (IsValid(weapon)) then
        UNIT.switchingWeaponNow = true
        input.SelectWeapon(weapon)
        timer.Remove(timerName)
      end
    end)

    return
  end

  UNIT.switchingWeaponNow = true
  input.SelectWeapon(weapon)
end)
