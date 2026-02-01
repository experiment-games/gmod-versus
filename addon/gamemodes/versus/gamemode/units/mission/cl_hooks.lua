local UNIT = UNIT

-- Called when the main menu tabs can be built
function UNIT.hook:BuildMainMenuTabs(tabs)
  tabs:addTab("Missions", vgui.Create("versus_Missions"), "icon16/script.png", 20)
end

net.Receive("versus.mission.updateHistory", function(len)
  local missionCount = net.ReadUInt(10)

  if (not UNIT.pendingCallback) then
    return
  end

  local timerName = "Wait for all missions"
  timer.Create(timerName, 0, 0, function()
    local missions, progress = UNIT.getPlayerMissions(LocalPlayer(), true)

    if (missionCount ~= table.Count(missions)) then
      print("Not all missions arrived yet!")
      timer.Adjust(timerName, 1)
      return
    end

    timer.Remove(timerName)

    UNIT.pendingCallback(missions, progress)
  end)
end)

net.Receive("versus.mission.update", function(len)
  local missionID = net.ReadString()
  local progress = UNIT.progress[missionID] or {}

  progress.startedAt = net.ReadUInt(32)
  progress.completedAt = net.ReadUInt(32)
  progress.stageIndex = net.ReadUInt(7)

  if (progress.completedAt == UNIT.NO_PROGRESS) then
    progress.completedAt = nil
  end
  if (progress.stageIndex == UNIT.NO_STAGE) then
    progress.stageIndex = nil
  end

  UNIT.progress[missionID] = progress
  UNIT.updatePanel = true
end)

net.Receive("versus.mission.updateStage", function(len)
  local missionID = net.ReadString()
  local progress = UNIT.progress[missionID] or {}

  progress.stageIndex = net.ReadUInt(7)

  UNIT.progress[missionID] = progress
  UNIT.updatePanel = true
end)

net.Receive("versus.mission.updateCompletion", function(len)
  local missionID = net.ReadString()
  local progress = UNIT.progress[missionID] or {}

  progress.completedAt = net.ReadUInt(32)

  if (progress.completedAt == UNIT.NO_PROGRESS) then
    progress.completedAt = nil
  end
  if (progress.stageIndex == UNIT.NO_STAGE) then
    progress.stageIndex = nil
  end

  UNIT.progress[missionID] = progress

  if (UNIT.isShowingPast) then
    UNIT.panelMissions[missionID] = UNIT.get(missionID)
    UNIT.panelProgress[missionID] = progress
  else
    UNIT.panelMissions[missionID] = nil
    UNIT.panelProgress[missionID] = nil
  end

  UNIT.updatePanel = true
end)

-- Admins can receive all missions data
versus.network.receiveUnbounded("versus.mission.sendFullAll", function(message)
  local byteCount = message:readUInt(32)
  local compressed = message:readData(byteCount)
  local json = util.Decompress(compressed)

  print("Receiving mission data...")
  print(json)

  local allData = util.JSONToTable(json)
  table.Merge(UNIT.stored, allData)

  UNIT.updateAdminPanel = true
end)

-- Admins can receive all mission data of a single mission
versus.network.receiveUnbounded("versus.mission.sendFull", function(message)
  local missionID = message:readString()
  local byteCount = message:readUInt(16)
  local compressed = message:readData(byteCount)
  local json = util.Decompress(compressed)

  print("Receiving mission data...")
  print(json)

  local allData = util.JSONToTable(json)
  table.Merge(UNIT.stored[missionID], allData)

  UNIT.updateAdminPanel = true
end)
