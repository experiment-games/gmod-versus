local PLUGIN = PLUGIN

PLUGIN.convarSundayExclusive = CreateConVar(
  "versus_sunday_exclusive",
  "0",
  { FCVAR_ARCHIVE },
  "Whether to enable Sunday Exclusive testing. Where the servers are locked to only allow testing on Sundays."
)

-- Tracks the last time we ran the per-second think logic.
PLUGIN.nextThinkSecond = PLUGIN.nextThinkSecond or 0

-- Tracks whether the password has already been removed this Sunday session, so we
-- don't keep spamming RunConsoleCommand every second once it's done.
PLUGIN.passwordRemovedThisSunday = false

-- Returns the current server time broken into components using UTC.
local function getCurrentTime()
  return os.date("!*t")
end

-- Removes the server password, unless this is an endurance map (which requires a
-- random password to enforce matchmaking-only access).
local function removePasswordIfAllowed()
  if GetGlobalBool("VersusEnduranceMap", false) then
    return
  end

  RunConsoleCommand("sv_password", "")
  print("[SundayTesting] Server password removed for Sunday testing.")
end

-- Kicks all non-admin players with a goodbye message.
local function kickNonAdminPlayers()
  for _, ply in ipairs(player.GetAll()) do
    if IsValid(ply) and not ply:IsAdmin() and not ply:IsSuperAdmin() then
      ply:Kick("Thanks for testing, cya next Sunday")
    end
  end
end

--[[
  Hooks
--]]

function PLUGIN.hook:Think()
  if (not self.convarSundayExclusive:GetBool()) then
    return
  end

  local now = CurTime()

  -- Throttle to once per second.
  if now < PLUGIN.nextThinkSecond then
    return
  end

  PLUGIN.nextThinkSecond = now + 1

  local t                = getCurrentTime()
  local weekday          = t.wday -- 1 = Sunday, 7 = Saturday
  local hour             = t.hour
  local min              = t.min

  local isSunday         = weekday == 1

  -- We track passwordRemovedThisSunday so we only act once per transition.
  if (isSunday) then
    if not PLUGIN.passwordRemovedThisSunday then
      PLUGIN.passwordRemovedThisSunday = true
      removePasswordIfAllowed()
    end
  else
    -- Reset the flag on any other day/time so the action fires again next week.
    if not (isSunday) then
      PLUGIN.passwordRemovedThisSunday = false
    end
  end

  -- Sunday at 23:59: kick all non-admin players.
  if isSunday and hour == 23 and min == 59 then
    if not PLUGIN._kickedThisSunday then
      PLUGIN._kickedThisSunday = true
      kickNonAdminPlayers()

      -- Set a random password to prevent new non-admin players from joining after the kick, until the next Sunday.
      local randomPassword = tostring(math.random(10000, 999999999999999999999999999))
      RunConsoleCommand("sv_password", randomPassword)

      print("[SundayTesting] Non-admin players kicked and server password set to " ..
      randomPassword .. " for the end of Sunday testing.")
    end
  else
    if not isSunday then
      PLUGIN._kickedThisSunday = false
    end
  end
end

-- When a player joins during Sunday testing hours, welcome them in chat.
function PLUGIN.hook:PlayerInitialized(ply)
  if (not self.convarSundayExclusive:GetBool()) then
    return
  end

  local t = getCurrentTime()
  local isSunday = t.wday == 1

  if not isSunday then
    return
  end

  -- Small delay so the player's client is ready to receive chat messages.
  timer.Simple(3, function()
    if not IsValid(ply) then return end

    versus.message.addChat(
      { ply },
      nil,
      "servermsg",
      "Welcome! Every Sunday we open the server for community testing. Thanks for joining, have fun and let us know what you think!"
    )
  end)
end
