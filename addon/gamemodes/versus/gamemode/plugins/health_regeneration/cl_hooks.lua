local PLUGIN = PLUGIN

PLUGIN.isRegenerating = false
PLUGIN.regenPulseAlpha = 0
PLUGIN.lastRegenState = false

function PLUGIN.getIsRegenerating()
  local maxHealth = LocalPlayer():GetMaxHealth()
  return PLUGIN.isRegenerating and LocalPlayer():Alive() and
      LocalPlayer():Health() < maxHealth * PLUGIN.maxRegenPercent
end

-- Draw a pulsing glow around the health bar when regenerating
function PLUGIN.hook:PostDrawHealthBar(bar, health, maxHealth, bar)
  if not self.getIsRegenerating() then
    return
  end

  local pulse = math.sin(CurTime() * 4) * 0.5 + 0.5
  local glowAlpha = 5 + (pulse * 15)
  local glowColor = Color(80, 220, 140, glowAlpha)
  local x, y = bar.x + 8, bar.y + 4
  local width, height = bar.width - 12, bar.height - 8

  surface.SetDrawColor(glowColor)
  surface.DrawRect(x, y, width, height)
end

-- Receive regeneration state from server
net.Receive("versus.healthregen.regenerating", function()
  local isRegen = net.ReadBool()

  PLUGIN.isRegenerating = isRegen

  -- Play subtle sound on regen start
  if isRegen and not PLUGIN.lastRegenState then
    -- LocalPlayer():EmitSound("items/smallmedkit1.wav", 40, 120, 0.2)
  end

  PLUGIN.lastRegenState = isRegen
end)
