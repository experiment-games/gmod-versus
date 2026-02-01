local UNIT = UNIT

UNIT.progress = UNIT.progress or {}
UNIT.isShowingPast = UNIT.isShowingPast or false
UNIT.panelMissions = UNIT.panelMissions or {}
UNIT.panelProgress = UNIT.panelProgress or {}
UNIT.creatorPanel = UNIT.creatorPanel
UNIT.pendingCallback = UNIT.pendingCallback or nil
UNIT.isFullyUpdated = false

function UNIT.fetchHistory(callback)
  if (UNIT.isFullyUpdated) then
    callback(UNIT.getPlayerMissions(LocalPlayer(), true))
    return
  end

  UNIT.isFullyUpdated = true
  UNIT.pendingCallback = callback

  net.Start("versus.mission.requestHistory")
  net.SendToServer()
end

function UNIT.showCreator()
  if (UNIT.creatorPanel) then
    UNIT.creatorPanel:Remove()
    UNIT.creatorPanel = nil
  end

  UNIT.creatorPanel = vgui.Create("versus_Mission_Manager")
  UNIT.creatorPanel:Center()
  UNIT.creatorPanel:MakePopup()
end
