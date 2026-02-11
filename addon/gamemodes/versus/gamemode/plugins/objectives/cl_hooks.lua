local PLUGIN = PLUGIN

-- TODO: Turn this into drawing ANYTHING we need to stay in range for, not just extractions. Allow contracts to network it.
-- function PLUGIN.hook:PostDrawTranslucentRenderables()
--   -- Find any started extractions that are not completed and draw the range we can stay in there
--   local pos, maxDistance

--   for extractionPointIndex, extractionData in pairs(PLUGIN.localExtractions) do
--     if not extractionData.completed then
--       local extractionPoint = Entity(extractionPointIndex)

--       if IsValid(extractionPoint) then
--         pos = extractionPoint:GetPos()
--         maxDistance = extractionData.maxDistance
--       end
--     end
--   end

--   if (not pos or not maxDistance) then
--     return
--   end

--   local radius = maxDistance
--   local segments = 48
--   local alphaModifier = 0.55 + (math.sin(CurTime() * 2) * 0.45)

--   render.SetColorMaterial()

--   for i = 0, segments - 1 do
--     local angle1 = (i / segments) * math.pi * 2
--     local angle2 = ((i + 1) / segments) * math.pi * 2

--     local x1 = math.cos(angle1) * radius
--     local y1 = math.sin(angle1) * radius
--     local x2 = math.cos(angle2) * radius
--     local y2 = math.sin(angle2) * radius

--     render.DrawLine(
--       pos + Vector(x1, y1, 0),
--       pos + Vector(x2, y2, 0),
--       Color(255, 0, 0, 255 * alphaModifier)
--     )
--   end
-- end

--[[
  Net Messages
--]]

net.Receive("versus.objective.setObjective", function()
  local title = net.ReadString()
  local description = net.ReadString()
  local hasDistance = net.ReadBool()
  local distance = hasDistance and net.ReadFloat() or nil

  if not IsValid(PLUGIN.hudContainer) then
    PLUGIN.createHUDContainer()
  end

  PLUGIN.hudContainer:SetObjective(title, description, distance)
end)

net.Receive("versus.objective.clearObjective", function()
  PLUGIN.clearHUDContainer()
end)

net.Receive("versus.objective.addSubObjective", function()
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

net.Receive("versus.objective.removeSubObjective", function()
  local id = net.ReadString()

  if IsValid(PLUGIN.hudContainer) then
    PLUGIN.hudContainer:RemoveSubObjective(id)
  end
end)

net.Receive("versus.objective.updateSubObjective", function()
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
