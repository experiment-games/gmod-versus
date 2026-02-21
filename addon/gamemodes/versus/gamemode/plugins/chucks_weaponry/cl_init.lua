local PLUGIN = PLUGIN

local blurMaterial = Material("pp/blurscreen")

function PLUGIN.hook:RenderScreenspaceEffects()
  local ply = LocalPlayer()

  -- Intensity is accumulated each frame by cw_teargas_impact entity Thinks.
  -- Read the value here then immediately reset it so the next frame starts fresh.
  local intensity = ply._VersusTeargasIntensity or 0
  ply._VersusTeargasIntensity = 0

  if intensity <= 0 then
    return
  end

  -- Reduce the effect for players wearing gas-resistant gear (e.g. gasmask).
  -- The highest resistanceAgainstGas value across all equipped items is used.
  local gasResistance = 0
  local equippedItems = versus.equipment.getEquippedItems(ply)

  for _, item in pairs(equippedItems) do
    if item.resistanceAgainstGas and item.resistanceAgainstGas > gasResistance then
      gasResistance = item.resistanceAgainstGas
    end
  end

  intensity = intensity * (1 - gasResistance)

  if intensity <= 0 then
    return
  end

  -- Yellow-green color shift: simulates the eyes reacting to the irritant gas.
  -- Desaturates vision and adds a slight yellow tint.
  DrawColorModify({
    ["$pp_colour_addr"]       = intensity * 0.04,
    ["$pp_colour_addg"]       = intensity * 0.02,
    ["$pp_colour_addb"]       = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"]   = 1,
    ["$pp_colour_colour"]     = 1 - (intensity * 0.3),
    ["$pp_colour_mulr"]       = 0,
    ["$pp_colour_mulg"]       = 0,
    ["$pp_colour_mulb"]       = 0,
  })

  DrawMotionBlur(
    0.25 * intensity,
    0.7 * intensity,
    0.1 * intensity
  )

  -- Blur vision to simulate tearing eyes and involuntary blinking.
  render.UpdateScreenEffectTexture()
  blurMaterial:SetFloat("$blur", intensity * 5)
  render.SetMaterial(blurMaterial)
  render.DrawScreenQuad()
end
