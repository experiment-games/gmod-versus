local PLUGIN = PLUGIN

PLUGIN.warningPanel = PLUGIN.warningPanel or nil
PLUGIN.lastState = PLUGIN.lastState or "ok"

local HL2_DEPOT_ID = 220
local HL2_FOLDER = "hl2"
local HL2_STORE_URL = "https://store.steampowered.com/app/220/HalfLife_2/"

--- Find the Half-Life 2 entry returned by engine.GetGames().
--- @return table?
local function findHalfLife2Game()
  local games = engine.GetGames() or {}

  for _, game in ipairs(games) do
    if game.depot == HL2_DEPOT_ID or game.folder == HL2_FOLDER then
      return game
    end
  end

  return nil
end

--- Returns the current HL2 availability state for the local client.
--- @return string state
--- @return table? game
function PLUGIN.getHalfLife2State()
  local game = findHalfLife2Game()

  if not game then
    return "unknown", nil
  end

  if game.mounted then
    return "ok", game
  end

  if game.owned == false then
    return "not_owned", game
  end

  if game.installed then
    return "not_mounted", game
  end

  return "not_installed", game
end

--- Build warning panel copy for a specific state.
--- @param state string
--- @return table
function PLUGIN.getWarningData(state)
  local data = {
    title = "Half-Life 2 Required",
    description =
    "Versus uses models, materials, and sounds from Half-Life 2. Please make sure HL2 is installed and mounted into Garry's Mod so everything renders correctly.",
    guidance = "",
    showStoreButton = false,
  }

  if state == "not_mounted" then
    data.guidance =
    "Half-Life 2 appears to be installed, but Garry's Mod has not mounted it. Open the main Garry's Mod menu, click 'Games' in the bottom-right, and enable Half-Life 2."
  elseif state == "not_installed" then
    data.guidance =
    "You own Half-Life 2, but it is not installed on this machine. Install Half-Life 2 through Steam, then restart Garry's Mod and ensure it's mounted so Versus can use its content."
  elseif state == "not_owned" then
    data.guidance =
    "Your Steam account does not appear to own Half-Life 2. Versus requires HL2 content to work properly."
    data.showStoreButton = true
  else
    data.guidance =
    "We could not verify your Half-Life 2 mount state. Please check Garry's Mod > Games and ensure Half-Life 2 is installed and mounted."
    data.showStoreButton = true
  end

  return data
end

--- Open or refresh the warning overlay for the current state.
--- @param state string
function PLUGIN.openWarning(state)
  local data = PLUGIN.getWarningData(state)

  if IsValid(PLUGIN.warningPanel) then
    ---@type versus_HL2RequirementWarning
    local warningPanel = PLUGIN.warningPanel
    warningPanel:SetWarningData(data)
    return
  end

  ---@type versus_HL2RequirementWarning
  PLUGIN.warningPanel = vgui.Create("versus_HL2RequirementWarning")
  PLUGIN.warningPanel:SetWarningData(data)
end

--- Checks the local HL2 mount state and opens/closes warning UI as needed.
function PLUGIN.checkHalfLife2Requirements()
  local state = select(1, PLUGIN.getHalfLife2State())

  PLUGIN.lastState = state

  if state == "ok" then
    if IsValid(PLUGIN.warningPanel) then
      ---@type any
      local warningPanel = PLUGIN.warningPanel
      warningPanel:Close()
    end

    return
  end

  PLUGIN.openWarning(state)
end

function PLUGIN.hook:InitPostEntity()
  -- Slight delay so this popup will be on top of any initial popups.
  timer.Simple(1, function()
    if not IsValid(LocalPlayer()) then
      return
    end

    PLUGIN.checkHalfLife2Requirements()
  end)
end

function PLUGIN.openHalfLife2StorePage()
  gui.OpenURL(HL2_STORE_URL)
end
