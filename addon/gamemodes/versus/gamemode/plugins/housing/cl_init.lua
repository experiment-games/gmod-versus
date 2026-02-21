local PLUGIN = PLUGIN

PLUGIN.ownedRooms = PLUGIN.ownedRooms or {}

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

  if IsValid(activeWeapon) and activeWeapon:GetPrimaryAmmoType() ~= -1 then
    player:EmitSound("weapons/pistol/pistol_empty.wav", 75, 100)
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
