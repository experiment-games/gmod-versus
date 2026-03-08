local PLUGIN = PLUGIN

PLUGIN.ownedRooms = PLUGIN.ownedRooms or {}
PLUGIN.housingMenuPanel = PLUGIN.housingMenuPanel or nil
PLUGIN.pendingRoomInvites = PLUGIN.pendingRoomInvites or {} -- array of {steamID, name}
PLUGIN.currentInsideHousing = PLUGIN.currentInsideHousing or false
PLUGIN.currentRoomID = PLUGIN.currentRoomID or ""
PLUGIN.currentRoomIsOwner = PLUGIN.currentRoomIsOwner or false
PLUGIN.currentRoomOwnerName = PLUGIN.currentRoomOwnerName or ""
PLUGIN.housingOverviewPanel = PLUGIN.housingOverviewPanel or nil

--- Opens the housing menu, or closes it if already open.
function PLUGIN.showHousingMenu()
  if (IsValid(PLUGIN.housingMenuPanel)) then
    PLUGIN.housingMenuPanel:Close()
    return
  end

  PLUGIN.housingMenuPanel = vgui.Create("versus_HousingMenu")
end

--[[
  Hooks
--]]

-- Add the Housing Overview tab to the housing menu.
function PLUGIN.hook:BuildHousingMenuTabs(tabs, isInsideHousing)
  tabs:addTab("Overview", vgui.Create("versus_HousingOverview"), 1)
end

--- Check if the local player owns the room with the given name.
--- @param targetName string
--- @return boolean
function PLUGIN.playerOwnsRoom(targetName)
  return PLUGIN.ownedRooms[targetName]
end

--[[
  Hooks
--]]

local attackBinds = {
  ["attack"] = true,
  ["+attack"] = true,
}

-- We disable attacks on the hideout map with a satisfying click sound. Since combat is disabled.
-- Hackers could circumvent this, but the server disables damage anyways, so they'd just waste ammo.
function PLUGIN.hook:PlayerBindPressLate(player, bind, pressed, code)
  if (not GetGlobalBool("VersusHideoutMap", false)) then
    return
  end

  if not attackBinds[bind:lower()] then
    return
  end

  local activeWeapon = player:GetActiveWeapon()

  if IsValid(activeWeapon) then
    -- If it's the toolgun or physgun, just let them
    if activeWeapon:GetClass() == "gmod_tool" or activeWeapon:GetClass() == "weapon_physgun" then
      return
    end

    if activeWeapon:GetPrimaryAmmoType() ~= -1 then
      player:EmitSound("weapons/pistol/pistol_empty.wav", 75, 100)
    end
  end

  if (not versus.util.throttled("combat_disabled_warning", 5)) then
    versus.message.notify("Combat is disabled here! Join a contract server to fight.", NOTIFY_ERROR)
  end

  return true
end

--[[
  Net Messages
--]]

net.Receive("versus.housing.sendOwnedRooms", function(len)
  local ownedRooms = {}

  local count = net.ReadUInt(16)
  for i = 1, count do
    local roomID = net.ReadString()
    ownedRooms[roomID] = true
  end

  PLUGIN.ownedRooms = ownedRooms
end)

net.Receive("versus.housing.showHousingMenu", function()
  PLUGIN.currentInsideHousing = net.ReadBool()
  PLUGIN.currentRoomID = net.ReadString()
  PLUGIN.currentRoomIsOwner = net.ReadBool()
  PLUGIN.currentRoomOwnerName = net.ReadString()
  PLUGIN.showHousingMenu()
end)

net.Receive("versus.housing.receiveRoomInvite", function()
  local ownerSteamID = net.ReadString()
  local ownerName    = net.ReadString()

  for _, inv in ipairs(PLUGIN.pendingRoomInvites) do
    if inv.steamID == ownerSteamID then return end
  end

  table.insert(PLUGIN.pendingRoomInvites, { steamID = ownerSteamID, name = ownerName })

  if IsValid(PLUGIN.housingOverviewPanel) then
    PLUGIN.housingOverviewPanel:ShowInvite(ownerSteamID, ownerName)
  else
    local key = versus.message.lookupBinding("gm_showspare2") or "F4"
    chat.AddText(
      Color(80, 140, 220),
      "[Housing] ",
      Color(220, 230, 240),
      ownerName .. " invited you to their room! Press " .. key .. " to accept."
    )
  end
end)
