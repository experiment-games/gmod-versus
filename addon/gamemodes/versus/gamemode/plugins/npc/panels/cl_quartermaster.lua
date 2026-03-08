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

    -- Build item panels dynamically from config
    self.kitItems = {} -- ordered list: { id, item, container, button }
    local kitConfig = versus.config["Starter Kit Items"] or {}
    for itemID, _ in pairs(kitConfig) do
      local item = versus.item.get(itemID)
      if item then
        local container = vgui.Create("DSizeToContents", self.itemsContainer)
        container:SetSizeX(false)
        container:SetVersusTooltip(function(tooltip)
          local description = tooltip:AddRow("description")
          description:SetText(versus.util.resolve(item.description))
          description:SizeToContents()
        end)

        local modelPanel = vgui.Create("versus_ItemModelPanel", container)
        modelPanel:SetItem(item)
        modelPanel:SetFOV(item.inventoryFov or 80)
        modelPanel:SetSize(128, 128)
        modelPanel:Dock(TOP)
        modelPanel:SetAmbientLight(Color(200, 200, 200, 255))
        modelPanel:SetMouseInputEnabled(false)

        local nameLabel = vgui.Create("DLabel", container)
        nameLabel:SetFont("VersusDefaultOutlined")
        nameLabel:SetTextColor(Color(200, 210, 220, 255))
        nameLabel:SetText(item.name)
        nameLabel:Dock(TOP)
        nameLabel:DockMargin(0, 4, 0, 0)
        nameLabel:SetContentAlignment(5)
        nameLabel:SizeToContents()

        local claimButton = vgui.Create("versus_Button", container)
        claimButton:SetText("CLAIM " .. string.upper(item.name))
        claimButton:Dock(TOP)
        claimButton:SetTall(40)
        claimButton:DockMargin(0, GAMEMODE.SPACING, 0, 0)
        claimButton:SetType("primary")
        claimButton.DoClick = function()
          self:ClaimEquipment(itemID)
        end

        table.insert(self.kitItems, { id = itemID, item = item, container = container, button = claimButton })
      end
    end

    -- Claim all button
    self.claimAllButton = vgui.Create("versus_Button", self.equipmentPanel)
    self.claimAllButton:SetText("CLAIM ALL")
    self.claimAllButton:Dock(TOP)
    self.claimAllButton:SetTall(40)
    self.claimAllButton:DockMargin(0, GAMEMODE.SPACING * .5, 0, GAMEMODE.SPACING * .5)
    self.claimAllButton:SetType("primary")
    self.claimAllButton.DoClick = function()
      self:ClaimEquipment("all")
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

  function PANEL:UpdateStatus(onCooldown, timeRemaining, itemStatus)
    self.onCooldown = onCooldown
    self.timeRemaining = timeRemaining
    self.itemStatus = itemStatus
    self.statusReceivedTime = CurTime()

    -- Clear previous status
    self.statusContainer:Clear()

    -- Update per-item button states and check if anything can be claimed
    local canClaimAny = false
    for _, kitItem in ipairs(self.kitItems) do
      local hasItem = itemStatus[kitItem.id] or false
      local canClaim = not hasItem and not onCooldown
      if canClaim then canClaimAny = true end
      if IsValid(kitItem.button) then
        kitItem.button:SetEnabled(canClaim)
      end
    end

    if IsValid(self.claimAllButton) then
      self.claimAllButton:SetEnabled(canClaimAny)
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
    elseif not canClaimAny then
      statusLabel:SetTextColor(Color(255, 100, 100, 255))
      statusLabel:SetText("No equipment available to claim at this time.")
    else
      statusLabel:SetTextColor(Color(100, 255, 150, 255))
      statusLabel:SetText("Equipment ready for pickup.")
    end

    statusLabel:SizeToContents()
    statusLabel:Dock(TOP)
    self.statusLabel = statusLabel
  end

  function PANEL:ClaimEquipment(itemID)
    -- Send claim request to server with item ID or "all"
    net.Start("versus.npc.claimStarterKit")
    net.WriteString(itemID or "all")
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

    -- Size item containers equally
    local itemCount = #self.kitItems
    if itemCount > 0 then
      local containerWidth = self.itemsContainer:GetWide()
      local itemWidth = (containerWidth - GAMEMODE.SPACING * (itemCount - 1)) / itemCount
      local maxTall = 0
      for i, kitItem in ipairs(self.kitItems) do
        if IsValid(kitItem.container) then
          kitItem.container:SetWide(itemWidth)
          kitItem.container:SetX((itemWidth + GAMEMODE.SPACING) * (i - 1))
          if kitItem.container:GetTall() > maxTall then
            maxTall = kitItem.container:GetTall()
          end
        end
      end
      self.itemsContainer:SetTall(maxTall)
    end
  end

  vgui.Register("versus_Quartermaster", PANEL, "EditablePanel")
end

local function readItemStatus()
  local count = net.ReadUInt(8)
  local itemStatus = {}
  for i = 1, count do
    local itemID = net.ReadString()
    local hasItem = net.ReadBool()
    itemStatus[itemID] = hasItem
  end
  return itemStatus
end

net.Receive("versus.npc.starterKitStatus", function()
  local onCooldown = net.ReadBool()
  local timeRemaining = net.ReadUInt(32)
  local itemStatus = readItemStatus()

  if IsValid(PLUGIN.quartermasterPanel) then
    PLUGIN.quartermasterPanel:UpdateStatus(onCooldown, timeRemaining, itemStatus)
  end
end)

net.Receive("versus.npc.starterKitClaimed", function()
  local itemStatus = readItemStatus()

  if IsValid(PLUGIN.quartermasterPanel) then
    local cooldown = versus.config["Starter Kit Cooldown Seconds"] or 3600
    PLUGIN.quartermasterPanel:UpdateStatus(true, cooldown, itemStatus)
    versus.message.notify("Equipment claimed! Check your inventory.", NOTIFY_SUCCESS)
  end
end)
