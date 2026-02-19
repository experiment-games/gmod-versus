local UNIT = UNIT

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    -- Left side - Info will go here
    self.leftPanel = vgui.Create("EditablePanel", self)
    self.leftPanel:Dock(LEFT)

    self.centerPanel = vgui.Create("EditablePanel", self)
    self.centerPanel:Dock(FILL)

    self.model = vgui.Create("versus_Character_Model", self.centerPanel)

    -- Right side - Controls
    self.rightPanel = vgui.Create("EditablePanel", self)
    self.rightPanel:Dock(RIGHT)

    self.controlsList = vgui.Create("versus_ScrollPanel", self.rightPanel)
    self.controlsList:Dock(FILL)

    self.actionsPanel = vgui.Create("DSizeToContents", self.rightPanel)
    self.actionsPanel:SetSizeX(false)
    self.actionsPanel:Dock(BOTTOM)

    -- Initialize data
    self.models = versus.player.getDefaultModelList()
    self.sliders = {}
    self.chosenModel = 1
    self.chosenBodygroups = {}

    -- Appearance slider
    self.appearance = vgui.Create("versus_Character_Slider", self.controlsList)
    self.appearance:Dock(TOP)
    self.appearance:Setup(
      "APPEARANCE",
      UNIT.getBaseModelNameFromModel(self.models[self.chosenModel]),
      function()
        self.chosenModel = self.chosenModel - 1

        if self.chosenModel < 1 then
          self.chosenModel = #self.models
        end

        return self:UpdateModel()
      end,
      function()
        self.chosenModel = self.chosenModel + 1

        if self.chosenModel > #self.models then
          self.chosenModel = 1
        end

        return self:UpdateModel()
      end
    )

    -- Bodygroup sliders
    local defaultBodygroupOptions = versus.player.getDefaultBodygroupOptions()

    for bodygroupName, bodygroups in pairs(defaultBodygroupOptions) do
      local bodygroupKeys = table.GetKeys(bodygroups)
      local slider = vgui.Create("versus_Character_Slider", self.controlsList)
      slider:Setup(
        bodygroupName:upper(),
        self.model:UpdateBodygroup(bodygroups, bodygroupName),
        function()
          self.chosenBodygroups[bodygroupName] = math.Clamp(self.chosenBodygroups[bodygroupName] - 1, 1, #bodygroupKeys)
          return self.model:UpdateBodygroup(bodygroups, bodygroupName)
        end,
        function()
          self.chosenBodygroups[bodygroupName] = math.Clamp(self.chosenBodygroups[bodygroupName] + 1, 1, #bodygroupKeys)
          return self.model:UpdateBodygroup(bodygroups, bodygroupName)
        end
      )

      self.sliders[bodygroupName] = slider
    end

    self:Setup()

    -- Confirm button for new characters
    if (not GAMEMODE.playerInitialized) then
      self:RandomizeAppearance()

      self.randomizeBtn = vgui.Create("versus_Button", self.actionsPanel)
      self.randomizeBtn:Dock(TOP)
      self.randomizeBtn:SetText("RANDOMIZE")
      self.randomizeBtn:SetTextColor(Color(200, 220, 240))
      self.randomizeBtn.accentColor = Color(140, 100, 220)
      self.randomizeBtn.DoClick = function()
        self:RandomizeAppearance()
      end

      self.confirmBtn = vgui.Create("versus_Button", self.actionsPanel)
      self.confirmBtn:Dock(TOP)
      self.confirmBtn:DockMargin(0, 8, 0, 0)
      self.confirmBtn:SetText("CONFIRM CHARACTER")
      self.confirmBtn:SetTextColor(Color(220, 240, 220))
      self.confirmBtn.accentColor = Color(100, 200, 120)
      self.confirmBtn.DoClick = function()
        if GAMEMODE.playerInitialized then
          return
        end

        net.Start("versus.player.initializedAppearance")
        net.WriteBool(false)
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
      end
    else
      self.confirmBtn = vgui.Create("versus_Button", self.actionsPanel)
      self.confirmBtn:Dock(TOP)
      self.confirmBtn:DockMargin(0, 8, 0, 0)
      self.confirmBtn:SetText("SAVE CHARACTER")
      self.confirmBtn:SetTextColor(Color(220, 240, 220))
      self.confirmBtn.accentColor = Color(100, 200, 120)
      self.confirmBtn.DoClick = function()
        net.Start("versus.player.initializedAppearance")
        net.WriteBool(false)
        net.WriteString(self.models[self.chosenModel])
        net.WriteUInt(table.Count(defaultBodygroupOptions), 6)

        for bodygroupName, bodygroups in pairs(defaultBodygroupOptions) do
          local bodygroupKeys = table.GetKeys(bodygroups)
          local key = bodygroupKeys[self.chosenBodygroups[bodygroupName]]

          net.WriteString(bodygroupName)
          net.WriteUInt(key, 6)
        end

        net.SendToServer()

        versus.message.notify(
          "Your appearance will be updated the next time you spawn.",
          NOTIFY_GENERIC
        )
      end
    end

    -- Allow other systems to add panels to the sides
    hook.Run("VersusCharacterBuildLeftPanel", self.leftPanel, self)
    hook.Run("VersusCharacterBuildCenterPanel", self.centerPanel, self)
    hook.Run("VersusCharacterBuildRightPanel", self.rightPanel, self)
  end

  function PANEL:RandomizeAppearance()
    self.chosenModel = math.random(1, #self.models)

    local defaultBodygroupOptions = versus.player.getDefaultBodygroupOptions()

    for bodygroupName, bodygroups in pairs(defaultBodygroupOptions) do
      local bodygroupKeys = table.GetKeys(bodygroups)
      self.chosenBodygroups[bodygroupName] = math.random(1, #bodygroupKeys)

      if IsValid(self.sliders[bodygroupName]) then
        self.sliders[bodygroupName]:SetValue(self.model:UpdateBodygroup(bodygroups, bodygroupName))
      end
    end

    self.model:SetBodygroupsTable(self.chosenBodygroups)
    self.appearance:SetValue(self:UpdateModel())
  end

  function PANEL:Think()
    if UNIT.updateCharacterPanel then
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
      if LocalPlayer().appearanceModel == model then
        self.chosenModel = index
        break
      end
    end

    for bodygroupName, bodygroups in pairs(versus.player.getDefaultBodygroupOptions()) do
      local bodygroupKeys = table.GetKeys(bodygroups)
      self.chosenBodygroups[bodygroupName] = 1

      local currentBodygroup = LocalPlayer()["appearanceBodygroup_" .. bodygroupName]

      for i, key in pairs(bodygroupKeys) do
        if key == currentBodygroup then
          self.chosenBodygroups[bodygroupName] = i
          break
        end
      end

      if IsValid(self.sliders[bodygroupName]) then
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

    local gap = 12
    local splitRatio = 0.3

    local sideWidth = math.floor(width * splitRatio)
    self.leftPanel:SetWide(sideWidth - gap * 1.5)
    self.rightPanel:SetWide(sideWidth - gap * 1.5)

    self.model:StretchToParent(25, 25, 25, 25)
  end

  vgui.Register("versus_Character", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self.label = vgui.Create("DLabel", self)
    self.label:SetFont("VersusDefault")
    self.label:SetTextColor(Color(150, 170, 200, 255))

    self.value = vgui.Create("DLabel", self)
    self.value:SetFont("VersusDefaultOutlined")
    self.value:SetTextColor(Color(220, 230, 240, 255))

    self.buttonBack = vgui.Create("versus_Button", self)
    self.buttonBack:SetText("◄")
    self.buttonBack.accentColor = Color(80, 140, 220)

    self.buttonForward = vgui.Create("versus_Button", self)
    self.buttonForward:SetText("►")
    self.buttonForward.accentColor = Color(80, 140, 220)
  end

  function PANEL:SetValue(value)
    self.value:SetText(value or "")
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

  function PANEL:Paint(w, h)
    draw.RoundedBox(0, 0, 0, w, h, color_background)

    return true
  end

  function PANEL:PerformLayout(width, height)
    local padding = 16
    local btnSize = 44

    self.label:SetPos(padding, padding)
    self.label:SizeToContents()

    local valueY = padding + self.label:GetTall() + 12
    self.value:SizeToContents()
    self.value:SetPos((width - self.value:GetWide()) / 2, valueY)

    self.buttonBack:SetPos(padding, valueY - 4)
    self.buttonBack:SetSize(btnSize, btnSize)

    self.buttonForward:SetPos(width - padding - btnSize, valueY - 4)
    self.buttonForward:SetSize(btnSize, btnSize)

    local desiredHeight = valueY + btnSize + padding

    if height ~= desiredHeight then
      self:SetTall(desiredHeight)
    end
  end

  vgui.Register("versus_Character_Slider", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self.label = vgui.Create("DLabel", self)
    self.label:SetFont("VersusHeading3")
    self.label:SetTextColor(Color(200, 210, 230))

    self.button = vgui.Create("versus_Button", self)
  end

  function PANEL:Setup(label, buttonText, callback)
    self.label:SetText(label)
    self.label:SizeToContents()
    self.button:SetText(buttonText)
    self.button.DoClick = callback
  end

  function PANEL:Paint(w, h)
    draw.RoundedBox(0, 0, 0, w, h, Color(20, 28, 40, 200))
    return true
  end

  function PANEL:PerformLayout(width, height)
    local padding = 12

    self.label:SetPos(padding, padding)
    self.label:SizeToContents()

    local btnY = padding + self.label:GetTall() + 8

    self.button:SetPos(padding, btnY)
    self.button:SetSize(width - padding * 2, 44)

    local desiredHeight = btnY + 44 + padding

    if height ~= desiredHeight then
      self:SetTall(desiredHeight)
    end
  end

  vgui.Register("versus_Character_Confirm", PANEL, "EditablePanel")
end

-- Autorefresh the menu on save
if versus.menu and IsValid(versus.menu.panel) then
  versus.menu.panel:Remove()
end
