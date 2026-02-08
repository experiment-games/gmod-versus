local PLUGIN = PLUGIN

util.AddNetworkString("versus.housing.sendOwnedRooms")
util.AddNetworkString("versus.housing.showRoomPurchaseScreen")
util.AddNetworkString("versus.housing.purchaseRoom")

function PLUGIN.hook:ServerShouldLoadManifest()
  -- Don't load the manifest on hideout maps
  if (GetGlobalBool("VersusHideoutMap", false)) then
    return false
  end
end

-- Send the players the rooms they own, so we can show them as unlocked
function PLUGIN.hook:PlayerInitialized(player)
  PLUGIN.sendOwnedRooms(player)
end

--- Check if the player owns the room with the given name.
--- @param targetName string
--- @return boolean
function PLUGIN.playerOwnsRoom(player, targetName)
  local ownedRooms = player:getCharacter("data").ownedRooms or {}
  return table.HasValue(ownedRooms, targetName)
end

--- Get the room with the given ID, if it exists.
--- @param roomID string
--- @return Entity?
function PLUGIN.getRoomByID(roomID)
  for _, room in ipairs(ents.FindByClass("versus_housing_instance_target")) do
    if (room:GetTargetName() == roomID) then
      return room
    end
  end

  return nil
end

function PLUGIN.sendOwnedRooms(player)
  local ownedRooms = player:getCharacter("data").ownedRooms or {}

  net.Start("versus.housing.sendOwnedRooms")
  net.WriteUInt(#ownedRooms, 16)

  for _, roomID in ipairs(ownedRooms) do
    net.WriteString(roomID)
  end

  net.Send(player)
end

--[[
  Net Messages
--]]

net.Receive("versus.housing.purchaseRoom", function(len, player)
  local roomID = net.ReadString()
  local room = PLUGIN.getRoomByID(roomID)

  if (not room) then
    ErrorNoHalt("Player attempted to purchase invalid room ID: " .. roomID .. "\n")
    return
  end

  local price = math.Round(room:GetPriceScale() * PLUGIN.baseRoomPrice)

  local canAfford, deficit = versus.finance.canAfford(player, price)

  if (not canAfford) then
    versus.message.notify(player,
      "You need another " .. versus.util.formatMoney(deficit) .. " to purchase this room.",
      NOTIFY_ERROR
    )

    return
  end

  versus.finance.takeMoney(player, price, "Purchased room.")

  -- Add the room to the player's owned rooms
  local charData = player:getCharacter("data")
  charData.ownedRooms = charData.ownedRooms or {}
  table.insert(charData.ownedRooms, roomID)
  player:setCharacter("data", charData)

  -- Notify the client that they now own this room so it can be shown as unlocked
  PLUGIN.sendOwnedRooms(player)
end)
