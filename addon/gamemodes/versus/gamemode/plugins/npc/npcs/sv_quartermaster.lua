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
  local hasWeapon = table.Count(versus.inventory.findAllWithBaseInAnyInventory(player, "base_weapon")) > 0
  local hasAmmo = table.Count(versus.inventory.findAllWithIDInAnyInventory(player, "ammo_57x28")) > 0
  local onCooldown = data.lastClaimedStarterKit and (os.time() - data.lastClaimedStarterKit < STARTER_KIT_COOLDOWN)

  -- Can claim full kit if no weapon and not on cooldown
  local canClaimFullKit = not hasWeapon and not onCooldown
  -- Can claim ammo only if has weapon but no ammo and not on cooldown
  local canClaimAmmoOnly = hasWeapon and not hasAmmo and not onCooldown
  local canNotClaim = not canClaimFullKit and not canClaimAmmoOnly

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
  net.WriteBool(canClaimAmmoOnly)
  net.WriteBool(hasAmmo)
  net.Send(player)
end)

net.Receive("versus.npc.claimStarterKit", function(len, player)
  local claimType = net.ReadString()
  local data = player:getCharacter("data")

  -- Check cooldown
  local onCooldown = data.lastClaimedStarterKit and (os.time() - data.lastClaimedStarterKit < STARTER_KIT_COOLDOWN)
  if onCooldown then
    versus.message.notify(player, "You have already claimed your starter equipment!", NOTIFY_ERROR)
    return
  end

  local hasWeapon = table.Count(versus.inventory.findAllWithBaseInAnyInventory(player, "base_weapon")) > 0
  local hasAmmo = table.Count(versus.inventory.findAllWithIDInAnyInventory(player, "ammo_57x28")) > 0

  local pistolItem = versus.item.get("#cw2_versus_cw_fiveseven")
  local ammoItem = versus.item.get("ammo_57x28")

  if not pistolItem or not ammoItem then
    versus.message.notify(player, "Starter equipment items not found!", NOTIFY_ERROR)
    ErrorNoHalt("[Versus] Starter kit items not found: #cw2_versus_cw_fiveseven or ammo_57x28\n")
    return
  end

  local itemsToGive = {}
  local totalSize = 0

  -- Determine what to give based on claim type
  if claimType == "pistol" then
    if hasWeapon then
      versus.message.notify(player, "You already have a weapon!", NOTIFY_ERROR)
      return
    end
    table.insert(itemsToGive, { item = pistolItem, id = "#cw2_versus_cw_fiveseven" })
    totalSize = pistolItem.size
  elseif claimType == "ammo" then
    if hasAmmo then
      versus.message.notify(player, "You already have ammo!", NOTIFY_ERROR)
      return
    end
    table.insert(itemsToGive, { item = ammoItem, id = "ammo_57x28" })
    totalSize = ammoItem.size
  elseif claimType == "both" then
    if hasWeapon and hasAmmo then
      versus.message.notify(player, "You already have both items!", NOTIFY_ERROR)
      return
    end
    if not hasWeapon then
      table.insert(itemsToGive, { item = pistolItem, id = "#cw2_versus_cw_fiveseven" })
      totalSize = totalSize + pistolItem.size
    end
    if not hasAmmo then
      table.insert(itemsToGive, { item = ammoItem, id = "ammo_57x28" })
      totalSize = totalSize + ammoItem.size
    end
  else
    versus.message.notify(player, "Invalid claim type!", NOTIFY_ERROR)
    return
  end

  if not versus.inventory.canFit(player, totalSize) then
    versus.message.notify(
      player,
      "You do not have enough inventory space! You need " .. totalSize .. " slots.",
      NOTIFY_ERROR
    )
    return
  end

  -- Give items
  for _, itemData in ipairs(itemsToGive) do
    local instance = versus.item.createInstance(itemData.id)
    instance.cannotBeScrapped = true
    versus.inventory.giveItem(player, instance)
  end

  data.lastClaimedStarterKit = os.time()

  -- Update state for response
  if claimType == "pistol" then
    hasWeapon = true
    versus.message.notify(player, "Pistol claimed successfully!", NOTIFY_SUCCESS)
  elseif claimType == "ammo" then
    hasAmmo = true
    versus.message.notify(player, "Ammo claimed successfully!", NOTIFY_SUCCESS)
  else
    hasWeapon = true
    hasAmmo = true
    versus.message.notify(player, "Equipment claimed successfully!", NOTIFY_SUCCESS)
  end

  net.Start("versus.npc.starterKitClaimed")
  net.WriteString(claimType)
  net.WriteBool(hasWeapon)
  net.WriteBool(hasAmmo)
  net.Send(player)
end)
