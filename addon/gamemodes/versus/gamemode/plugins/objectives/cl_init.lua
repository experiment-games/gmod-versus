local PLUGIN = PLUGIN

PLUGIN.lockedColor = Color(255, 100, 100, 255)
PLUGIN.completedColor = Color(100, 255, 100, 255)
PLUGIN.unlockedColor = Color(255, 200, 80, 255)

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

function PLUGIN.createHUDContainer()
  if IsValid(PLUGIN.hudContainer) then
    PLUGIN.hudContainer:Remove()
  end

  PLUGIN.hudContainer = vgui.Create("versus_ObjectiveHUDContainer")
end

function PLUGIN.updateHUDContainer()
  if not IsValid(PLUGIN.hudContainer) then
    PLUGIN.createHUDContainer()
  end
end

function PLUGIN.clearHUDContainer()
  if IsValid(PLUGIN.hudContainer) then
    PLUGIN.hudContainer:Clear()
  end
end

PLUGIN.clearHUDContainer()
