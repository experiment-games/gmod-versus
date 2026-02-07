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

    -- Spacing
    local spacer1 = vgui.Create("EditablePanel", self)
    spacer1:SetTall(20)
    spacer1:Dock(TOP)

    -- Contract items
    self.contracts = {}

    -- Loading indicator (shown when there are no contracts to display)
    self.loadingIndicator = vgui.Create("versus_LoadingIndicator", self)
    self.loadingIndicator:Dock(TOP)
    self.loadingIndicator:SetTall(500)

    hook.Add("PlayerReceivedContracts", "VersusContractsListUpdate", function(contracts)
      self:SetContracts(contracts)
    end)
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
        data.name,
        data.spawnPoint,
        data.extractionPoint,
        data.difficulty,
        data.reward,
        data.pvpMode
      )
      contractItem:SetTall(140)
      contractItem:Dock(TOP)
      contractItem:SetEnabled(data.enabled)

      if (not data.enabled and data.unavailableReason) then
        contractItem:SetUnavailableReason(data.unavailableReason)
      end

      table.insert(self.contracts, contractItem)

      -- Add spacing after each contract
      local spacer = vgui.Create("EditablePanel", self)
      spacer:SetTall(20)
      spacer:Dock(TOP)
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
        contract:DockMargin(math.min(w * .25, 150), 0, 0, 0)
      end
    end

    -- Size to our contents vertically
    local totalHeight = self.header:GetTall() + 20 -- header + spacer1

    if (#self.contracts > 0) then
      for _, contract in ipairs(self.contracts) do
        if IsValid(contract) then
          totalHeight = totalHeight + contract:GetTall() + 20 -- contract + spacer
        end
      end
    else
      totalHeight = totalHeight + self.loadingIndicator:GetTall()
    end

    self:SetSize(w, totalHeight)
  end

  vgui.Register("versus_ContractsList", PANEL, "EditablePanel")
end
