local PLUGIN = PLUGIN

PLUGIN.heatwaveMaterial = Material("sprites/heatwave")
PLUGIN.heatwaveMaterial:SetFloat("$refractamount", 0.01)
PLUGIN.shinyMaterial = Material("models/shiny")

--- Returns true if the local player's stealth camouflage is currently active.
--- @return boolean
function PLUGIN.localPlayerHasStealthActive()
  local client = LocalPlayer()

  if (not IsValid(client)) then
    return false
  end

  return client:GetNWBool(PLUGIN.nwKeyStealthActive, false)
end

--- Returns true if the local player has thermal vision active (equipped and thus always on).
--- @return boolean
function PLUGIN.localPlayerHasThermalActive()
  local client = LocalPlayer()

  if (not IsValid(client)) then
    return false
  end

  return client:GetNWBool(PLUGIN.nwKeyThermalActive, false)
end

--[[
  Context-menu (C key) hooks — activate / deactivate stealth camo
--]]

function PLUGIN.hook:ContextMenuOpen()
  local client = LocalPlayer()

  if (not IsValid(client)) then
    return
  end

  -- Only send a request if we actually have the camo equipped
  local equippedItems = versus.equipment.getEquippedItems(client)
  local hasStealthCamo = false

  for _, item in pairs(equippedItems) do
    if (item.itemID == "stealth_camo") then
      hasStealthCamo = true
      break
    end
  end

  if (not hasStealthCamo) then
    return
  end

  net.Start("versus.stealth.requestToggle")
  net.WriteBool(not PLUGIN.localPlayerHasStealthActive())
  net.SendToServer()

  return false
end

function PLUGIN.hook:RenderScreenspaceEffects()
  local client = LocalPlayer()

  if (not IsValid(client)) then
    return
  end

  local stealthActive = PLUGIN.localPlayerHasStealthActive()
  local thermalActive = PLUGIN.localPlayerHasThermalActive()

  local colorModify = {}
  local modulation = { 1, 1, 1 }

  if (stealthActive) then
    modulation = { 0, 1, 0 }

    colorModify["$pp_colour_brightness"] = -0.1
    colorModify["$pp_colour_contrast"] = 1
    colorModify["$pp_colour_colour"] = 0.1
    colorModify["$pp_colour_addr"] = 0
    colorModify["$pp_colour_addg"] = 0.1
    colorModify["$pp_colour_addb"] = 0
    colorModify["$pp_colour_mulr"] = 0
    colorModify["$pp_colour_mulg"] = 1
    colorModify["$pp_colour_mulb"] = 0
  end

  if (thermalActive) then
    modulation = { 1, 0, 0 }

    colorModify["$pp_colour_brightness"] = 0
    colorModify["$pp_colour_contrast"] = 1
    colorModify["$pp_colour_colour"] = 0.1
    colorModify["$pp_colour_addr"] = 0
    colorModify["$pp_colour_addg"] = 0
    colorModify["$pp_colour_addb"] = 0.1
    colorModify["$pp_colour_mulr"] = 25
    colorModify["$pp_colour_mulg"] = 0
    colorModify["$pp_colour_mulb"] = 25
  end

  if (stealthActive or thermalActive) then
    DrawColorModify(colorModify)
  end

  -- Draw stealthed or thermal-visible players in 3D space
  cam.Start3D(EyePos(), EyeAngles())

  for _, otherClient in ipairs(player.GetAll()) do
    if (otherClient == client and GetViewEntity() == client) then
      continue
    end

    if (otherClient:GetMoveType() == MOVETYPE_NOCLIP) then
      continue
    end

    local isStealthed = otherClient:GetNWBool(PLUGIN.nwKeyStealthActive, false)

    local material = PLUGIN.heatwaveMaterial

    if (thermalActive) then
      -- Thermal vision shows all players (stealthed or not) in red shiny
      material = PLUGIN.shinyMaterial
    elseif (not isStealthed or otherClient:GetVelocity():Length() < 1) then
      -- Stealth camo only renders players who are stealthed and moving
      continue
    end

    render.SuppressEngineLighting(true)
    render.SetColorModulation(unpack(modulation))

    render.MaterialOverride(material)

    otherClient:DrawModel()

    render.MaterialOverride()

    render.SetColorModulation(1, 1, 1)
    render.SuppressEngineLighting(false)
  end

  cam.End3D()
end

function PLUGIN.hook:HUDPaint()
  local stealthActive = PLUGIN.localPlayerHasStealthActive()

  if (stealthActive) then
    render.SetMaterial(self.heatwaveMaterial)
    -- Scroll the heatwave texture based on time to create a moving distortion effect
    local speed = 0.1
    local scrollY = (CurTime() * speed % 1) * ScrH()

    render.DrawScreenQuadEx(0, scrollY - ScrH(), ScrW(), ScrH())
    render.DrawScreenQuadEx(0, scrollY, ScrW(), ScrH())
  end
end

--[[
  Battery HUD — drawn via the shared DrawBottomBars hook so it stacks with other bars.
--]]

local BATTERY_BG       = Color(25, 35, 50, 220)
local BATTERY_BG_DARK  = Color(20, 28, 40, 200)
local BATTERY_FULL     = Color(80, 210, 200, 255)   -- cyan: full battery
local BATTERY_LOW      = Color(230, 180, 40, 255)   -- amber: below 30 %
local BATTERY_EMPTY    = Color(210, 70, 70, 255)    -- red: depleted
local BATTERY_TEXT     = Color(220, 230, 240, 255)
local BATTERY_DIM      = Color(160, 170, 180, 255)

local BATTERY_BAR_H  = 28  -- same height as stamina bar for visual consistency
local NUM_SEGS       = 5   -- battery cell segments

function PLUGIN.hook:DrawBottomBars(bar)
  local client = LocalPlayer()
  if not IsValid(client) or not client:Alive() then return end

  -- Only display if the player has stealth camo or thermal vision equipped.
  local hasStealthCamo    = false
  local hasThermalVision  = false
  local equippedItems     = versus.equipment.getEquippedItems(client)

  for _, item in pairs(equippedItems) do
    if (item.itemID == "stealth_camo")   then hasStealthCamo   = true end
    if (item.itemID == "thermal_vision") then hasThermalVision = true end
  end

  if not hasStealthCamo and not hasThermalVision then return end

  if not versus.resource.getDefinition(PLUGIN.batteryKey) then return end

  local fraction = versus.resource.get(client, PLUGIN.batteryKey) / versus.resource.getMax(PLUGIN.batteryKey)
  fraction = math.Clamp(fraction, 0, 1)

  local accentColor
  if fraction <= 0 then
    accentColor = BATTERY_EMPTY
  elseif fraction < 0.3 then
    accentColor = BATTERY_LOW
  else
    accentColor = BATTERY_FULL
  end

  local x = bar.x
  local y = bar.y - (BATTERY_BAR_H - bar.height)
  local w = bar.width

  -- Background panel
  surface.SetDrawColor(BATTERY_BG)
  surface.DrawRect(x, y, w, BATTERY_BAR_H)

  -- Left accent strip (wider than stamina to distinguish)
  surface.SetDrawColor(accentColor)
  surface.DrawRect(x, y, 6, BATTERY_BAR_H)

  -- Label
  surface.SetFont("VersusDefault")
  local labelText = "BATTERY"
  local _, labelH = surface.GetTextSize(labelText)
  surface.SetTextColor(ColorAlpha(BATTERY_DIM, 200))
  surface.SetTextPos(x + 18, y + (BATTERY_BAR_H / 2) - (labelH / 2))
  surface.DrawText(labelText)

  -- Battery cell segments (wider gaps, rounded look via border)
  local segAreaStart = x + 120
  local segAreaEnd   = x + w - 50
  local segAreaW     = segAreaEnd - segAreaStart
  local segSpacing   = 5
  local totalSpacing = segSpacing * (NUM_SEGS - 1)
  local segW         = math.floor((segAreaW - totalSpacing) / NUM_SEGS)
  local segH         = 18
  local segY         = y + (BATTERY_BAR_H / 2) - (segH / 2)

  local filledSegs = math.ceil(fraction * NUM_SEGS)

  for i = 1, NUM_SEGS do
    local sx = segAreaStart + (i - 1) * (segW + segSpacing)

    surface.SetDrawColor(BATTERY_BG_DARK)
    surface.DrawRect(sx, segY, segW, segH)

    if i <= filledSegs then
      surface.SetDrawColor(accentColor)
      surface.DrawRect(sx, segY, segW, segH)
      -- Inner highlight
      surface.SetDrawColor(Color(accentColor.r, accentColor.g, accentColor.b, 60))
      surface.DrawRect(sx + 2, segY + 2, segW - 4, segH - 4)
    end

    surface.SetDrawColor(Color(50, 60, 75, 150))
    surface.DrawOutlinedRect(sx, segY, segW, segH)
  end

  -- Battery nub (the small bump on the right of a battery symbol)
  local nubX = segAreaEnd + segSpacing
  local nubW = 8
  local nubH = 10
  local nubY = y + (BATTERY_BAR_H / 2) - (nubH / 2)

  surface.SetDrawColor(ColorAlpha(accentColor, 180))
  surface.DrawRect(nubX, nubY, nubW, nubH)

  -- Percentage text on the far right
  surface.SetFont("VersusDefault")
  local pctText = math.floor(fraction * 100) .. "%"
  local pctW, pctH = surface.GetTextSize(pctText)
  surface.SetTextColor(ColorAlpha(BATTERY_TEXT, 200))
  surface.SetTextPos(x + w - pctW - 16, y + (BATTERY_BAR_H / 2) - (pctH / 2))
  surface.DrawText(pctText)

  bar.y = y - 8
end
