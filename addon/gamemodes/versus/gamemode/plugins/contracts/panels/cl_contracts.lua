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

    -- Contract 1: Sabotage The Nexus Core
    local contract1 = vgui.Create("versus_ContractItem", self)
    contract1:SetContract("[Sabotage] The Nexus Core", "EASY", "LOW", "BOTH")
    contract1:SetTall(140)
    contract1:Dock(TOP)
    contract1:SetEnabled(true)
    table.insert(self.contracts, contract1)

    local spacer2 = vgui.Create("EditablePanel", self)
    spacer2:SetTall(20)
    spacer2:Dock(TOP)

    -- Contract 2: Defend City 18 Rebel Hideout
    local contract2 = vgui.Create("versus_ContractItem", self)
    contract2:SetContract("[Defend] City 18 Rebel Hideout", "EASY", "LOW", "BOTH")
    contract2:SetTall(140)
    contract2:Dock(TOP)
    contract2:SetEnabled(true)
    table.insert(self.contracts, contract2)

    local spacer3 = vgui.Create("EditablePanel", self)
    spacer3:SetTall(20)
    spacer3:Dock(TOP)

    -- Contract 3: Defend (Unavailable)
    local contract3 = vgui.Create("versus_ContractItem", self)
    contract3:SetContract("[Defend] City 18 Rebel Hideout", "EASY", "LOW", "BOTH")
    contract3:SetTall(140)
    contract3:Dock(TOP)
    contract3:SetEnabled(false)
    contract3:SetUnavailableReason("RECENTLY EXECUTED")
    table.insert(self.contracts, contract3)
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
  end

  vgui.Register("versus_Contracts", PANEL, "EditablePanel")
end

-- Test command
concommand.Add("versus_open_contracts", function()
  if (not LocalPlayer():IsAdmin()) then return end

  if IsValid(PLUGIN.contractsPanel) then
    PLUGIN.contractsPanel:Remove()
  end

  PLUGIN.contractsPanel = vgui.Create("versus_Contracts")
  PLUGIN.contractsPanel:SetSize(ScrW() * .5, ScrH() * .8)
  PLUGIN.contractsPanel:SetPos(
    ScrW() - PLUGIN.contractsPanel:GetWide(),
    (ScrH() - PLUGIN.contractsPanel:GetTall()) / 2
  )
end)

if IsValid(PLUGIN.contractsPanel) then
  PLUGIN.contractsPanel:Remove()
end
