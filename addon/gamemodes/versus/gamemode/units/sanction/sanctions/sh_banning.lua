local UNIT = UNIT

local SANCTION = versus.sanction.define("ban")
SANCTION.description = "Ban a player from the server"
SANCTION.banLookup = SANCTION.banLookup or {}

---@param player Player
---@param playerSanction table Modifiable data about the sanction
function SANCTION:onApply(player, playerSanction)
  local timeLeft = string.NiceTime(playerSanction.expires_at - os.time())

  versus.message.notifyAll(
    player:getCombinedName() .. " has been banned for " .. timeLeft .. "! Reason: " .. playerSanction.reason,
    NOTIFY_WARNING)
  player:Kick("Banned for " .. timeLeft .. ". Reason: " .. playerSanction.reason)
end

---@param player Player
---@param playerSanction table Modifiable data about the sanction
function SANCTION:onExpire(player, playerSanction) end

function SANCTION.hook:DatabaseConnected(connection)
  UNIT.processNotExpired()
end

function SANCTION.hook:PlayerSanctionProcessing(player, sanction, playerSanction)
  if (sanction ~= SANCTION) then
    return
  end

  local steamID64 = playerSanction.data
  local banLookup = {
    reason = playerSanction.reason,
    expiresAt = playerSanction.expires_at,
    id = playerSanction.id
  }

  SANCTION.banLookup[steamID64] = banLookup

  if (IsValid(player)) then
    local banEnd = os.date(versus.config["MySQL Date Format"], banLookup.expiresAt)
    player:Kick("Banned until " .. banEnd .. " for reason: " .. banLookup.reason)
  end
end

-- TODO: Test if this works on a dedicated server
function SANCTION.hook:CheckPassword(steamID64, ip, serverPassword, incomingPassword, name)
  local banLookup = SANCTION.banLookup and SANCTION.banLookup[steamID64] or nil

  MsgN("SANCTION.hook:CheckPassword")
  if (not banLookup) then
    MsgN(steamID64, SANCTION.banLookup)
    return
  end

  local banEnd = os.date(versus.config["MySQL Date Format"], banLookup.expiresAt)
  return false, "Banned until " .. banEnd .. " for reason: " .. banLookup.reason
end

SANCTION:registerHooks()

do
  local COMMAND = versus.command.define("ban")
  COMMAND.description = "Ban a player from joining the server."
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(Player, "Target", "The player to be banned")
  COMMAND:addRequiredParameter(tonumber, "Duration", "How long the ban should last")
  COMMAND:addRequiredParameter(tostring, "Reason", "Why the player is receiving the ban")

  function COMMAND:onRun(player, target, duration, reason)
    if (duration <= 0) then
      player:notify("The duration you provided is too low! Pick a time in seconds higher than 0.", NOTIFY_ERROR)
      return
    end

    UNIT.addSanction(target, SANCTION, duration, reason, player, target:getSteamID64())
  end
end

do
  local COMMAND = versus.command.define("unban")
  COMMAND.description = "Unban a player."
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(tostring, "SteamID64", "The SteamID64 of the player to be unbanned.")

  function COMMAND:onRun(player, steamID64)
    local cachedBan = SANCTION.banLookup[steamID64]

    if (not cachedBan) then
      player:notify("This player isn't banned!", NOTIFY_ERROR)
      return
    end

    local statement = string.format([[
		UPDATE `%s`
		SET `expired_at` = NOW()
		WHERE `id` = %u
	]], versus.config["MySQL Player Sanctions Table"], cachedBan.id)

    versus.database.query(statement)

    player:notify("You have unbanned " .. steamID64 .. "!", NOTIFY_INFORMATION)
  end
end
