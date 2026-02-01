local UNIT = UNIT

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
