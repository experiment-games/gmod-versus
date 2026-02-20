local UNIT = UNIT

UNIT.libraryKey = "audio"

-- Duration in seconds for the default crossfade between tracks
local DEFAULT_FADE = 2.0

-- Two sound slots used to crossfade between tracks.
-- At most one slot is actively playing at full volume; the other either
-- holds a fading-out remnant or is empty.
UNIT.slots = UNIT.slots or { nil, nil }

-- Index (1 or 2) of the slot that was most recently started.
-- 0 means no music has been started yet.
UNIT.activeSlot = UNIT.activeSlot or 0

-- Returns the entity used as the audio source anchor (the local player, or
-- the world entity as a fallback before the player has fully spawned).
local function getAnchorEntity()
  local ply = LocalPlayer()
  return IsValid(ply) and ply or game.GetWorld()
end

-- Returns the slot index that is NOT the active slot.
local function getInactiveSlot()
  return UNIT.activeSlot == 1 and 2 or 1
end

--- Plays background music, crossfading from any currently playing track.
---
--- Two CSoundPatches are managed internally: the outgoing track fades out on
--- its slot while the incoming track fades in on the other, producing a smooth
--- crossfade with no jarring cut.
---
--- @param soundPath   string  Path relative to the game root (e.g. "music/hl2_song1.mp3")
--- @param fadeDuration number? Seconds for the crossfade (default 2)
function UNIT.playBackgroundMusic(soundPath, fadeDuration)
  fadeDuration = fadeDuration or DEFAULT_FADE

  local nextSlot = getInactiveSlot()

  -- Fade out the currently active slot
  if UNIT.activeSlot ~= 0 then
    local outgoingSlot  = UNIT.activeSlot
    local outgoingSound = UNIT.slots[outgoingSlot]

    if outgoingSound then
      outgoingSound:ChangeVolume(0, fadeDuration)

      -- Stop and release the slot once the fade has finished.
      timer.Simple(fadeDuration, function()
        if outgoingSound then
          outgoingSound:Stop()
        end
        UNIT.slots[outgoingSlot] = nil
      end)
    else
      UNIT.slots[outgoingSlot] = nil
    end
  end

  -- Claim the inactive slot
  -- Forcibly stop any leftover sound on this slot (can happen when
  -- playBackgroundMusic is called again before a previous fade-out finishes).
  local existingSound = UNIT.slots[nextSlot]
  if existingSound then
    existingSound:Stop()
  end
  UNIT.slots[nextSlot] = nil

  -- Start the new track on the inactive slot
  local newSound       = CreateSound(getAnchorEntity(), soundPath)
  UNIT.slots[nextSlot] = newSound
  UNIT.activeSlot      = nextSlot

  newSound:PlayEx(0, 100) -- Start with volume 0, we'll fade in from silence

  -- Capture both the sound and its slot so the deferred fade-in is skipped if
  -- playBackgroundMusic is called again before this timer fires (which would
  -- have caused the old sound to fade back in after already being faded out).
  local capturedSound = newSound
  local capturedSlot  = nextSlot
  timer.Simple(0, function()
    if UNIT.slots[capturedSlot] == capturedSound then
      capturedSound:ChangeVolume(1, fadeDuration)
    end
  end)
end

--- Fades out all currently playing background music slots.
--- @param fadeDuration number? Seconds for the fade-out (default 2)
function UNIT.stopBackgroundMusic(fadeDuration)
  fadeDuration = fadeDuration or DEFAULT_FADE

  if UNIT.activeSlot == 0 then
    return
  end

  UNIT.activeSlot = 0

  for slot = 1, 2 do
    local snd = UNIT.slots[slot]
    if snd then
      snd:ChangeVolume(0, fadeDuration)

      local capturedSound = snd
      local capturedSlot  = slot
      timer.Simple(fadeDuration, function()
        if capturedSound then
          capturedSound:Stop()
        end
        UNIT.slots[capturedSlot] = nil
      end)
    else
      UNIT.slots[slot] = nil
    end
  end
end
