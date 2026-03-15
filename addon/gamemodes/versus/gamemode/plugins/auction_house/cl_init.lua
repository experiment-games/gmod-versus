local PLUGIN = PLUGIN

--- Opens the auction panel. If it is already open, closes it instead.
function PLUGIN.openAuctionPanel()
  if IsValid(PLUGIN.auctionPanel) then
    PLUGIN.auctionPanel:Close()
    return
  end

  PLUGIN.auctionPanel = vgui.Create("versus_Auction")
end

--[[
  Net Messages
--]]

net.Receive("versus.auction.open", function()
  PLUGIN.openAuctionPanel()
end)

-- Incoming page of auction data from the server
net.Receive("versus.auction.pageData", function()
  local tab     = net.ReadString()
  local page    = net.ReadUInt(16)
  local total   = net.ReadUInt(32)
  local count   = net.ReadUInt(8)

  local entries = {}

  for _ = 1, count do
    table.insert(entries, {
      id            = net.ReadUInt(32),
      sellerSteamID = net.ReadString(),
      sellerName    = net.ReadString(),
      itemName      = net.ReadString(),
      itemID        = net.ReadString(),
      itemRarity    = net.ReadString(), -- per-instance rarity (may be empty; client falls back to item definition)
      minBid        = net.ReadUInt(32),
      currentBid    = net.ReadUInt(32),
      buyoutPrice   = net.ReadUInt(32),
      expireUnix    = net.ReadUInt(32),
      hasBidder     = net.ReadBool(),
      bidderName    = net.ReadString(),
    })
  end

  -- For my_listings the server appends the player's listing limit info
  local meta = nil

  if tab == "my_listings" then
    meta = {
      limit = net.ReadUInt(8),
    }
  end

  if IsValid(PLUGIN.auctionPanel) then
    PLUGIN.auctionPanel:OnPageData(tab, page, total, entries, meta)
  end
end)

-- Server signals that an action (bid, buyout, list, cancel) completed successfully
net.Receive("versus.auction.actionResult", function()
  local success = net.ReadBool()

  if success and IsValid(PLUGIN.auctionPanel) then
    PLUGIN.auctionPanel:OnActionResult()
  end
end)

-- Refresh the sell inventory when items leave or enter the player's inventory
hook.Add("InventoryItemGivenNetworked", "versus.auctionHouseRefresh", function()
  if IsValid(PLUGIN.auctionPanel) then
    PLUGIN.auctionPanel:OnInventoryChanged()
  end
end)

hook.Add("InventoryItemTakenNetworked", "versus.auctionHouseRefresh", function()
  if IsValid(PLUGIN.auctionPanel) then
    PLUGIN.auctionPanel:OnInventoryChanged()
  end
end)

hook.Add("InventoryEntireInventoryNetworked", "versus.auctionHouseRefresh", function()
  if IsValid(PLUGIN.auctionPanel) then
    PLUGIN.auctionPanel:OnInventoryChanged()
  end
end)
