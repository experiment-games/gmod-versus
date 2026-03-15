local g_Player = player

file.CreateDir(GM.FolderName)

-- Include the shared gamemode file.
AddCSLuaFile("sh_init.lua")
include("sh_init.lua")

GM.entities = GM.entities or {}

-- Add the Lua files that we need to send to the client.
versus.includePrefixed("cl_init.lua")

-- Versus Official Server Content (https://steamcommunity.com/sharedfiles/filedetails/?id=3674682445)
resource.AddWorkshop("3674682445")

-- Add our red glow to the download list.
resource.AddFile("materials/sprites/redglow8.vmt")

-- Enable realistic fall damage for this gamemode.
game.ConsoleCommand("mp_falldamage 1\n")
game.ConsoleCommand("sbox_godmode 0\n")
game.ConsoleCommand("sbox_plpldamage 0\n")

-- Check to see if local voice is enabled.
if (versus.config["Local Voice"]) then
  game.ConsoleCommand("sv_voiceenable 1\n")
  game.ConsoleCommand("sv_alltalk 1\n")
  game.ConsoleCommand("sv_voicecodec voice_speex\n")
  game.ConsoleCommand("sv_voicequality 5\n")
end

-- A function to check whether we're running on a listen server.
function GM:IsListenServer()
  for _, player in ipairs(g_Player.GetAll()) do
    -- This will always be true in single player
    if (player:IsListenServerHost()) then
      return true
    end
  end

  -- There is no listen server host and it isn't single player.
  return false
end

-- Called when all of the map entities have been initialized.
function GM:InitPostEntity()
  for _, entity in ents.Iterator() do
    self.entities[entity] = entity
  end

  -- Call the base class function.
  return self.BaseClass:InitPostEntity()
end

-- Called when a player initially spawns.
function GM:PlayerInitialSpawn(player)
  player:SetTeam(TEAM_PLAYERS)
end

--- Called when a player spawns.
function GM:PlayerSpawn(player)
  if (not player._VersusInitialized) then
    return
  end

  local hasAnyWeapon = false
  local equippedItems = versus.equipment.getEquippedItems(player)

  for _, item in pairs(equippedItems) do
    if (item.isWeapon) then
      -- A weapon item is equipped, no need to give the default pistol.
      hasAnyWeapon = true
    end
  end

  local hasAnyHealingItem = false
  local inventoryItems = versus.inventory.getItems(player)

  for _, item in pairs(inventoryItems) do
    if (item.isWeapon) then
      -- A weapon item is in the inventory, no need to give the default pistol.
      hasAnyWeapon = true
    end

    if (item.isHealingItem) then
      hasAnyHealingItem = true
    end
  end

  -- When the player spawns and they have no weapons at all, we hand them a basic pistol.
  if (not hasAnyWeapon) then
    local pistolItem = versus.item.createInstance("#cw2_versus_cw_fiveseven")

    if (pistolItem) then
      pistolItem.untradable = true
      versus.equipment.equipItem(player, pistolItem)
    else
      ErrorNoHalt("Failed to create default pistol item for player spawn, item definition not found.\n")
    end
  end

  -- When the player spawns and they have no healing items at all, we hand them a basic heal item.
  if (not hasAnyHealingItem) then
    local healthItem = versus.item.createInstance("health_kit")

    if (healthItem) then
      healthItem.untradable = true
      versus.inventory.giveItem(player, healthItem)
    end
  end
end

-- Called when a player's model should be set.
function GM:PlayerSetModel(player)
  local appearance = player:getCharacter("appearance") or {}
  player:SetModel(appearance.model or table.Random(versus.player.getDefaultModelList()))

  if (appearance.bodygroups) then
    for bodygroup, value in pairs(appearance.bodygroups) do
      player:SetBodygroup(bodygroup, value)
    end
  end
end

-- Choose the model for hands according to their player model.
function GM:PlayerSetHandsModel(player, handEntity) end

-- Called when a player should take damage.
function GM:PlayerShouldTakeDamage(player, attacker)
  -- Confusingly if this return moves to a unit then it stops working
  return true
end

-- Called when a player is attacked by a trace.
function GM:PlayerTraceAttack(player, damageInfo, direction, trace) end

-- Called just before a player dies.
function GM:DoPlayerDeath(player, attacker, damageInfo) end

-- Called when a player dies.
function GM:PlayerDeath(player, inflictor, attacker, ragdoll) end

-- Called when a player's weapons should be given.
function GM:PlayerLoadout(player)
  versus.util.nextFrame(function()
    hook.Run("PostPlayerLoadout", player)
  end, player)
end

-- Called when the server shuts down or the map changes.
function GM:ShutDown()
  -- Workaround for bug:
  -- https://github.com/Facepunch/garrysmod-issues/issues/3523
  if (self:IsListenServer()) then
    for _, player in ipairs(g_Player.GetAll()) do
      if (player:IsListenServerHost()) then
        hook.Call("PlayerDisconnected", self, player)
        return
      end
    end
  end
end

-- Called when a player presses a key.
function GM:KeyPress(player, key) end

-- Called when a player presses F1.
function GM:ShowHelp(player) end

-- Called when a player presses F2.
function GM:ShowTeam(player) end

-- Called when a player says something.
function GM:PlayerSay(player, text, public)
  -- Override default
  if (not player._VersusInitialized) then
    return ""
  end
end

-- Called when a player switches their flashlight on or off.
function GM:PlayerSwitchFlashlight(player, on) end

-- Called when a player attempts suicide.
function GM:CanPlayerSuicide(player) end

-- Called when a player attempts to punt an entity with the gravity gun.
function GM:GravGunPunt(player, entity) end

-- Called when a player attempts to pick up an entity with the physics gun.
function GM:PhysgunPickup(player, entity)
  if (self.entities[entity]) then
    return false
  end

  -- Call the base class function.
  return self.BaseClass:PhysgunPickup(player, entity)
end

-- Called when a player attempts to drop an entity with the physics gun.
function GM:PhysgunDrop(player, entity) end

-- Called when a player attempts to use a tool.
function GM:CanTool(player, trace, tool)
  if (IsValid(trace.Entity)) then
    if (tool == "nail") then
      local line = {}

      -- Set the information for the trace line.
      line.start = trace.HitPos
      line.endpos = trace.HitPos + player:GetAimVector() * 16
      line.filter = { player, trace.Entity }

      -- Perform the trace line.
      line = util.TraceLine(line)

      -- Check if the trace entity is valid.
      if (IsValid(line.Entity)) then
        if (self.entities[line.Entity]) then
          return false
        end
      end
    end

    -- Check if we're using the remover tool and we're trying to remove constrained entities.
    if (tool == "remover" and player:KeyDown(IN_ATTACK2) and not player:KeyDownLast(IN_ATTACK2)) then
      local entities = constraint.GetAllConstrainedEntities(trace.Entity)

      for _, entity in pairs(entities) do
        -- Check if it's a map entity
        if (self.entities[entity]) then
          return false
        end
      end
    end

    -- Check if this entity cannot be used by the tool.
    if (self.entities[trace.Entity]) then
      return false
    end
  end

  -- Call the base class function.
  return self.BaseClass:CanTool(player, trace, tool)
end

-- Called when a player attempts to spawn an NPC.
function GM:PlayerSpawnNPC(player, model) end

-- Called when a player attempts to spawn a ragdoll.
function GM:PlayerSpawnRagdoll(player, model) end

-- Called when a player attempts to spawn an effect.
function GM:PlayerSpawnEffect(player, model) end

-- Called when a player attempts to spawn a SWEP.
function GM:PlayerSpawnSWEP(player, class, weapon) end

-- Called when a player is given a SWEP.
function GM:PlayerGiveSWEP(player, class, weapon) end

-- Called when attempts to spawn a SENT.
function GM:PlayerSpawnSENT(player, class) end
