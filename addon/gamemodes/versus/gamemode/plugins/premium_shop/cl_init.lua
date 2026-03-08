local PLUGIN = PLUGIN

-- Show admin payment records panel
function PLUGIN.showAdminPaymentsPanel()
  if (IsValid(PLUGIN.paymentHistoryPanel)) then
    PLUGIN.paymentHistoryPanel:Close()
  end

  if (IsValid(PLUGIN.adminPaymentsPanel)) then
    PLUGIN.adminPaymentsPanel:Close()
  end

  PLUGIN.adminPaymentsPanel = vgui.Create("versus_AdminPaymentsPanel")
  PLUGIN.adminPaymentsPanel:MakePopup()

  net.Start("versus.premium_shop.requestAdminPayments")
  net.WriteString("") -- search query
  net.SendToServer()
end

function PLUGIN.showPaymentHistory()
  if (IsValid(PLUGIN.adminPaymentsPanel)) then
    PLUGIN.adminPaymentsPanel:Close()
  end

  if (IsValid(PLUGIN.paymentHistoryPanel)) then
    PLUGIN.paymentHistoryPanel:Close()
  end

  PLUGIN.paymentHistoryPanel = vgui.Create("versus_PaymentHistoryPanel")
  PLUGIN.paymentHistoryPanel:MakePopup()

  net.Start("versus.premium_shop.requestPaymentHistory")
  net.SendToServer()
end

--[[
  Hooks
--]]

-- Register the unified Play tab in the main menu
function PLUGIN.hook:BuildMainMenuTabs(tabs)
  local url = PLUGIN.premiumShopUrl:GetString()

  if (not url or url == "") then
    return
  end

  tabs:addTab("Premium Shop", vgui.Create("versus_PremiumShop"), 9)
end

-- Supporters get a heart icon in OOC chat, this is not called if they're also moderator, admin or superadmin
function PLUGIN.hook:GetPlayerIcon(speaker)
  if (speaker:HasPremiumPackage("supporter-role-lifetime")) then
    return { Material("icon16/heart.png"), "<3" }
  end
end

--[[
	Player Meta functions
--]]

local playerMeta = FindMetaTable("Player")

function playerMeta:HasPremiumPackage(slug)
  if (not self._VersusPremiumPackages) then
    return false
  end

  return self._VersusPremiumPackages[slug] == true
end

function playerMeta:GetPremiumPackages()
  return self._VersusPremiumPackages or {}
end

--[[
  Net Messages
--]]

net.Receive("versus.premium_shop.syncPackages", function(len)
  local player = net.ReadPlayer()
  local count = net.ReadUInt(16)
  local premiumPackages = {}

  for i = 1, count do
    local slug = net.ReadString()
    premiumPackages[slug] = true
  end

  if (IsValid(player)) then
    player._VersusPremiumPackages = premiumPackages
  else
    ErrorNoHalt(
      "Received premium package data for invalid player: " .. tostring(player)
    )
  end
end)

versus.network.receiveUnbounded("versus.premium_shop.playerPaymentHistory", function(message)
  local paymentRecords = message:readTable()

  if (IsValid(PLUGIN.paymentHistoryPanel)) then
    PLUGIN.paymentHistoryPanel:DisplayPaymentRecords(paymentRecords)
  end
end)

versus.network.receiveUnbounded("versus.premium_shop.adminPaymentRecords", function(message)
  local paymentRecords = message:readTable()
  local searchQuery = message:readString()

  if (IsValid(PLUGIN.adminPaymentsPanel)) then
    PLUGIN.adminPaymentsPanel:DisplayPaymentRecords(paymentRecords, searchQuery)
  end
end)
