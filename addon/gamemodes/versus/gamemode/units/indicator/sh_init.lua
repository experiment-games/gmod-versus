local UNIT = UNIT

UNIT.libraryKey = "indicator"

versus.includePrefixed("cl_init.lua")

if (CLIENT) then
  UNIT.activeIndicators = UNIT.activeIndicators or {}
  UNIT.nextIndicatorID = UNIT.nextIndicatorID or 1

  -- Create a new indicator
  function UNIT.create(data)
    local id = UNIT.nextIndicatorID
    UNIT.nextIndicatorID = UNIT.nextIndicatorID + 1

    UNIT.activeIndicators[id] = {
      id = id,
      pos = data.pos or Vector(0, 0, 0),
      text = data.text or "",
      icon = data.icon or nil,
      color = data.color or Color(80, 140, 220, 255),
      duration = data.duration or nil,
      createdTime = CurTime(),
      removeOnReach = data.removeOnReach,
      reachDistance = data.reachDistance or 100,
      fadeInTime = data.fadeInTime or 0.3,
      fadeOutTime = data.fadeOutTime or 0.3,
      scale = data.scale or 1,
      onRemove = data.onRemove,
      alpha = 0
    }

    return id
  end

  -- Remove an indicator by ID
  function UNIT.remove(id)
    if UNIT.activeIndicators[id] then
      local indicator = UNIT.activeIndicators[id]

      if indicator.onRemove then
        indicator.onRemove(id)
      end

      UNIT.activeIndicators[id] = nil
    end
  end

  -- Update indicator position
  function UNIT.updatePosition(id, pos)
    if UNIT.activeIndicators[id] then
      UNIT.activeIndicators[id].pos = pos
    end
  end

  -- Update indicator text
  function UNIT.updateText(id, text)
    if UNIT.activeIndicators[id] then
      UNIT.activeIndicators[id].text = text
    end
  end

  -- Clear all indicators
  function UNIT.clear()
    UNIT.activeIndicators = {}
  end

  -- Get indicator by ID
  function UNIT.get(id)
    return UNIT.activeIndicators[id]
  end

  -- Get all indicators
  function UNIT.getAll()
    return UNIT.activeIndicators
  end
end

if (CLIENT) then
  concommand.Add("versus_test_indicators", function()
    local indicatorID = UNIT.create({
      pos = LocalPlayer():GetPos() + Vector(0, 0, 200),
      text = "Objective Test",
      color = Color(80, 140, 220, 255),
      removeOnReach = true,
      reachDistance = 100,
      onRemove = function(id)
        print("Objective completed: test")
      end
    })
  end)
end
