local PLUGIN = PLUGIN

PLUGIN.lockedColor = Color(255, 100, 100, 255)
PLUGIN.completedColor = Color(100, 255, 100, 255)
PLUGIN.unlockedColor = Color(255, 200, 80, 255)

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
