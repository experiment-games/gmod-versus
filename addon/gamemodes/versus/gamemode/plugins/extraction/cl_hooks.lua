local PLUGIN = PLUGIN

-- Hook to update indicators when conditions are completed
function PLUGIN.hook:PlayerCompleteExtractionCondition(player, condition)
  if player == LocalPlayer() then
    self.updateConditionIndicators()
  end
end

-- Clean up on extraction complete
function PLUGIN.hook:PlayerExtracted(player, extractionPoint)
  if player == LocalPlayer() then
    self.clearExtractionPoint()
  end
end

-- Hook into extraction start to show progress
function PLUGIN.hook:PlayerStartExtraction(player, extractionPoint, extractionTime)
  if player == LocalPlayer() then
    local extraction = PLUGIN.localExtractions[extractionPoint:EntIndex()]
    if extraction then
      self.showExtractionProgress(extractionPoint, extraction.extractionTime)
    end
  end
end

-- Hook into extraction complete to hide progress
function PLUGIN.hook:PlayerExtracted(player, extractionPoint)
  if player == LocalPlayer() then
    self.hideExtractionProgress()
  end
end

function PLUGIN.hook:PostDrawTranslucentRenderables()
  -- Find any started extractions that are not completed and draw the range we can stay in there
  local pos, maxDistance

  for extractionPointIndex, extractionData in pairs(PLUGIN.localExtractions) do
    if not extractionData.completed then
      local extractionPoint = Entity(extractionPointIndex)

      if IsValid(extractionPoint) then
        pos = extractionPoint:GetPos()
        maxDistance = extractionData.maxDistance
      end
    end
  end

  if (not pos or not maxDistance) then
    return
  end

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

--[[
  Net Messages
--]]

net.Receive("versus.extraction.assignExtractionPoint", function()
  local extractionPointIndex = net.ReadUInt(MAX_EDICT_BITS)
  local extractionPoint = Entity(extractionPointIndex)

  if IsValid(extractionPoint) then
    PLUGIN.assignExtractionPoint(extractionPoint)
  else
    PLUGIN.clearExtractionPoint()
  end
end)

net.Receive("versus.extraction.startExtraction", function(len, player)
  local extractionPointIndex = net.ReadUInt(MAX_EDICT_BITS)
  local extractionTime = net.ReadUInt(16)
  local maxDistance = net.ReadUInt(16)

  PLUGIN.localExtractions[extractionPointIndex] = {
    startTime = CurTime(),
    extractionTime = extractionTime,
    completed = false,
    maxDistance = maxDistance,
  }

  hook.Run("PlayerStartExtraction", player, Entity(extractionPointIndex), extractionTime)
end)

net.Receive("versus.extraction.failedExtraction", function(len, player)
  local extractionPointIndex = net.ReadUInt(MAX_EDICT_BITS)

  PLUGIN.localExtractions[extractionPointIndex] = nil

  hook.Run("PlayerFailedExtraction", player, Entity(extractionPointIndex))
end)

net.Receive("versus.extraction.completeExtraction", function(len, player)
  local extractionPointIndex = net.ReadUInt(MAX_EDICT_BITS)

  PLUGIN.localExtractions[extractionPointIndex] = PLUGIN.localExtractions[extractionPointIndex] or {}
  PLUGIN.localExtractions[extractionPointIndex].completed = true

  hook.Run("PlayerExtracted", player, Entity(extractionPointIndex))
end)

net.Receive("versus.extraction.completeCondition", function(len, player)
  local conditionIndex = net.ReadUInt(MAX_EDICT_BITS)

  PLUGIN.localConditionsCompleted[conditionIndex] = true

  hook.Run("PlayerCompleteExtractionCondition", player, Entity(conditionIndex))
end)
