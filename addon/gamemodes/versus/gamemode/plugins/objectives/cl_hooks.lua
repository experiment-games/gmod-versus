local PLUGIN = PLUGIN

function PLUGIN.hook:HUDPaint()
  PLUGIN.drawRadiusRenders()
end

local function clearAllRelevance()
  for _, ent in ipairs(ents.FindByClass("versus_objective_interaction")) do
    ent.isRelevantForLocalPlayer = false
  end
end

-- When a contract is selected or new contracts are offered, clear all relevance.
-- Relevance is set by the server via setEntityRelevant when SetInteractionCallback is called.
function PLUGIN.hook:PlayerSelectedContract()
  clearAllRelevance()
end

function PLUGIN.hook:PlayerReceivedContracts()
  clearAllRelevance()
end

--[[
  Net Messages
--]]

net.Receive("versus.objectives.setObjective", function()
  local title = net.ReadString()
  local description = net.ReadString()
  local hasDistance = net.ReadBool()
  local distance = hasDistance and net.ReadFloat() or nil

  if not IsValid(PLUGIN.hudContainer) then
    PLUGIN.createHUDContainer()
  end

  PLUGIN.hudContainer:SetObjective(title, description, distance)
end)

net.Receive("versus.objectives.clearObjective", function()
  PLUGIN.clearHUDContainer()
end)

net.Receive("versus.objectives.addSubObjective", function()
  local id = net.ReadString()
  local text = net.ReadString()
  local completed = net.ReadBool()
  local hasDistance = net.ReadBool()
  local distance = hasDistance and net.ReadFloat() or nil

  if not IsValid(PLUGIN.hudContainer) then
    PLUGIN.createHUDContainer()
  end

  PLUGIN.hudContainer:AddSubObjective(id, text, completed, distance)
end)

net.Receive("versus.objectives.removeSubObjective", function()
  local id = net.ReadString()

  if IsValid(PLUGIN.hudContainer) then
    PLUGIN.hudContainer:RemoveSubObjective(id)
  end
end)

net.Receive("versus.objectives.updateSubObjective", function()
  local id = net.ReadString()
  local hasText = net.ReadBool()
  local text = hasText and net.ReadString() or nil
  local completed = net.ReadBool()
  local hasDistance = net.ReadBool()
  local distance = hasDistance and net.ReadFloat() or nil

  if IsValid(PLUGIN.hudContainer) then
    PLUGIN.hudContainer:UpdateSubObjective(id, text, completed, distance)
  end
end)

net.Receive("versus.objectives.setTimer", function()
  local time = net.ReadFloat()
  local countDown = net.ReadBool()
  local text = net.ReadString()

  PLUGIN.objectiveTimer = vgui.Create("versus_Timer")
  PLUGIN.objectiveTimer:SetTimer(time, countDown, text)
  PLUGIN.objectiveTimer:SizeToContents(250)
  PLUGIN.objectiveTimer:SetRemoveOnExpire(true)
  PLUGIN.objectiveTimer:MoveToDefaultPosition()
end)

net.Receive("versus.objectives.setTimerPaused", function()
  local paused = net.ReadBool()

  if IsValid(PLUGIN.objectiveTimer) then
    if (paused) then
      PLUGIN.objectiveTimer:Pause()
    else
      PLUGIN.objectiveTimer:Resume()
    end
  end
end)

net.Receive("versus.objectives.clearTimer", function()
  if IsValid(PLUGIN.objectiveTimer) then
    PLUGIN.objectiveTimer:Remove()
    PLUGIN.objectiveTimer = nil
  end
end)

net.Receive("versus.objectives.addRadiusRender", function()
  local id = net.ReadString()
  local position = net.ReadVector()
  local maxDistance = net.ReadFloat()

  PLUGIN.addRadiusRender(id, position, maxDistance)
end)

net.Receive("versus.objectives.removeRadiusRender", function()
  local id = net.ReadString()

  PLUGIN.removeRadiusRender(id)
end)

net.Receive("versus.objectives.clearRadiusRenders", function()
  PLUGIN.clearRadiusRenders()
end)
