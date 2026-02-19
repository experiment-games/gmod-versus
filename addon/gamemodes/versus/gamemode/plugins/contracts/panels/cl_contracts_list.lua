local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    -- Header
    self.header = vgui.Create("versus_ContractHeader", self)
    self.header:SetText("SELECT YOUR CONTRACT")
    self.header:Dock(TOP)
    self.header:DockMargin(0, 0, 0, 20)

    -- Re-roll icon button placed inside the header
    self.rerollButton = vgui.Create("versus_RerollButton", self.header)
    self.rerollButton:SetSize(48, 48)
    self.rerollButton.DoClick = function()
      self:OnReroll()
    end
    self.header:SetRightPanel(self.rerollButton, 20)

    -- Contract items
    self.contracts = {}
    self.contractsContainer = vgui.Create("versus_ScrollPanel", self)
    self.contractsContainer:Dock(FILL)
    self.contractsContainer:SetVisible(false) -- Start hidden until we have contracts to show

    -- Loading indicator (shown when there are no contracts to display)
    self.loadingIndicator = vgui.Create("versus_LoadingIndicator", self)
    self.loadingIndicator:Dock(TOP)
    self.loadingIndicator:SetTall(500)
  end

  --- Called when the re-roll button is clicked. Sends the reroll request to the server
  --- and shows the loading state while waiting for the new contract list.
  function PANEL:OnReroll()
    -- Enforce client-side cooldown guard
    if PLUGIN.lastRerollTime and (CurTime() - PLUGIN.lastRerollTime) < PLUGIN.rerollContractTimeout then
      return
    end

    PLUGIN.lastRerollTime = CurTime()

    -- Show loading state
    self.contractsContainer:SetVisible(false)
    self.loadingIndicator:SetVisible(true)

    -- Clear contract panels
    for _, contract in ipairs(self.contracts) do
      if IsValid(contract) then
        contract:Remove()
      end
    end
    self.contracts = {}

    net.Start("versus.contracts.rerollContracts")
    net.SendToServer()
  end

  function PANEL:SetContracts(contractsData)
    -- Clear existing contracts
    for _, contract in ipairs(self.contracts) do
      if IsValid(contract) then
        contract:Remove()
      end
    end

    self.contracts = {}

    -- Create new contract items based on data
    for _, data in ipairs(contractsData) do
      local contractItem = vgui.Create("versus_ContractItem", self.contractsContainer)
      contractItem:SetContract(
        data.id,
        data.name,
        data.description,
        data.image,
        data.locations,
        data.tags
      )
      contractItem:SetTall(140)
      contractItem:Dock(TOP)
      contractItem:DockMargin(0, 0, 0, 20)
      contractItem:SetEnabled(data.enabled)

      if (not data.enabled and data.unavailableReason) then
        contractItem:SetUnavailableReason(data.unavailableReason)
      end

      contractItem.OnContractSelected = function(button)
        local contractID = button:GetContractID()

        local function selectContract()
          self.loadingIndicator:SetVisible(true)
          self:SetMouseInputEnabled(false)

          -- Hide contracts
          for _, contract in ipairs(self.contracts) do
            if IsValid(contract) then
              contract:SetVisible(false)
            end
          end

          net.Start("versus.contracts.selectContract")
          net.WriteUInt(contractID, PLUGIN.bitCountContractID)
          net.SendToServer()
        end

        local hasWeaponItems = table.Count(
          versus.inventory.findAllByBase(LocalPlayer(), "base_weapon")
        ) > 0

        if (hasWeaponItems) then
          selectContract()
        else
          versus.panel.query(
            "You do not have any weapon items with ammo. It is recommended to head to the hideout server to get some.\n\nAre you sure you want to select this contract without any weapon items?",
            "Recommended to have weapon items for contracts",
            "Yes, select the contract",
            selectContract,
            "Go to the hideout",
            function()
              local hideoutServerConVar = GetConVar("versus_hideout_server")
              local hideoutServerAddress = hideoutServerConVar and hideoutServerConVar:GetString() or ""
              permissions.AskToConnect(hideoutServerAddress)
            end
          )
        end
      end

      table.insert(self.contracts, contractItem)
    end

    self.loadingIndicator:SetVisible(#contractsData == 0)
    self.contractsContainer:SetVisible(#contractsData > 0)

    self:InvalidateLayout()
  end

  function PANEL:GetHoveredContract()
    for _, contract in ipairs(self.contracts) do
      if IsValid(contract) and contract:IsHovered() then
        return contract
      end
    end

    return nil
  end

  --- Updates the availability status of specific contracts
  --- @param updates table Array of updates with {id, enabled, unavailableReason}
  function PANEL:UpdateContractAvailability(updates)
    for _, update in ipairs(updates) do
      -- Find the contract panel with matching ID
      for _, contractPanel in ipairs(self.contracts) do
        if IsValid(contractPanel) and contractPanel:GetContractID() == update.id then
          contractPanel:SetEnabled(update.enabled)

          if not update.enabled and update.unavailableReason then
            contractPanel:SetUnavailableReason(update.unavailableReason)
          end

          break
        end
      end
    end
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    -- Fade in animation
    if elapsed < self.animDuration then
      local progress = elapsed / self.animDuration
      progress = math.ease.InOutQuad(progress)

      self.contentAlpha = 255 * progress
    else
      self.contentAlpha = 255
    end

    self:SetAlpha(self.contentAlpha)

    -- Update reroll button cooldown display
    if IsValid(self.rerollButton) then
      local cooldownRemaining = 0
      if PLUGIN.lastRerollTime then
        cooldownRemaining = math.max(0, PLUGIN.rerollContractTimeout - (CurTime() - PLUGIN.lastRerollTime))
      end
      self.rerollButton:SetCooldown(cooldownRemaining)
    end
  end

  function PANEL:PerformLayout(w, h)
    for _, contract in ipairs(self.contracts) do
      if IsValid(contract) then
        local dockLeft, dockTop, dockRight, dockBottom = contract:GetDockMargin()
        contract:DockMargin(math.min(w * .25, 150), dockTop, dockRight, dockBottom)
      end
    end

    -- Size to our contents vertically
    local dockLeft, dockTop, dockRight, dockBottom = self.header:GetDockMargin()
    local totalHeight = self.header:GetTall() + dockTop + dockBottom -- header

    if (#self.contracts > 0) then
      for _, contract in ipairs(self.contracts) do
        if IsValid(contract) then
          dockLeft, dockTop, dockRight, dockBottom = contract:GetDockMargin()
          totalHeight = totalHeight + contract:GetTall() + dockTop + dockBottom
        end
      end
    else
      totalHeight = totalHeight + self.loadingIndicator:GetTall()
    end

    self.contractsContainer:SetSize(w, totalHeight)
  end

  vgui.Register("versus_ContractsList", PANEL, "EditablePanel")
end

-- A simple square icon button used for the re-roll action.
do
  local rerollIcon = Material("versus/icons/reroll.png", "smooth")

  local PANEL = {}

  function PANEL:Init()
    self:SetText("")
    self:SetVersusTooltip(function(tooltip)
      local description = tooltip:AddRow("description")
      description:SetText("Re-roll Contracts")
      description:SizeToContents()
    end)
    self.hovered           = false
    self.cooldownRemaining = 0
    self.iconColor         = Color(255, 204, 0, 255)
    self.iconColorHover    = Color(255, 255, 255, 255)
  end

  function PANEL:SetCooldown(remaining)
    self.cooldownRemaining = remaining
  end

  function PANEL:Paint(w, h)
    local onCooldown = self.cooldownRemaining > 0
    local hovered = self.hovered and not onCooldown
    local icon = hovered and self.iconColorHover or self.iconColor
    local padding = hovered and 10 or 5
    local iconAlpha = onCooldown and 35 or 255

    surface.SetMaterial(rerollIcon)
    surface.SetDrawColor(ColorAlpha(icon, iconAlpha))
    surface.DrawTexturedRect(padding, padding, w - padding * 2, h - padding * 2)

    if onCooldown then
      local secsText = math.ceil(self.cooldownRemaining) .. "s"
      surface.SetFont("VersusDefault")
      local tw, th = surface.GetTextSize(secsText)
      surface.SetTextColor(Color(0, 0, 0, 255))
      -- We subtract 5 here to visually center it better within our icon
      surface.SetTextPos(((w - 5) * .5) - tw * .5, h * .5 - th * .5)
      surface.DrawText(secsText)
    end
  end

  function PANEL:OnCursorEntered() self.hovered = true end

  function PANEL:OnCursorExited() self.hovered = false end

  vgui.Register("versus_RerollButton", PANEL, "DButton")
end
