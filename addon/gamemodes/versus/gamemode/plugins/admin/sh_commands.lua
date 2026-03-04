local PLUGIN = PLUGIN

do
  local COMMAND = versus.command.define("kick")
  COMMAND.description = "Kick a player from the server."
  COMMAND.category = "Admin Commands"
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(Player, "Target", "The player to be kicked")
  COMMAND:addRequiredParameter(tostring, "Reason", "Why the player is being kicked")

  function COMMAND:onRun(player, target, reason)
    versus.message.notifyAll(
      player:getCombinedName() .. " kicked " .. target:getCombinedName() .. ": " .. reason,
      NOTIFY_WARNING
    )

    target:Kick("Kicked by admin. Reason: " .. reason)
  end
end
