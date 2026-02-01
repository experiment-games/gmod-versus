local UNIT = UNIT
local PANEL = {}

local BUTTON_TEXT_CREATOR = "Manage Missions (administrator)"
local BUTTON_TEXT_PAST = "Show all my missions"
local BUTTON_TEXT_CURRENT = "Show only active missions"

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self:SetSize(versus.menu.width, versus.menu.height - 8)

  local missions, progress = versus.mission.getPlayerMissions(LocalPlayer())
  versus.mission.panelMissions = missions
  versus.mission.panelProgress = progress

  -- Create a panel list to store the missions.
  self.missionsList = vgui.Create("DPanelList", self)
  self.missionsList:SizeToContents()
  self.missionsList:SetPadding(2)
  self.missionsList:SetSpacing(3)
  self.missionsList:StretchToParent(4, 4, 12, 44)
  self.missionsList:EnableVerticalScrollbar()

  -- Set this to true to begin with so that we do one starting update.
  UNIT.updatePanel = true

  -- We call think just once on initialize so that we can update.
  self:Think()
end

function PANEL:PerformLayout()
  self:StretchToParent(0, 22, 0, 0)
  self.missionsList:StretchToParent(0, 0, 0, 0)
end

function PANEL:Think()
  if (UNIT.updatePanel) then
    local scrollBar = self.missionsList.VBar
    local oldScroll = scrollBar:GetScroll()

    UNIT.updatePanel = false

    self.missionsList:Clear()
    self.missionsList:AddItem(vgui.Create("versus_Missions_Information", self))

    local missionCount = 0

    for missionID, _ in pairs(versus.mission.panelMissions) do
      self.currentMission = missionID

      if (versus.mission.get(missionID)) then
        self.missionsList:AddItem(vgui.Create("versus_Missions_Entry", self))
        missionCount = missionCount + 1
      end
    end

    if (missionCount == 0) then
      self.missionsList:AddItem(vgui.Create("versus_Missions_Empty", self))
    end

    self.missionsList:Rebuild()

    timer.Simple(0, function()
      scrollBar:AnimateTo(oldScroll, 0.2)
    end)
  end
end

vgui.Register("versus_Missions", PANEL, "Panel")

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.missionFunctions = {}

  self:SetSize(versus.menu.width, 75)
  self:SetPos(1, 5)

  -- Set the mission that we are.
  self.missionID = self:GetParent().currentMission
  local mission = versus.mission.get(self.missionID)

  self.name = vgui.Create("DLabel", self)
  self.name:SetText(mission.name)
  self.name:SetFont("Trebuchet18")
  self.name:SizeToContents()
  self.name:SetTextColor(color_white)

  self.description = vgui.Create("DLabel", self)
  self.description:SetText(mission.description)
  self.description:SizeToContents()
  self.description:SetTextColor(color_white)

  if (true or mission.onAbandon) then
    table.insert(self.missionFunctions, {
      name = "Abandon",
      onClick = function()
        versus.command.run("mission", self.missionID, "use")
      end,
    })
  end

  self.missionStages = {}
  local stages = mission:getStages()

  for i, stage in pairs(stages) do
    self.missionStages[i] = vgui.Create("versus_Missions_Stage", self)
    self.missionStages[i]:SetStageProgress(stage, versus.mission.getPlayerProgress(mission, LocalPlayer()))
  end

  self.missionButton = {}

  if (not versus.mission.isShowingPast) then
    for i = 1, #self.missionFunctions do
      if (self.missionFunctions[i]) then
        self.missionButton[i] = vgui.Create("DButton", self)
        self.missionButton[i]:SetText(self.missionFunctions[i].name)

        if (self.missionFunctions[i] == "Abandon") then
          self.missionButton[i].DoClick = self.missionFunctions[i].onClick
        end
      end
    end
  end
end

function PANEL:PerformLayout(width, height)
  self.name:SizeToContents()
  self.description:SizeToContents()

  local spacingY = 4
  local x, y = 6, spacingY

  -- Set the position of the name and description.
  self.name:SetPos(x, y)
  y = y + self.name:GetTall() + spacingY
  self.description:SetPos(x, 24)
  y = y + self.description:GetTall() + spacingY

  local inset = 24
  for i, stagePanel in pairs(self.missionStages) do
    stagePanel:SetWide(width - inset - 6)
    stagePanel:SetPos(inset, y)
    y = y + stagePanel:GetTall() + spacingY
  end

  for i = 1, #self.missionFunctions do
    if (self.missionButton[i]) then
      self.missionButton[i]:SetPos(x, y)

      x = x + self.missionButton[i]:GetWide() + 4
    end
  end

  if (#self.missionButton > 0) then
    y = y + self.missionButton[1]:GetTall() + spacingY
  end

  if (height ~= y) then
    self:SetTall(y)
  end
end

vgui.Register("versus_Missions_Entry", PANEL, "DPanel")

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  local amountActive = table.Count(versus.mission.panelMissions)
  local maximumActive = 5 -- versus.mission.getMaximumActive(LocalPlayer())

  self.activeMissions = vgui.Create("DLabel", self)

  if (versus.mission.isShowingPast) then
    self.activeMissions:SetText("Missions Total: " .. amountActive)
  else
    self.activeMissions:SetText("Missions Active: " .. amountActive .. "/" .. maximumActive)
  end

  self.activeMissions:SizeToContents()
  self.activeMissions:SetTextColor(color_white)

  if (LocalPlayer():IsSuperAdmin()) then
    self.creatorAction = vgui.Create("DButton", self)
    self.creatorAction:SetText(BUTTON_TEXT_CREATOR)
    self.creatorAction:SizeToContents()

    self.creatorAction.DoClick = function()
      versus.menu.hide()
      UNIT.showCreator()
    end
  end

  self.historyToggle = vgui.Create("DButton", self)
  self.historyToggle:SetText(versus.mission.isShowingPast and BUTTON_TEXT_CURRENT or BUTTON_TEXT_PAST)
  self.historyToggle:SizeToContents()

  function self.historyToggle:DoClick()
    if (versus.mission.isShowingPast) then
      self:SetText(BUTTON_TEXT_PAST)
      versus.mission.isShowingPast = false
    else
      self:SetText(BUTTON_TEXT_CURRENT)
      versus.mission.isShowingPast = true
    end
    self:SizeToContents()

    versus.mission.fetchHistory(function(missions, progress)
      if (not versus.mission.isShowingPast) then
        missions, progress = versus.mission.getPlayerMissions(LocalPlayer())
      end

      versus.mission.panelMissions = missions
      versus.mission.panelProgress = progress
      UNIT.updatePanel = true
    end)
  end
end

function PANEL:PerformLayout(width, height)
  local amountActive = table.Count(versus.mission.panelMissions)
  local maximumActive = 5 -- versus.mission.getMaximumActive(LocalPlayer())

  -- Set the position of the label.
  self.activeMissions:SetPos((width / 2) - (self.activeMissions:GetWide() / 2), 5)

  if (versus.mission.isShowingPast) then
    self.activeMissions:SetText("Missions Total: " .. amountActive)
  else
    self.activeMissions:SetText("Missions Active: " .. amountActive .. "/" .. maximumActive)
  end

  self.creatorAction:SetPos(5, 3)
  self.historyToggle:SetPos(width - 5 - self.historyToggle:GetWide(), 3)
end

vgui.Register("versus_Missions_Information", PANEL, "DPanel")

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.progressIcon = vgui.Create("DImage", self)
  self.progressIcon:SetSize(16, 16)
  self.progressIcon:SetImage("icon16/tick.png")

  self.stageText = vgui.Create("DLabel", self)
  self.stageText:SetText("Some info on this stage.")
  self.stageText:SizeToContents()
  self.stageText:SetTextColor(color_white)
end

function PANEL:SetStageProgress(stage, progress)
  self._stage = stage
  self._progress = progress
end

function PANEL:PerformLayout(width, height)
  local x, y = 6, 4

  if (self._progress.stageIndex < self._stage:getIndex()) then
    self:SetTall(0)
    return
  end

  self.progressIcon:SetPos(x, y)
  self.stageText:SetPos(x + self.progressIcon:GetWide() + 4, y)

  local stageCompleted = self._progress.completedAt ~= nil or self._progress.stageIndex > self._stage:getIndex()
  self.progressIcon:SetImageColor(stageCompleted and color_white or Color(0, 0, 0, 50))
  self.stageText:SetText(self._stage:getTitle())
  self.stageText:SizeToContents()

  y = y + self.progressIcon:GetTall() + 4

  if (height ~= y) then
    self:SetTall(y)
  end
end

vgui.Register("versus_Missions_Stage", PANEL, "DPanel")

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.info = vgui.Create("DLabel", self)
  self.info:SetText("You have no active missions.")
  self.info:SetFont("Trebuchet18")
  self.info:SizeToContents()
  self.info:SetTextColor(color_white)

  self.infoAction = vgui.Create("DLabel", self)
  self.infoAction:SetText("Go look around the city, there's plenty missions to engage in!")
  self.infoAction:SizeToContents()
  self.infoAction:SetTextColor(color_white)
end

function PANEL:PerformLayout(width, height)
  local y = 12

  self.info:SetPos((width / 2) - (self.info:GetWide() / 2), y)
  y = y + self.info:GetTall()

  self.infoAction:SetPos((width / 2) - (self.infoAction:GetWide() / 2), y)
  y = y + self.infoAction:GetTall() + 14

  if (height ~= y) then
    self:SetTall(y)
  end
end

vgui.Register("versus_Missions_Empty", PANEL, "DPanel")
