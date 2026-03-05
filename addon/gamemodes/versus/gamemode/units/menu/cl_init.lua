local UNIT = UNIT

UNIT.width = ScrW()
UNIT.height = ScrH()

-- Only add this library on the client
UNIT.libraryKey = "menu"

function UNIT.getTabBuilder()
  local tabBuilder = setmetatable({}, FindMetaTable("VersusOrderedList")):init()
  tabBuilder.addTab = function(tabBuilder, label, contentPanel, order)
    tabBuilder:add(order, setmetatable({
      label = label,
      contentPanel = contentPanel,
    }, FindMetaTable("VersusTab")))
  end

  return tabBuilder
end

-- A function to toggle the menu.
function UNIT.toggle(openTab)
  if (UNIT.open) then
    UNIT.hide()
  else
    UNIT.show(openTab)
  end
end

--- Shows the menu.
--- @param openTab? VersusTab
function UNIT.show(openTab)
  if (GAMEMODE.playerInitialized) then
    UNIT.open = true

    gui.EnableScreenClicker(true)

    if (IsValid(UNIT.panel)) then
      UNIT.panel:SetVisible(true)
    else
      UNIT.panel = vgui.Create("versus_Menu")
      UNIT.panel:MakePopup()
    end

    if (openTab) then
      UNIT.panel:ShowTab(openTab)
    end

    UNIT.panel:CallShownEvent()

    surface.PlaySound("versus/ui_unfold.wav")
  end
end

--- Hides the menu.
function UNIT.hide()
  UNIT.open = false
  gui.EnableScreenClicker(false)

  if (IsValid(UNIT.panel)) then
    UNIT.panel:SetVisible(false)

    UNIT.panel:CallHiddenEvent()

    surface.PlaySound("versus/ui_fold.wav")
  end
end

function UNIT.hook:OnScreenSizeChanged(oldWidth, oldHeight, newWidth, newHeight)
  UNIT.width = ScrW()
  UNIT.height = ScrH()
end

-- Sets the scoreboard to visible
function UNIT.hook:ScoreboardShow()
  versus.menu.show()
end

-- Hides the scoreboard
function UNIT.hook:ScoreboardHide()
  -- Don't hide if a child textentry is focused
  local focusedPanel = vgui.GetKeyboardFocus()
  if (IsValid(focusedPanel) and UNIT.panel:IsOurChild(focusedPanel)) then
    local isTextEntry = focusedPanel:GetName() == "DTextEntry" or focusedPanel:GetName() == "versus_TextEntry"

    if (isTextEntry) then
      return
    end
  end

  versus.menu.hide()
end

-- Hook to toggle the menu from the server.
net.Receive("versus.showMenu", function(len)
  UNIT.toggle()
end)
