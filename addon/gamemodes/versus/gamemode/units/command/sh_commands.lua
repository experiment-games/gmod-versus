local UNIT = UNIT

do
  local COMMAND = versus.command.define("teleport")
  COMMAND.description = "Teleport to a given vector and angle."
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(Vector, "Position", "The vector to teleport to.")
  COMMAND:addParameter(Angle, "Angle", "The rotation to appear in.")

  function COMMAND:onRun(player, position, angles)
    player:SetPos(position)

    if (angle) then
      player:SetAngles(angles)
    end
  end
end

do
  local COMMAND = versus.command.define("bring")
  COMMAND.description = "Bring a player to where you are looking at."
  COMMAND.requiredFlags = "a"

  COMMAND:addRequiredParameter(Player, "Player", "The player to bring.")

  function COMMAND:onRun(player, target)
    local trace = player:GetEyeTrace()
    local position = trace.HitPos + trace.HitNormal * 16

    target:SetPos(position)

    -- Have them face us
    local angle = (player:GetPos() - target:GetPos()):Angle()
    target:SetEyeAngles(angle)
  end
end
