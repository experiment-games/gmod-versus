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

    -- Contract items
    self.contracts = {}

    -- Loading indicator (shown when there are no contracts to display)
    self.loadingIndicator = vgui.Create("versus_LoadingIndicator", self)
    self.loadingIndicator:Dock(TOP)
    self.loadingIndicator:SetTall(500)
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
      local contractItem = vgui.Create("versus_ContractItem", self)
      contractItem:SetContract(
        data.id,
        data.name,
        data.locations,
        data.difficulty,
        data.reward,
        data.pvpMode
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

        local hasWeaponItems = false

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

    self:SetSize(w, totalHeight)
  end

  vgui.Register("versus_ContractsList", PANEL, "EditablePanel")
end
