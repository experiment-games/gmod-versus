local PLUGIN = PLUGIN

PLUGIN.premiumShopUrl = CreateConVar(
  "versus_premium_shop_url",
  "https://versus.paynow.store/",
  { FCVAR_REPLICATED, FCVAR_ARCHIVE },
  "URL of the premium shop to open in a frame in the main menu."
)

--[[
	Theme colors
--]]

PLUGIN.THEME = {
  background = Color(45, 45, 48),
  surface = Color(60, 60, 65),
  panel = Color(55, 55, 60),
  primary = Color(0, 122, 255),
  secondary = Color(88, 166, 255),
  success = Color(40, 167, 69),
  warning = Color(255, 193, 7),
  danger = Color(220, 53, 69),
  text = Color(240, 240, 240),
  textSecondary = Color(180, 180, 180),
  border = Color(80, 80, 85),
  hover = Color(70, 70, 75),
  premium = Color(255, 215, 0),      -- Gold color for premium
  premiumAccent = Color(255, 165, 0) -- Orange accent for premium
}

--[[
  Premium package tracking
--]]

PLUGIN.PREMIUM_PACKAGES = {}

function PLUGIN.registerPremiumPackage(packageData)
  if (not packageData) then
    ErrorNoHaltWithStack("RegisterPremiumPackage: packageData is required")
  end

  if (not packageData.slug or type(packageData.slug) ~= "string" or packageData.slug == "") then
    ErrorNoHaltWithStack("RegisterPremiumPackage: 'slug' must be a non-empty string")
  end

  if (not packageData.name or type(packageData.name) ~= "string" or packageData.name == "") then
    ErrorNoHaltWithStack("RegisterPremiumPackage: 'name' must be a non-empty string")
  end

  if (not packageData.image or type(packageData.image) ~= "string") then
    ErrorNoHaltWithStack("RegisterPremiumPackage: 'image' must be a string upon registration")
  end

  if (not packageData.description or type(packageData.description) ~= "string") then
    ErrorNoHaltWithStack("RegisterPremiumPackage: 'description' must be a string")
  end

  if (PLUGIN.PREMIUM_PACKAGES[packageData.slug]) then
    ErrorNoHaltWithStack("RegisterPremiumPackage: package slug '" .. packageData.slug .. "' is already registered")
  end

  if (SERVER) then
    local path = packageData.image

    resource.AddFile("materials/" .. path)
  end

  packageData.image = Material(packageData.image)

  PLUGIN.PREMIUM_PACKAGES[packageData.slug] = packageData
end

function PLUGIN.getPremiumPackage(slug)
  return PLUGIN.PREMIUM_PACKAGES[slug]
end

--[[
	Premium Package Registrations

	Note that the `slug` must match the product slug on PayNow.gg
--]]

-- For testing run: versus_premium_order purchased supporter-role-lifetime 1337 <steamid64>
PLUGIN.registerPremiumPackage({
  slug = "supporter-role-lifetime",
  name = "Supporter Role (Lifetime)",
  description = "Show your support for the server with a special supporter role!",
  image = "versus/premium/supporter_role.png",
})

PLUGIN.registerPremiumPackage({
  slug = "supporter-role-monthly",
  name = "Supporter Role (Monthly)",
  description = "Show your support for the server with a special supporter role!",
  image = "versus/premium/supporter_role.png",
})
