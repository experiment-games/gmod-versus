local PLUGIN = PLUGIN

-- Duration the unlock animation plays before the inventory opens (seconds).
local UNLOCK_DURATION = 2.8

local TICK_SOUNDS = {
  "buttons/button14.wav",
  "buttons/button15.wav",
  "buttons/button17.wav",
}

local REVEAL_SOUND = "items/gunpickup2.wav"

local TUMBLER_CHARS = { "#", "@", "*", "!", "%", "&", "?", "$", "~", "+" }

--- Creates a fullscreen unlock animation panel, calls onDone when the animation finishes.
local function showUnlockScreen(crate, onDone)
  local scrW, scrH = ScrW(), ScrH()

  local frame = vgui.Create("EditablePanel")
  frame:SetSize(scrW, scrH)
  frame:SetPos(0, 0)
  frame:MakePopup()

  local startTime = CurTime()
  local lastTickAt = 0
  local done = false

  -- 5 tumblers spin through random characters and each stop at a staggered time.
  local tumblerCount = 5
  local tumblers = {}

  for i = 1, tumblerCount do
    tumblers[i] = {
      value     = TUMBLER_CHARS[math.random(#TUMBLER_CHARS)],
      speed     = math.Rand(18, 28),
      stopAt    = UNLOCK_DURATION * (0.55 + (i / tumblerCount) * 0.4),
      stopped   = false,
      finalChar = TUMBLER_CHARS[math.random(#TUMBLER_CHARS)],
      accum     = 0,
    }
  end

  function frame:Paint(w, h)
    Derma_DrawBackgroundBlur(self, startTime)

    -- Dark vignette.
    draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 200))

    local elapsed         = CurTime() - startTime
    local progress        = math.Clamp(elapsed / UNLOCK_DURATION, 0, 1)
    local dt              = FrameTime()

    -- Tick sound interval slows down as we approach the end.
    local dynamicInterval = Lerp(progress, 0.08, 0.45)

    if (not done and elapsed - lastTickAt >= dynamicInterval) then
      lastTickAt = elapsed
      surface.PlaySound(TICK_SOUNDS[math.random(#TICK_SOUNDS)])
    end

    -- Update and draw tumblers.
    local allStopped = true
    local cellW      = 64
    local spacing    = 10
    local totalW     = tumblerCount * cellW + (tumblerCount - 1) * spacing
    local startX     = (w - totalW) * 0.5

    for i, t in ipairs(tumblers) do
      if (not t.stopped) then
        allStopped = false
        t.accum = t.accum + t.speed * dt

        if (t.accum >= 1) then
          t.accum = t.accum - math.floor(t.accum)
          t.value = TUMBLER_CHARS[math.random(#TUMBLER_CHARS)]
        end

        if (elapsed >= t.stopAt) then
          t.stopped = true
          t.value   = t.finalChar
        end
      end

      local cx  = startX + (i - 1) * (cellW + spacing) + cellW * 0.5
      local col = t.stopped
          and Color(80, 230, 130, 255)
          or Color(180, 220, 180, 200)

      draw.SimpleText(t.value, "DermaLarge", cx, h * 0.44, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- "UNLOCKING..." label with a gentle pulse.
    local labelAlpha = math.Clamp(math.sin(elapsed * 4) * 127 + 128, 60, 255)
    draw.SimpleText(
      "UNLOCKING...",
      "DermaLarge",
      w * 0.5, h * 0.55,
      Color(200, 220, 200, labelAlpha),
      TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    -- Progress bar.
    local barW = w * 0.4
    local barH = 8
    local barX = (w - barW) * 0.5
    local barY = h * 0.62

    draw.RoundedBox(4, barX, barY, barW, barH, Color(40, 40, 40, 240))
    draw.RoundedBox(4, barX, barY, barW * progress, barH, Color(80, 200, 120, 230))

    -- When all tumblers have stopped, play the reveal sound and call back.
    if (allStopped and not done) then
      done = true
      surface.PlaySound(REVEAL_SOUND)

      timer.Simple(0.35, function()
        if (IsValid(frame)) then
          frame:Remove()
        end

        onDone()
      end)
    end
  end

  -- Safety net in case something goes wrong client-side.
  timer.Simple(UNLOCK_DURATION + 1.5, function()
    if (IsValid(frame)) then
      frame:Remove()
    end
  end)
end

-- Server told us to start the animation for a specific crate.
net.Receive("versus.lootcrate.beginUnlock", function()
  local crate = net.ReadEntity()

  showUnlockScreen(crate, function()
    -- Notify the server that the animation has finished so it can open inventory.
    net.Start("versus.lootcrate.unlockComplete")
    net.WriteEntity(crate)
    net.SendToServer()
  end)
end)
