local PLUGIN = PLUGIN

--- Handler: applyStatusEffect
---
--- Applies a timed gameplay modifier to the player: health drain and/or a movement speed
--- penalty. The speed change is automatically rolled back when the phase ends.
---
--- Schema:
--- {
---   effectID        = string,            -- unique within the phase; referenced by clearStatusEffect
---   tickRate        = number?,           -- seconds between ticks (default 1)
---   duration        = number?,           -- total seconds before auto-expiry; nil = lasts until phase ends
---   tickDamage      = number?,           -- HP removed per tick (optional)
---   damageType      = DMG_* constant?,   -- Source damage-type flag (default DMG_GENERIC)
---   speedMultiplier = number?,           -- walk/run speed multiplier, e.g. 0.7 for 30% slow (default 1)
---   expiryCallback  = {"funcID", ...}?,  -- fired once when duration expires
---   tickCallback    = {"funcID", ...}?,  -- fired each tick
---   hudLabel        = string?,           -- text shown on the client HUD strip (default "Status Effect")
---   hudColor        = Color?,            -- colour of the HUD strip (default white)
--- }
---
--- ! NOTE: DMG_POISON always slowly heals back what is lost after a bit, so avoid that.
PLUGIN.registerContractPhaseKeyHandler("applyStatusEffect", function(player, bag, data)
  if not istable(data) then
    error("Data for contract phase applyStatusEffect key is not a table: " .. tostring(data))
    return
  end

  local effectID = data.effectID
  if not effectID then
    ErrorNoHalt("[Contract] applyStatusEffect: No effectID specified\n")
    return
  end

  local tickRate                    = data.tickRate or 1.0
  local duration                    = data.duration
  local speedMult                   = data.speedMultiplier
  local hudLabel                    = data.hudLabel or "Status Effect"
  local hudColor                    = data.hudColor

  -- Save original speeds and apply multiplier
  bag.phase.statusEffects           = bag.phase.statusEffects or {}

  local originalWalkSpeed           = player:GetWalkSpeed()
  local originalRunSpeed            = player:GetRunSpeed()

  bag.phase.statusEffects[effectID] = {
    originalWalkSpeed = originalWalkSpeed,
    originalRunSpeed  = originalRunSpeed,
  }

  if speedMult then
    player:SetWalkSpeed(originalWalkSpeed * speedMult)
    player:SetRunSpeed(originalRunSpeed * speedMult)
  end

  -- Notify the client to show the HUD indicator
  local hasColor = istable(hudColor)

  net.Start("versus.contracts.applyStatusEffect")
  net.WriteString(effectID)
  net.WriteString(hudLabel)
  net.WriteBool(hasColor)
  if hasColor then
    net.WriteUInt(math.Round(hudColor.r), 8)
    net.WriteUInt(math.Round(hudColor.g), 8)
    net.WriteUInt(math.Round(hudColor.b), 8)
  end
  net.WriteBool(duration ~= nil)
  if duration ~= nil then
    net.WriteFloat(duration)
  end
  net.Send(player)

  -- How many ticks to run (0 = infinite, cleared by phase end)
  local maxTicks = duration and math.ceil(duration / tickRate) or 0
  local tickCount = 0

  PLUGIN.createPhaseTimer(player, bag, "statusEffect_" .. effectID .. "_tick", tickRate, maxTicks, function()
    if not IsValid(player) then return end

    tickCount = tickCount + 1

    -- Apply damage
    if data.tickDamage and data.tickDamage > 0 then
      local dmgInfo = DamageInfo()
      dmgInfo:SetDamage(data.tickDamage)
      dmgInfo:SetDamageType(data.damageType or DMG_GENERIC)
      dmgInfo:SetAttacker(player)
      dmgInfo:SetInflictor(player)
      player:TakeDamageInfo(dmgInfo)
    end

    -- Fire optional per-tick callback
    if data.tickCallback then
      PLUGIN.callContractFunction(player, bag, data.tickCallback)
    end

    -- Fire expiry callback on the final tick
    if maxTicks > 0 and tickCount >= maxTicks then
      PLUGIN.callContractFunction(player, bag, data.expiryCallback)
    end
  end)
end)

--- Shared helper that actually removes a named status effect and restores the player's speeds.
local function doCleanStatusEffect(player, bag, effectID)
  if not bag.phase.statusEffects or not bag.phase.statusEffects[effectID] then
    return
  end

  local effect = bag.phase.statusEffects[effectID]

  if IsValid(player) then
    if effect.originalWalkSpeed then
      player:SetWalkSpeed(effect.originalWalkSpeed)
    end
    if effect.originalRunSpeed then
      player:SetRunSpeed(effect.originalRunSpeed)
    end

    -- Tell the client to remove the HUD indicator for this specific effect
    net.Start("versus.contracts.clearStatusEffect")
    net.WriteString(effectID)
    net.Send(player)
  end

  bag.phase.statusEffects[effectID] = nil
end

--- Companion phase-key handler: clearStatusEffect
---
--- Manually removes a named status effect before the phase ends, restoring any speed
--- modification it applied. The phase-scoped tick timer will still run until the phase ends,
--- but damage and callbacks will continue — use this primarily to undo the speed change and
--- HUD indicator early.
---
--- Can also be used as a contract function in callbacks:
---   expiryCallback = { "clearStatusEffect", "my_effect_id" }
---
--- Phase-key schema:  { effectID = string }
--- Contract-function: called with (player, bag, effectID)
PLUGIN.registerContractPhaseKeyHandler("clearStatusEffect", function(player, bag, data)
  local effectID = istable(data) and data.effectID or data
  if not effectID then
    ErrorNoHalt("[Contract] clearStatusEffect: No effectID specified\n")
    return
  end

  doCleanStatusEffect(player, bag, effectID)
end)

PLUGIN.registerContractFunction("clearStatusEffect", function(player, bag, effectID)
  if not effectID then
    ErrorNoHalt("[Contract] clearStatusEffect function: No effectID specified\n")
    return
  end

  doCleanStatusEffect(player, bag, effectID)
end)
