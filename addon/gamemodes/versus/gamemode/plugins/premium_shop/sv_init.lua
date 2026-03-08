local PLUGIN = PLUGIN

local STATUS_MAP = {
  purchased = "purchased",
  expired = "expired",
  renewed = "renewed",
  refunded = "refunded",
  canceled = "canceled"
}

util.AddNetworkString("versus.premium_shop.syncPackages")
util.AddNetworkString("versus.premium_shop.claimPackage")
util.AddNetworkString("versus.premium_shop.requestAdminPayments")
util.AddNetworkString("versus.premium_shop.requestPaymentHistory")

function PLUGIN.syncPremiumPackages(player)
  local premiumPackages = player:GetPremiumPackages()

  net.Start("versus.premium_shop.syncPackages")
  net.WritePlayer(player)
  net.WriteUInt(table.Count(premiumPackages), 16)
  for slug, _ in pairs(premiumPackages) do
    net.WriteString(slug)
  end
  net.Broadcast()
end

function PLUGIN.logInfo(message, ...)
  local debugData = { ... }

  ServerLog(
    string.format("[PremiumShop] %s (%s)\n", message, table.concat(debugData, ", "))
  )
end

--[[
  Hooks
--]]

function PLUGIN.hook:VersusBuildCreateTablesQueriesCore(queries)
  local statusses = ""

  for status, _ in pairs(STATUS_MAP) do
    if (statusses ~= "") then
      statusses = statusses .. ", "
    end

    statusses = statusses .. "'" .. status .. "'"
  end

  table.insert(queries, [[
    CREATE TABLE IF NOT EXISTS `player_premiums` (
      `order_id` varchar(255) NOT NULL PRIMARY KEY,
      `steamid64` varchar(32) NOT NULL,
      `player_name` varchar(64) NOT NULL,
      `item_slug` varchar(255) NOT NULL,
      `status` enum(]] .. statusses .. [[) NOT NULL,
      `created_at` int(11) unsigned NOT NULL,
      `updated_at` int(11) unsigned NOT NULL
    );
  ]])

  table.insert(queries, [[
    CREATE TABLE IF NOT EXISTS `player_pending_actions` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
      `order_id` varchar(255) NOT NULL,
      `status` varchar(32) NOT NULL,
      `steamid64` varchar(32) NOT NULL,
      `action_type` varchar(32) NOT NULL,
      `payload` varchar(255) NOT NULL,
      `created_at` int(11) unsigned NOT NULL,
      UNIQUE KEY `unique_order_status` (`order_id`, `status`)
    );
  ]])
end

function PLUGIN.hook:CanPlayerSay(player, text, filter)
  if (not IsValid(player) or filter ~= "world") then
    return
  end

  local throttleTime = player:HasPremiumPackage("supporter-role-lifetime") and 0.5 or 10

  if (versus.util.throttled("player_world_chat", throttleTime, player)) then
    versus.message.notify(
      player,
      "You are sending messages too quickly. Please wait a moment before chatting again.",
      NOTIFY_ERROR
    )

    return false
  end
end

-- Network data about premium packages on load
function PLUGIN.hook:PlayerDataLoaded(player, isExisting)
  PLUGIN.syncPremiumPackages(player)
  PLUGIN.applyPendingActions(player)
end

--[[
	Player Meta functions
--]]

local playerMeta = FindMetaTable("Player")

function playerMeta:GetPremiumPackages()
  if (not self._VersusInitialized) then
    return {}
  end

  local data = self:getCharacter("data")
  data.premiumPackages = data.premiumPackages or {}

  return data.premiumPackages
end

function playerMeta:HasPremiumPackage(slug)
  if (not self._VersusInitialized) then
    return false
  end

  local premiumPackages = self:GetPremiumPackages()
  return premiumPackages[slug] == true
end

function playerMeta:GivePremiumPackage(slug)
  if (not self._VersusInitialized) then
    return false
  end

  local premiumPackages = self:GetPremiumPackages()
  premiumPackages[slug] = true

  PLUGIN.syncPremiumPackages(self)

  hook.Run("PlayerGainPackage", self, slug)
  return true
end

function playerMeta:RemovePremiumPackage(slug)
  if (not self._VersusInitialized) then
    return false
  end

  local premiumPackages = self:GetPremiumPackages()
  premiumPackages[slug] = nil

  PLUGIN.syncPremiumPackages(self)

  hook.Run("PlayerLosePackage", self, slug)
  return true
end

--[[
	Database functions for payment records
--]]

function PLUGIN.createPaymentRecord(orderId, steamId64, playerName, itemSlug, status, callback)
  local values = {
    versus.player.getValueTypeDefinition(orderId),
    versus.player.getValueTypeDefinition(steamId64),
    versus.player.getValueTypeDefinition(playerName),
    versus.player.getValueTypeDefinition(itemSlug),
    versus.player.getValueTypeDefinition(status),
    versus.player.getValueTypeDefinition(os.time()),
    versus.player.getValueTypeDefinition(os.time())
  }

  versus.database.queryPrepared(
    "INSERT INTO `player_premiums` (`order_id`, `steamid64`, `player_name`, `item_slug`, `status`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?, ?)",
    values,
    function(_, lastID)
      if (callback) then
        callback(true)
      end
    end,
    function(err)
      PLUGIN.logInfo("Failed to create payment record: " .. tostring(err))

      if (callback) then
        callback(false)
      end
    end
  )
end

function PLUGIN.updatePaymentRecord(orderId, status, callback)
  local values = {
    versus.player.getValueTypeDefinition(status),
    versus.player.getValueTypeDefinition(os.time()),
    versus.player.getValueTypeDefinition(orderId)
  }

  versus.database.queryPrepared(
    "UPDATE `player_premiums` SET `status` = ?, `updated_at` = ? WHERE `order_id` = ?",
    values,
    function(_, lastID)
      if (callback) then
        callback(true)
      end
    end,
    function(err)
      PLUGIN.logInfo("Failed to update payment record: " .. tostring(err))

      if (callback) then
        callback(false)
      end
    end
  )
end

function PLUGIN.getPlayerPaymentRecords(steamId64, callback)
  local values = {
    versus.player.getValueTypeDefinition(steamId64)
  }

  versus.database.queryPrepared(
    "SELECT * FROM `player_premiums` WHERE `steamid64` = ? ORDER BY `created_at` DESC",
    values,
    function(result)
      callback(result or {})
    end,
    function(err)
      PLUGIN.logInfo("Failed to get payment records: " .. tostring(err))
      callback({})
    end
  )
end

function PLUGIN.getAllPaymentRecords(searchQuery, callback)
  local values = {}
  local query = "SELECT * FROM `player_premiums`"

  if (searchQuery and searchQuery ~= "") then
    query = query .. " WHERE (`player_name` LIKE ? OR `steamid64` LIKE ? OR `order_id` LIKE ?)"
    local likeQuery = "%" .. searchQuery .. "%"
    table.insert(values, versus.player.getValueTypeDefinition(likeQuery))
    table.insert(values, versus.player.getValueTypeDefinition(likeQuery))
    table.insert(values, versus.player.getValueTypeDefinition(likeQuery))
  end

  query = query .. " ORDER BY `created_at` DESC LIMIT 200"

  versus.database.queryPrepared(
    query,
    values,
    function(result)
      callback(result or {})
    end,
    function(err)
      PLUGIN.logInfo("Failed to get all payment records: " .. tostring(err))
      callback({})
    end
  )
end

--[[
	Pending actions: used to safely apply in-game effects (item/package gives and removes) across
	multiple servers that share the same database. INSERT IGNORE + a unique key on (order_id, status)
	means only one server can "win" each PayNow notification and apply its effect.
--]]

-- Insert a pending action for a player. Calls callback(true) only on the server that wins the race.
function PLUGIN.insertPendingAction(orderId, status, steamId64, actionType, payload, callback)
  local values = {
    versus.player.getValueTypeDefinition(orderId),
    versus.player.getValueTypeDefinition(status),
    versus.player.getValueTypeDefinition(steamId64),
    versus.player.getValueTypeDefinition(actionType),
    versus.player.getValueTypeDefinition(payload),
    versus.player.getValueTypeDefinition(os.time()),
  }

  versus.database.queryPrepared(
    "INSERT IGNORE INTO `player_pending_actions` (`order_id`, `status`, `steamid64`, `action_type`, `payload`, `created_at`) VALUES (?, ?, ?, ?, ?, ?)",
    values,
    function(_, _, affectedRows)
      if (callback) then
        callback(affectedRows ~= nil and affectedRows > 0)
      end
    end,
    function(err)
      PLUGIN.logInfo("Failed to insert pending action: " .. tostring(err))

      if (callback) then
        callback(false)
      end
    end
  )
end

-- Apply a single pending action to a loaded player.
function PLUGIN.applyPendingAction(player, actionType, payload)
  if (actionType == "give_item") then
    local item = versus.item.get(payload)

    if (item) then
      local instance = versus.item.createInstance(item)
      instance.undroppable = true
      versus.inventory.giveItem(player, instance)
      PLUGIN.logInfo(player:Name() .. " received pending item: " .. payload)
    else
      PLUGIN.logInfo("Could not apply give_item - item not found: " .. payload)
    end
  elseif (actionType == "remove_item") then
    local instance = versus.inventory.getAnyItem(player, payload, {
      undroppable = true
    })
    local removed = instance and versus.inventory.takeItem(player, instance) or false

    -- Try have plugins remove the item if it wasn't found in the player's inventory. This handles cases where the item
    -- may have been stored in player housing for example.
    if (not removed) then
      removed = hook.Run("VersusPremiumShopRemoveItem", player, payload) == true
    end

    if (removed) then
      PLUGIN.logInfo(player:Name() .. " had pending item removed: " .. payload)
    else
      player:Ban(
        0,    -- Permanent ban
        false -- Don't kick
      )

      PLUGIN.logInfo("Failed to remove item for " ..
        player:Name() .. " - item not found: " .. payload .. ". Player has been banned for manual intervention.")

      player:Kick(
        "A premium item was refunded, but couldn't be found! Contact an admin on Discord."
      )
    end
  elseif (actionType == "give_package") then
    player:GivePremiumPackage(payload)
    PLUGIN.logInfo(player:Name() .. " received pending package: " .. payload)
  elseif (actionType == "remove_package") then
    player:RemovePremiumPackage(payload)
    PLUGIN.logInfo(player:Name() .. " had pending package removed: " .. payload)
  end
end

-- Fetch and apply all pending actions for a player, then delete them.
function PLUGIN.applyPendingActions(player)
  if (not IsValid(player) or not player._VersusInitialized) then
    return
  end

  local steamId64 = player:SteamID64()
  local values = { versus.player.getValueTypeDefinition(steamId64) }

  versus.database.queryPrepared(
    "SELECT * FROM `player_pending_actions` WHERE `steamid64` = ? ORDER BY `created_at` ASC",
    values,
    function(rows)
      if (not IsValid(player) or not player._VersusInitialized or not rows or #rows == 0) then
        return
      end

      for _, row in ipairs(rows) do
        PLUGIN.applyPendingAction(player, row.action_type, row.payload)
      end

      -- Delete consumed rows after applying
      versus.database.queryPrepared(
        "DELETE FROM `player_pending_actions` WHERE `steamid64` = ?",
        { versus.player.getValueTypeDefinition(steamId64) },
        nil,
        function(err)
          PLUGIN.logInfo("Failed to delete pending actions for " .. steamId64 .. ": " .. tostring(err))
        end
      )
    end,
    function(err)
      PLUGIN.logInfo("Failed to fetch pending actions for " .. steamId64 .. ": " .. tostring(err))
    end
  )
end

--[[
	PayNow.gg Integration Commands
	(Will be sent by PayNow.gg to us through the PayNow Garry's Mod Addon)
--]]

concommand.Add("versus_premium_order", function(client, command, arguments)
  if (IsValid(client) and not client:IsSuperAdmin()) then
    return
  end

  local status = arguments[1]
  local itemSlug = arguments[2]
  local orderId = arguments[3]
  local steamId64 = arguments[4]

  if (not status or not itemSlug or not orderId or not steamId64) then
    ErrorNoHalt("Invalid command usage: " .. command .. " " .. table.concat(arguments, " ") .. "\n")
    return
  end

  if (not STATUS_MAP[status]) then
    ErrorNoHalt("Invalid status: " .. status .. " for command: " .. command .. "\n")
    return
  end

  local isItemSlug = string.sub(itemSlug, 1, 5) == "item-"
  local itemID = isItemSlug and string.gsub(itemSlug:sub(6), "-", "_") or nil

  -- Determine what in-game action (if any) this notification requires
  local actionType, payload

  if (status == "purchased" or status == "renewed") then
    if (isItemSlug) then
      actionType = "give_item"
      payload = itemID
    else
      actionType = "give_package"
      payload = itemSlug
    end
  elseif (status == "refunded" or status == "canceled" or status == "expired") then
    if (isItemSlug) then
      actionType = "remove_item"
      payload = itemID
    else
      actionType = "remove_package"
      payload = itemSlug
    end
  end

  -- Get player name for record keeping (best-effort; may be "Unknown Player" if offline)
  local playerName = "Unknown Player"
  local targetPlayer = player.GetBySteamID64(steamId64)

  if (IsValid(targetPlayer)) then
    playerName = targetPlayer:Name()
  end

  local function handlePaymentRecord()
    if (status == "purchased") then
      PLUGIN.createPaymentRecord(orderId, steamId64, playerName, itemSlug, status, function(success)
        if (success) then
          if (IsValid(client)) then
            versus.message.notify(client, "Payment record created successfully for order ID: " .. orderId)
          end

          PLUGIN.logInfo("Created payment record for order ID: " .. orderId)
        else
          PLUGIN.logInfo("Failed to create payment record: " .. orderId)
        end
      end)
    else
      PLUGIN.updatePaymentRecord(orderId, status, function(success)
        if (success) then
          if (IsValid(client)) then
            versus.message.notify(client, "Payment record updated successfully for order ID: " .. orderId)
          end

          PLUGIN.logInfo("Updated payment record for order ID: " .. orderId)
        else
          if (IsValid(client)) then
            versus.message.notify(client, "Failed to update payment record for order ID: " .. orderId, NOTIFY_ERROR)
          end

          PLUGIN.logInfo("Failed to update payment record: " .. orderId)
        end
      end)
    end
  end

  if (actionType) then
    -- Race-safe: INSERT IGNORE with a unique key on (order_id, status) ensures only one server
    -- across the shared database will win this notification and apply the in-game effect.
    PLUGIN.insertPendingAction(orderId, status, steamId64, actionType, payload, function(won)
      if (not won) then
        PLUGIN.logInfo("Order already handled by another server, skipping: " .. orderId)
        return
      end

      -- This server won. If the player is online here, apply now; otherwise the row
      -- stays in player_pending_actions until their next login or the polling timer picks it up.
      if (IsValid(targetPlayer) and targetPlayer._VersusInitialized) then
        PLUGIN.applyPendingActions(targetPlayer)
      end

      handlePaymentRecord()
    end)
  else
    -- No in-game action needed for this notification (e.g. item refund/expire).
    -- Payment record UPDATE is idempotent, so all servers running it is fine.
    handlePaymentRecord()
  end
end)

--[[
	Network handling for claiming packages
--]]

net.Receive("versus.premium_shop.claimPackage", function(length, client)
  if (not client._VersusInitialized) then
    return
  end

  local packageKey = net.ReadString()

  if (not packageKey or packageKey == "") then
    versus.message.notify(client, "Invalid package key.", NOTIFY_ERROR)
    return
  end

  if (not PLUGIN.PREMIUM_PACKAGES[packageKey]) then
    versus.message.notify(client, "Unknown package: " .. packageKey, NOTIFY_ERROR)
    return
  end

  -- Check if they already have this package
  if (client:HasPremiumPackage(packageKey)) then
    versus.message.notify(client, "You already have this package on this character.", NOTIFY_ERROR)
    return
  end

  -- Check if they own this package (have purchased/renewed it)
  PLUGIN.getPlayerPaymentRecords(client:SteamID64(), function(paymentRecords)
    local hasValidPayment = false

    for _, record in ipairs(paymentRecords) do
      if (record.item_slug == packageKey and (record.status == "purchased" or record.status == "renewed")) then
        hasValidPayment = true
        break
      end
    end

    if (not hasValidPayment) then
      versus.message.notify(client, "You don't own this package or it's not available for claiming.", NOTIFY_ERROR)
      return
    end

    -- Give them the package
    if (client:GivePremiumPackage(packageKey)) then
      local packageName = PLUGIN.PREMIUM_PACKAGES[packageKey].name
      versus.message.notify(client, "Successfully claimed: " .. packageName)

      PLUGIN.logInfo(client:Name() .. " claimed premium package: " .. packageKey)
    else
      versus.message.notify(client, "Failed to claim package. Please try again.", NOTIFY_ERROR)
    end
  end)
end)

--[[
	Network callbacks
--]]

-- Handle payment history requests
net.Receive("versus.premium_shop.requestPaymentHistory", function(length, client)
  -- Throttle check to prevent spam
  if (versus.util.throttled("premium_history", 5, client)) then
    versus.message.notify(client, "Please wait before requesting payment history again.", NOTIFY_ERROR)
    return
  end

  PLUGIN.getPlayerPaymentRecords(client:SteamID64(), function(paymentRecords)
    if (not IsValid(client)) then
      return
    end

    local message = versus.network.startUnboundedMessage("versus.premium_shop.playerPaymentHistory")
    message:writeTable(paymentRecords)
    message:send(client)
  end)
end)

-- Handle admin payment records requests
net.Receive("versus.premium_shop.requestAdminPayments", function(length, client)
  if (not client:IsSuperAdmin()) then
    versus.message.notify(client, "You don't have permission to access this feature.", NOTIFY_ERROR)
    return
  end

  local searchQuery = net.ReadString()

  PLUGIN.getAllPaymentRecords(searchQuery, function(paymentRecords)
    if (not IsValid(client)) then
      return
    end

    local message = versus.network.startUnboundedMessage("versus.premium_shop.adminPaymentRecords")
    message:writeTable(paymentRecords)
    message:writeString(searchQuery)
    message:send(client)
  end)
end)

-- Poll for pending actions every 30 seconds for players who are already online.
-- This handles the case where a pending action was queued by a different server
-- while the player is connected to this one.
timer.Create("versus.premium_shop.pollPendingActions", 30, 0, function()
  for _, ply in ipairs(player.GetAll()) do
    if (ply._VersusInitialized) then
      PLUGIN.applyPendingActions(ply)
    end
  end
end)
