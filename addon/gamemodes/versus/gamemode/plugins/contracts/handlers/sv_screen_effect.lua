local PLUGIN = PLUGIN

--- Handler: screenEffect
---
--- Sends a named post-process screen effect to the player's client for the duration of the
--- current phase. The effect is automatically cleared when the phase ends.
--- Use the `clearScreenEffect` key handler to remove it early within the same phase.
---
--- Built-in effect names:
---   "bleeding"    – red vignette + mild desaturation
---   "drunk"       – heavy motion blur + warm colour boost
---   "nightvision" – green tint + high contrast
---   "toxic"       – yellow-green tint + subtle motion blur
---   "radiation"   – pulsing green tint + desaturation
---   "cold"        – blue desaturated tint
---   "blinded"     – bright white flash that fades out over ~2 seconds
---
--- Schema:
--- {
---   effect   = string,   -- effect name (see above)
---   duration = number?,  -- auto-clear after N seconds; nil = lasts until phase ends
--- }
PLUGIN.registerContractPhaseKeyHandler("screenEffect", function(player, bag, data)
  if not istable(data) then
    error("Data for contract phase screenEffect key is not a table: " .. tostring(data))
    return
  end

  local effectName = data.effect
  if not effectName then
    ErrorNoHalt("[Contract] screenEffect: No effect name specified\n")
    return
  end

  local duration = data.duration

  -- Track the active effect so cleanupPhase can clear it
  bag.phase.screenEffect = effectName

  -- Tell the client to activate the effect
  net.Start("versus.contracts.screenEffect")
  net.WriteString(effectName)
  net.Send(player)

  -- Schedule auto-clear if a fixed duration was given
  if duration then
    PLUGIN.createPhaseTimerSimple(player, bag, "screenEffect_autoClear", duration, function()
      if not IsValid(player) then return end
      bag.phase.screenEffect = nil
      net.Start("versus.contracts.clearScreenEffect")
      net.Send(player)
    end)
  end
end)

--- Companion phase-key handler: clearScreenEffect
---
--- Removes the currently active screen effect before the phase ends.
--- Schema: (empty table — no data required)
PLUGIN.registerContractPhaseKeyHandler("clearScreenEffect", function(player, bag, data)
  bag.phase.screenEffect = nil
  net.Start("versus.contracts.clearScreenEffect")
  net.Send(player)
end)
