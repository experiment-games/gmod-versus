local PLUGIN = PLUGIN

PLUGIN.radiusRenders = PLUGIN.radiusRenders or {}

-- Draws all active radius renders for the player, such as extraction zones they need to stay within
function PLUGIN.drawRadiusRenders()
  local pos, maxDistance

  for _, radiusData in pairs(PLUGIN.radiusRenders) do
    if (radiusData.position) then
      pos = radiusData.position
      maxDistance = radiusData.maxDistance

      local radius = maxDistance
      local segments = 48
      local alphaModifier = 0.55 + (math.sin(CurTime() * 2) * 0.45)

      render.SetColorMaterial()

      for i = 0, segments - 1 do
        local angle1 = (i / segments) * math.pi * 2
        local angle2 = ((i + 1) / segments) * math.pi * 2

        local x1 = math.cos(angle1) * radius
        local y1 = math.sin(angle1) * radius
        local x2 = math.cos(angle2) * radius
        local y2 = math.sin(angle2) * radius

        render.DrawLine(
          pos + Vector(x1, y1, 0),
          pos + Vector(x2, y2, 0),
          Color(255, 0, 0, 255 * alphaModifier)
        )
      end
    end
  end
end

function PLUGIN.addRadiusRender(id, position, maxDistance)
  PLUGIN.radiusRenders[id] = {
    position = position,
    maxDistance = maxDistance,
  }
end

function PLUGIN.removeRadiusRender(id)
  PLUGIN.radiusRenders[id] = nil
end

function PLUGIN.clearRadiusRenders()
  PLUGIN.radiusRenders = {}
end

--[[
  Hooks
--]]

function PLUGIN.hook:HUDPaint()
  PLUGIN.drawRadiusRenders()
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
