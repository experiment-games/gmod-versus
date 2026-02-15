local PLUGIN = PLUGIN
local NPC = PLUGIN.get("quartermaster") or {}

NPC.name = "Quartermaster"
NPC.description = "Distributes standard issue equipment to new recruits."
NPC.model = "models/Humans/Group03/male_04.mdl"
NPC.bodygroups = {}
NPC.health = PLUGIN.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  PLUGIN.openNPCMenu(player, "versus_Quartermaster")
end

PLUGIN.registerNPC("quartermaster", NPC)

--[[
  Logic
--]]

local STARTER_KIT_COOLDOWN = 3600 -- 1 hour cooldown between claims

util.AddNetworkString("versus.npc.checkStarterKit")
util.AddNetworkString("versus.npc.claimStarterKit")
util.AddNetworkString("versus.npc.starterKitStatus")
util.AddNetworkString("versus.npc.starterKitClaimed")

net.Receive("versus.npc.checkStarterKit", function(len, player)
  local data = player:getCharacter("data")
  local hasWeapon = versus.inventory.hasItemInAnyInventory(player, "base_weapon")
  local onCooldown = data.lastClaimedStarterKit and (os.time() - data.lastClaimedStarterKit < STARTER_KIT_COOLDOWN)
  local canNotClaim = hasWeapon or onCooldown

  local timeRemaining = 0
  if data.lastClaimedStarterKit then
    local timeSinceClaim = os.time() - data.lastClaimedStarterKit
    timeRemaining = math.max(0, STARTER_KIT_COOLDOWN - timeSinceClaim)
  end

  net.Start("versus.npc.starterKitStatus")
  net.WriteBool(canNotClaim)
  net.WriteBool(hasWeapon)
  net.WriteBool(onCooldown or false)
  net.WriteUInt(timeRemaining, 32)
  net.Send(player)
end)

net.Receive("versus.npc.claimStarterKit", function(len, player)
  local data = player:getCharacter("data")

  -- Check if player already has a weapon
  if versus.inventory.hasItemInAnyInventory(player, "base_weapon") then
    versus.message.notify(player, "You already have a weapon!", NOTIFY_ERROR)
    return
  end

  -- Check cooldown
  local onCooldown = data.lastClaimedStarterKit and (os.time() - data.lastClaimedStarterKit < STARTER_KIT_COOLDOWN)
  if onCooldown then
    versus.message.notify(player, "You have already claimed your starter equipment!", NOTIFY_ERROR)
    return
  end

  local pistolItem = versus.item.get("#cw2_versus_cw_fiveseven")
  local ammoItem = versus.item.get("ammo_57x28")

  if not pistolItem or not ammoItem then
    versus.message.notify(player, "Starter equipment items not found!", NOTIFY_ERROR)
    ErrorNoHalt("[Versus] Starter kit items not found: #cw2_versus_cw_fiveseven or ammo_57x28\n")
    return
  end

  local totalSize = pistolItem.size + ammoItem.size

  if not versus.inventory.canFit(player, totalSize) then
    versus.message.notify(
      player,
      "You do not have enough inventory space! You need " .. totalSize .. " slots.",
      NOTIFY_ERROR
    )
    return
  end

  -- Give items
  local pistol = versus.item.createInstance("#cw2_versus_cw_fiveseven")
  local ammo = versus.item.createInstance("ammo_57x28")

  -- Mark these items as non-scrappable to prevent abuse
  pistol.cannotBeScrapped = true
  ammo.cannotBeScrapped = true

  versus.inventory.giveItem(player, pistol)
  versus.inventory.giveItem(player, ammo)

  data.lastClaimedStarterKit = os.time()

  -- Notify player
  versus.message.notify(player, "Starter equipment claimed successfully!", NOTIFY_SUCCESS)

  net.Start("versus.npc.starterKitClaimed")
  net.Send(player)
end)
