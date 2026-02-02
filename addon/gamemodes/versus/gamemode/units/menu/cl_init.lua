local UNIT = UNIT

UNIT.width = ScrW()
UNIT.height = ScrH()

-- Only add this library on the client
UNIT.libraryKey = "menu"

function UNIT.getTabBuilder()
  local tabBuilder = setmetatable({}, FindMetaTable("VersusOrderedList")):init()
  tabBuilder.addTab = function(tabBuilder, label, contentPanel, icon, order)
    tabBuilder:add(order, setmetatable({
      label = label,
      contentPanel = contentPanel,
      icon = icon
    }, FindMetaTable("VersusTab")))
  end

  return tabBuilder
end

function UNIT.hide()
  UNIT.panel:SetVisible(false)
  gui.EnableScreenClicker(false)
end

-- A function to toggle the menu.
function UNIT.toggle(openTab)
  if (GAMEMODE.playerInitialized) then
    UNIT.open = not UNIT.open

    gui.EnableScreenClicker(UNIT.open)

    if (IsValid(UNIT.panel)) then
      UNIT.panel:SetVisible(UNIT.open)
    else
      UNIT.panel = vgui.Create("versus_Menu")
      UNIT.panel:MakePopup()
    end

    if (openTab) then
      UNIT.panel:ShowTab(openTab)
    end

    UNIT.panel:CallShownEvent()
  end
end

function UNIT.hook:OnScreenSizeChanged(oldWidth, oldHeight, newWidth, newHeight)
  UNIT.width = ScrW()
  UNIT.height = ScrH()
end

-- Sets the scoreboard to visible
function UNIT.hook:ScoreboardShow()
  versus.menu.toggle()
end

-- Hides the scoreboard
function UNIT.hook:ScoreboardHide()
  versus.menu.toggle()
end

-- Hook to toggle the menu from the server.
net.Receive("versus.showMenu", function(len)
  UNIT.toggle()
end)
