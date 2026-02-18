local PLUGIN = PLUGIN

-- Colour-modification and motion-blur passes (run inside RenderScreenspaceEffects)
local SCREEN_COLOR_MODS = {
  bleeding = function(t)
    DrawColorModify({
      ["$pp_colour_addr"]       = 0,
      ["$pp_colour_addg"]       = 0,
      ["$pp_colour_addb"]       = 0,
      ["$pp_colour_brightness"] = -0.05,
      ["$pp_colour_contrast"]   = 1.1,
      ["$pp_colour_colour"]     = 0.5,
      ["$pp_colour_mulr"]       = 1.2,
      ["$pp_colour_mulg"]       = 0.8,
      ["$pp_colour_mulb"]       = 0.8,
    })
  end,

  drunk = function(t)
    DrawMotionBlur(0.1, 0.6, 0.02)
    DrawColorModify({
      ["$pp_colour_addr"]       = 0,
      ["$pp_colour_addg"]       = 0,
      ["$pp_colour_addb"]       = 0,
      ["$pp_colour_brightness"] = 0,
      ["$pp_colour_contrast"]   = 0.9,
      ["$pp_colour_colour"]     = 1.4,
      ["$pp_colour_mulr"]       = 1,
      ["$pp_colour_mulg"]       = 1,
      ["$pp_colour_mulb"]       = 1,
    })
  end,

  nightvision = function(t)
    DrawColorModify({
      ["$pp_colour_addr"]       = 0,
      ["$pp_colour_addg"]       = 0.05,
      ["$pp_colour_addb"]       = 0,
      ["$pp_colour_brightness"] = 0.05,
      ["$pp_colour_contrast"]   = 1.5,
      ["$pp_colour_colour"]     = 0,
      ["$pp_colour_mulr"]       = 0.3,
      ["$pp_colour_mulg"]       = 1.5,
      ["$pp_colour_mulb"]       = 0.3,
    })
  end,

  toxic = function(t)
    DrawMotionBlur(0.04, 0.4, 0.02)
    DrawColorModify({
      ["$pp_colour_addr"]       = 0,
      ["$pp_colour_addg"]       = 0.02,
      ["$pp_colour_addb"]       = 0,
      ["$pp_colour_brightness"] = -0.05,
      ["$pp_colour_contrast"]   = 1.15,
      ["$pp_colour_colour"]     = 0.7,
      ["$pp_colour_mulr"]       = 0.9,
      ["$pp_colour_mulg"]       = 1.2,
      ["$pp_colour_mulb"]       = 0.7,
    })
  end,

  radiation = function(t)
    local pulse = 0.5 + 0.5 * math.abs(math.sin(t * 1.2))
    DrawColorModify({
      ["$pp_colour_addr"]       = 0,
      ["$pp_colour_addg"]       = 0.01 * pulse,
      ["$pp_colour_addb"]       = 0,
      ["$pp_colour_brightness"] = -0.08,
      ["$pp_colour_contrast"]   = 1.2,
      ["$pp_colour_colour"]     = 0.6 + 0.3 * (1 - pulse),
      ["$pp_colour_mulr"]       = 0.8,
      ["$pp_colour_mulg"]       = 1.0 + 0.2 * pulse,
      ["$pp_colour_mulb"]       = 0.8,
    })
  end,

  cold = function(t)
    DrawColorModify({
      ["$pp_colour_addr"]       = 0,
      ["$pp_colour_addg"]       = 0,
      ["$pp_colour_addb"]       = 0.03,
      ["$pp_colour_brightness"] = -0.05,
      ["$pp_colour_contrast"]   = 1.1,
      ["$pp_colour_colour"]     = 0.4,
      ["$pp_colour_mulr"]       = 0.8,
      ["$pp_colour_mulg"]       = 0.9,
      ["$pp_colour_mulb"]       = 1.3,
    })
  end,

  blinded = function(t)
    local fade = math.max(0, 1 - t * 0.5) -- fades from full white to clear over 2 seconds
    DrawColorModify({
      ["$pp_colour_addr"]       = fade,
      ["$pp_colour_addg"]       = fade,
      ["$pp_colour_addb"]       = fade,
      ["$pp_colour_brightness"] = fade * 0.5,
      ["$pp_colour_contrast"]   = 1,
      ["$pp_colour_colour"]     = 1,
      ["$pp_colour_mulr"]       = 1,
      ["$pp_colour_mulg"]       = 1,
      ["$pp_colour_mulb"]       = 1,
    })
  end,
}

local VIGNETTE_MATERIALS = {
  bleeding = Material("versus/vignette_blood.png", "noclamp smooth"),
  toxic    = Material("versus/vignette_toxic.png", "noclamp smooth"),
}

-- Vignette overlays drawn on top of the HUD
local SCREEN_VIGNETTES = {
  bleeding = function(t)
    local alpha = math.Round((0.4 + 0.1 * math.sin(t * 2)) * 100)
    local w, h  = ScrW(), ScrH()
    surface.SetMaterial(VIGNETTE_MATERIALS.bleeding)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRect(0, 0, w, h)
  end,

  toxic = function(t)
    local alpha = math.Round((0.3 + 0.07 * math.sin(t * 1.5)) * 200)
    local w, h  = ScrW(), ScrH()
    surface.SetMaterial(VIGNETTE_MATERIALS.toxic)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRect(0, 0, w, h)
  end,
}

-- We show the contract selection on spawn
function PLUGIN.hook:LocalPlayerInitialized()
  if (hook.Run("PlayerShouldSelectContract") == false) then
    return
  end

  self.contractSelectionPanel = vgui.Create("versus_ContractSelection")

  -- Load existing contracts if we already have them, which can happen if this
  -- hook runs after we've already received contracts from the server
  hook.Run("PlayerReceivedContracts", self.getLocalContracts() or {})
end

function PLUGIN.hook:PlayerSelectedContract(contract, contractID)
  if (IsValid(self.contractSelectionPanel)) then
    self.contractSelectionPanel:Remove()
    self.contractSelectionPanel = nil
  end

  if (IsValid(self.radioStack)) then
    self.radioStack:ClearMessages()
  end
end

function PLUGIN.hook:PlayerEliminated(subtitle)
  if IsValid(self.radioStack) then
    self.radioStack:ClearMessages()
  end
end

function PLUGIN.hook:PlayerReceivedContracts(contracts)
  if (IsValid(self.contractSelectionPanel)) then
    self.contractSelectionPanel:SetContracts(contracts)
  end
end

function PLUGIN.hook:PlayerContractAvailabilityUpdated(updates)
  if IsValid(self.contractSelectionPanel) and IsValid(self.contractSelectionPanel.contractsPanel) then
    self.contractSelectionPanel.contractsPanel:UpdateContractAvailability(updates)
  end
end

function PLUGIN.hook:DrawBottomBars(bar)
  if not next(PLUGIN.activeStatusEffects) then return end

  local now = RealTime()
  local x   = bar.x
  local y   = bar.y
  local w   = 220
  local h   = 42

  for effectID, effect in pairs(PLUGIN.activeStatusEffects) do
    -- Client-side expiry mirror so the HUD doesn't show stale entries
    if effect.duration and (now - effect.startTime) >= effect.duration then
      PLUGIN.activeStatusEffects[effectID] = nil
      continue
    end

    -- Dark background panel
    surface.SetDrawColor(20, 20, 20, 180)
    surface.DrawRect(x, y, w, h)

    -- Thin colour strip on the left edge
    surface.SetDrawColor(effect.color.r, effect.color.g, effect.color.b, 220)
    surface.DrawRect(x, y, 4, h)

    -- Effect label
    draw.SimpleText(
      effect.label, "VersusDefault",
      x + 12, y + h * 0.5,
      color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )

    -- Duration progress bar draining rightward
    if effect.duration then
      local remaining = math.max(0, effect.duration - (now - effect.startTime))
      local frac      = remaining / effect.duration
      surface.SetDrawColor(effect.color.r, effect.color.g, effect.color.b, 100)
      surface.DrawRect(x + 4, y + h - 3, math.Round((w - 4) * frac), 3)
    end

    y = y - h - 4
  end

  -- Push bar.y up so versus.message.position sits above our panels
  bar.y = y
end

function PLUGIN.hook:HUDPaint()
  local effectName = PLUGIN.activeScreenEffect
  if not effectName then
    return
  end

  local fn = SCREEN_VIGNETTES[effectName]
  if not fn then
    return
  end

  fn(RealTime() - (PLUGIN.screenEffectStartTime or RealTime()))
end

function PLUGIN.hook:RenderScreenspaceEffects()
  local effectName = PLUGIN.activeScreenEffect
  if not effectName then
    return
  end

  local fn = SCREEN_COLOR_MODS[effectName]
  if not fn then
    return
  end

  fn(RealTime() - (PLUGIN.screenEffectStartTime or RealTime()))
end

--[[
  Net Messages
--]]

net.Receive("versus.contracts.closeSelectionPanel", function()
  if (IsValid(PLUGIN.contractSelectionPanel)) then
    PLUGIN.contractSelectionPanel:Remove()
    PLUGIN.contractSelectionPanel = nil
  end
end)

net.Receive("versus.contracts.receiveContracts", function()
  local contractCount = net.ReadUInt(PLUGIN.bitCountContractAmount)
  local contracts = {}

  for i = 1, contractCount do
    local id = net.ReadUInt(PLUGIN.bitCountContractID)
    local enabled = net.ReadBool()
    local unavailableReason = not enabled and net.ReadString() or nil
    local name = net.ReadString()
    local description = net.ReadString()
    local image = net.ReadString()

    -- Receive tags
    local tagCount = net.ReadUInt(8)
    local tags = {}
    for t = 1, tagCount do
      local label = net.ReadString()
      local r = net.ReadUInt(8)
      local g = net.ReadUInt(8)
      local b = net.ReadUInt(8)
      table.insert(tags, { label = label, color = Color(r, g, b) })
    end

    -- Receive all non-hidden locations
    local locationCount = net.ReadUInt(8)
    local locations = {}

    for j = 1, locationCount do
      local key = net.ReadString()
      local entity = net.ReadEntity()
      local displayName = net.ReadString()
      local class = net.ReadString()

      locations[key] = {
        entity = entity,
        displayName = displayName,
        class = class
      }
    end

    contracts[id] = {
      id = id,
      name = name,
      description = description,
      image = image,
      enabled = enabled,
      unavailableReason = unavailableReason,
      locations = locations,
      tags = tags,
    }
  end

  PLUGIN.receiveContracts(contracts)
end)

net.Receive("versus.contracts.selectedContract", function()
  local contractID = net.ReadUInt(PLUGIN.bitCountContractID)
  local contract = PLUGIN.getLocalContract(contractID)

  hook.Run("PlayerSelectedContract", contract, contractID)
end)

net.Receive("versus.contracts.forceReselectContract", function()
  if (hook.Run("PlayerShouldSelectContract") == false) then
    return
  end

  PLUGIN.contractSelectionPanel = vgui.Create("versus_ContractSelection")
  hook.Run("PlayerReceivedContracts", PLUGIN.getLocalContracts() or {})
end)

net.Receive("versus.contracts.playerEliminated", function()
  -- Create elimination screen
  local eliminationScreen = vgui.Create("versus_EliminationScreen")

  -- Set subtitle based on who killed the player
  local subtitle = net.ReadString()

  eliminationScreen:SetSubtitle(subtitle)

  hook.Run("PlayerEliminated", subtitle)
end)

net.Receive("versus.contracts.updateContractAvailability", function()
  local contractCount = net.ReadUInt(8)
  local updates = {}

  for i = 1, contractCount do
    local contractID = net.ReadUInt(PLUGIN.bitCountContractID)
    local enabled = net.ReadBool()
    local unavailableReason = not enabled and net.ReadString() or nil

    table.insert(updates, {
      id = contractID,
      enabled = enabled,
      unavailableReason = unavailableReason
    })
  end

  -- Update local contract data
  local localContracts = PLUGIN.getLocalContracts()
  if localContracts then
    for _, update in ipairs(updates) do
      if localContracts[update.id] then
        localContracts[update.id].enabled = update.enabled
        localContracts[update.id].unavailableReason = update.unavailableReason
      end
    end
  end

  -- Update UI if contract selection panel is open
  if IsValid(PLUGIN.contractSelectionPanel) then
    hook.Run("PlayerContractAvailabilityUpdated", updates)
  end
end)

net.Receive("versus.contracts.applyStatusEffect", function()
  local effectID = net.ReadString()
  local label    = net.ReadString()
  local hasColor = net.ReadBool()
  local color    = Color(255, 255, 255)

  if hasColor then
    local r = net.ReadUInt(8)
    local g = net.ReadUInt(8)
    local b = net.ReadUInt(8)
    color = Color(r, g, b)
  end

  local hasDuration                    = net.ReadBool()
  local duration                       = hasDuration and net.ReadFloat() or nil

  PLUGIN.activeStatusEffects[effectID] = {
    label     = label,
    color     = color,
    startTime = RealTime(),
    duration  = duration,
  }
end)

net.Receive("versus.contracts.clearStatusEffect", function()
  local effectID = net.ReadString()
  if effectID == "__all__" then
    PLUGIN.activeStatusEffects = {}
  else
    PLUGIN.activeStatusEffects[effectID] = nil
  end
end)


net.Receive("versus.contracts.screenEffect", function()
  PLUGIN.activeScreenEffect    = net.ReadString()
  PLUGIN.screenEffectStartTime = RealTime()
end)

net.Receive("versus.contracts.clearScreenEffect", function()
  PLUGIN.activeScreenEffect    = nil
  PLUGIN.screenEffectStartTime = nil
end)

--[[
  Console Commands
--]]

concommand.Add("versus_test_fail_contract", function()
  local eliminationScreen = vgui.Create("versus_EliminationScreen")
  eliminationScreen:SetSubtitle("Elimination Screen Test")
end)
