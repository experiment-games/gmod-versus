local UNIT = UNIT
local PANEL = {}
local g_Team = team

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self:SetSize(versus.menu.width, versus.menu.height - 8)

  -- Create a panel list to store the items.
  self.itemsList = vgui.Create("DPanelList", self)
  self.itemsList:SizeToContents()
  self.itemsList:SetPadding(2)
  self.itemsList:SetSpacing(3)
  self.itemsList:Dock(TOP)

  -- TODO: Create a single apply changes button that changes all this
  self.name = vgui.Create("versus_Character_TextEntry", self)
  self.name:Setup("Character name", LocalPlayer():GetNWString("versus_Name", UNIT.getRandomName()), "Change", function()
    versus.command.run("name", self.name.textEntry:GetValue())
  end)
  self.itemsList:AddItem(self.name)

  -- These "Change" buttons wont work pre-initialization as commands are blocked
  if (not GAMEMODE.playerInitialized) then
    self.name.button:SetVisible(false)
  end

  local halfWidth = versus.menu.width * .5

  self.body = vgui.Create("DPanel", self)
  self.body:SizeToContents()

  self.model = vgui.Create("versus_Character_Model", self.body)

  self.bodyActionList = vgui.Create("DPanelList", self.body)
  self.bodyActionList:SizeToContents()
  self.bodyActionList:SetPadding(8)
  self.bodyActionList:SetSpacing(6)
  self.bodyActionList:Dock(RIGHT)
  self.bodyActionList:EnableVerticalScrollbar()

  self.models = versus.player.getDefaultModelList()
  self.sliders = {}
  self.chosenModel = 1
  self.chosenBodygroups = {}

  self.appearance = vgui.Create("versus_Character_Slider", self)
  self.appearance:Setup("Appearance", UNIT.getBaseModelNameFromModel(self.models[self.chosenModel]),
    function()
      self.chosenModel = math.Clamp(self.chosenModel - 1, 1, #self.models)

      return self:UpdateModel()
    end,
    function()
      self.chosenModel = math.Clamp(self.chosenModel + 1, 1, #self.models)

      return self:UpdateModel()
    end)
  self.bodyActionList:AddItem(self.appearance)

  self:Setup()

  local defaultBodygroupOptions = versus.player.getDefaultBodygroupOptions()

  for bodygroupName, bodygroups in pairs(defaultBodygroupOptions) do
    local bodygroupKeys = table.GetKeys(bodygroups)
    local slider = vgui.Create("versus_Character_Slider", self)
    slider:Setup(bodygroupName:gsub("^%l", string.upper), self.model:UpdateBodygroup(bodygroups, bodygroupName),
      function()
        self.chosenBodygroups[bodygroupName] = math.Clamp(self.chosenBodygroups[bodygroupName] - 1, 1, #bodygroupKeys)

        return self.model:UpdateBodygroup(bodygroups, bodygroupName)
      end,
      function()
        self.chosenBodygroups[bodygroupName] = math.Clamp(self.chosenBodygroups[bodygroupName] + 1, 1, #bodygroupKeys)

        return self.model:UpdateBodygroup(bodygroups, bodygroupName)
      end)
    self.bodyActionList:AddItem(slider)

    self.sliders[bodygroupName] = slider
  end

  if (not GAMEMODE.playerInitialized) then
    self:RandomizeAppearance()

    self.confirm = vgui.Create("versus_Character_Confirm", self)
    self.confirm:Setup(
      "Are you sure?",
      "Yes, create this character",
      function()
        if (GAMEMODE.playerInitialized) then
          MsgN("TODO!") -- TODO: Create common save button instead of separate ones
          -- RunConsoleCommand(
          --   "versus",
          --   "appearance",
          --   self.models[self.chosenModel],
          --   self.chosenBodygroups["torso"],
          --   self.chosenBodygroups["legs"])
          return
        end

        net.Start("versus.player.initializedAppearance")
        net.WriteBool(false)
        net.WriteString(self.name.textEntry:GetValue())
        net.WriteString(self.models[self.chosenModel])
        net.WriteUInt(table.Count(defaultBodygroupOptions), 6)

        for bodygroupName, bodygroups in pairs(defaultBodygroupOptions) do
          local bodygroupKeys = table.GetKeys(bodygroups)
          local key = bodygroupKeys[self.chosenBodygroups[bodygroupName]]

          net.WriteString(bodygroupName)
          net.WriteUInt(key, 6)
        end

        net.SendToServer()

        self.parentMenu:Close()
      end)
  end
end

function PANEL:RandomizeAppearance()
  self.chosenModel = math.random(1, #self.models)

  local defaultBodygroupOptions = versus.player.getDefaultBodygroupOptions()

  for bodygroupName, bodygroups in pairs(defaultBodygroupOptions) do
    local bodygroupKeys = table.GetKeys(bodygroups)
    self.chosenBodygroups[bodygroupName] = math.random(1, #bodygroupKeys)

    if (IsValid(self.sliders[bodygroupName])) then
      self.sliders[bodygroupName]:SetValue(self.model:UpdateBodygroup(bodygroups, bodygroupName))
    end
  end

  self.model:SetBodygroupsTable(self.chosenBodygroups)
  self.appearance:SetValue(self:UpdateModel())
end

function PANEL:Think()
  if (UNIT.updateCharacterPanel) then
    UNIT.updateCharacterPanel = false

    self:UpdateModel()
  end
end

function PANEL:OnMenuShown()
  self:Setup()
end

function PANEL:Setup()
  self.chosenModel = 1
  self.chosenBodygroups = {}

  for index, model in pairs(self.models) do
    if (LocalPlayer().appearanceModel == model) then
      self.chosenModel = index
      break
    end
  end

  for bodygroupName, bodygroups in pairs(versus.player.getDefaultBodygroupOptions()) do
    local bodygroupKeys = table.GetKeys(bodygroups)
    self.chosenBodygroups[bodygroupName] = 1

    local currentBodygroup = LocalPlayer()["appearanceBodygroup_" .. bodygroupName]

    for i, key in pairs(bodygroupKeys) do
      if (key == currentBodygroup) then
        self.chosenBodygroups[bodygroupName] = i
        break
      end
    end

    if (IsValid(self.sliders[bodygroupName])) then
      self.sliders[bodygroupName]:SetValue(self.model:UpdateBodygroup(bodygroups, bodygroupName))
    end
  end

  self.model:SetBodygroupsTable(self.chosenBodygroups)
  self.appearance:SetValue(self:UpdateModel())
end

function PANEL:UpdateModel()
  return self.model:UpdateModel(self.models[self.chosenModel])
end

function PANEL:PerformLayout(width, height)
  self:StretchToParent(0, 22, 0, 0)

  local itemListHeight = self.itemsList:GetPadding()

  for _, pnl in pairs(self.itemsList:GetItems()) do
    itemListHeight = itemListHeight + pnl:GetTall() + self.itemsList:GetSpacing()
  end

  self.itemsList:SetTall(itemListHeight)
  self.body:StretchToParent(2, self.itemsList.x + itemListHeight, 2, 2)
  self.bodyActionList:SetWide(width * .5 - 16)

  if (not GAMEMODE.playerInitialized) then
    self.confirm:SetWide(self.appearance:GetWide())
    self.confirm:SetPos(self.appearance.x + self.bodyActionList.x, height - 8 - self.confirm:GetTall())
  end
end

vgui.Register("versus_Character", PANEL, "Panel")

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.label = vgui.Create("DLabel", self)
  self.label:SizeToContents()
  self.label:SetTextColor(color_white)
  self.textEntry = vgui.Create("DTextEntry", self)

  self.button = vgui.Create("DButton", self)
end

function PANEL:Setup(label, defaultValue, buttonText, buttonCallback)
  self.label:SetText(label)
  self.label:SizeToContents()
  self.textEntry:SetText(defaultValue or "")
  self.button:SetText(buttonText)
  self.button.DoClick = buttonCallback
end

function PANEL:PerformLayout()
  self.label:SetPos(8, 5)
  self.label:SizeToContents()

  if (self.button:IsVisible()) then
    self.button:SizeToContents()
    self.button:SetTall(16)
    self.button:SetWide(self.button:GetWide() + 16)
    self.textEntry:SetSize(self:GetWide() - self.button:GetWide() - self.label:GetWide() - 32, 16)
  else
    self.textEntry:SetSize(self:GetWide() - self.label:GetWide() - 24, 16)
  end
  self.textEntry:SetPos(self.label.x + self.label:GetWide() + 8, 5)
  self.button:SetPos(self.textEntry.x + self.textEntry:GetWide() + 8, 5)
end

vgui.Register("versus_Character_TextEntry", PANEL, "DPanel")

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.label = vgui.Create("DLabel", self)
  self.label:SizeToContents()
  self.label:SetFont("Trebuchet18")
  self.label:SetTextColor(color_white)
  self.value = vgui.Create("DLabel", self)
  self.value:SizeToContents()
  self.value:SetTextColor(color_white)

  self.buttonBack = vgui.Create("DButton", self)
  self.buttonBack:SetText("◄")
  self.buttonForward = vgui.Create("DButton", self)
  self.buttonForward:SetText("►")
end

function PANEL:SetValue(value)
  self.value:SetText(value)
  self.value:SizeToContents()
end

function PANEL:Setup(label, defaultValue, backCallback, forwardCallback)
  self.label:SetText(label)
  self.label:SizeToContents()
  self:SetValue(defaultValue)
  self.buttonBack.DoClick = function()
    self.value:SetText(backCallback() or "")
    self.value:SizeToContents()
  end
  self.buttonForward.DoClick = function()
    self.value:SetText(forwardCallback() or "")
    self.value:SizeToContents()
  end
end

function PANEL:PerformLayout(width, height)
  self.label:SetPos(8, 5)
  self.label:SizeToContents()

  local y = self.label.x + self.label:GetTall() + 6
  self.value:SizeToContents()
  self.value:SetPos((width * .5) - (self.value:GetWide() * .5), y)

  self.buttonBack:SetPos(8, y)
  self.buttonBack:SetSize(16, 16)
  self.buttonForward:SetPos(width - 8 - self.buttonForward:GetWide(), y)
  self.buttonForward:SetSize(16, 16)

  local desiredHeight = y + 16 + 8

  if (height ~= desiredHeight) then
    self:SetTall(desiredHeight)
  end
end

vgui.Register("versus_Character_Slider", PANEL, "DPanel")

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.label = vgui.Create("DLabel", self)
  self.label:SizeToContents()
  self.label:SetFont("Trebuchet18")
  self.label:SetTextColor(color_white)

  self.button = vgui.Create("DButton", self)
  self.button:SetText("")
end

function PANEL:Setup(label, buttonText, callback)
  self.label:SetText(label)
  self.label:SizeToContents()
  self.button:SetText(buttonText)
  self.button.DoClick = function()
    callback()
  end
end

function PANEL:PerformLayout(width, height)
  self.label:SetPos(8, 5)
  self.label:SizeToContents()

  local y = self.label.x + self.label:GetTall() + 4

  self.button:SetPos(8, y)
  self.button:SizeToContents()
  self.button:SetWide(width - 16)

  local desiredHeight = y + 16 + 8

  if (height ~= desiredHeight) then
    self:SetTall(desiredHeight)
  end
end

vgui.Register("versus_Character_Confirm", PANEL, "DPanel")

-- Autorefresh the menu on save
if (versus.menu and IsValid(versus.menu.panel)) then
  versus.menu.panel:Remove()
end
