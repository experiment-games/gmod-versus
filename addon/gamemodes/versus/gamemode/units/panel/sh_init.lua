local UNIT = UNIT
local gamemodeFolder = GM.FolderName

UNIT.libraryKey = "panel"

versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("cl_derma_skin.lua")

if (CLIENT) then
  function UNIT.initPanelSkin(panel)
    panel:SetSkin("Versus")
  end
end

function UNIT.loadPanels(panelsPath)
  panelsPath = panelsPath:Trim("/") .. "/"

  for _, panelFile in pairs(file.Find(panelsPath .. "*.lua", "LUA")) do
    if (CLIENT) then
      include(panelsPath .. panelFile)
    else
      AddCSLuaFile(panelsPath .. panelFile)
    end
  end
end
