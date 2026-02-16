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

  -- TODO: In the future, kick players when the owner leaves the room. For now we just save the position of entities in the room when players leave.
  PLUGIN.saveAllRoomEntityDataForPlayer(owner, instanceID, owner._VersusRoomID)
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
