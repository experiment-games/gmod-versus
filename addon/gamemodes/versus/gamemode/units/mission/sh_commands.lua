local UNIT = UNIT

do
  local COMMAND = versus.command.define("startmission")
  COMMAND.description = "Take start a mission for a player."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Player", "Player to start the mission for")
  COMMAND:addRequiredParameter(tostring, "Mission ID", "ID of the mission to start")

  function COMMAND:onRun(player, target, missionID)
    local mission = versus.mission.get(missionID)

    if (not mission) then
      versus.message.notify(player, missionID .. " is not a valid mission ID!", NOTIFY_ERROR)
      PrintTable(table.GetKeys(versus.mission.stored))
      return
    end

    local started, message = versus.mission.start(mission, target)

    if (not started) then
      local message = target:getCombinedName() .. " " .. message

      versus.message.notify(player, message, NOTIFY_ERROR)
      return
    end

    versus.message.notifyAll(player:getCombinedName() ..
      " started mission '" .. mission.name .. "' for " .. target:getCombinedName() .. ".")
  end
end

do
  local COMMAND = versus.command.define("missionwaypoints")
  COMMAND.description = "Show waypoints that need to be configured (or all missions and waypoints if specified)"
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addParameter(tobool, "Show all?", "Show all missions instead of only the unconfigured ones?")

  function COMMAND:onRun(player, showAll)
    versus.message.notify(player, "Showing " .. (showAll and "all" or "unconfigured") .. " waypoints for missions:",
      NOTIFY_WARNING)

    for missionID, mission in pairs(versus.mission.stored) do
      local waypoints = mission:getWaypoints()

      versus.message.notify(player, "⦾ Mission: " .. mission.missionID, NOTIFY_WARNING)

      if (#waypoints == 0) then
        versus.message.notify(player, "   ‣ This mission has no waypoints", NOTIFY_WARNING)
      else
        local waypointsShown = 0

        for waypointIndex, waypoint in pairs(waypoints) do
          if (showAll or waypoint.vector == nil) then
            waypointsShown = waypointsShown + 1
            versus.message.notify(player,
              "   ‣ #" ..
              waypointIndex ..
              " (" ..
              waypoint.name .. ") = " .. (waypoint.vector ~= nil and tostring(waypoint.vector) or "unconfigured!"),
              NOTIFY_WARNING)
          end
        end

        if (waypointsShown == 0) then
          versus.message.notify(player, "   ‣ This mission has no waypoints to be configured", NOTIFY_WARNING)
        end
      end
    end

    versus.message.notify(player,
      "Use the shown mission ID and the waypoint number shown after the # with the /setmissionwaypoint command.",
      NOTIFY_WARNING)
  end
end

do
  local COMMAND = versus.command.define("setmissionwaypoint")
  COMMAND.description = "Set a waypoint position for a mission to where you are aiming now"
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(tostring, "Mission ID", "The ID of the mission to configure a waypoint for")
  COMMAND:addRequiredParameter(tonumber, "Waypoint Index", "Use /missionwaypoints all to see valid waypoint ID's")

  function COMMAND:onRun(player, missionID, waypointIndex)
    local mission = versus.mission.get(missionID)

    if (not mission) then
      versus.message.notify(player,
        missionID .. " is not a valid mission ID! Use /missionwaypoints all to see valid ID's",
        NOTIFY_ERROR)
      PrintTable(table.GetKeys(versus.mission.stored))
      return
    end

    local waypoints = mission:getWaypoints()
    local waypoint = waypoints[waypointIndex]

    if (not waypoint) then
      versus.message.notify(player,
        waypointIndex ..
        " is not a valid waypoint for this mission! Use /missionwaypoints all to see all waypoint numbers.", NOTIFY_ERROR)
      return
    end

    local trace = player:GetEyeTraceNoCursor()

    versus.mission.setMissionWaypoint(mission, waypointIndex, trace.HitPos, trace.HitNormal:Angle())

    UNIT.networkMission(mission, player)

    local message = string.format("Set the mission waypoint #%d (%s) for '%s'", waypointIndex, waypoint.name,
      mission.name)
    versus.message.notify(player, message, NOTIFY_CHAT_LIGHTBULB)
  end
end

do
  local COMMAND = versus.command.define("missions")
  COMMAND.description = "Show your (uncompleted) missions and related instructions"

  COMMAND:addParameter(tobool, "Show all?", "Show all missions instead of only the uncompleted ones?")

  function COMMAND:onRun(player, showAll)
    local missions, allProgress = versus.mission.getPlayerMissions(player, showAll)
    local dateFormat = versus.config["Date Format"]
    local showCount = 0

    versus.message.notify(player, "Showing " .. (showAll and "all" or "unfinished") .. " missions:", NOTIFY_WARNING)

    for missionID, mission in pairs(missions) do
      local progress = allProgress[missionID]
      local interestingDate

      if (progress.completedAt) then
        interestingDate = " (Completed on " .. os.date(dateFormat, progress.completedAt) .. ")"
      else
        interestingDate = " (Started on " .. os.date(dateFormat, progress.startedAt) .. ")"
      end

      versus.message.notify(player, "⦾ Mission: " .. mission.name .. interestingDate, NOTIFY_WARNING)

      for i, message in pairs(progress.messages) do
        versus.message.notify(player, "   " .. i .. ". " .. message, NOTIFY_WARNING)
      end

      showCount = showCount + 1
    end

    if (showCount == 0) then
      versus.message.notify(player, "   You have " .. (showAll and "accepted no" or "no unfinished") .. " missions.",
        NOTIFY_WARNING)
    end
  end
end

do
  local COMMAND = versus.command.define("missiondialog")
  COMMAND.description = "Open a dialog for the given mission"

  COMMAND:addRequiredParameter(tostring, "Mission ID", "The ID of the mission to configure a waypoint for")

  function COMMAND:onRun(player, missionID)
    local mission = versus.mission.get(missionID)

    if (not mission) then
      versus.message.notify(player, missionID .. " is not a valid mission ID!", NOTIFY_ERROR)
      return
    end

    local stage = mission:getPlayerStage(player)

    if (not stage or not mission:runStageCallback(stage, player)) then
      versus.message.notify(player, mission.name .. " has no dialog to offer to you at the moment!", NOTIFY_ERROR)
    end
  end
end
