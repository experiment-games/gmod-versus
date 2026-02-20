local UNIT = UNIT
local g_Player = player

util.AddNetworkString("versus.player.initializeAppearance")
util.AddNetworkString("versus.player.initializedAppearance")

-- Called every server tick.
function UNIT.hook:Tick()
  local curTime = CurTime()
  local pastNextSecond = curTime >= self.playerNextSecond
  local pastNextTenthSecond = curTime >= self.playerNextTenthSecond

  for _, player in ipairs(g_Player.GetAll()) do
    if (player._VersusInitialized) then
      if (pastNextSecond) then
        if (player._UpdateData) then
          UNIT.update(player)
        end

        hook.Run("PlayerSecond", player)
      end

      if (pastNextTenthSecond) then
        hook.Run("PlayerTenthSecond", player)
      end
    end
  end

  if (pastNextSecond) then
    self.playerNextSecond = curTime + 1
  end

  if (pastNextTenthSecond) then
    self.playerNextTenthSecond = curTime + 0.1
  end
end

-- Called every 1 second for each player
-- function UNIT.hook:PlayerSecond(player) end

-- Called every 0.1 second for each player
-- function UNIT.hook:PlayerTenthSecond(player) end

-- Called when a player is given a flag for access
function UNIT.hook:PlayerGotAccessFlags(player, access)
  if (UNIT.hasFlags(player, "t")) then player:Give("gmod_tool") end
  if (UNIT.hasFlags(player, "p")) then player:Give("weapon_physgun") end
end

-- Called when a player has a flag for access taken
function UNIT.hook:PlayerLostAccessFlags(player, access)
  if (not UNIT.hasFlags(player, "t")) then player:StripWeapon("gmod_tool") end
  if (not UNIT.hasFlags(player, "p")) then player:StripWeapon("weapon_physgun") end
end

-- Called when a player switches their flashlight on or off.
function UNIT.hook:PlayerSwitchFlashlight(player, on)
  if (player._KnockedOut) then
    return false
  else
    return true
  end
end

-- Called when a player attempts to use an entity.
function UNIT.hook:PlayerUse(player, entity)
  if (player._KnockedOut) then
    return false
  end
end

-- Decides whether a player can hear another player using voice chat.
function UNIT.hook:PlayerCanHearPlayersVoice(listener, talker)
  if (not versus.config["Local Voice"]) then
    return true
  end

  if (talker:Alive()
        and listener:Alive()
        and versus.entity.isNearPosition(talker, listener:GetPos(), versus.config["Talk Radius"])
        and not talker:GetNWBool("versus_KnockedOut")
        and not listener:GetNWBool("versus_KnockedOut")) then
    return true, true
  else
    return false
  end
end

-- Called when a player knocks out another player.
function UNIT.hook:PlayerKnockOut(player, target) end

-- Called when a player wakes up another player.
function UNIT.hook:PlayerWakeUp(player, target) end

-- Called when a player attempts to own a door.
function UNIT.hook:PlayerCanOwnDoor(player, door) end

-- Called when a player attempts to view a door.
function UNIT.hook:PlayerCanViewDoor(player, door) end

-- Called when a player attempts to holster a weapon.
function UNIT.hook:PlayerCanHolster(player, weapon, silent) end

-- Called when a player attempts to use an item.
function UNIT.hook:PlayerCanUseItem(player, item, silent) end

-- Called when a player attempts to knock out a player.
function UNIT.hook:PlayerCanKnockOut(player, target) end

-- Called when a player attempts to wake up another player.
function UNIT.hook:PlayerCanWakeUp(player, target) end

-- Called when a player attempts to use a door.
function UNIT.hook:PlayerCanUseDoor(player, door)
  if (IsValid(door._Owner)) then
    if (door._Owner ~= player) then
      return false
    end
  end
end

-- Called when a player attempts suicide.
function UNIT.hook:CanPlayerSuicide(player)
  return false
end

-- Called when a player attempts to punt an entity with the gravity gun.
function UNIT.hook:GravGunPunt(player, entity)
  return false
end

-- Called when a player attempts to pick up an entity with the physics gun.
function UNIT.hook:PhysgunPickup(player, entity)
  -- Check if the player is an administrator.
  if (player:IsAdmin()) then
    if (entity:IsPlayer()) then
      if (not entity:InVehicle()) then
        entity:SetMoveType(MOVETYPE_NOCLIP)
      else
        return false
      end
    end

    return true
  end

  -- Check if this entity is a player's ragdoll.
  if (IsValid(entity._Player)) then
    return false
  end

  -- Check if the entity is a forbidden class.
  if (string.find(entity:GetClass(), "npc_", nil, false)
        or string.find(entity:GetClass(), "versus_", nil, false)
        or string.find(entity:GetClass(), "prop_vehicle_", nil, false)
        or string.find(entity:GetClass(), "prop_dynamic", nil, false)) then
    return false
  end
end

-- Called when a player attempts to drop an entity with the physics gun.
function UNIT.hook:PhysgunDrop(player, entity)
  if (entity:IsPlayer()) then
    entity:SetMoveType(MOVETYPE_WALK)
  end
end

-- Called when a player attempts to spawn an NPC.
function UNIT.hook:PlayerSpawnNPC(player, model)
  if (not UNIT.hasFlags(player, "n")) then
    return false
  end

  if (not player:Alive() or player._KnockedOut) then
    versus.message.notify(player, "You cannot do that because you are unconcious!", NOTIFY_ERROR)

    return false
  end

  -- Check if the player is an administrator.
  if (not player:IsAdmin()) then
    return false
  else
    return true
  end
end

-- Called when a player attempts to spawn a prop.
function UNIT.hook:PlayerSpawnProp(player, model)
  if (not UNIT.hasFlags(player, "e")) then
    return false
  end

  -- Check if the player can spawn this prop.
  if (not player:Alive() or player._KnockedOut) then
    versus.message.notify(player, "You cannot do that because you are unconcious!", NOTIFY_ERROR)

    return false
  end

  -- Check if the player is an administrator.
  if (player:IsAdmin()) then
    return true
  end

  -- Escape the bad characters from the model.
  model = string.Replace(model, "\\", "/")
  model = string.Replace(model, "//", "/")

  for _, bannedProp in pairs(versus.config["Banned Props"]) do
    if (string.lower(bannedProp) == string.lower(model)) then
      versus.message.notify(player, "You cannot spawn banned props!", NOTIFY_ERROR)

      return false
    end
  end

  -- Check if they can spawn this prop yet.
  if (player._NextSpawnProp and player._NextSpawnProp > CurTime()) then
    versus.message.notify(player, "You cannot spawn another prop for " ..
      math.ceil(player._NextSpawnProp - CurTime()) .. " second(s)!", NOTIFY_ERROR)

    return false
  else
    player._NextSpawnProp = CurTime() + 1
  end
end

-- When a prop is spawned, we check that it's not too big
function UNIT.hook:PlayerSpawnedProp(player, modelPath, entity)
  local maximumBounds = versus.config["Maximum Prop Bounds"]
  local min, max = entity:GetModelBounds()

  if (math.abs(max.x - min.x) > maximumBounds.x
        or math.abs(max.y - min.y) > maximumBounds.y
        or math.abs(max.z - min.z) > maximumBounds.z) then
    if (player:IsSuperAdmin()) then
      versus.message.notify(
        player,
        "The prop you tried to spawn is too big, but as an admin it was allowed.",
        NOTIFY_WARNING
      )
      return
    end

    entity:Remove()
    versus.message.notify(player, "The prop you tried to spawn is too big!", NOTIFY_ERROR)
  end
end

-- Called when a player attempts to spawn a ragdoll.
function UNIT.hook:PlayerSpawnRagdoll(player, model)
  if (not UNIT.hasFlags(player, "r")) then
    return false
  end

  if (not player:Alive() or player._KnockedOut) then
    versus.message.notify(player, "You cannot do that because you are unconcious!", NOTIFY_ERROR)

    return false
  end

  if (not player:IsAdmin()) then
    return false
  else
    return true
  end
end

-- Called when a player attempts to spawn an effect.
function UNIT.hook:PlayerSpawnEffect(player, model)
  if (not UNIT.hasFlags(player, "f")) then
    return false
  end

  if (not player:Alive() or player._KnockedOut) then
    versus.message.notify(player, "You cannot do that because you are unconcious!", NOTIFY_ERROR)

    return false
  end

  if (not player:IsAdmin()) then
    return false
  else
    return true
  end
end

-- Called when a player attempts to spawn a vehicle.
function UNIT.hook:PlayerSpawnVehicle(player, model)
  if (player:IsAdmin()) then
    return true
  end

  if (not UNIT.hasFlags(player, "v")) then
    return false
  end

  -- Check if the model is a chair.
  if (not string.find(model, "chair", nil, false) and not string.find(model, "seat", nil, false)) then
    return false
  end

  -- Check if the player can spawn this vehicle.
  if (not player:Alive() or player._KnockedOut) then
    versus.message.notify(player, "You cannot do that because you are unconcious!", NOTIFY_ERROR)

    return false
  end
end

-- Called when a player attempts to use a tool.
function UNIT.hook:CanTool(player, trace, tool)
  if (not UNIT.hasFlags(player, "t")) then
    return false
  end

  if (player:IsAdmin()) then
    return true
  end

  if (IsValid(trace.Entity)) then
    -- Check if this entity is a player's ragdoll.
    if (IsValid(trace.Entity._Player)) then
      return false
    end
  end
end

-- Called when a player attempts to noclip.
function UNIT.hook:PlayerNoClip(player)
  if (player._KnockedOut) then
    return false
  else
    if (player:IsAdmin()) then
      return true
    else
      return false
    end
  end
end

net.Receive("versus.player.initializedAppearance", function(len, player)
  local alreadySetup = net.ReadBool()

  if (not alreadySetup) then
    local model = net.ReadString()
    local bodygroupOptionCount = net.ReadUInt(6)

    local appearance = {}

    for i = 1, bodygroupOptionCount do
      local bodygroupName = net.ReadString()
      local bodygroup = net.ReadUInt(6)

      appearance[bodygroupName] = bodygroup
    end

    UNIT.changeAppearance(player, model, appearance)
  end

  player._AppearanceInitialized = true
end)

-- Called to get a list of functions that should return true when this unit
-- is done doing it's loading for the player. The player won't spawn until
-- all blockingCallbacks return true
function UNIT.hook:PlayerInitializing(player, blockingCallbacks)
  if (player:IsBot()) then
    return
  end

  local appearance = player:getCharacter("appearance")

  net.Start("versus.player.initializeAppearance")
  net.WriteString(appearance.model or "")

  for bodygroupName, bodygroups in pairs(versus.player.getDefaultBodygroupOptions()) do
    net.WriteString(bodygroupName .. ":" .. tostring(appearance.bodygroups and appearance.bodygroups[bodygroupName] or 0))
  end
  net.Send(player)

  table.insert(blockingCallbacks, function(player)
    return player._AppearanceInitialized == true
  end)
end

-- Called when a player's data is loaded.
function UNIT.hook:PlayerDataLoaded(player, isExisting)
  player._Ammo = {}
  player.nextPayday = 0
  player._Ragdoll = {}
  player._Sleeping = false
  player._LightSpawn = false
  player._ChangeTeam = false
  player._NextChangeTeam = {}
  player._HideHealthEffects = false

  player:SetNWInt("versus_ID", player:getCharacter("id"))

  player._SpawnTime = versus.config["Spawn Time"]
  player._KnockOutTime = versus.config["Knock Out Time"]

  UNIT.initialize(player)
end

-- Called when a player initially spawns.
function UNIT.hook:PlayerInitialSpawn(player)
  if (player:IsBot()) then
    UNIT.loadData(player)
  end

  if (not player._VersusInitialized) then
    -- Kill them silently until we've loaded the data.
    player:KillSilent()
  end
end

-- Called every frame that a player is dead.
function UNIT.hook:PlayerDeathThink(player)
  if (not player._VersusInitialized) then
    return false
  end

  if (player._VersusNextSpawnTime and CurTime() >= player._VersusNextSpawnTime) then
    player:Spawn()
  end

  -- Check if the player is a bot.
  if (player:SteamID() == "BOT") then
    return true
  end
end

-- Called when a player should gain a frag.
function UNIT.hook:PlayerCanGainFrag(player, victim) end

-- Called when a player spawns.
function UNIT.hook:PlayerSpawn(player)
  -- So ShouldCollide is called in sh_hooks
  player:SetCustomCollisionCheck(true)

  if (player._VersusInitialized) then
    -- Do not drop weapons in the default hl2 manner (we manually drop versus items instead)
    player:ShouldDropWeapon(false)

    -- Check if we're respawning from death
    if (not player._LightSpawn) then
      player:SetRunSpeed(versus.config["Run Speed"])
      player:SetWalkSpeed(versus.config["Walk Speed"])

      player._Ammo = {}
      player._Sleeping = false
      player._HideHealthEffects = false

      -- Make the player become conscious again.
      UNIT.knockOut(player, false, nil, true)

      hook.Run("PlayerSetModel", player)
      hook.Run("PlayerLoadout", player)
    end

    hook.Run("PostPlayerSpawn", player, player._LightSpawn, player._ChangeTeam)

    player._LightSpawn = false
    player._ChangeTeam = false
  else
    player:KillSilent()
  end

  player:SetupHands()
end

-- Choose the model for hands according to their player model.
function UNIT.hook:PlayerSetHandsModel(player, handEntity)
  local playerModelName = player_manager.TranslateToPlayerModelName(player:GetModel())
  local handsModelInfo = player_manager.TranslatePlayerHands(playerModelName)

  if (handsModelInfo) then
    handEntity:SetModel(handsModelInfo.model)
    handEntity:SetSkin(handsModelInfo.skin)
    handEntity:SetBodyGroups(handsModelInfo.body)
  end
end

-- Called when a player is attacked by a trace.
function UNIT.hook:PlayerTraceAttack(player, damageInfo, direction, trace)
  player._LastHitGroup = trace.HitGroup

  return false
end

-- Called as a player dies (not called for KillSilent).
function UNIT.hook:DoPlayerDeath(player, attacker, damageInfo)
  UNIT.bleed(player, false)

  -- We delay the stripping of weapons/ammo so other DoPlayerDeath hooks can still access them
  versus.util.nextFrame(function()
    -- Strip any remaining weapons the player has
    player:StripWeapons()

    -- TODO: Store ammo
    player:StripAmmo()
  end, player)

  player:AddDeaths(1)

  if (IsValid(attacker) and attacker:IsPlayer()) then
    if (player ~= attacker) then
      if (hook.Run("PlayerCanGainFrag", attacker, player) ~= false) then
        attacker:AddFrags(1)
      end
    end
  end
end

-- Called when a player dies.
function UNIT.hook:PlayerDeath(player, inflictor, attacker, ragdoll)
  if (ragdoll ~= false) then
    player._Ragdoll.weapons = {}
    player._Ragdoll.health = player:Health()
    player._Ragdoll.model = player:GetModel()
    player._Ragdoll.team = player:Team()

    -- Knockout the player to simulate their death.
    UNIT.knockOut(player, true)
  end

  local hasNextRespawnTime = hook.Run("CanPlayerRespawnInTime", player, attacker) ~= false

  if (hasNextRespawnTime) then
    -- Set their next spawn time.
    player._VersusNextSpawnTime = CurTime() + player._SpawnTime

    -- Set it so that we can the next spawn time client side.
    UNIT.setLocalPlayerVariable(player, NWTYPE_ULONG, "_VersusNextSpawnTime", player._VersusNextSpawnTime)
  end

  -- Check if the attacker is a player.
  if (attacker:IsPlayer()) then
    if (IsValid(attacker:GetActiveWeapon())) then
      UNIT.printConsoleAccess(
        attacker:getCombinedName() ..
        " killed " .. player:getCombinedName() .. " with " .. attacker:GetActiveWeapon():GetClass() .. ".", "a")
    else
      UNIT.printConsoleAccess(attacker:getCombinedName() .. " killed " .. player:getCombinedName() .. ".", "a")
    end
  else
    UNIT.printConsoleAccess(attacker:GetClass() .. " killed " .. player:getCombinedName() .. ".", "a")
  end
end

-- Called when a player's weapons should be given.
function UNIT.hook:PlayerLoadout(player)
  -- We must give at least 1 weapon the player can select. Since we give grenade weapons that are not selectable
  -- while they don't have ammo. If we have not at least 1 selectable weapon, a grenade weapon would be selected
  -- and visually show a grenade the player cannot use.
  player:Give("weapon_fists")

  if (UNIT.hasFlags(player, "t")) then
    player:Give("gmod_tool")
  end
  if (UNIT.hasFlags(player, "p")) then
    player:Give("weapon_physgun")
  end
end

-- Called when the server shuts down or the map changes.
function UNIT.hook:ShutDown()
  for _, player in ipairs(g_Player.GetAll()) do
    versus.weapon.holsterAllWeaponItems(player)

    UNIT.saveData(player, nil, nil, true)
  end
end

-- Called when an entity takes damage.
function UNIT.hook:EntityTakeDamage(entity, damageInfo)
  local attacker = damageInfo:GetAttacker()
  local amount = damageInfo:GetDamage()
  local inflictor = damageInfo:GetInflictor()

  if (not IsValid(attacker)) then
    return
  end

  if (attacker:IsPlayer() and IsValid(attacker:GetActiveWeapon())
        and attacker:GetActiveWeapon():GetClass() == "weapon_stunstick") then
    damageInfo:SetDamage(versus.config["Stunstick Damage"])
  end

  -- Check if the entity that got damaged is a player.
  if (entity:IsPlayer()) then
    if (entity._KnockedOut) then
      if (IsValid(entity._Ragdoll.entity)) then
        hook.Run("EntityTakeDamage", entity._Ragdoll.entity, damageInfo)
      end
    else
      if (entity:InVehicle() and damageInfo:IsExplosionDamage()) then
        if (not damageInfo:GetDamage() or damageInfo:GetDamage() == 0) then
          damageInfo:SetDamage(100)
        end
      end

      -- Check if the player has a last hit group defined.
      if (entity._LastHitGroup) then
        if (entity._LastHitGroup == HITGROUP_HEAD) then
          damageInfo:ScaleDamage(versus.config["Scale Head Damage"])
        elseif (entity._LastHitGroup == HITGROUP_CHEST or entity._LastHitGroup == HITGROUP_GENERIC) then
          damageInfo:ScaleDamage(versus.config["Scale Chest Damage"])
        elseif (entity._LastHitGroup == HITGROUP_LEFTARM or
              entity._LastHitGroup == HITGROUP_RIGHTARM or
              entity._LastHitGroup == HITGROUP_LEFTLEG or
              entity._LastHitGroup == HITGROUP_RIGHTLEG or
              entity._LastHitGroup == HITGROUP_GEAR) then
          damageInfo:ScaleDamage(versus.config["Scale Limb Damage"])
        end

        -- Set the last hit group to nil so that we don't use it again.
        entity._LastHitGroup = nil
      end

      -- Make the player bleed.
      UNIT.bleed(entity, true, versus.config["Bleed Time"])
    end
  elseif (entity:IsNPC()) then
    if (attacker:IsPlayer() and IsValid(attacker:GetActiveWeapon())
          and attacker:GetActiveWeapon():GetClass() == "weapon_crowbar") then
      damageInfo:ScaleDamage(0.25)
    end
  end

  -- Check if the entity is a knocked out player.
  if (IsValid(entity._Player)) then
    local player = entity._Player

    -- Set the damage to the amount we're given.
    damageInfo:SetDamage(amount)

    -- Check if the attacker is not a player.
    if (not attacker:IsPlayer()) then
      if (attacker == game.GetWorld()) then
        if ((entity._NextWorldDamage and entity._NextWorldDamage > CurTime())
              or damageInfo:GetDamage() <= 10) then
          return
        end

        -- Set the next world damage to be 1 second from now.
        entity._NextWorldDamage = CurTime() + 1
      else
        if (damageInfo:GetDamage() <= 25) then
          return
        end
      end
    else
      damageInfo:ScaleDamage(versus.config["Scale Ragdoll Damage"])
    end

    -- Take the damage from the player's health.
    player:SetHealth(math.max(player:Health() - damageInfo:GetDamage(), 0))

    -- Set the player's conscious health.
    player._Ragdoll.health = player:Health()

    -- Create new effect data so that we can create a blood impact at the damage position.
    local effectData = EffectData()
    effectData:SetOrigin(damageInfo:GetDamagePosition())
    util.Effect("BloodImpact", effectData)

    -- Draw some blood decals around the ragdoll.
    for i = 1, 2 do
      local trace = {}

      -- Set some settings and information for the trace.
      trace.start = damageInfo:GetDamagePosition()
      trace.endpos = trace.start + (damageInfo:GetDamageForce() + (VectorRand() * 16) * 128)
      trace.filter = entity

      -- Create the trace line from the set information.
      trace = util.TraceLine(trace)

      -- Draw a blood decal at the hit position.
      util.Decal("Blood", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal)
    end

    -- Check to see if the player's health is less than 0 and that the player is alive.
    if (player:Health() <= 0 and player:Alive()) then
      player:KillSilent()

      -- Call some gamemode hooks to fake the player's death.
      hook.Run("DoPlayerDeath", player, attacker, damageInfo)
      hook.Run("PlayerDeath", player, inflictor, attacker, false)
    end
  end
end

-- Called when a player has disconnected.
function UNIT.hook:PlayerDisconnected(player)
  versus.weapon.holsterAllWeaponItems(player)
  UNIT.knockOut(player, false, nil, true)

  -- We call this hook twice so we don't have to worry about hook order
  -- TODO: We could think of a better way to handle this. (used for failContract and removing items on disconnect)
  hook.Run("PlayerSaveDisconnect", player)
  hook.Run("PlayerSaveDisconnect2", player)
  UNIT.saveData(player, nil, nil, true)
end

-- Called when a player presses a key.
function UNIT.hook:KeyPress(player, key)
  if (key == IN_JUMP and player._StuckInWorld) then
    versus.weapon.holsterAllWeaponItems(player)

    -- Spawn them lightly now that we holstered their weapons.
    UNIT.lightSpawn(player)
  end
end

-- Called when a player attempts to spawn a SWEP.
function UNIT.hook:PlayerSpawnSWEP(player, class, weapon)
  if (not player:IsSuperAdmin()) then
    return false
  else
    return true
  end
end

-- Called when a player is given a SWEP.
function UNIT.hook:PlayerGiveSWEP(player, class, weapon)
  if (not player:IsSuperAdmin()) then
    return false
  else
    return true
  end
end

-- Called when attempts to spawn a SENT.
function UNIT.hook:PlayerSpawnSENT(player, class)
  if (not player:IsSuperAdmin()) then
    return false
  else
    return true
  end
end

net.Receive("versus.player.ready", function(len, player)
  UNIT.loadData(player)
end)

function UNIT.hook:VersusBuildCreateTablesQueriesCore(queries)
  local extraColumns = {}
  hook.Run("VersusPlayerBuildExtraColumns", extraColumns)

  local extraColumnSQL = ""
  for _, columnDef in ipairs(extraColumns) do
    extraColumnSQL = extraColumnSQL .. ",\n\t\t\t" .. columnDef
  end

  table.insert(queries, string.format([[
		CREATE TABLE IF NOT EXISTS `%s` (
			`id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			`last_name` varchar(255) NOT NULL,
			`owner_steamid` varchar(255) NULL DEFAULT NULL,
			`steamid` varchar(255) NOT NULL,
			`inventory` longtext NOT NULL,
			`blocklist` longtext NOT NULL,
			`appearance` longtext NOT NULL,
			`data` longtext NOT NULL,
			`donator` TIMESTAMP NULL DEFAULT NULL,
			`money` bigint(20) UNSIGNED NOT NULL,
			`flags` varchar(255) NOT NULL%s
		);
	]], versus.config["MySQL Player Table"], extraColumnSQL))
end
