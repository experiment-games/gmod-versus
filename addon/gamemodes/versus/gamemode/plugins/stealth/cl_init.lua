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
