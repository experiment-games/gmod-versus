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

local function getCooldown()
  return versus.config["Starter Kit Cooldown Seconds"] or 3600
end

local function getPlayerItemStatus(player)
  local kitItems = versus.config["Starter Kit Items"] or {}
  local status = {}
  for itemID, _ in pairs(kitItems) do
    status[itemID] = table.Count(versus.inventory.findAllWithIDInAnyInventory(player, itemID)) > 0
  end
  return status
end

local function writeItemStatus(itemStatus)
  local count = table.Count(itemStatus)
  net.WriteUInt(count, 8)
  for itemID, hasItem in pairs(itemStatus) do
    net.WriteString(itemID)
    net.WriteBool(hasItem)
  end
end

--[[
  Logic
--]]

util.AddNetworkString("versus.npc.checkStarterKit")
util.AddNetworkString("versus.npc.claimStarterKit")
util.AddNetworkString("versus.npc.starterKitStatus")
util.AddNetworkString("versus.npc.starterKitClaimed")

net.Receive("versus.npc.checkStarterKit", function(len, player)
  local cooldown = getCooldown()
  local data = player:getCharacter("data")
  local onCooldown = data.lastClaimedStarterKit and (os.time() - data.lastClaimedStarterKit < cooldown)

  local timeRemaining = 0
  if data.lastClaimedStarterKit then
    timeRemaining = math.max(0, cooldown - (os.time() - data.lastClaimedStarterKit))
  end

  local itemStatus = getPlayerItemStatus(player)

  net.Start("versus.npc.starterKitStatus")
  net.WriteBool(onCooldown or false)
  net.WriteUInt(timeRemaining, 32)
  writeItemStatus(itemStatus)
  net.Send(player)
end)

net.Receive("versus.npc.claimStarterKit", function(len, player)
  local claimId = net.ReadString() -- item ID or "all"
  local data = player:getCharacter("data")

  -- Check cooldown
  local cooldown = getCooldown()
  local onCooldown = data.lastClaimedStarterKit and (os.time() - data.lastClaimedStarterKit < cooldown)

  if onCooldown then
    versus.message.notify(player, "You have already claimed your starter equipment!", NOTIFY_ERROR)
    return
  end

  local kitItems = versus.config["Starter Kit Items"] or {}

  -- Resolve which item IDs to attempt to give
  local idsToCheck = {}
  if claimId == "all" then
    for itemID, _ in pairs(kitItems) do
      idsToCheck[itemID] = true
    end
  elseif kitItems[claimId] then
    idsToCheck[claimId] = true
  else
    versus.message.notify(player, "Invalid item!", NOTIFY_ERROR)
    return
  end

  -- Filter out items the player already has
  local itemsToGive = {}
  local totalSize = 0

  for itemID, _ in pairs(idsToCheck) do
    local hasItem = table.Count(versus.inventory.findAllWithIDInAnyInventory(player, itemID)) > 0
    if not hasItem then
      local item = versus.item.get(itemID)
      if item then
        table.insert(itemsToGive, { item = item, id = itemID })
        totalSize = totalSize + (item.size or 1)
      else
        ErrorNoHalt(string.format("[Versus] Starter kit item not found: %s\n", itemID))
      end
    end
  end

  if #itemsToGive == 0 then
    versus.message.notify(player, "You already have all the requested items!", NOTIFY_ERROR)
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
    instance.untradable = true
    versus.inventory.giveItem(player, instance)
  end

  data.lastClaimedStarterKit = os.time()

  versus.message.notify(player, "Equipment claimed successfully!", NOTIFY_SUCCESS)

  local itemStatus = getPlayerItemStatus(player)

  net.Start("versus.npc.starterKitClaimed")
  writeItemStatus(itemStatus)
  net.Send(player)
end)
