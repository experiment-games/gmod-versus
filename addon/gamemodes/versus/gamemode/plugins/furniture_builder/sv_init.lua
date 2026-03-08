local PLUGIN = PLUGIN

local RAW_FURNITURE_MATERIAL_ID = "raw_furniture_material"

util.AddNetworkString("versus.furnitureBuilder.build")
util.AddNetworkString("versus.furnitureBuilder.showCatalogHint")

--- Add Raw Furniture Material to loot tables so players can find it during contracts.
function PLUGIN.hook:ModifyContractLootTable(npc, lootTable, attacker, position, angles)
  lootTable[RAW_FURNITURE_MATERIAL_ID] = 0.15
end

--- When the player enters their housing instance, send a hint to open the catalog.
function PLUGIN.hook:PlayerSwitchedToInstance(player, playerInstanceID, roomID)
  if (versus.instance.getInstanceOwner(playerInstanceID) ~= player) then
    return
  end

  net.Start("versus.furnitureBuilder.showCatalogHint")
  net.Send(player)
end

--[[
  Net Messages
--]]

net.Receive("versus.furnitureBuilder.build", function(len, player)
  local itemID = net.ReadString()
  local catalogItem = PLUGIN.catalogItems[itemID]

  if (not catalogItem) then
    ErrorNoHalt("Player attempted to build invalid furniture item: " .. tostring(itemID) .. "\n")
    return
  end

  -- Only allow building inside the player's own housing instance
  local playerInstance = versus.instance.getPlayerInstance(player)

  if (not playerInstance) then
    versus.message.notify(player, "You can only build furniture inside your hideout.", NOTIFY_ERROR)
    return
  end

  local instanceOwner = versus.instance.getInstanceOwner(playerInstance)

  if (instanceOwner ~= player) then
    versus.message.notify(player, "You can only build furniture in your own hideout.", NOTIFY_ERROR)
    return
  end

  -- Check the player has enough Raw Furniture Materials
  local materialCount = versus.inventory.countItem(player, RAW_FURNITURE_MATERIAL_ID)
  local cost = catalogItem.materialCost

  if (materialCount < cost) then
    local deficit = cost - materialCount
    versus.message.notify(
      player,
      "You need " .. deficit .. " more Raw Furniture Material to build this.",
      NOTIFY_ERROR
    )
    return
  end

  -- Take the materials
  versus.inventory.takeItem(player, RAW_FURNITURE_MATERIAL_ID, cost)

  -- Spawn the prop in the player's instance, slightly in front of them
  local forward = player:GetForward()
  local spawnPos = player:GetPos() + forward * 80 + Vector(0, 0, 10)

  local prop = ents.Create("prop_physics")
  prop:SetModel(catalogItem.model)
  prop:SetPos(spawnPos)
  prop:SetAngles(Angle(0, player:GetAngles().y, 0))
  prop:Spawn()

  versus.instance.addEntity(prop, playerInstance)
end)
