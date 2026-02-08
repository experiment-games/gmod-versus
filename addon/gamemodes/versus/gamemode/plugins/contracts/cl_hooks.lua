local PLUGIN = PLUGIN

-- We show the contract selection on spawn
function PLUGIN.hook:LocalPlayerInitialized()
  if (hook.Run("PlayerShouldSelectContract") == false) then
    return
  end

  self.contractSelectionPanel = vgui.Create("versus_ContractSelection")

  -- Load existing contracts if we already have them, which can happen if this
  -- hook runs after we've already received contracts from the server
  hook.Run("PlayerReceivedContracts", self:getLocalContracts() or {})
end

function PLUGIN.hook:PlayerSelectedContract(contract, contractID)
  if (IsValid(self.contractSelectionPanel)) then
    self.contractSelectionPanel:Remove()
    self.contractSelectionPanel = nil
  end

  self.showSetupTimeUntil = CurTime() + PLUGIN.setupTimeInSeconds

  PLUGIN.setupTimePanel = vgui.Create("versus_Timer")
  PLUGIN.setupTimePanel:SetTimer(PLUGIN.setupTimeInSeconds, true, "PREPARING FOR EXTRACTION")
  PLUGIN.setupTimePanel:SizeToContents(250)
  PLUGIN.setupTimePanel:SetRemoveOnExpire(true)
  PLUGIN.setupTimePanel:MoveToDefaultPosition()
end

function PLUGIN.hook:PlayerReceivedContracts(contracts)
  if (IsValid(self.contractSelectionPanel)) then
    self.contractSelectionPanel:SetContracts(contracts)
  end
end

function PLUGIN.hook:HUDPaint()
  if (self.showSetupTimeUntil and CurTime() < self.showSetupTimeUntil) then
    GAMEMODE:DrawBackgroundBox(0, 0, ScrW(), ScrH(), Color(0, 0, 0, 200))

    local textWidth, textHeight = draw.SimpleText(
      "Prepare for extraction!",
      "VersusHeading1",
      ScrW() * .5,
      ScrH() * .5,
      Color(255, 255, 255),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
      string.format(
        "Equip your weapons (Press %s) and get ready to fight for extraction! ",
        input.LookupBinding("gm_showhelp")
      ),
      "VersusHeading3",
      ScrW() * .5,
      (ScrH() * .5) + textHeight,
      Color(255, 255, 255),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.contracts.receiveContracts", function()
  local contractCount = net.ReadUInt(PLUGIN.bitCountContractAmount)
  local contracts = {}

  for i = 1, contractCount do
    local id = net.ReadUInt(PLUGIN.bitCountContractID)
    local enabled = net.ReadBool()
    local unavailableReason = not enabled and net.ReadString() or nil
    local name = net.ReadString()
    local contractType = net.ReadString()
    local extractionPoint = net.ReadEntity()
    local spawnPoint = net.ReadEntity()
    local difficulty = net.ReadString()
    local reward = net.ReadString()
    local pvpMode = net.ReadString()

    contracts[id] = {
      id = id,
      name = name,
      enabled = enabled,
      unavailableReason = unavailableReason,
      type = contractType,
      extractionPoint = extractionPoint,
      spawnPoint = spawnPoint,
      difficulty = difficulty,
      reward = reward,
      pvpMode = pvpMode,
    }
  end

  PLUGIN:receiveContracts(contracts)
end)

net.Receive("versus.contracts.selectedContract", function()
  local contractID = net.ReadUInt(PLUGIN.bitCountContractID)
  local contract = PLUGIN:getLocalContract(contractID)

  hook.Run("PlayerSelectedContract", contract, contractID)
end)

net.Receive("versus.contracts.forceReselectContract", function()
  if (hook.Run("PlayerShouldSelectContract") == false) then
    return
  end

  PLUGIN.contractSelectionPanel = vgui.Create("versus_ContractSelection")
  hook.Run("PlayerReceivedContracts", PLUGIN:getLocalContracts() or {})
end)
