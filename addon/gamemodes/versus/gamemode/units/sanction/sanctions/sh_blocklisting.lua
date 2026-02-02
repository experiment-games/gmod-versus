local UNIT = UNIT

local SANCTION = versus.sanction.define("blocklist")
SANCTION.description = "Block a player from performing an action"

-- This is not a generic SANCTION property, but only here in the blocklist
SANCTION.validActions = {
  chat_local = { label = "chatting in-character", hook = "PlayerCanSayLocal" },
  knockout = { label = "knocking players out", hook = "PlayerCanKnockOut" }
}

---@param player Player
---@param playerSanction table Modifiable data about the sanction
function SANCTION:onApply(player, playerSanction)
  local timeLeft = string.NiceTime(playerSanction.expires_at - os.time())

  versus.message.notifyAll(
    player:getCombinedName() ..
    " has been blocked from using " ..
    playerSanction.data .. " for " .. timeLeft .. "! Reason: " .. playerSanction.reason,
    NOTIFY_WARNING)
end

---@param player Player
---@param playerSanction table Modifiable data about the sanction
function SANCTION:onExpire(player, playerSanction)
  player:notify("You are no longer blocked from " .. playerSanction.data .. ".", NOTIFY_INFORMATION)
end

-- Easy way to add all blocklistable actions
for actionKey, actionData in pairs(SANCTION.validActions) do
  SANCTION.hook[actionData.hook] = function(sanction, player, ...)
    local data = SANCTION:getApplied(player, actionKey)

    if (not data) then
      return
    end

    local timeLeft = string.NiceTime(os.difftime(data.expires_at, os.time()))
    player:notify("You have been blocked from " .. actionData.label .. "! About " .. timeLeft .. " remaining")
    return false
  end
end

SANCTION:registerHooks()

do
  local COMMAND = versus.command.define("blocklists")
  COMMAND.description = "View all valid actions you can blocklist from."
  COMMAND.requiredFlags = "a"

  function COMMAND:onRun(player, target, action, duration)
    local actionsString = ""
    local seperator = ", "

    for action in pairs(SANCTION.validActions) do
      actionsString = actionsString .. seperator .. action
    end

    player:notify(actionsString:sub(seperator:len() + 1), NOTIFY_INFORMATION)
  end
end

do
  local COMMAND = versus.command.define("blocklist")
  COMMAND.description = "Block a player from performing an action."
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(Player, "Target", "The player to receive the sanction")
  COMMAND:addRequiredParameter(tostring, "Action", "The action to block the player from")
  COMMAND:addRequiredParameter(tonumber, "Duration", "How long the block should last")
  COMMAND:addRequiredParameter(tostring, "Reason", "Why the player is receiving the sanction")

  function COMMAND:onRun(player, target, action, duration, reason)
    if (not SANCTION.validActions[action]) then
      player:notify("The action you provided is invalid! Use /blocklists to see a list of valid actions.", NOTIFY_ERROR)
      return
    end

    if (duration <= 0) then
      player:notify("The duration you provided is too low! Pick a time in seconds higher than 0.", NOTIFY_ERROR)
      return
    end

    UNIT.addSanction(target, SANCTION, duration, reason, player, action)
  end
end

do
  local COMMAND = versus.command.define("unblocklist")
  COMMAND.description = "Remove a player from the blocklist for an action."
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(Player, "Target", "The player to have their sanction expire")
  COMMAND:addRequiredParameter(tostring, "Action", "The action the player is allowed to perform again")

  function COMMAND:onRun(player, target, action)
    if (not SANCTION.validActions[action]) then
      player:notify("The action you provided is invalid! Use /blocklists to see a list of valid actions.", NOTIFY_ERROR)
      return
    end

    if (UNIT.expireSanction(target, SANCTION) == false) then
      player:notify("This player doesn't have this sanction!", NOTIFY_ERROR)
      return
    end

    player:notify("You have unblocked " .. player:getCombinedName() .. " from " .. action .. "!", NOTIFY_INFORMATION)
  end
end
