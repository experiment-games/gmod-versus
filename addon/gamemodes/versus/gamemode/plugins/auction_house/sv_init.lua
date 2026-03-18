local PLUGIN = PLUGIN

util.AddNetworkString("versus.auction.open")
util.AddNetworkString("versus.auction.requestPage")
util.AddNetworkString("versus.auction.pageData")
util.AddNetworkString("versus.auction.placeBid")
util.AddNetworkString("versus.auction.buyout")
util.AddNetworkString("versus.auction.listItem")
util.AddNetworkString("versus.auction.cancelListing")
util.AddNetworkString("versus.auction.actionResult")

-- Per-player in-flight guard: at most one page query running per player at a time
PLUGIN._requestInFlight = PLUGIN._requestInFlight or {}

local TABLE_LISTINGS    = "auction_listings"
local TABLE_PENDING     = "auction_pending"

--[[
  Database helpers
--]]

--- Create the tables if they do not already exist. Called once on Initialize.
function PLUGIN.ensureTables()
  versus.database.query(string.format([[
    CREATE TABLE IF NOT EXISTS `%s` (
      `id`                     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      `seller_steamid`         VARCHAR(25)  NOT NULL,
      `seller_name`            VARCHAR(64)  NOT NULL,
      `item_data`              MEDIUMTEXT   NOT NULL,
      `item_name`              VARCHAR(64)  NOT NULL,
      `min_bid`                INT UNSIGNED NOT NULL,
      `buyout_price`           INT UNSIGNED NULL,
      `current_bid`            INT UNSIGNED NOT NULL DEFAULT 0,
      `current_bidder_steamid` VARCHAR(25)  NULL,
      `current_bidder_name`    VARCHAR(64)  NULL,
      `expires_at`             DATETIME     NOT NULL,
      `status`                 ENUM('active','sold','expired','cancelled') NOT NULL DEFAULT 'active',
      INDEX idx_status_expires (`status`, `expires_at`),
      INDEX idx_seller         (`seller_steamid`),
      INDEX idx_bidder         (`current_bidder_steamid`)
    )
  ]], TABLE_LISTINGS))

  versus.database.query(string.format([[
    CREATE TABLE IF NOT EXISTS `%s` (
      `id`        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      `steamid`   VARCHAR(25) NOT NULL,
      `type`      ENUM('item','money') NOT NULL,
      `amount`    INT UNSIGNED NULL,
      `item_data` MEDIUMTEXT   NULL,
      `reason`    VARCHAR(128) NOT NULL DEFAULT '',
      INDEX idx_steamid (`steamid`)
    )
  ]], TABLE_PENDING))
end

--- Returns the maximum concurrent active listings allowed for a player.
function PLUGIN.getListingLimit(player)
  if player:HasPremiumPackage("supporter-role-lifetime") or player:HasPremiumPackage("supporter-role-monthly") then
    return PLUGIN.LISTING_LIMIT_PREMIUM
  end

  return PLUGIN.LISTING_LIMIT_BASE
end

--- Compute the up-front listing fee for a given min bid and duration index.
function PLUGIN.computeFee(minBid, durationIndex)
  local dur = PLUGIN.DURATIONS[durationIndex]
  if not dur then return 0 end

  return math.max(1, math.floor(minBid * dur.feeMultiplier))
end

--- Minimum valid next bid given a listing row (as returned from the DB).
function PLUGIN.minNextBid(row)
  local current = tonumber(row.current_bid) or 0

  if current > 0 then
    local increment = math.max(PLUGIN.BID_INCREMENT_MIN, math.floor(current * PLUGIN.BID_INCREMENT_FRACTION))
    return current + increment
  end

  return tonumber(row.min_bid) or 1
end

--- Deliver money or an item to a player immediately if they are online,
--- or queue it in the pending table for delivery on next login.
function PLUGIN.deliver(steamID, deliveryType, amount, itemData, reason)
  local target = nil

  for _, p in ipairs(player.GetAll()) do
    if p:SteamID64() == steamID then
      target = p
      break
    end
  end

  if IsValid(target) then
    if deliveryType == "money" then
      versus.finance.giveMoney(target, amount, reason)
      versus.message.notify(
        target,
        "Received " .. versus.util.formatMoney(amount) .. " — " .. reason,
        NOTIFY_GENERIC
      )
    elseif deliveryType == "item" then
      local item = versus.item.restoreInstance(itemData)

      if item then
        versus.inventory.giveItem(target, item)
        versus.message.notify(target, "Received item from auction — " .. reason, NOTIFY_GENERIC)
      end
    end

    return
  end

  -- Player offline: queue for delivery on next login
  local itemJSON = (deliveryType == "item" and itemData ~= nil) and util.TableToJSON(itemData) or nil

  versus.database.queryPrepared(
    string.format(
      "INSERT INTO `%s` (`steamid`, `type`, `amount`, `item_data`, `reason`) VALUES (?, ?, ?, ?, ?)",
      TABLE_PENDING
    ),
    {
      versus.player.getValueTypeDefinition(steamID),
      versus.player.getValueTypeDefinition(deliveryType),
      versus.player.getValueTypeDefinition(amount),
      versus.player.getValueTypeDefinition(itemJSON),
      versus.player.getValueTypeDefinition(reason),
    }
  )
end

--- Deliver any pending items/money queued for a player who just logged in.
function PLUGIN.deliverPending(player)
  local steamID = player:SteamID64()

  versus.database.queryPrepared(
    string.format("SELECT * FROM `%s` WHERE `steamid` = ?", TABLE_PENDING),
    { versus.player.getValueTypeDefinition(steamID) },
    function(rows)
      if not rows or #rows == 0 then return end
      if not IsValid(player) then return end

      local idsToDelete = {}

      for _, row in ipairs(rows) do
        table.insert(idsToDelete, tonumber(row.id))

        if row.type == "money" then
          local amount = tonumber(row.amount) or 0
          versus.finance.giveMoney(player, amount, row.reason)
          versus.message.notify(
            player,
            "Received " .. versus.util.formatMoney(amount) .. " — " .. row.reason,
            NOTIFY_GENERIC
          )
        elseif row.type == "item" and row.item_data then
          local instanceData = util.JSONToTable(row.item_data)

          if instanceData then
            local item = versus.item.restoreInstance(instanceData)

            if item then
              versus.inventory.giveItem(player, item)
              versus.message.notify(player, "Received item from auction — " .. row.reason, NOTIFY_GENERIC)
            end
          end
        end
      end

      if #idsToDelete > 0 then
        local idList = table.concat(idsToDelete, ",")
        versus.database.query(
          string.format("DELETE FROM `%s` WHERE `id` IN (%s)", TABLE_PENDING, idList)
        )
      end
    end
  )
end

--- Process all listings whose time has expired. Finalises sales and returns
--- unsold items. Called on a repeating timer.
function PLUGIN.processExpired()
  versus.database.query(
    string.format(
      "SELECT * FROM `%s` WHERE `status` = 'active' AND `expires_at` <= NOW()",
      TABLE_LISTINGS
    ),
    function(rows)
      if not rows or #rows == 0 then return end

      for _, row in ipairs(rows) do
        local listingID  = tonumber(row.id)
        local currentBid = tonumber(row.current_bid) or 0

        if currentBid > 0 and row.current_bidder_steamid ~= nil then
          -- Winning bid exists — finalise the sale
          versus.database.queryPrepared(
            string.format("UPDATE `%s` SET `status` = 'sold' WHERE `id` = ?", TABLE_LISTINGS),
            { versus.player.getValueTypeDefinition(listingID) }
          )

          local instanceData = util.JSONToTable(row.item_data)

          if instanceData then
            PLUGIN.deliver(
              row.current_bidder_steamid, "item", nil, instanceData,
              "Won auction: " .. tostring(row.item_name)
            )
          end

          PLUGIN.deliver(
            row.seller_steamid, "money", currentBid, nil,
            "Sold at auction: " .. tostring(row.item_name)
          )
        else
          -- No bids — return item to seller
          versus.database.queryPrepared(
            string.format("UPDATE `%s` SET `status` = 'expired' WHERE `id` = ?", TABLE_LISTINGS),
            { versus.player.getValueTypeDefinition(listingID) }
          )

          local instanceData = util.JSONToTable(row.item_data)

          if instanceData then
            PLUGIN.deliver(
              row.seller_steamid, "item", nil, instanceData,
              "Auction expired: " .. tostring(row.item_name)
            )
          end
        end
      end
    end
  )
end

--- Fetch a page of listings and call callback(totalRows, rows).
--- @param tab string "browse" | "my_listings" | "my_bids"
--- @param steamID string Requesting player's SteamID64
--- @param page number 1-based page index
--- @param callback function Called as callback(total, rows)
function PLUGIN.fetchPage(tab, steamID, page, callback)
  local pageSize     = PLUGIN.PAGE_SIZE
  local offset       = (page - 1) * pageSize
  local expireSelect = "UNIX_TIMESTAMP(`expires_at`) AS `expire_unix`"

  local function onError(err)
    ErrorNoHalt("[AuctionHouse] Query error: " .. tostring(err) .. "\n")
    callback(0, {})
  end

  if tab == "browse" then
    local countSQL = string.format(
      "SELECT COUNT(*) AS `total` FROM `%s` WHERE `status` = 'active'",
      TABLE_LISTINGS
    )
    local dataSQL = string.format(
      "SELECT *, %s FROM `%s` WHERE `status` = 'active' ORDER BY `expires_at` ASC LIMIT %d OFFSET %d",
      expireSelect, TABLE_LISTINGS, pageSize, offset
    )

    versus.database.query(countSQL, function(cr)
      local total = cr and cr[1] and tonumber(cr[1].total) or 0

      versus.database.query(dataSQL, function(dr)
        callback(total, dr or {})
      end, onError)
    end, onError)
  elseif tab == "my_listings" then
    versus.database.queryPrepared(
      string.format(
        "SELECT COUNT(*) AS `total` FROM `%s` WHERE `seller_steamid` = ? AND `status` = 'active'",
        TABLE_LISTINGS
      ),
      { versus.player.getValueTypeDefinition(steamID) },
      function(cr)
        local total = cr and cr[1] and tonumber(cr[1].total) or 0

        versus.database.queryPrepared(
          string.format(
            "SELECT *, %s FROM `%s` WHERE `seller_steamid` = ? AND `status` = 'active' ORDER BY `expires_at` ASC LIMIT %d OFFSET %d",
            expireSelect, TABLE_LISTINGS, pageSize, offset
          ),
          { versus.player.getValueTypeDefinition(steamID) },
          function(dr) callback(total, dr or {}) end,
          onError
        )
      end,
      onError
    )
  elseif tab == "my_bids" then
    versus.database.queryPrepared(
      string.format(
        "SELECT COUNT(*) AS `total` FROM `%s` WHERE `current_bidder_steamid` = ? AND `status` = 'active'",
        TABLE_LISTINGS
      ),
      { versus.player.getValueTypeDefinition(steamID) },
      function(cr)
        local total = cr and cr[1] and tonumber(cr[1].total) or 0

        versus.database.queryPrepared(
          string.format(
            "SELECT *, %s FROM `%s` WHERE `current_bidder_steamid` = ? AND `status` = 'active' ORDER BY `expires_at` ASC LIMIT %d OFFSET %d",
            expireSelect, TABLE_LISTINGS, pageSize, offset
          ),
          { versus.player.getValueTypeDefinition(steamID) },
          function(dr) callback(total, dr or {}) end,
          onError
        )
      end,
      onError
    )
  end
end

--[[
  Net message helpers
--]]

local function writeRow(row)
  local data

  if row.item_data then
    local ok, decoded = pcall(util.JSONToTable, tostring(row.item_data))

    if ok and decoded then
      data = decoded
    end
  end

  net.WriteUInt(tonumber(row.id) or 0, 32)
  net.WriteString(tostring(row.seller_steamid or ""))
  net.WriteString(tostring(row.seller_name or "Unknown"))
  net.WriteString(tostring(row.item_name or "Unknown"))
  net.WriteTable(data or {})
  net.WriteUInt(tonumber(row.min_bid) or 0, 32)
  net.WriteUInt(tonumber(row.current_bid) or 0, 32)
  net.WriteUInt(tonumber(row.buyout_price) or 0, 32) -- 0 = no buyout
  net.WriteUInt(tonumber(row.expire_unix) or 0, 32)

  local bidderID  = row.current_bidder_steamid
  local hasBidder = bidderID ~= nil and bidderID ~= "" and bidderID ~= "NULL"
  net.WriteBool(hasBidder)
  net.WriteString(tostring(row.current_bidder_name or ""))
end

--[[
  Net Messages
--]]

net.Receive("versus.auction.requestPage", function(len, player)
  local tab  = net.ReadString()
  local page = net.ReadUInt(16)

  page       = math.max(1, page)

  if tab ~= "browse" and tab ~= "my_listings" and tab ~= "my_bids" then
    tab = "browse"
  end

  local steamID = player:SteamID64()

  if PLUGIN._requestInFlight[steamID] then return end

  PLUGIN._requestInFlight[steamID] = true

  PLUGIN.fetchPage(tab, steamID, page, function(total, rows)
    PLUGIN._requestInFlight[steamID] = nil

    if not IsValid(player) then return end

    net.Start("versus.auction.pageData")
    net.WriteString(tab)
    net.WriteUInt(page, 16)
    net.WriteUInt(total, 32)
    net.WriteUInt(#rows, 8)

    for _, row in ipairs(rows) do
      writeRow(row)
    end

    -- For my_listings, send the player's listing limit so the client can display slot indicators
    if tab == "my_listings" then
      net.WriteUInt(PLUGIN.getListingLimit(player), 8)
    end

    net.Send(player)
  end)
end)

net.Receive("versus.auction.placeBid", function(len, player)
  local listingID = net.ReadUInt(32)
  local bidAmount = net.ReadUInt(32)

  if listingID == 0 or bidAmount == 0 then return end

  local steamID = player:SteamID64()

  versus.database.queryPrepared(
    string.format(
      "SELECT * FROM `%s` WHERE `id` = ? AND `status` = 'active' LIMIT 1",
      TABLE_LISTINGS
    ),
    { versus.player.getValueTypeDefinition(listingID) },
    function(rows)
      if not IsValid(player) then return end

      if not rows or #rows == 0 then
        versus.message.notify(player, "This listing is no longer available.", NOTIFY_ERROR)
        return
      end

      local row = rows[1]

      if row.seller_steamid == steamID then
        versus.message.notify(player, "You cannot bid on your own listing.", NOTIFY_ERROR)
        return
      end

      local minNext = PLUGIN.minNextBid(row)

      if bidAmount < minNext then
        versus.message.notify(
          player,
          "Bid must be at least " .. versus.util.formatMoney(minNext) .. ".",
          NOTIFY_ERROR
        )
        return
      end

      local canAfford, deficit = versus.finance.canAfford(player, bidAmount)

      if not canAfford then
        versus.message.notify(
          player,
          "You cannot afford this bid. You need " .. versus.util.formatMoney(deficit) .. " more.",
          NOTIFY_ERROR
        )
        return
      end

      -- Take money from the new leading bidder
      versus.finance.takeMoney(player, bidAmount, "Auction bid: " .. tostring(row.item_name))

      -- Refund the previous bidder if there was one
      local prevBid      = tonumber(row.current_bid) or 0
      local prevBidderID = row.current_bidder_steamid

      if prevBid > 0 and prevBidderID ~= nil and prevBidderID ~= "" then
        PLUGIN.deliver(
          prevBidderID, "money", prevBid, nil,
          "Outbid refund: " .. tostring(row.item_name)
        )
      end

      versus.database.queryPrepared(
        string.format(
          "UPDATE `%s` SET `current_bid` = ?, `current_bidder_steamid` = ?, `current_bidder_name` = ? WHERE `id` = ?",
          TABLE_LISTINGS
        ),
        {
          versus.player.getValueTypeDefinition(bidAmount),
          versus.player.getValueTypeDefinition(steamID),
          versus.player.getValueTypeDefinition(player:Nick()),
          versus.player.getValueTypeDefinition(listingID),
        }
      )

      versus.message.notify(
        player,
        string.format("Bid of %s placed on %s!", versus.util.formatMoney(bidAmount), tostring(row.item_name)),
        NOTIFY_GENERIC
      )

      net.Start("versus.auction.actionResult")
      net.WriteBool(true)
      net.Send(player)
    end
  )
end)

net.Receive("versus.auction.buyout", function(len, player)
  local listingID = net.ReadUInt(32)

  if listingID == 0 then return end

  local steamID = player:SteamID64()

  versus.database.queryPrepared(
    string.format(
      "SELECT * FROM `%s` WHERE `id` = ? AND `status` = 'active' LIMIT 1",
      TABLE_LISTINGS
    ),
    { versus.player.getValueTypeDefinition(listingID) },
    function(rows)
      if not IsValid(player) then return end

      if not rows or #rows == 0 then
        versus.message.notify(player, "This listing is no longer available.", NOTIFY_ERROR)
        return
      end

      local row    = rows[1]
      local buyout = tonumber(row.buyout_price)

      if row.seller_steamid == steamID then
        versus.message.notify(player, "You cannot buy your own listing.", NOTIFY_ERROR)
        return
      end

      if not buyout or buyout <= 0 then
        versus.message.notify(player, "This listing has no buy-out price.", NOTIFY_ERROR)
        return
      end

      local canAfford, deficit = versus.finance.canAfford(player, buyout)

      if not canAfford then
        versus.message.notify(
          player,
          "You cannot afford this. You need " .. versus.util.formatMoney(deficit) .. " more.",
          NOTIFY_ERROR
        )
        return
      end

      -- Refund the existing leading bidder if there is one
      local prevBid      = tonumber(row.current_bid) or 0
      local prevBidderID = row.current_bidder_steamid

      if prevBid > 0 and prevBidderID ~= nil and prevBidderID ~= "" then
        PLUGIN.deliver(
          prevBidderID, "money", prevBid, nil,
          "Bid refund — item bought out: " .. tostring(row.item_name)
        )
      end

      -- Charge the buyer, give item, pay seller
      versus.finance.takeMoney(player, buyout, "Auction buyout: " .. tostring(row.item_name))

      local instanceData = util.JSONToTable(row.item_data)

      if instanceData then
        local item = versus.item.restoreInstance(instanceData)

        if item then
          versus.inventory.giveItem(player, item)
        end
      end

      PLUGIN.deliver(
        row.seller_steamid, "money", buyout, nil,
        "Sold at auction (buyout): " .. tostring(row.item_name)
      )

      versus.database.queryPrepared(
        string.format(
          "UPDATE `%s` SET `status` = 'sold', `current_bidder_steamid` = ?, `current_bidder_name` = ?, `current_bid` = ? WHERE `id` = ?",
          TABLE_LISTINGS
        ),
        {
          versus.player.getValueTypeDefinition(steamID),
          versus.player.getValueTypeDefinition(player:Nick()),
          versus.player.getValueTypeDefinition(buyout),
          versus.player.getValueTypeDefinition(listingID),
        }
      )

      versus.message.notify(
        player,
        string.format("You bought %s for %s!", tostring(row.item_name), versus.util.formatMoney(buyout)),
        NOTIFY_GENERIC
      )

      net.Start("versus.auction.actionResult")
      net.WriteBool(true)
      net.Send(player)
    end
  )
end)

net.Receive("versus.auction.listItem", function(len, player)
  local itemKey     = net.ReadUInt(versus.inventory.bitSizeItemKeys)
  local minBid      = net.ReadUInt(32)
  local buyoutPrice = net.ReadUInt(32) -- 0 = no buyout
  local durationIdx = net.ReadUInt(4)
  local item        = versus.inventory.getItem(player, itemKey)

  if not item then
    versus.message.notify(player, "Item not found in your inventory.", NOTIFY_ERROR)
    return
  end

  if item.untradable then
    versus.message.notify(player, "This item cannot be listed for auction.", NOTIFY_ERROR)
    return
  end

  if minBid < 1 then
    versus.message.notify(player, "Minimum bid must be at least 1.", NOTIFY_ERROR)
    return
  end

  if durationIdx < 1 or durationIdx > #PLUGIN.DURATIONS then
    versus.message.notify(player, "Invalid listing duration.", NOTIFY_ERROR)
    return
  end

  if buyoutPrice > 0 and buyoutPrice <= minBid then
    versus.message.notify(player, "Buy-out price must be higher than the minimum bid.", NOTIFY_ERROR)
    return
  end

  local steamID = player:SteamID64()
  local limit   = PLUGIN.getListingLimit(player)

  -- Check active listing count against the player's limit before touching inventory or money
  versus.database.queryPrepared(
    string.format(
      "SELECT COUNT(*) AS `cnt` FROM `%s` WHERE `seller_steamid` = ? AND `status` = 'active'",
      TABLE_LISTINGS
    ),
    { versus.player.getValueTypeDefinition(steamID) },
    function(cr)
      if not IsValid(player) then return end

      local activeCount = cr and cr[1] and tonumber(cr[1].cnt) or 0

      if activeCount >= limit then
        versus.message.notify(
          player,
          string.format(
            "You have reached your listing limit of %d. Cancel an existing listing to add a new one.",
            limit
          ),
          NOTIFY_ERROR
        )
        return
      end

      local fee = PLUGIN.computeFee(minBid, durationIdx)
      local canAfford, deficit = versus.finance.canAfford(player, fee)

      if not canAfford then
        versus.message.notify(
          player,
          "You cannot afford the listing fee of " .. versus.util.formatMoney(fee) ..
          ". You need " .. versus.util.formatMoney(deficit) .. " more.",
          NOTIFY_ERROR
        )
        return
      end

      local itemName = tostring(item.name or item.itemID or "Unknown")
      local itemData = util.TableToJSON(item:getSafeData())
      local dur      = PLUGIN.DURATIONS[durationIdx]

      versus.inventory.takeItem(player, item)

      versus.finance.takeMoney(
        player, fee,
        string.format("Auction listing fee: %s (%s)", itemName, dur.label)
      )

      versus.database.queryPrepared(
        string.format([[
          INSERT INTO `%s`
            (`seller_steamid`, `seller_name`, `item_data`, `item_name`, `min_bid`, `buyout_price`, `expires_at`)
          VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL %d SECOND))
        ]], TABLE_LISTINGS, dur.seconds),
        {
          versus.player.getValueTypeDefinition(steamID),
          versus.player.getValueTypeDefinition(player:Nick()),
          versus.player.getValueTypeDefinition(itemData),
          versus.player.getValueTypeDefinition(itemName),
          versus.player.getValueTypeDefinition(minBid),
          versus.player.getValueTypeDefinition(buyoutPrice > 0 and buyoutPrice or nil),
        }
      )

      versus.message.notify(
        player,
        string.format("%s listed for auction! Listing fee charged: %s.", itemName, versus.util.formatMoney(fee)),
        NOTIFY_GENERIC
      )

      net.Start("versus.auction.actionResult")
      net.WriteBool(true)
      net.Send(player)
    end
  )
end)

net.Receive("versus.auction.cancelListing", function(len, player)
  local listingID = net.ReadUInt(32)

  if listingID == 0 then return end

  local steamID = player:SteamID64()

  versus.database.queryPrepared(
    string.format(
      "SELECT * FROM `%s` WHERE `id` = ? AND `status` = 'active' LIMIT 1",
      TABLE_LISTINGS
    ),
    { versus.player.getValueTypeDefinition(listingID) },
    function(rows)
      if not IsValid(player) then return end

      if not rows or #rows == 0 then
        versus.message.notify(player, "This listing is no longer available.", NOTIFY_ERROR)
        return
      end

      local row = rows[1]

      if row.seller_steamid ~= steamID then
        versus.message.notify(player, "You can only cancel your own listings.", NOTIFY_ERROR)
        return
      end

      -- Refund any existing bid
      local prevBid      = tonumber(row.current_bid) or 0
      local prevBidderID = row.current_bidder_steamid

      if prevBid > 0 and prevBidderID ~= nil and prevBidderID ~= "" then
        PLUGIN.deliver(
          prevBidderID, "money", prevBid, nil,
          "Bid refund — listing cancelled: " .. tostring(row.item_name)
        )
      end

      -- Return item to seller
      local instanceData = util.JSONToTable(row.item_data)

      if instanceData then
        PLUGIN.deliver(
          steamID, "item", nil, instanceData,
          "Auction cancelled: " .. tostring(row.item_name)
        )
      end

      versus.database.queryPrepared(
        string.format("UPDATE `%s` SET `status` = 'cancelled' WHERE `id` = ?", TABLE_LISTINGS),
        { versus.player.getValueTypeDefinition(listingID) }
      )

      versus.message.notify(
        player,
        "Listing for " .. tostring(row.item_name) .. " cancelled. Item returned.",
        NOTIFY_GENERIC
      )

      net.Start("versus.auction.actionResult")
      net.WriteBool(true)
      net.Send(player)
    end
  )
end)

--[[
  Hooks
--]]

function PLUGIN.hook:DatabaseConnected()
  PLUGIN.ensureTables()

  timer.Create("versus.auction.expiry", PLUGIN.EXPIRY_CHECK_INTERVAL, 0, function()
    PLUGIN.processExpired()
  end)
end

function PLUGIN.hook:PlayerInitialized(player)
  PLUGIN.deliverPending(player)
end
