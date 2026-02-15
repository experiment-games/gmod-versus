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
    self.equipmentPanel = vgui.Create("DSizeToContents", self.contentPanel)
    self.equipmentPanel:Dock(TOP)
    self.equipmentPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.equipmentPanel:SetSizeX(false)

    -- Equipment title
    self.equipTitle = vgui.Create("DLabel", self.equipmentPanel)
    self.equipTitle:SetFont("VersusHeading2")
    self.equipTitle:SetTextColor(Color(200, 210, 220, 255))
    self.equipTitle:SetText("STARTER EQUIPMENT")
    self.equipTitle:SizeToContents()
    self.equipTitle:Dock(TOP)
    self.equipTitle:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    -- Equipment items container
    self.itemsContainer = vgui.Create("EditablePanel", self.equipmentPanel)
    self.itemsContainer:Dock(TOP)

    -- Get item definitions
    self.pistolItem = versus.item.get("#cw2_versus_cw_fiveseven")
    self.ammoItem = versus.item.get("ammo_57x28")

    if self.pistolItem then
      self.pistolContainer = vgui.Create("DSizeToContents", self.itemsContainer)
      self.pistolContainer:SetSizeX(false)
      self.pistolContainer:SetVersusTooltip(function(tooltip)
        local description = tooltip:AddRow("description")
        description:SetText(self.pistolItem.description)
        description:SizeToContents()
      end)

      local pistolModel = vgui.Create("versus_ItemModelPanel", self.pistolContainer)
      pistolModel:SetItem(self.pistolItem)
      pistolModel:SetFOV(self.pistolItem.inventoryFov or 80)
      pistolModel:SetSize(128, 128)
      pistolModel:Dock(TOP)
      pistolModel:SetAmbientLight(Color(200, 200, 200, 255))
      pistolModel:SetMouseInputEnabled(false)

      local pistolLabel = vgui.Create("DLabel", self.pistolContainer)
      pistolLabel:SetFont("VersusDefaultOutlined")
      pistolLabel:SetTextColor(Color(200, 210, 220, 255))
      pistolLabel:SetText(self.pistolItem.name)
      pistolLabel:Dock(TOP)
      pistolLabel:DockMargin(0, 4, 0, 0)
      pistolLabel:SetContentAlignment(5)
      pistolLabel:SizeToContents()

      self.claimPistolButton = vgui.Create("versus_Button", self.pistolContainer)
      self.claimPistolButton:SetText("CLAIM PISTOL")
      self.claimPistolButton:Dock(TOP)
      self.claimPistolButton:SetTall(40)
      self.claimPistolButton:DockMargin(0, GAMEMODE.SPACING, 0, 0)
      self.claimPistolButton:SetType("primary")
      self.claimPistolButton.DoClick = function()
        self:ClaimEquipment("pistol")
      end
    end

    if self.ammoItem then
      self.ammoContainer = vgui.Create("DSizeToContents", self.itemsContainer)
      self.ammoContainer:SetSizeX(false)
      self.ammoContainer:SetVersusTooltip(function(tooltip)
        local description = tooltip:AddRow("description")
        description:SetText(self.ammoItem.description)
        description:SizeToContents()
      end)

      local ammoModel = vgui.Create("versus_ItemModelPanel", self.ammoContainer)
      ammoModel:SetItem(self.ammoItem)
      ammoModel:SetFOV(self.ammoItem.inventoryFov or 80)
      ammoModel:SetSize(128, 128)
      ammoModel:Dock(TOP)
      ammoModel:SetAmbientLight(Color(200, 200, 200, 255))
      ammoModel:SetMouseInputEnabled(false)

      local ammoLabel = vgui.Create("DLabel", self.ammoContainer)
      ammoLabel:SetFont("VersusDefaultOutlined")
      ammoLabel:SetTextColor(Color(200, 210, 220, 255))
      ammoLabel:SetText(self.ammoItem.name)
      ammoLabel:Dock(TOP)
      ammoLabel:DockMargin(0, 4, 0, 0)
      ammoLabel:SetContentAlignment(5)
      ammoLabel:SizeToContents()

      self.claimAmmoButton = vgui.Create("versus_Button", self.ammoContainer)
      self.claimAmmoButton:SetText("CLAIM AMMO")
      self.claimAmmoButton:Dock(TOP)
      self.claimAmmoButton:SetTall(40)
      self.claimAmmoButton:DockMargin(0, GAMEMODE.SPACING, 0, 0)
      self.claimAmmoButton:SetType("primary")
      self.claimAmmoButton.DoClick = function()
        self:ClaimEquipment("ammo")
      end
    end

    -- Claim both button
    self.claimBothButton = vgui.Create("versus_Button", self.equipmentPanel)
    self.claimBothButton:SetText("CLAIM BOTH")
    self.claimBothButton:Dock(TOP)
    self.claimBothButton:SetTall(40)
    self.claimBothButton:DockMargin(0, GAMEMODE.SPACING * .5, 0, GAMEMODE.SPACING * .5)
    self.claimBothButton:SetType("primary")
    self.claimBothButton.DoClick = function()
      self:ClaimEquipment("both")
    end

    -- Status container
    self.statusContainer = vgui.Create("DSizeToContents", self.contentPanel)
    self.statusContainer:Dock(TOP)
    self.statusContainer:SetSizeX(false)
    self.statusContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Bottom button container
    local buttonContainer = vgui.Create("DSizeToContents", self.contentPanel)
    buttonContainer:Dock(BOTTOM)
    buttonContainer:SetSizeX(false)

    -- Close button
    self.cancelButton = vgui.Create("versus_Button", buttonContainer)
    self.cancelButton:SetText("CLOSE")
    self.cancelButton:Dock(TOP)
    self.cancelButton:SetTall(40)
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

  function PANEL:UpdateStatus(canNotClaim, hasWeapon, onCooldown, timeRemaining, canClaimAmmoOnly, hasAmmo)
    self.canNotClaim = canNotClaim
    self.hasWeapon = hasWeapon
    self.onCooldown = onCooldown
    self.timeRemaining = timeRemaining
    self.canClaimAmmoOnly = canClaimAmmoOnly
    self.hasAmmo = hasAmmo
    self.statusReceivedTime = CurTime()

    -- Clear previous status
    self.statusContainer:Clear()

    -- Determine what can be claimed
    local canClaimPistol = not hasWeapon and not onCooldown
    local canClaimAmmo = not hasAmmo and not onCooldown
    local canClaimBoth = canClaimPistol and canClaimAmmo

    -- Update button states
    if IsValid(self.claimPistolButton) then
      self.claimPistolButton:SetEnabled(canClaimPistol)
    end
    if IsValid(self.claimAmmoButton) then
      self.claimAmmoButton:SetEnabled(canClaimAmmo)
    end
    if IsValid(self.claimBothButton) then
      self.claimBothButton:SetEnabled(canClaimBoth)
    end

    -- Status message
    local statusLabel = vgui.Create("DLabel", self.statusContainer)
    statusLabel:SetContentAlignment(5)
    statusLabel:SetFont("VersusDefault")

    if onCooldown and timeRemaining > 0 then
      statusLabel:SetTextColor(Color(255, 100, 100, 255))
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

      statusLabel:SetText(string.format("You've already claimed equipment. Time remaining: %s", timeStr))
    elseif hasWeapon and hasAmmo then
      statusLabel:SetTextColor(Color(255, 100, 100, 255))
      statusLabel:SetText("You already have a weapon and ammo.")
    elseif canClaimBoth then
      statusLabel:SetTextColor(Color(100, 255, 150, 255))
      statusLabel:SetText("Equipment ready for pickup. Claim pistol, ammo, or both.")
    elseif canClaimPistol then
      statusLabel:SetTextColor(Color(100, 255, 150, 255))
      statusLabel:SetText("Pistol available for claim.")
    elseif canClaimAmmo then
      statusLabel:SetTextColor(Color(100, 255, 150, 255))
      statusLabel:SetText("Ammo available for claim.")
    else
      statusLabel:SetTextColor(Color(255, 100, 100, 255))
      statusLabel:SetText("No equipment available to claim at this time.")
    end

    statusLabel:SizeToContents()
    statusLabel:Dock(TOP)
    self.statusLabel = statusLabel
  end

  function PANEL:ClaimEquipment(claimType)
    -- Send claim request to server with type
    net.Start("versus.npc.claimStarterKit")
    net.WriteString(claimType or "both")
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

    -- Size pistol and ammo containers equally
    local containerWidth = self.itemsContainer:GetWide()
    local halfWidth = (containerWidth - GAMEMODE.SPACING) / 2
    self.pistolContainer:SetWide(halfWidth)
    self.ammoContainer:SetWide(halfWidth)
    self.ammoContainer:SetX(self.pistolContainer:GetWide() + GAMEMODE.SPACING)

    self.itemsContainer:SetTall(
      math.max(
        self.pistolContainer:GetTall(),
        self.ammoContainer:GetTall()
      )
    )
  end

  vgui.Register("versus_Quartermaster", PANEL, "EditablePanel")
end

net.Receive("versus.npc.starterKitStatus", function()
  local canNotClaim = net.ReadBool()
  local hasWeapon = net.ReadBool()
  local onCooldown = net.ReadBool()
  local timeRemaining = net.ReadUInt(32)
  local canClaimAmmoOnly = net.ReadBool()
  local hasAmmo = net.ReadBool()

  if IsValid(PLUGIN.quartermasterPanel) then
    PLUGIN.quartermasterPanel:UpdateStatus(canNotClaim, hasWeapon, onCooldown, timeRemaining, canClaimAmmoOnly, hasAmmo)
  end
end)

net.Receive("versus.npc.starterKitClaimed", function()
  local claimType = net.ReadString()
  local hasWeapon = net.ReadBool()
  local hasAmmo = net.ReadBool()

  if IsValid(PLUGIN.quartermasterPanel) then
    -- Update status with new state
    PLUGIN.quartermasterPanel:UpdateStatus(true, hasWeapon, true, 3600, false, hasAmmo)

    if claimType == "pistol" then
      versus.message.notify("Pistol claimed! Check your inventory.", NOTIFY_SUCCESS)
    elseif claimType == "ammo" then
      versus.message.notify("Ammo claimed! Check your inventory.", NOTIFY_SUCCESS)
    else
      versus.message.notify("Equipment claimed! Check your inventory.", NOTIFY_SUCCESS)
    end
  end
end)
