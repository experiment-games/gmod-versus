local UNIT = UNIT
local PANEL = {}

local ICON_STAGE = "icon16/plugin.png"
local ICON_WAYPOINT = "icon16/flag_blue.png"
local ICON_SCRIPT = "icon16/script.png"
local ICON_ACTION = "icon16/mouse.png"
local ICON_BULLET = "icon16/bullet_black.png"
local ICON_BULLET_GO = "icon16/bullet_go.png"
local ICON_MISSING = "icon16/cross.png"

surface.CreateFont("versus_MissionCode", {
  font = "Consolas",
  size = 14,
  weight = 400,
})

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.missionsList = vgui.Create("DTree", self)
  self.missionsList:Dock(LEFT)

  self.missionsScript = vgui.Create("DTextEntry", self)
  self.missionsScript:Dock(FILL)
  self.missionsScript:SetFont("versus_MissionCode")
  self.missionsScript:SetMultiline(true)
  self.missionsScript:SetEditable(false)

  -- Set this to true to begin with so that we do one starting update.
  versus.mission.updateAdminPanel = true

  -- We call think just once on initialize so that we can update.
  self:Think()
end

function PANEL:PerformLayout(width, height)
  self:SetSize(ScrW() * .75, ScrH() * .7)

  self.missionsList:StretchToParent(0, 0, width * .5, 0)
  self.missionsScript:StretchToParent(width * .5, 0, 0, 0)

  DFrame.PerformLayout(self, width, height)
end

function PANEL:Think()
  if (versus.mission.updateAdminPanel) then
    local scrollBar = self.missionsList.VBar
    local oldScroll = scrollBar:GetScroll()

    versus.mission.updateAdminPanel = false

    self.missionsList:Clear()

    local markBroken = function(missionNode)
      missionNode:SetIcon(ICON_MISSING)
      missionNode:SetTooltip("This mission has missing elements which prevent it from functioning properly.")
    end

    local actions = {
      ["Start Mission (for yourself)"] = function(mission)
        versus.command.run("startmission", LocalPlayer():SteamID(), mission.missionID)
      end
    }

    for missionID, mission in pairs(UNIT.stored) do
      local missionNode = self.missionsList:AddNode(string.format("%s (%s)", mission.name, missionID))
      local stagesNode = missionNode:AddNode("Stages", ICON_STAGE)
      local waypointsNode = missionNode:AddNode("Waypoints", ICON_WAYPOINT)
      local filesNode = missionNode:AddNode("Script Files", ICON_SCRIPT)
      local actionsNode = missionNode:AddNode("Actions", ICON_ACTION)

      for _, stage in pairs(mission:getStages()) do
        local stageNode = stagesNode:AddNode(stage:getTitle(), ICON_STAGE)
      end

      for _, waypoint in pairs(mission:getWaypoints()) do
        local waypointNode = waypointsNode:AddNode(
          waypoint:getName(),
          waypoint.vector and (waypoint.icon or ICON_WAYPOINT) or ICON_MISSING)

        if (not waypoint.vector) then
          markBroken(missionNode)

          local positionNode = waypointNode:AddNode("Missing waypoint position!", ICON_MISSING)
          positionNode:ExpandTo(true)
        else
          local positionNode = waypointNode:AddNode(
            string.format("Teleport to waypoint position (Vector: %s, Angle: %s)", waypoint.vector, waypoint.angle),
            ICON_BULLET_GO)

          positionNode.DoClick = function()
            versus.command.run("teleport", waypoint.vector, waypoint.angle)
          end

          -- TODO: Teleport to location
        end

        local setPositionNode = waypointNode:AddNode("Set waypoint position to where you are aiming now.", ICON_BULLET_GO)
        setPositionNode.DoClick = function()
          versus.command.run("setmissionwaypoint", missionID, waypoint:getIndex())
        end
      end

      for _, file in pairs(mission:getFiles()) do
        local fileNode = filesNode:AddNode(file.fullPath, ICON_SCRIPT)
        fileNode.DoClick = function()
          self.missionsScript:SetValue(file.content)
        end
      end

      for action, callback in pairs(actions) do
        local actionNode = actionsNode:AddNode(action, ICON_BULLET_GO)
        actionNode.DoClick = function()
          callback(mission)
        end
      end
    end

    timer.Simple(0, function()
      scrollBar:AnimateTo(oldScroll, 0.2)
    end)
  end

  DFrame.Think(self)
end

vgui.Register("versus_Mission_Manager", PANEL, "DFrame")
