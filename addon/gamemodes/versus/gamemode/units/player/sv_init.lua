local UNIT = UNIT
local g_Player = player

UNIT._GetInfoNumOverrides = UNIT._GetInfoNumOverrides or {}

util.AddNetworkString("versus.player.setPlayerVariable")
util.AddNetworkString("versus.finance.changeMoney")
util.AddNetworkString("versus.player.initialized")
util.AddNetworkString("versus.player.ready")

UNIT.nextSecond = UNIT.nextSecond or 0

function UNIT.initialize(player)
  local blockingCallbacks = {}
  hook.Run("PlayerInitializing", player, blockingCallbacks)

  local checkInitializedTimer = "Check Player Initializing: " .. player:getCharacter("id")

  -- Let plugins initialize startup data and send that to the player before
  -- they are spawned into the game
  timer.Create(checkInitializedTimer, 0.5, 0, function()
    if (not IsValid(player)) then
      timer.Remove(checkInitializedTimer)
      return
    end

    for _, blockingCallback in pairs(blockingCallbacks) do
      if (blockingCallback(player) ~= true) then
        -- Let plugins do their thing
        return
      end
    end

    -- Past this point we've done loading, initialize the player now
    timer.Remove(checkInitializedTimer)

    player._VersusInitialized = true
    hook.Run("PlayerInitialized", player)
    player._UpdateData = true

    net.Start("versus.player.initialized")
    net.Send(player)

    -- Check if we are allowed to spawn from other hooks. The PlayerDeathThink we
    -- manage will now allow it since _VersusInitialized is true, but other plugins may
    -- have their own checks
    local canSpawn = hook.Run("PlayerDeathThink", player) ~= false

    if (canSpawn) then
      player:Spawn()
    end
  end)
end

function UNIT.changeAppearance(player, model, skin, bodygroups)
  local validModels = versus.player.getDefaultModelList()
  local validBodygroups = versus.player.getDefaultBodygroupOptions()

  if (not table.HasValue(validModels, model)) then
    versus.message.notify(player, "The model you chose for your appearance is not valid!", NOTIFY_ERROR)
    return
  end

  local appearance = player:getCharacter("appearance")

  appearance.model = model
  appearance.skin = skin
  appearance.bodygroups = bodygroups

  for bodygroupName, bodygroup in pairs(bodygroups) do
    local availableBodygroups = validBodygroups[bodygroupName]

    if (availableBodygroups == nil or not availableBodygroups[bodygroup]) then
      versus.message.notify(player, "The " .. bodygroupName .. " you chose for your appearance is not valid!",
        NOTIFY_ERROR)
      return
    end
  end

  hook.Run("PlayerChangedAppearance", player, appearance)

  player:setCharacterDirty(true)
end

function UNIT.reloadAppearance(player)
  local appearance = player:getCharacter("appearance") or {}
  player:SetModel(appearance.model or table.Random(versus.player.getDefaultModelList()))
  player:SetSkin(appearance.skin or 0)

  if (appearance.bodygroups) then
    for bodygroup, value in pairs(appearance.bodygroups) do
      local bodygroupID = player:FindBodygroupByName(bodygroup)
      player:SetBodygroup(bodygroupID, value)
    end
  end
end

-- Give access to a player.
function UNIT.giveFlags(player, access)
  for i = 1, string.len(access) do
    local flag = string.sub(access, i, i)

    -- Check to see if we do not already have this flag.
    if (not string.find(player:getCharacter("flags"), flag, nil, true)) then
      player:setCharacter("flags", player:getCharacter("flags") .. flag)
      player:SetNWString("versus_Flags", player:getCharacter("flags"))

      hook.Run("PlayerGotAccessFlags", player, access)
    end
  end
end

-- Take access from a player.
function UNIT.takeFlags(player, access)
  for i = 1, string.len(access) do
    local flag = string.sub(access, i, i)

    -- Check to see if we have this flag.
    if (string.find(player:getCharacter("flags"), flag, nil, true)) then
      player:setCharacter("flags", string.gsub(player:getCharacter("flags"), access, ""))
      player:SetNWString("versus_Flags", player:getCharacter("flags"))

      hook.Run("PlayerLostAccessFlags", player, access)
    end
  end
end

-- Set a player's local player variable for the client.
function UNIT.setLocalPlayerVariable(player, class, key, value)
  if (IsValid(player)) then
    local variable = key .. "_Last_" .. class

    -- Check if we can send this player variable again.
    if (player[variable] == nil or player[variable] ~= value) then
      net.Start("versus.player.setPlayerVariable")
      net.WriteUInt(class, 5)
      net.WriteString(key)

      -- Check if we can get what class of variable it is.
      if (class == NWTYPE_STRING) then
        value = value or ""
        net.WriteString(value)
      elseif (class == NWTYPE_LONG) then
        value = value or 0
        net.WriteInt(value, 32)
      elseif (class == NWTYPE_ULONG) then
        value = value or 0
        net.WriteUInt(value, 32)
      elseif (class == NWTYPE_SHORT) then
        value = value or 0
        net.WriteInt(value, 16)
      elseif (class == NWTYPE_USHORT) then
        value = value or 0
        net.WriteUInt(value, 16)
      elseif (class == NWTYPE_BOOL) then
        value = value or false
        net.WriteBool(value)
      elseif (class == NWTYPE_VECTOR) then
        value = value or Vector(0, 0, 0)
        net.WriteVector(value)
      elseif (class == NWTYPE_ENTITY) then
        value = value or NULL
        net.WriteEntity(value)
      elseif (class == NWTYPE_ANGLE) then
        value = value or Angle(0, 0, 0)
        net.WriteAngle(value)
      elseif (class == NWTYPE_CHAR) then
        value = value or 0
        net.WriteUInt(string.byte(value), 8)
      elseif (class == NWTYPE_BYTE) then
        value = value or 0
        net.WriteInt(value, 8)
      elseif (class == NWTYPE_UBYTE) then
        value = value or 0
        net.WriteUInt(value, 8)
      elseif (class == NWTYPE_FLOAT) then
        value = value or 0
        net.WriteFloat(value)
      end
      net.Send(player)

      -- Set the last sent value with this key to this value.
      player[variable] = value
    end
  end
end

-- Print a message to player's with the specified access.
function UNIT.printConsoleAccess(text, access)
  for _, player in ipairs(g_Player.GetAll()) do
    if (UNIT.hasFlags(player, access)) then
      player:PrintMessage(2, text)
    end
  end
end

-- Get a player by a part of their name.
function UNIT.get(name)
  for _, player in ipairs(g_Player.GetAll()) do
    if (string.find(string.lower(player:getCombinedName()), string.lower(name), nil, true)) then
      return player
    end
  end

  return false
end

-- Make a player bleed or stop them from bleeding.
function UNIT.bleed(player, boolean, seconds)
  if (not boolean) then
    timer.Remove("Bleed: " .. player:getVersusID())
  else
    timer.Create("Bleed: " .. player:getVersusID(), 0.25, (seconds or 0) * 4, function()
      if (IsValid(player)) then
        local trace = {}

        -- Set some settings and information for the trace.
        trace.start = player:GetPos() + Vector(0, 0, 256)
        trace.endpos = trace.start + Vector(0, 0, -1024)
        trace.filter = player

        -- Create the trace line from the set information.
        trace = util.TraceLine(trace)

        -- Draw a blood decal at the hit position.
        util.Decal("Blood", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal)
      end
    end)
  end
end

-- Knock out a player or bring them back to consciousness.
function UNIT.knockOut(player, isBeingKnockedOut, seconds, reset)
  if (isBeingKnockedOut and player._KnockedOut) then
    return
  elseif (not isBeingKnockedOut and not player._KnockedOut) then
    return
  end

  if (isBeingKnockedOut) then
    local ragdoll = ents.Create("prop_ragdoll")

    -- Get the velocity and model of the player.
    local velocity = player:GetVelocity()
    local model = player:GetModel()

    -- Check if the model is valid without the player in it.
    if (util.IsValidModel(string.Replace(model, "/player/", "/humans/"))) then
      model = string.Replace(model, "/player/", "/humans/")
    end

    -- Set the position, angles and model of the ragdoll and then spawn it.
    ragdoll:SetPos(player:GetPos())
    ragdoll:SetAngles(player:GetAngles())
    ragdoll:SetModel(model)
    ragdoll:Spawn()

    for i = 1, ragdoll:GetPhysicsObjectCount() do
      local physicsObject = ragdoll:GetPhysicsObjectNum(i)

      -- Check if the physics object is a valid entity.
      if (IsValid(physicsObject)) then
        local position, angle = player:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))

        -- Set the position and angle of the physics object, then add velocity to it.
        physicsObject:SetPos(position)
        physicsObject:SetAngles(angle)
        physicsObject:AddVelocity(velocity)
      end
    end

    -- Copy any settings that we can and set the networked entity to the player.
    ragdoll:SetSkin(player:GetSkin())
    ragdoll:SetColor(player:GetColor())
    ragdoll:SetMaterial(player:GetMaterial())
    ragdoll:SetNWEntity("versus_Player", player)

    -- Set the ragdoll's player.
    ragdoll._Player = player

    -- Check if the player is on fire.
    if (player:IsOnFire()) then
      ragdoll:Ignite(8, 0)
    end

    -- Set some variables for this player's ragdoll.
    player._Ragdoll.weapons = {}
    player._Ragdoll.entity = ragdoll
    player._Ragdoll.health = player:Health()
    player._Ragdoll.model = player:GetModel()
    player._Ragdoll.team = player:Team()

    -- Check if the player is alive.
    if (player:Alive()) then
      for _, weapon in pairs(player:GetWeapons()) do
        local class = weapon:GetClass()

        -- Check if this weapon is a valid item.
        local canHolster = false

        if (weapon._VersusItem and hook.Run("PlayerCanHolster", player, class, true) ~= false) then
          canHolster = true

          -- Save the current clip to the item instance so PostPlayerSpawn/onEquip can restore it.
          weapon._VersusItem.clip = weapon:Clip1()
        end

        table.insert(player._Ragdoll.weapons, {
          class = class,
          canHolster = canHolster,
          clip1 = weapon:Clip1(),
          clip2 = weapon:Clip2(),
          item = weapon._VersusItem,
        })
      end

      if (IsValid(player:GetActiveWeapon())) then
        -- Sort the active weapon to the end of the weapons table
        table.sort(player._Ragdoll.weapons, function(a, b)
          if (a.class == player:GetActiveWeapon():GetClass()) then
            return false
          elseif (b.class == player:GetActiveWeapon():GetClass()) then
            return true
          end

          return false
        end)
      end

      -- Check if we specified how long we're knocked out for.
      if (seconds) then
        -- TODO: Move this to a think hook instead
        timer.Create("Become Conscious: " .. player:getVersusID(), seconds, 1, function()
          if (IsValid(player) and player:Alive()) then
            UNIT.knockOut(player, false)
          end
        end)

        -- Set it so that we can get this client side.
        player._VersusBecomeConsciousTime = CurTime() + seconds
        UNIT.setLocalPlayerVariable(player, NWTYPE_ULONG, "_VersusBecomeConsciousTime", player
          ._VersusBecomeConsciousTime)
      end
    end

    -- Check if the player is in a vehicle.
    if (player:InVehicle() and IsValid(player:GetVehicle())) then
      constraint.NoCollide(ragdoll, player:GetVehicle(), true, true)
    end

    -- Strip the player's weapons and make them spectate the ragdoll.
    player:StripWeapons()
    player:Flashlight(false)
    player:Spectate(OBS_MODE_CHASE)
    player:SpectateEntity(ragdoll)
    player:CrosshairDisable()

    -- Stop the player from bleeding.
    UNIT.bleed(player, false)

    -- Set the player to be knocked out.
    player._KnockedOut = true

    -- Set a networked boolean to let the client know we're knocked out.
    player:SetNWBool("versus_KnockedOut", true)
    player:SetNWEntity("versus_Ragdoll", ragdoll)

    -- Call a function on every plugin so they can know about this.
    hook.Run("PlayerKnockedOut", player)
  else
    if (player:Team() ~= player._Ragdoll.team) then
      player._Ragdoll.team = player:Team()

      -- Spawn the player fully.
      player:Spawn()
    else
      player:UnSpectate()
      player:CrosshairEnable()

      -- Check if we're not doing a reset.
      if (not reset) then
        UNIT.lightSpawn(player)
      end

      local last = #player._Ragdoll.weapons
      for i, weapon in ipairs(player._Ragdoll.weapons) do
        if (reset and weapon.canHolster) then
          -- No longer needed, now that weapons stay in the inventory when equipped - joker
          -- if (not versus.inventory.update(player, weapon.class, 1)) then
          --   player:Give(weapon.class)
          -- end
        elseif (weapon.item) then
          -- Versus weapon items are restored by the equipment system's PostPlayerSpawn hook.
          -- Giving them here would cause double-equipping, so we skip them.
        else
          local weaponEntity = player:Give(weapon.class, true)

          if (IsValid(weaponEntity)) then
            weaponEntity:SetClip1(weapon.clip1)
            weaponEntity:SetClip2(weapon.clip2)
          end
        end

        if (i == last) then
          -- We must delay, otherwise the deploy delay of other weapons causes this to fail
          -- commented because it feels janky
          -- timer.Simple(0.8, function()
          --   local weaponEntity = player:GetWeapon(weapon.class)
          --   if (IsValid(player) and IsValid(weaponEntity)) then
          --     versus.weapon.forceSelect(player, weaponEntity)
          --   end
          -- end)
        end
      end

      -- Check if we're not doing a reset.
      if (not reset) then
        if (IsValid(player._Ragdoll.entity)) then
          player:SetPos(player._Ragdoll.entity:GetPos())
          player:SetSkin(player._Ragdoll.entity:GetSkin())
          player:SetColor(player._Ragdoll.entity:GetColor())
          player:SetMaterial(player._Ragdoll.entity:GetMaterial())
        end

        -- Restore some information from the ragdoll.
        player:SetModel(player._Ragdoll.model)
        player:SetSkin(player._Ragdoll.skin)
        player:SetHealth(player._Ragdoll.health)
      end

      -- Check if the ragdoll entity is valid.
      if (IsValid(player._Ragdoll.entity)) then
        player._Ragdoll.entity:Remove()
      end

      -- Restore the ragdoll table and set the knocked out variable to nil.
      player._Ragdoll = {}
      player._KnockedOut = nil
      player._VersusBecomeConsciousTime = nil

      -- Set a networked boolean to let the client know we're unknocked out.
      player:SetNWBool("versus_KnockedOut", false)
      player:SetNWEntity("versus_Ragdoll", NULL)

      -- Remove the timer to become conscious.
      timer.Remove("Become Conscious: " .. player:getVersusID())

      -- Call a function on every plugin so they can know about this.
      hook.Run("PlayerUnknockedOut", player)
    end
  end
end

-- Lightly spawn a player.
function UNIT.lightSpawn(player)
  player._LightSpawn = true

  -- Spawn the player lightly.
  player:Spawn()
end

-- Load a player's data.
function UNIT.loadData(player)
  local name = player:Name()
  local ownerSteamID = player:OwnerSteamID64()
  local steamID = player:SteamID64()

  -- Singleplayer fixes: OwnerSteamID64 returns an empty string, SteamID64 returns no value in singleplayer
  if (game.SinglePlayer()) then
    ownerSteamID = "singleplayer"
    steamID = "singleplayer"
  end

  -- Create the main versus table with some default variables. NOTE: You
  -- should only access these with playerMeta:getCharacter(key, default)
  -- and setCharacter
  player.versus = {}
  player:setCharacter("id", nil)
  player:setCharacter("last_name", name)
  player:setCharacter("owner_steamid", ownerSteamID ~= steamID and ownerSteamID or nil)
  player:setCharacter("steamid", steamID)
  player:setCharacter("money", versus.config["Default Money"])
  player:setCharacter("flags", versus.config["Default Flags"])
  player:setCharacter("blocklist", {})
  player:setCharacter("appearance", {})
  player:setCharacter("data", {})

  hook.Run("PlayerPreDataLoad", player)

  local selectColumns = {
    "`id`",
    "`last_name`",
    "`owner_steamid`",
    "`steamid`",
    "`inventory`",
    "`blocklist`",
    "`appearance`",
    "`data`",
    "`money`",
    "`flags`"
  }

  hook.Run("VersusPlayerBuildSelectColumns", selectColumns)

  local playerStatement = string.format(
    "SELECT %s FROM `%s` WHERE `steamid` = ?",
    table.concat(selectColumns, ", "),
    versus.config["MySQL Player Table"]
  )

  local values = {
    UNIT.getValueTypeDefinition(player:getCharacter("steamid"))
  }

  versus.database.queryPrepared(playerStatement, values, function(result)
    if (IsValid(player)) then
      if (#result > 0) then
        result = result[1]

        player:setCharacterDirty(false)
        player:setCharacter("id", result.id, true)
        player:setCharacter("money", tonumber(result.money), true)
        player:setCharacter("flags", result.flags, true)
        player:setCharacter("inventory", {}, true)

        player:SetNWString("versus_Flags", player:getCharacter("flags"))

        local blocklist = UNIT.convertBlocklistString(result.blocklist)
        local appearance = UNIT.convertAppearanceString(result.appearance)
        local data = UNIT.convertDataString(player, result.data)

        player:setCharacter("blocklist", blocklist, true)
        player:setCharacter("appearance", appearance, true)
        player:setCharacter("data", data, true)

        hook.Run("PlayerDataLoading", player, result)

        hook.Run("PlayerDataLoaded", player, true)
      else
        hook.Run("PlayerDataLoading", player)

        UNIT.saveData(player, true, function()
          -- Only after inserting can we truly say we've loaded the data
          -- since only now the id is known
          hook.Run("PlayerDataLoaded", player, false)
        end, true)
      end
    end
  end)

  --- TODO: This shouldn't be necessary. Commented 27 april 2021
  -- Create a timer to check if the player has initialized and retry
  -- timer.Create("Player Data Loaded: "..player:UniqueID(), 2, 1, function()
  -- 	if(IsValid(player) and not player._VersusInitialized)then UNIT.loadData(player) end
  -- end)
end

-- Get the player's data as a string.
function UNIT.getDataString(player)
  local data = table.Copy(player:getCharacter("data"))

  hook.Run("PlayerSavingData", player, data)

  return util.TableToJSON(data)
end

-- Convert a data string to a table.
function UNIT.convertDataString(player, dataString)
  local data = util.JSONToTable(dataString)

  hook.Run("PlayerConvertingData", player, data)

  return data
end

-- Get the player's blocklisted actions as a string.
function UNIT.getBlocklistString(player)
  return util.TableToJSON(player:getCharacter("blocklist"))
end

-- Convert a blocklist string to a table.
function UNIT.convertBlocklistString(blocklistString)
  return util.JSONToTable(blocklistString)
end

-- Get the player's appearance as a string.
function UNIT.getAppearanceString(player)
  return util.TableToJSON(player:getCharacter("appearance"))
end

-- Convert a appearance data to a table.
function UNIT.convertAppearanceString(appearanceString)
  local appearance = util.JSONToTable(appearanceString)

  -- Replace old models with new ones. TODO: Remove this after a few months (or after a reset)
  if (appearance and appearance.model and string.StartsWith(appearance.model, "models/humans/pandafishizens/")) then
    appearance.model = string.Replace(appearance.model, "models/humans/pandafishizens/", "models/versus/player/")
  end

  return appearance
end

function UNIT.getValueTypeDefinition(value, isUnixTimestmap)
  if (isUnixTimestmap) then
    value = versus.database.getDate(value)
  end

  local databaseType = versus.database.getTypeFromValue(value)

  return {
    value = value,
    databaseType = databaseType,
  }
end

function UNIT.preparePlayerTableKey(player, key)
  if (key == "blocklist") then
    return UNIT.getBlocklistString(player)
  elseif (key == "appearance") then
    return UNIT.getAppearanceString(player)
  elseif (key == "data") then
    return UNIT.getDataString(player)
  else
    return hook.Run("PlayerPrepareTableData", player, key)
  end
end

-- Get a player's data as MySQL key values.
function UNIT.getDataKeyValues(player)
  local keys = ""
  local values = {}
  local valuePlaceholders = ""
  local amount = 1

  for key, rawValue in pairs(player.versus) do
    local final = (table.Count(player.versus) == amount)
    local value

    -- Check to see if it's the final key.
    if (final) then
      keys = keys .. key
    else
      keys = keys .. key .. ", "
    end

    -- Check to see if the type of the value is a table.
    if (type(rawValue) == "table") then
      value = UNIT.preparePlayerTableKey(player, key, rawValue)
    else
      value = rawValue
    end

    table.insert(values, UNIT.getValueTypeDefinition(value))

    -- Check to see if it's the final key.
    if (final) then
      valuePlaceholders = valuePlaceholders .. "?"
    else
      valuePlaceholders = valuePlaceholders .. "?, "
    end

    -- Update the amount that we've done.
    amount = amount + 1
  end

  return keys, valuePlaceholders, values
end

-- Get an update query of a player's data.
function UNIT.getDataUpdateQuery(player)
  local versusID = player:getVersusID()
  local statement = ""
  local values = {}

  for key, value in pairs(player.versus) do
    if (type(value) == "table") then
      value = UNIT.preparePlayerTableKey(player, key, value)
    end

    -- Check our query to see if it's an empty string.
    if (statement == "") then
      statement = "UPDATE " .. versus.config["MySQL Player Table"] .. " SET " .. key .. " = ?"
    else
      statement = statement .. ", " .. key .. " = ?"
    end

    table.insert(values, UNIT.getValueTypeDefinition(value))
  end

  table.insert(values, UNIT.getValueTypeDefinition(versusID))

  return statement .. " WHERE id = ?", values
end

-- Save a player's data.
function UNIT.saveData(player, create, callback, force)
  if (create) then
    local keys, valuePlaceholders, values = UNIT.getDataKeyValues(player)
    local statement = "INSERT INTO " ..
        versus.config["MySQL Player Table"] .. " (" .. keys .. ") VALUES (" .. valuePlaceholders .. ")"

    versus.database.queryPrepared(statement, values, function(data, lastInsertedID)
      if (not IsValid(player)) then return end

      player:setCharacterDirty(false)
      player:setCharacter("id", lastInsertedID)

      if (callback) then
        callback(player)
      end
    end, nil, true)
  elseif (player._VersusInitialized) then
    if (not force and not player:isCharacterDirty()) then
      print("Not saving, character is not dirty")
      return
    end

    -- Only update if we haven't recently updated. This prevents a user
    -- DOS-ing the server by for example repeatedly dropping and picking up
    -- money
    if (not force and player.nextSaveAllowed and player.nextSaveAllowed > CurTime()) then
      return
    end

    -- Let's see if this works. With 64 players every 10 seconds a save
    -- would mean ~384 database queries every minute. Honestly our server
    -- should be more than capable of handling that.
    player.nextSaveAllowed = CurTime() + 10

    local statement, values = UNIT.getDataUpdateQuery(player)

    versus.database.queryPrepared(statement, values, function()
      if (callback and IsValid(player)) then
        player:setCharacterDirty(false)
        callback(player)
      end
    end)
  end
end

---
-- Source: https://github.com/Lexicality/applejack/blob/master/gamemode/metatables/sv_player.lua#L649
-- Checks if a player is able to pick up an entity based on various limits.
-- This is a Lua version of CBasePlayer::CanPickupObject kindly ported by blackops7799 and then tweaked by Lexi.
-- You can find the original at http://goo.gl/FEFFE
-- @param pObject The entity you wish to pick up
-- @param massLimit The maximum mass the entity may possess.
-- @param sizeLimit The maximum size the entity may be in the X, Y or Z planes. (Diagonal lengths ignored)
-- @return True if they can pick it up, false if they can't.
function UNIT.CanPickupObject(player, pObject, massLimit, sizeLimit)
  if (pObject == NULL) then
    return false, "Object is NULL"
  elseif (pObject:GetMoveType() ~= MOVETYPE_VPHYSICS) then
    return false, "Object cannot be moved!"
  elseif (player:GetGroundEntity() == pObject) then
    return false, "You're standing on that!"
  end

  if (not massLimit) then
    massLimit = 35
  end
  if (not sizeLimit) then
    sizeLimit = 128
  end

  local count = pObject:GetPhysicsObjectCount()

  if (not count) then
    return false, "This object has no physics!"
  end

  local objectMass = 0
  local checkEnable = false

  for i = 0, count - 1 do
    local pList = pObject:GetPhysicsObjectNum(i)
    objectMass = objectMass + pList:GetMass()
    if (pList:HasGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)) then
      return false, "The map maker has asked that you not be able to pick this up."
      --[[elseif ( pList:IsHinged() ) then -- Not possible now
			return false]]
    elseif (not pList:IsMoveable()) then
      checkEnable = true
    end
  end

  if (massLimit > 0 and objectMass > massLimit) then
    return false, "That object is too heavy to carry!"
  elseif (checkEnable and not pObject:HasSpawnFlags(64)) then
    return false, "That object is stuck and can't be carried!"
  end

  if (sizeLimit > 0) then
    local maxs = pObject:OBBMaxs()
    local mins = pObject:OBBMins()
    local sizez = maxs.z - mins.z
    local sizey = maxs.y - mins.y
    local sizex = maxs.x - mins.x
    if (sizex > sizeLimit or sizey > sizeLimit or sizez > sizeLimit) then
      return false, "That object is too big for you to move!"
    end
  end

  return true
end

-- Update a player's data.
function UNIT.update(player)
  if (player:Alive() and not player._KnockedOut and not player:IsInWorld() and player:GetMoveType() == MOVETYPE_WALK) then
    if (not player._StuckInWorld) then player._StuckInWorld = true end
  else
    player._StuckInWorld = false
  end

  -- Check if the player has at least 50 health.
  if (player:Health() >= 50) then player._HideHealthEffects = false end

  -- Set it so that we can get some of the player's information client side.
  UNIT.setLocalPlayerVariable(player, NWTYPE_BOOL, "_HideHealthEffects", player._HideHealthEffects)
  UNIT.setLocalPlayerVariable(player, NWTYPE_BOOL, "_StuckInWorld", player._StuckInWorld)

  local appearance = player:getCharacter("appearance")

  if (appearance.model and appearance.bodygroups) then
    UNIT.setLocalPlayerVariable(player, NWTYPE_STRING, "appearanceModel", appearance.model)
    UNIT.setLocalPlayerVariable(player, NWTYPE_SHORT, "appearanceSkin", appearance.skin)

    for bodygroupName, bodygroups in pairs(versus.player.getDefaultBodygroupOptions()) do
      UNIT.setLocalPlayerVariable(player, NWTYPE_USHORT, "appearanceBodygroup_" .. bodygroupName,
        appearance.bodygroups[bodygroupName])
    end
  end

  hook.Run("PlayerSetLocalVariables", player)
end

function UNIT.addGetInfoNumOverride(conVarName, callback)
  UNIT._GetInfoNumOverrides[conVarName] = UNIT._GetInfoNumOverrides[conVarName] or {}

  table.insert(UNIT._GetInfoNumOverrides[conVarName], callback)
end
