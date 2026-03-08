local PLUGIN = PLUGIN

util.AddNetworkString("versus.housing.sendOwnedRooms")
util.AddNetworkString("versus.housing.showRoomPurchaseScreen")
util.AddNetworkString("versus.housing.purchaseRoom")
util.AddNetworkString("versus.housing.showHousingMenu")
util.AddNetworkString("versus.housing.inviteToRoom")
util.AddNetworkString("versus.housing.receiveRoomInvite")
util.AddNetworkString("versus.housing.respondToRoomInvite")

PLUGIN.pendingRoomInvites = PLUGIN.pendingRoomInvites or {} -- targetSteamID64 -> ownerSteamID64

function PLUGIN.hook:ServerShouldLoadManifest()
  -- Don't load the manifest on hideout maps
  if (GetGlobalBool("VersusHideoutMap", false)) then
    return false
  end
end

-- Disable damage on the hideout map since it's meant to be a safe social space
function PLUGIN.hook:EntityTakeDamage(target, dmgInfo)
  if (GetGlobalBool("VersusHideoutMap", false)) then
    return true
  end
end

-- Send the players the rooms they own, so we can show them as unlocked
function PLUGIN.hook:PlayerInitialized(player)
  PLUGIN.sendOwnedRooms(player)
end

--- Open the housing menu, both inside and outside of a housing instance.
function PLUGIN.hook:ShowSpare2(player)
  local instanceID = versus.instance.getPlayerInstance(player)
  local isInsideHousing = instanceID ~= nil

  local isOwner = false
  local roomID = ""
  local ownerName = ""

  if isInsideHousing then
    isOwner = versus.instance.getInstanceOwner(instanceID) == player
    roomID = player._VersusRoomID or ""

    if not isOwner then
      local owner = versus.instance.getInstanceOwner(instanceID)
      ownerName = IsValid(owner) and owner:Nick() or "Unknown"
    end
  end

  net.Start("versus.housing.showHousingMenu")
  net.WriteBool(isInsideHousing)
  net.WriteString(roomID)
  net.WriteBool(isOwner)
  net.WriteString(ownerName)
  net.Send(player)
end

-- When entering a room, provide the physgun
function PLUGIN.hook:PlayerSwitchedToInstance(player, playerInstanceID, roomID)
  if (versus.instance.getInstanceOwner(playerInstanceID) == player) then
    player:Give("weapon_physgun")

    self.spawnRoomEntitiesForPlayer(player, roomID)
  end
end

-- When leaving a room, remove the physgun
function PLUGIN.hook:PlayerSwitchedFromInstance(player, playerInstanceID, roomID)
  if (versus.instance.getInstanceOwner(playerInstanceID) ~= player) then
    return
  end

  player:StripWeapon("weapon_physgun")

  versus.instance.destroyInstance(playerInstanceID, "player_left_room")
end

function PLUGIN.hook:InstancePreDestroy(instanceID, reason)
  local owner = versus.instance.getInstanceOwner(instanceID)

  if (not IsValid(owner) or not owner._VersusRoomID) then
    return
  end

  -- Cancel pending room invites that the owner sent out
  local ownerSteamID = owner:SteamID64()
  for targetSteamID, senderSteamID in pairs(PLUGIN.pendingRoomInvites) do
    if senderSteamID == ownerSteamID then
      PLUGIN.pendingRoomInvites[targetSteamID] = nil
    end
  end

  -- TODO: In the future, kick players when the owner leaves the room. For now we just save the position of entities in the room when players leave.
  PLUGIN.saveAllRoomEntityDataForPlayer(owner, instanceID, owner._VersusRoomID)
end

function PLUGIN.hook:PlayerSaveDisconnect(player)
  -- On hideout maps, save ammo on disconenct
  if (GetGlobalBool("VersusHideoutMap", false)) then
    versus.weapon.returnEquippedAmmo(player)
  end
end

-- When a player refunds a premium shop item and it isn't found in the inventory, remove it from the
-- room named inventories if it exists there.
function PLUGIN.hook:VersusPremiumShopRemoveItem(player, itemID)
  local rooms = player:getCharacter("data").ownedRooms or {}

  for _, roomID in ipairs(rooms) do
    local chestInventory = versus.inventory.getNamedInventory(player, roomID)

    if (chestInventory and versus.inventory.hasItemInNamedInventory(player, roomID, itemID)) then
      local removed = versus.inventory.takeItemFromNamedInventory(player, roomID, itemID)

      if (removed) then
        return true
      end
    end
  end
end

--[[
  Library functions
--]]

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

--- Generates a unique ID for a housing entity
function PLUGIN.generateEntityID()
  return tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

--- Spawns the entities that come with a housing instance for the player.
function PLUGIN.spawnRoomEntitiesForPlayer(player, roomID)
  local ownedRoomEntities = player:getCharacter("data").ownedRoomEntities or {}
  local roomEntityData = ownedRoomEntities[roomID]
  local playerInstance = versus.instance.getPlayerInstance(player)

  -- If no saved data exists, initialize from default entities
  if (not roomEntityData) then
    roomEntityData = {}

    -- Find all default entities for this instance
    for _, defaultEntity in ipairs(ents.FindByClass("versus_housing_instance_default_entity")) do
      if (defaultEntity:GetInstanceID() == roomID) then
        local entityID = PLUGIN.generateEntityID()

        -- Save the default entity data
        roomEntityData[entityID] = {
          class = defaultEntity:GetEntityClass(),
          model = defaultEntity:GetEntityModel(),
          pos = defaultEntity:GetPos(),
          ang = defaultEntity:GetAngles(),
        }
      end
    end

    -- Save the initialized defaults
    ownedRoomEntities[roomID] = roomEntityData
    local data = player:getCharacter("data")
    data.ownedRoomEntities = ownedRoomEntities
  end

  -- Spawn all saved entities (either defaults or previously modified)
  for entityID, data in pairs(roomEntityData) do
    local spawnedEntity = ents.Create(data.class)
    spawnedEntity:SetModel(data.model)
    spawnedEntity:SetPos(data.pos)
    spawnedEntity:SetAngles(data.ang)
    spawnedEntity:Spawn()

    if (spawnedEntity.SetupRoomID) then
      spawnedEntity:SetupRoomID(roomID)
    end

    local physicsObject = spawnedEntity:GetPhysicsObject()

    if (data.frozen and IsValid(physicsObject)) then
      physicsObject:EnableMotion(false)
    end

    -- Store the unique ID on the entity so we can identify it later
    spawnedEntity.housingEntityID = entityID

    versus.instance.addEntity(spawnedEntity, playerInstance)
  end
end

--- Saves all entities in the player's instance.
function PLUGIN.saveAllRoomEntityDataForPlayer(player, playerInstanceID, roomID)
  local data = player:getCharacter("data")
  local ownedRoomEntities = data.ownedRoomEntities or {}
  ownedRoomEntities[roomID] = {}

  for entity, _ in pairs(versus.instance.getEntitiesInInstance(playerInstanceID)) do
    if (IsValid(entity)) then
      local physicsObject = entity:GetPhysicsObject()

      -- Generate ID if entity doesn't have one (newly spawned)
      if not entity.housingEntityID then
        entity.housingEntityID = PLUGIN.generateEntityID()
      end

      ownedRoomEntities[roomID][entity.housingEntityID] = {
        class = entity:GetClass(),
        model = entity:GetModel(),
        pos = entity:GetPos(),
        ang = entity:GetAngles(),
        frozen = IsValid(physicsObject) and not physicsObject:IsMotionEnabled() or nil,
      }
    end
  end

  data.ownedRoomEntities = ownedRoomEntities
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

  -- Notify the client that they now own this room so it can be shown as unlocked
  PLUGIN.sendOwnedRooms(player)
end)

net.Receive("versus.housing.inviteToRoom", function(len, owner)
  local targetSteamID = net.ReadString()

  local instanceID = versus.instance.getPlayerInstance(owner)

  if (not instanceID) then
    return
  end

  if (versus.instance.getInstanceOwner(instanceID) ~= owner) then return end

  local target = nil
  for _, ply in ipairs(player.GetAll()) do
    if ply:SteamID64() == targetSteamID then
      target = ply
      break
    end
  end

  if (not IsValid(target)) then
    return
  end
  if (target == owner) then
    return
  end

  PLUGIN.pendingRoomInvites[targetSteamID] = owner:SteamID64()

  net.Start("versus.housing.receiveRoomInvite")
  net.WriteString(owner:SteamID64())
  net.WriteString(owner:Nick())
  net.Send(target)
end)

net.Receive("versus.housing.respondToRoomInvite", function(len, visitor)
  local ownerSteamID   = net.ReadString()
  local accepted       = net.ReadBool()
  local visitorSteamID = visitor:SteamID64()

  if (PLUGIN.pendingRoomInvites[visitorSteamID] ~= ownerSteamID) then
    return
  end

  PLUGIN.pendingRoomInvites[visitorSteamID] = nil

  if (not accepted) then
    return
  end

  local owner = nil
  for _, ply in ipairs(player.GetAll()) do
    if ply:SteamID64() == ownerSteamID then
      owner = ply
      break
    end
  end

  if (not IsValid(owner)) then
    versus.message.notify(visitor, "The room owner is no longer available.", NOTIFY_ERROR)
    return
  end

  local instanceID = versus.instance.getPlayerInstance(owner)
  if (not instanceID) then
    versus.message.notify(visitor, "The room owner has left their room.", NOTIFY_ERROR)
    return
  end

  if (versus.instance.getInstanceOwner(instanceID) ~= owner) then
    versus.message.notify(visitor, "The room owner has left their room.", NOTIFY_ERROR)
    return
  end

  local roomID = owner._VersusRoomID
  if (not roomID) then
    versus.message.notify(visitor, "Cannot find room.", NOTIFY_ERROR)
    return
  end

  local instanceTarget = nil
  for _, target in ipairs(ents.FindByClass("versus_housing_instance_target")) do
    if (target:GetInstanceID() == roomID) then
      instanceTarget = target
      break
    end
  end

  if (not IsValid(instanceTarget)) then
    versus.message.notify(visitor, "Cannot find room entry.", NOTIFY_ERROR)
    return
  end

  visitor:SetPos(instanceTarget:GetPos())
  visitor:SetEyeAngles(instanceTarget:GetAngles())
  visitor:EmitSound("buttons/button19.wav")

  visitor._VersusRoomID = roomID
  versus.instance.addPlayer(visitor, instanceID)

  local playerInstance = versus.instance.getPlayerInstance(visitor)
  hook.Run("PlayerSwitchedToInstance", visitor, playerInstance, roomID)
end)
