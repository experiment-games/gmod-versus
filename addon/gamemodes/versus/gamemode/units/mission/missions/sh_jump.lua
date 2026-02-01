---@type VersusMission
local MISSION = MISSION

MISSION.name = "Jump around"
MISSION.description = "When I say jump, you ask: how high?"
MISSION.reward = 100

local MISSION = MISSION

function MISSION:canStart(player)
  return true
end

function MISSION:onStart(player)
  return nil, "Press Jump to jump ;)"
end

function MISSION.hook:KeyPress(player, key)
  -- Since hooks for missions are always called you should check whether
  -- the given player is relevant for this mission. By default only the
  -- player actively engaged in this mission who is also alive and not
  -- unconcious is relevant to the mission.
  if (not self:isRelevant(player)) then
    return
  end

  if (key == IN_JUMP) then
    self:complete(player)
  end
end

--- Can return with an optional message to the player.
function MISSION:onComplete(player)
  versus.finance.giveMoney(player, self.reward, "Completed mission: " .. self.name)

  return string.format("Great, here's %s. Now it ain't always that easy to make money.",
    versus.util.formatMoney(self.reward))
end
