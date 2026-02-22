local PLUGIN = PLUGIN

ENT.Type = "anim"
ENT.Base = "versus_lootcrate"
ENT.PrintName = "Random Loot Crate"
ENT.Author = ""
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true

--- Weighted item pool. Each entry: { itemID = "...", size = N, weight = N }
--- Higher weight = more common. Weights are relative within the pool.
ENT.ItemPool = {}

--- How many items to draw from the pool when the crate spawns.
ENT.RandomItemCountMin = 1
ENT.RandomItemCountMax = 5

-- Shared constant so both server (fallback timer) and client (render duration) agree.
ENT.UnlockDuration = 1.5

if (not SERVER) then
  local TUMBLER_CHARS = { "#", "@", "*", "!", "%", "&", "?", "$", "~", "+" }
  local TICK_SOUNDS = {
    "buttons/button14.wav",
    "buttons/button15.wav",
    "buttons/button17.wav",
  }
  local REVEAL_SOUND = "items/gunpickup2.wav"

  -- World-space scale for the 3D2D billboard.
  local SCALE_3D2D = 0.15
  local DISPLAY_RENDER_DIST_SQR = 512 * 512

  local function initTumblers(count, duration)
    local tumblers = {}

    for i = 1, count do
      tumblers[i] = {
        value = TUMBLER_CHARS[math.random(#TUMBLER_CHARS)],
        speed = math.Rand(18, 28),
        stopAt = duration * (0.55 + (i / count) * 0.4),
        stopped = false,
        finalChar = TUMBLER_CHARS[math.random(#TUMBLER_CHARS)],
        accum = 0,
      }
    end

    return tumblers
  end

  function ENT:Initialize()
    self._tumblerState = nil
    self._lastUnlockStart = 0
    self._lastTickAt = 0
    self._revealSoundPlayed = false
  end

  function ENT:Draw()
    self:DrawModel()

    local localPlayer = LocalPlayer()

    if (not IsValid(localPlayer)) then
      return
    end

    if (self:GetPos():DistToSqr(localPlayer:GetPos()) > DISPLAY_RENDER_DIST_SQR) then
      return
    end

    local unlockStart = self:GetNWFloat("versus_UnlockStartTime", 0)
    local isUnlocked = self:GetNWBool("versus_IsUnlocked", false)

    if (unlockStart == 0 and not isUnlocked) then
      return
    end

    -- Re-initialize tumblers whenever a new unlock animation begins.
    if (unlockStart > 0 and unlockStart ~= self._lastUnlockStart) then
      self._lastUnlockStart = unlockStart
      self._tumblerState = initTumblers(5, self.UnlockDuration)
      self._lastTickAt = 0
      self._revealSoundPlayed = false
    end

    -- Billboard: position above the crate lid, always face the camera.
    local displayPos = self:GetPos() + Vector(0, 0, 28)
    local ang = (EyePos() - displayPos):Angle()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    if (not isUnlocked and unlockStart > 0 and self._tumblerState) then
      local elapsed = CurTime() - unlockStart
      local progress = math.Clamp(elapsed / self.UnlockDuration, 0, 1)
      local dt = FrameTime()

      -- Tick sounds slow down as the animation approaches completion.
      local dynInterval = Lerp(progress, 0.08, 0.45)

      if (elapsed - self._lastTickAt >= dynInterval) then
        self._lastTickAt = elapsed
        surface.PlaySound(TICK_SOUNDS[math.random(#TICK_SOUNDS)])
      end

      -- Advance each tumbler.
      local allStopped = true
      local tumblerCount = #self._tumblerState
      local cellW = 64
      local spacing = 10
      local totalW = tumblerCount * cellW + (tumblerCount - 1) * spacing

      for i, t in ipairs(self._tumblerState) do
        if (not t.stopped) then
          allStopped = false
          t.accum = t.accum + t.speed * dt

          if (t.accum >= 1) then
            t.accum = t.accum - math.floor(t.accum)
            t.value = TUMBLER_CHARS[math.random(#TUMBLER_CHARS)]
          end

          if (elapsed >= t.stopAt) then
            t.stopped = true
            t.value = t.finalChar
          end
        end
      end

      if (allStopped and not self._revealSoundPlayed) then
        self._revealSoundPlayed = true
        surface.PlaySound(REVEAL_SOUND)
      end

      -- Render the 3D2D billboard.
      local panW = totalW + 24
      cam.Start3D2D(displayPos, ang, SCALE_3D2D)
      -- Dark background panel.
      draw.RoundedBox(4, -panW * 0.5, -44, panW, 90, Color(0, 0, 0, 170))

      -- Tumbler characters.
      local startX = -totalW * 0.5
      for i, t in ipairs(self._tumblerState) do
        local cx  = startX + (i - 1) * (cellW + spacing) + cellW * 0.5
        local col = t.stopped
            and Color(80, 230, 130, 255)
            or Color(180, 220, 180, 200)

        draw.SimpleText(t.value, "DermaLarge", cx, -24, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
      end

      -- "UNLOCKING…" label with a pulse.
      local labelAlpha = math.Clamp(math.sin(elapsed * 4) * 127 + 128, 60, 255)
      draw.SimpleText(
        "UNLOCKING...",
        "DermaDefault",
        0, 14,
        Color(200, 220, 200, labelAlpha),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
      )

      -- Progress bar.
      local barW = totalW
      local barH = 8
      local barX = -barW * 0.5
      local barY = 30

      draw.RoundedBox(4, barX, barY, barW, barH, Color(40, 40, 40, 240))
      draw.RoundedBox(4, barX, barY, barW * progress, barH, Color(80, 200, 120, 230))
      cam.End3D2D()
    end
  end
end

--- Picks `count` items from `pool` using weighted random selection (with replacement).
local function pickRandomItems(pool, count)
  if (#pool == 0) then
    return {}
  end

  local totalWeight = 0

  for _, entry in ipairs(pool) do
    totalWeight = totalWeight + (entry.weight or 1)
  end

  local picked = {}

  for _ = 1, count do
    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, entry in ipairs(pool) do
      cumulative = cumulative + (entry.weight or 1)

      if (roll <= cumulative) then
        local item = versus.item.createInstance(entry.itemID)

        local rarity = versus.item.rollRarity()

        if (rarity) then
          item.rarity = rarity.id
        end

        table.insert(picked, item)
        break
      end
    end
  end

  return picked
end

function ENT:Initialize()
  -- Populate _Items from the pool before the base class creates the inventory.
  if (#self.ItemPool > 0) then
    self._Items = pickRandomItems(
      self.ItemPool,
      math.random(self.RandomItemCountMin, self.RandomItemCountMax)
    )
  end

  self.BaseClass.Initialize(self)

  -- Network vars used by the client to drive the 3D2D animation and "UNLOCKED" display.
  self:SetNWFloat("versus_UnlockStartTime", 0)
  self:SetNWBool("versus_IsUnlocked", false)
end

function ENT:SetItemPool(pool)
  self.ItemPool = pool or {}
end

function ENT:OpenCrate(activator)
  -- If this crate was already unlocked by someone else, skip the animation entirely.
  if (self:GetNWBool("versus_IsUnlocked")) then
    self._IsOpening = false
    versus.inventory.openOrCreateNamedInventory(activator, self:GetChestName(), self, nil)
    return
  end

  self._IsOpening = true

  -- Broadcast the start time so every nearby client can render the 3D2D animation.
  self:SetNWFloat("versus_UnlockStartTime", CurTime())

  -- Store activator so sv_init.lua's net.Receive can validate the response.
  local timerName = "versus_lootcrate_unlock_fallback_" .. self:EntIndex()
  self._pendingActivator = activator
  self._unlockTimerName = timerName

  -- Tell only the activating client to play the animation.
  -- The inventory is opened once the client confirms the animation finished
  -- (handled in sv_init.lua), or by the fallback timer below.
  net.Start("versus.lootcrate.beginUnlock")
  net.WriteEntity(self)
  net.Send(activator)

  -- Safety fallback: open the inventory after 4 s in case the client never responds.
  timer.Create(timerName, 4, 1, function()
    if (not IsValid(self) or not IsValid(activator)) then
      return
    end

    local openSeq = self:LookupSequence("open")
    self:ResetSequence(openSeq)
    self:SetPlaybackRate(1)
    self:EmitSound("items/ammocrate_open.wav", 75, 100, 0.8)

    self._pendingActivator = nil
    self._unlockTimerName = nil
    self._IsOpening = false

    self:SetNWBool("versus_IsUnlocked", true)

    versus.inventory.openOrCreateNamedInventory(activator, self:GetChestName(), self, nil)
  end)
end
