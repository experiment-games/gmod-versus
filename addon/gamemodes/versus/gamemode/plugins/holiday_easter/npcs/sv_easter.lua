local PLUGIN = PLUGIN
local NPC = {}

NPC.name = "Diana"
NPC.description = "This girl seems to have lost something important."
NPC.model = "models/humans/group05/female01.mdl"
NPC.bodygroups = {}
NPC.health = versus.npc.NO_HEALTH
NPC.voicePitch = 140

local function getEasterKey()
  local year = os.date("%Y")
  return "easterEggsTurnedIn" .. year
end

local function getMaskKey()
  local year = os.date("%Y")
  return "easterMaskClaimed" .. year
end

function NPC:onInteract(player, npcEntity)
  local key = getEasterKey()
  local easterEggsTurnedIn = player:getCharacter("data")[key] or 0
  local hasMask = player:getCharacter("data")[getMaskKey()] or false

  versus.npc.openNPCMenu(player, "versus_Easter", {
    isEaster = PLUGIN.isEaster(),
    eggCount = easterEggsTurnedIn,
    hasMask = hasMask,
  })
end

-- Keeps resetting for some reason
-- function NPC:OnThink(npcEntity)
--   local idleSequence = npcEntity:LookupSequence("idle_to_lean_back")

--   if (npcEntity:GetSequence() ~= idleSequence) then
--     npcEntity:SetSequence(idleSequence)
--   end
-- end

versus.npc.registerNPC("easter", NPC)

--[[
  Logic
--]]

-- Half-Life 2 Beta Child Worker Playermodels + NPCs (https://steamcommunity.com/sharedfiles/filedetails/?id=1907665587)
resource.AddWorkshop("1907665587")

util.AddNetworkString("versus.npc.easter.turnIn")
util.AddNetworkString("versus.npc.easter.updateEggCount")
util.AddNetworkString("versus.npc.easter.claimMask")
util.AddNetworkString("versus.npc.easter.maskClaimed")

net.Receive("versus.npc.easter.turnIn", function(len, player)
  local itemKey = net.ReadUInt(16)
  local amount = net.ReadUInt(16)

  if not itemKey or not amount or amount <= 0 then
    return
  end

  -- Find the item in the inventory
  local item = versus.inventory.getItem(player, itemKey)

  if (not item) then
    versus.message.notify(player, "Item not found in inventory!", NOTIFY_ERROR)
    return
  end

  -- Determine how many items we can actually scrap
  local itemCount = versus.inventory.countItem(player, item)
  local actualAmount = math.min(amount, itemCount)

  versus.inventory.takeItem(player, item.itemID, actualAmount, true)

  versus.inventory.networkEntireInventory(player)

  -- Update the count of Easter Eggs turned in for this year
  local key = getEasterKey()
  player:getCharacter("data")[key] = (player:getCharacter("data")[key] or 0) + actualAmount

  net.Start("versus.npc.easter.updateEggCount")
  net.WriteUInt(player:getCharacter("data")[key], 16)
  net.WriteBool(player:getCharacter("data")[getMaskKey()] or false)
  net.Send(player)
end)

net.Receive("versus.npc.easter.claimMask", function(len, player)
  if not PLUGIN.isEaster() then
    versus.message.notify(player, "It's not Easter!", NOTIFY_ERROR)
    return
  end

  local key = getEasterKey()
  local easterEggsTurnedIn = player:getCharacter("data")[key] or 0

  if easterEggsTurnedIn < 10 then
    versus.message.notify(player, "You need to turn in 10 Easter Eggs first!", NOTIFY_ERROR)
    return
  end

  local maskKey = getMaskKey()

  if player:getCharacter("data")[maskKey] then
    versus.message.notify(player, "You have already claimed your Easter reward!", NOTIFY_ERROR)
    return
  end

  local maskItem = versus.item.get("mask_easter")

  if not maskItem then
    ErrorNoHalt("[Versus] mask_easter item not found!\n")
    versus.message.notify(player, "Something went wrong. Please contact an admin.", NOTIFY_ERROR)
    return
  end

  if not versus.inventory.canFit(player, maskItem.size or 1) then
    versus.message.notify(
      player,
      "You don't have enough inventory space! You need " .. (maskItem.size or 1) .. " slot(s).",
      NOTIFY_ERROR
    )
    return
  end

  local instance = versus.item.createInstance("mask_easter")
  instance.untradable = true
  versus.inventory.giveItem(player, instance)

  player:getCharacter("data")[maskKey] = true

  versus.message.notify(player, "Happy Easter! You've received the Easter Bunny Mask!", NOTIFY_SUCCESS)

  net.Start("versus.npc.easter.maskClaimed")
  net.Send(player)
end)
