local PLUGIN = PLUGIN

util.AddNetworkString("versus.admin.requestOnlinePlayers")
util.AddNetworkString("versus.admin.requestBannedPlayers")
util.AddNetworkString("versus.admin.onlinePlayers")
util.AddNetworkString("versus.admin.bannedPlayers")
util.AddNetworkString("versus.admin.kick")
util.AddNetworkString("versus.admin.ban")
util.AddNetworkString("versus.admin.unban")
util.AddNetworkString("versus.admin.spectate")
util.AddNetworkString("versus.admin.stopSpectating")
util.AddNetworkString("versus.admin.mute")
util.AddNetworkString("versus.admin.unmute")
util.AddNetworkString("versus.admin.warn")

--- Sends the list of online players with their moderation status to the requesting admin.
--- @param admin Player
local function sendOnlinePlayers(admin)
  local players = {}

  for _, ply in ipairs(player.GetAll()) do
    local data = ply:getCharacter("data")
    local mutedUntil = data.moderationMutedUntil or 0
    local muteRemaining = math.max(0, mutedUntil - os.time())

    table.insert(players, {
      name        = ply:Nick(),
      steamID64   = ply:SteamID64(),
      isSuperAdmin = ply:IsSuperAdmin(),
      isAdmin     = ply:IsAdmin(),
      warnings    = data.moderationWarnings or 0,
      muteRemaining = muteRemaining,
    })
  end

  net.Start("versus.admin.onlinePlayers")
  net.WriteTable(players)
  net.Send(admin)
end

--- Sends the list of currently banned players to the requesting admin.
--- @param admin Player
local function sendBannedPlayers(admin)
  local banSanction = versus.sanction and versus.sanction.get("ban")
  local banLookup   = banSanction and banSanction.banLookup or {}
  local bans        = {}

  for steamID64, banData in pairs(banLookup) do
    table.insert(bans, {
      steamID64 = steamID64,
      reason    = banData.reason,
      expiresAt = banData.expiresAt,
      id        = banData.id,
    })
  end

  net.Start("versus.admin.bannedPlayers")
  net.WriteTable(bans)
  net.Send(admin)
end

-- ─── Inbound handlers ────────────────────────────────────────────────────────

net.Receive("versus.admin.requestOnlinePlayers", function(_, admin)
  if not admin:IsAdmin() then return end

  sendOnlinePlayers(admin)
end)

net.Receive("versus.admin.requestBannedPlayers", function(_, admin)
  if not admin:IsAdmin() then return end

  sendBannedPlayers(admin)
end)

net.Receive("versus.admin.kick", function(_, admin)
  if not admin:IsAdmin() then return end

  local steamID64 = net.ReadString()
  local reason    = net.ReadString()
  local target    = player.GetBySteamID64(steamID64)

  if not IsValid(target) then return end

  versus.message.notifyAll(
    admin:getCombinedName() .. " kicked " .. target:getCombinedName() .. ": " .. reason,
    NOTIFY_WARNING
  )

  target:Kick("Kicked by admin. Reason: " .. reason)
end)

net.Receive("versus.admin.ban", function(_, admin)
  if not admin:IsAdmin() then return end

  local steamID64     = net.ReadString()
  local durationSecs  = net.ReadUInt(32)
  local reason        = net.ReadString()
  local target        = player.GetBySteamID64(steamID64)

  if not IsValid(target) then return end

  local banSanction = versus.sanction and versus.sanction.get("ban")

  if not banSanction then
    ErrorNoHalt("[Admin] Ban sanction not found.\n")
    return
  end

  versus.sanction.addSanction(target, banSanction, durationSecs, reason, admin, target:getSteamID64())
end)

net.Receive("versus.admin.unban", function(_, admin)
  if not admin:IsAdmin() then return end

  local steamID64 = net.ReadString()
  local banSanction = versus.sanction and versus.sanction.get("ban")

  if not banSanction then
    ErrorNoHalt("[Admin] Ban sanction not found.\n")
    return
  end

  local cachedBan = banSanction.banLookup[steamID64]

  if not cachedBan then
    versus.message.notify(admin, "This player isn't banned!", NOTIFY_ERROR)
    return
  end

  local statement = string.format([[
    UPDATE `%s`
    SET `expired_at` = NOW()
    WHERE `id` = %u
  ]], versus.config["MySQL Player Sanctions Table"], cachedBan.id)

  versus.database.query(statement)

  banSanction.banLookup[steamID64] = nil

  versus.message.notify(admin, "You have unbanned " .. steamID64 .. "!", NOTIFY_INFORMATION)

  -- Refresh the banned players list for the admin.
  sendBannedPlayers(admin)
end)

net.Receive("versus.admin.spectate", function(_, admin)
  if not admin:IsAdmin() then return end

  local steamID64 = net.ReadString()

  if not versus.spectating then
    ErrorNoHalt("[Admin] Spectating plugin not available.\n")
    return
  end

  versus.spectating.setSpectator(admin, { steamID64 })
end)

net.Receive("versus.admin.stopSpectating", function(_, admin)
  if not admin:IsAdmin() then return end

  if not versus.spectating then return end

  versus.spectating.clearSpectator(admin)
end)

net.Receive("versus.admin.mute", function(_, admin)
  if not admin:IsAdmin() then return end

  local steamID64      = net.ReadString()
  local durationMins   = net.ReadUInt(16)
  local reason         = net.ReadString()
  local target         = player.GetBySteamID64(steamID64)

  if not IsValid(target) then return end

  local data = target:getCharacter("data")
  data.moderationMutedUntil = os.time() + durationMins * 60

  local displayTime = durationMins >= 60
    and string.format("%d hour(s)", math.ceil(durationMins / 60))
    or string.format("%d minute(s)", durationMins)

  versus.message.notifyAll(
    string.format("[Admin] '%s' has been muted for %s: %s", target:Nick(), displayTime, reason),
    NOTIFY_ERROR
  )
end)

net.Receive("versus.admin.unmute", function(_, admin)
  if not admin:IsAdmin() then return end

  local steamID64 = net.ReadString()
  local target    = player.GetBySteamID64(steamID64)

  if not IsValid(target) then return end

  local data = target:getCharacter("data")
  data.moderationMutedUntil = 0

  versus.message.notifyAll(
    string.format("[Admin] '%s' has been unmuted by %s.", target:Nick(), admin:getCombinedName())
  )
end)

net.Receive("versus.admin.warn", function(_, admin)
  if not admin:IsAdmin() then return end

  local steamID64 = net.ReadString()
  local reason    = net.ReadString()
  local target    = player.GetBySteamID64(steamID64)

  if not IsValid(target) then return end

  local data = target:getCharacter("data")
  data.moderationWarnings = (data.moderationWarnings or 0) + 1

  versus.message.notifyAll(
    string.format("[Admin] '%s' received a warning: %s", target:Nick(), reason),
    NOTIFY_ERROR
  )
end)
