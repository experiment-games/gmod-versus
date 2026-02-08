local PLUGIN = PLUGIN

PLUGIN.ownedRooms = PLUGIN.ownedRooms or {}

--- Check if the local player owns the room with the given name.
--- @param targetName string
--- @return boolean
function PLUGIN.playerOwnsRoom(targetName)
  return PLUGIN.ownedRooms[targetName]
end

net.Receive("versus.housing.sendOwnedRooms", function(len)
  local ownedRooms = {}

  local count = net.ReadUInt(16)
  for i = 1, count do
    local roomID = net.ReadString()
    ownedRooms[roomID] = true
  end

  PLUGIN.ownedRooms = ownedRooms
end)
