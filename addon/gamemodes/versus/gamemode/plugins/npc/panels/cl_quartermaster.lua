local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    PLUGIN.quartermasterPanel = self

    self:SetSize(
      math.max(ScrW() * 0.5, 700),
      ScrH()
    )

    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha = 0
    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    self.contentPanel = vgui.Create("EditablePanel", self)
    self.contentPanel:DockPadding(
      GAMEMODE.SPACING,
      GAMEMODE.SPACING,
      GAMEMODE.SPACING,
      GAMEMODE.SPACING
    )

    self.titleLabel = vgui.Create("DLabel", self.contentPanel)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("RESISTANCE QUARTERMASTER")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    -- Story/dialogue text
    self.dialogueLabel = vgui.Create("DLabel", self.contentPanel)
    self.dialogueLabel:SetFont("VersusDefault")
    self.dialogueLabel:SetTextColor(Color(180, 190, 200, 255))
    self.dialogueLabel:SetText(
      "Welcome to the Resistance. We're spread thin, but we can at least equip you with the basics.\n\n" ..
      "The Combine won't go easy on you, so make every shot count. Once you've taken your equipment, " ..
      "you'll need to wait before we can supply you again. Stay sharp out there."
    )
    self.dialogueLabel:SetWrap(true)
    self.dialogueLabel:SetAutoStretchVertical(true)
    self.dialogueLabel:Dock(TOP)
    self.dialogueLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Equipment info panel
    self.equipmentPanel = vgui.Create("EditablePanel", self.contentPanel)
    self.equipmentPanel:Dock(TOP)
    self.equipmentPanel:SetTall(230)
    self.equipmentPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Equipment title
    local equipTitle = vgui.Create("DLabel", self.equipmentPanel)
    equipTitle:SetFont("VersusHeading2")
    equipTitle:SetTextColor(Color(200, 210, 220, 255))
    equipTitle:SetText("STARTER EQUIPMENT")
    equipTitle:SizeToContents()
    equipTitle:Dock(TOP)
    equipTitle:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    -- Equipment items container
    local itemsContainer = vgui.Create("EditablePanel", self.equipmentPanel)
    itemsContainer:Dock(TOP)
    itemsContainer:SetTall(230 - equipTitle:GetTall() - GAMEMODE.SPACING * 0.5)

    -- Get item definitions
    local pistolItem = versus.item.get("#cw2_versus_cw_fiveseven")
    local ammoItem = versus.item.get("ammo_57x28")

    if pistolItem then
      local pistolPanel = vgui.Create("DSizeToContents", itemsContainer)
      pistolPanel:Dock(LEFT)
      pistolPanel:SetSizeX(false)
      pistolPanel:SetWide(128)
      pistolPanel:SetVersusTooltip(function(tooltip)
        local description = tooltip:AddRow("description")
        description:SetText(pistolItem.description)
        description:SizeToContents()
      end)

      local pistolModel = vgui.Create("versus_ItemModelPanel", pistolPanel)
      pistolModel:SetItem(pistolItem)
      pistolModel:SetFOV(pistolItem.inventoryFov or 80)
      pistolModel:SetSize(128, 128)
      pistolModel:Dock(TOP)
      pistolModel:SetAmbientLight(Color(200, 200, 200, 255))
      pistolModel:SetMouseInputEnabled(false)

      local pistolLabel = vgui.Create("DLabel", pistolPanel)
      pistolLabel:SetFont("VersusDefaultOutlined")
      pistolLabel:SetTextColor(Color(200, 210, 220, 255))
      pistolLabel:SetText(pistolItem.name)
      pistolLabel:Dock(TOP)
      pistolLabel:DockMargin(0, 4, 0, 0)
      pistolLabel:SizeToContents()
    end

    if ammoItem then
      local ammoPanel = vgui.Create("DSizeToContents", itemsContainer)
      ammoPanel:Dock(LEFT)
      ammoPanel:SetSizeX(false)
      ammoPanel:SetWide(128)
      ammoPanel:SetVersusTooltip(function(tooltip)
        local description = tooltip:AddRow("description")
        description:SetText(ammoItem.description)
        description:SizeToContents()
      end)

      local ammoModel = vgui.Create("versus_ItemModelPanel", ammoPanel)
      ammoModel:SetItem(ammoItem)
      ammoModel:SetFOV(ammoItem.inventoryFov or 80)
      ammoModel:SetSize(128, 128)
      ammoModel:Dock(TOP)
      ammoModel:SetAmbientLight(Color(200, 200, 200, 255))
      ammoModel:SetMouseInputEnabled(false)

      local ammoLabel = vgui.Create("DLabel", ammoPanel)
      ammoLabel:SetFont("VersusDefaultOutlined")
      ammoLabel:SetTextColor(Color(200, 210, 220, 255))
      ammoLabel:SetText(ammoItem.name)
      ammoLabel:Dock(TOP)
      ammoLabel:DockMargin(0, 4, 0, 0)
      ammoLabel:SizeToContents()
    end

    -- Status container
    self.statusContainer = vgui.Create("EditablePanel", self.contentPanel)
    self.statusContainer:Dock(TOP)
    self.statusContainer:SetTall(50)
    self.statusContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Bottom button container
    local buttonContainer = vgui.Create("EditablePanel", self.contentPanel)
    buttonContainer:Dock(BOTTOM)
    buttonContainer:SetTall(50)

    -- Claim button
    self.claimButton = vgui.Create("versus_Button", buttonContainer)
    self.claimButton:SetText("CLAIM EQUIPMENT")
    self.claimButton:Dock(LEFT)
    self.claimButton:SetWide(300)
    self.claimButton:DockMargin(0, 0, GAMEMODE.SPACING, 0)
    self.claimButton:SetType("primary")
    self.claimButton.DoClick = function()
      self:ClaimEquipment()
    end

    -- Close button
    self.cancelButton = vgui.Create("versus_Button", buttonContainer)
    self.cancelButton:SetText("CLOSE")
    self.cancelButton:Dock(FILL)
    self.cancelButton:SetType("secondary")
    self.cancelButton.DoClick = function()
      self:Close()
    end
  end

  function PANEL:Populate()
    -- Check if player has already claimed
    net.Start("versus.npc.checkStarterKit")
    net.SendToServer()
  end

  function PANEL:UpdateStatus(canNotClaim, hasWeapon, onCooldown, timeRemaining)
    self.canNotClaim = canNotClaim
    self.hasWeapon = hasWeapon
    self.onCooldown = onCooldown
    self.timeRemaining = timeRemaining
    self.statusReceivedTime = CurTime()

    -- Clear previous status
    self.statusContainer:Clear()

    if canNotClaim then
      local statusLabel = vgui.Create("DLabel", self.statusContainer)
      statusLabel:SetFont("VersusDefault")
      statusLabel:SetTextColor(Color(255, 100, 100, 255))

      local statusText = ""
      if hasWeapon then
        statusText = "You already have a weapon in your inventory."
      elseif onCooldown and timeRemaining > 0 then
        local hours = math.floor(timeRemaining / 3600)
        local minutes = math.floor((timeRemaining % 3600) / 60)
        local seconds = timeRemaining % 60

        local timeStr = ""
        if hours > 0 then
          timeStr = string.format("%dh %dm %ds", hours, minutes, seconds)
        elseif minutes > 0 then
          timeStr = string.format("%dm %ds", minutes, seconds)
        else
          timeStr = string.format("%ds", seconds)
        end

        statusText = string.format("You've already claimed equipment. Time remaining: %s", timeStr)
      else
        statusText = "You cannot claim equipment at this time."
      end

      statusLabel:SetText(statusText)
      statusLabel:SizeToContents()
      statusLabel:Dock(TOP)

      self.statusLabel = statusLabel

      self.claimButton:SetEnabled(false)
      self.claimButton:SetText("CANNOT CLAIM")
    else
      local statusLabel = vgui.Create("DLabel", self.statusContainer)
      statusLabel:SetFont("VersusDefault")
      statusLabel:SetTextColor(Color(100, 255, 150, 255))
      statusLabel:SetText("Equipment ready for pickup. This can be claimed once every hour if you have no weapons.")
      statusLabel:SizeToContents()
      statusLabel:Dock(TOP)

      self.statusLabel = statusLabel

      self.claimButton:SetEnabled(true)
      self.claimButton:SetText("CLAIM EQUIPMENT")
    end
  end

  function PANEL:ClaimEquipment()
    if self.canNotClaim then
      versus.message.notify("You cannot claim equipment right now!", NOTIFY_ERROR)
      return
    end

    -- Send claim request to server
    net.Start("versus.npc.claimStarterKit")
    net.SendToServer()

    surface.PlaySound("buttons/button14.wav")
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    -- Fade in animation
    if not self.closing then
      if elapsed < self.animDuration then
        local progress = elapsed / self.animDuration
        progress = math.ease.InOutQuad(progress)

        self.bgAlpha = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha = 200
        self.contentAlpha = 255
      end

      -- Update countdown timer if on cooldown
      if self.onCooldown and self.statusReceivedTime and self.statusLabel and IsValid(self.statusLabel) then
        self.nextCountdownUpdate = self.nextCountdownUpdate or 0

        if CurTime() >= self.nextCountdownUpdate then
          self.nextCountdownUpdate = CurTime() + 1 -- Update every second

          local elapsedSinceReceived = math.floor(CurTime() - self.statusReceivedTime)
          local currentTimeRemaining = math.max(0, self.timeRemaining - elapsedSinceReceived)

          if currentTimeRemaining > 0 then
            local hours = math.floor(currentTimeRemaining / 3600)
            local minutes = math.floor((currentTimeRemaining % 3600) / 60)
            local seconds = currentTimeRemaining % 60

            local timeStr = ""
            if hours > 0 then
              timeStr = string.format("%dh %dm %ds", hours, minutes, seconds)
            elseif minutes > 0 then
              timeStr = string.format("%dm %ds", minutes, seconds)
            else
              timeStr = string.format("%ds", seconds)
            end

            self.statusLabel:SetText(string.format("You've already claimed equipment. Time remaining: %s", timeStr))
            self.statusLabel:SizeToContents()
          else
            -- Cooldown expired, request fresh status
            net.Start("versus.npc.checkStarterKit")
            net.SendToServer()
          end
        end
      end
    else
      -- Fade out animation
      local closeElapsed = CurTime() - self.closeStart
      if closeElapsed < 0.3 then
        local progress = 1 - (closeElapsed / 0.3)
        self.bgAlpha = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self:Remove()
      end
    end

    self:SetAlpha(self.contentAlpha)
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)

    -- Dark overlay background
    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self.contentPanel:SetWide(self:GetWide() - GAMEMODE.SPACING * 2)
    self.contentPanel:SetTall(h)
    self.contentPanel:Center()

    self:Center()
  end

  vgui.Register("versus_Quartermaster", PANEL, "EditablePanel")
end

net.Receive("versus.npc.starterKitStatus", function()
  local canNotClaim = net.ReadBool()
  local hasWeapon = net.ReadBool()
  local onCooldown = net.ReadBool()
  local timeRemaining = net.ReadUInt(32)

  if IsValid(PLUGIN.quartermasterPanel) then
    PLUGIN.quartermasterPanel:UpdateStatus(canNotClaim, hasWeapon, onCooldown, timeRemaining)
  end
end)

net.Receive("versus.npc.starterKitClaimed", function()
  if IsValid(PLUGIN.quartermasterPanel) then
    PLUGIN.quartermasterPanel:UpdateStatus(true, false, true, 3600)
    versus.message.notify("Equipment claimed! Check your inventory.", NOTIFY_SUCCESS)
  end
end)
