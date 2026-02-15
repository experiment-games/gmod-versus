local PLUGIN = PLUGIN

if (SERVER) then
  -- Chuck's Weaponry 2.0 (https://steamcommunity.com/sharedfiles/filedetails/?id=349050451)
  resource.AddWorkshop("349050451")

  -- Extra Chuck's Weaponry 2.0 (https://steamcommunity.com/sharedfiles/filedetails/?id=358608166)
  resource.AddWorkshop("358608166")
end

if (not CustomizableWeaponry) then
  ErrorNoHalt(
    "[Versus] Chuck's Weaponry 2.0 is not installed! Please install it from the Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=349050451\n")
  return
end

-- CustomizableWeaponry.registeredAttachments = {}
-- SKey stands for 'string key', whereas the registeredAttachments has numerical indexes
-- CustomizableWeaponry.registeredAttachmentsSKey = {}
-- CustomizableWeaponry.suppressors = {}
-- CustomizableWeaponry.sights = {}
-- CustomizableWeaponry.knownStatTexts = {}
-- CustomizableWeaponry.knownVariableTexts = {}

-- Disable all attachments on spawn
CustomizableWeaponry.giveAllAttachmentsOnSpawn = 0
-- The interaction menu cannot be opened
CustomizableWeaponry.canOpenInteractionMenu = false

-- Whether it should play sounds when interacting with the weapon (attaching stuff, changing ammo, etc)
-- CustomizableWeaponry.playSoundsOnInteract = true

-- Whether players can customize their guns in general
CustomizableWeaponry.customizationEnabled = false
-- The gamemode can handle attachments by:
-- - calling :attach(category, desiredPos) with the number of the group to cycle through all attachments in that group, or specifying the desired position
-- - calling :detach(group) to remove the currently attached attachment in the group
-- - figure out attachments with lua_run PrintTable(player.GetByID(1):GetActiveWeapon().Attachments):
--     - The top level are the groups listed, those match the group for attaching/detaching
--     - Each group contains a table of attachments in "atts", although 1-indexed, the attach desiredPos requires 0 for the first attachment, 1 for the second, etc.
--     - Each group also has "header" to get the name of the group

-- The key we need to press to toggle the customization menu
-- CustomizableWeaponry.customizationMenuKey = "+menu_context"

--- Finds all weapons based on a specific base class.
--- @param baseClass string The base class to search for.
--- @return table # Table of weapon class names.
function PLUGIN.findWeaponsByBase(baseClass)
  local foundWeapons = {}

  for k, v in pairs(weapons.GetList()) do
    if (weapons.IsBasedOn(v.ClassName, baseClass)) then
      table.insert(foundWeapons, v.ClassName)
    end
  end

  return foundWeapons
end

--- Registers items for all weapons found based on Chuck's Weaponry base class.
--- We check for RegisterWithVersus to ensure only CW2 weapons we have in our gamemode
--- are registered. We do this because the default CW2 weapons doesn't share PrintName
--- with the server, causing incorrect names on the server.
function PLUGIN:registerWeapons()
  local weaponClasses = self.findWeaponsByBase("cw_base")

  for _, className in pairs(weaponClasses) do
    local weapon = weapons.Get(className)

    if (not weapon or not weapon.RegisterWithVersus) then
      continue
    end

    local itemID = "#cw2_" .. className
    local item = versus.item.getAndResetOrCreateItem(itemID)

    item.base = "base_weapon"
    item.itemID = itemID
    item.weaponClass = className
    item.path = itemID
    item.name = weapon.PrintName
    item.description = weapon.Description
    item.model = weapon.WorldModel
    item.size = weapon.Weight or 5
    item.cost = weapon.Price

    versus.item.registerItem(item)
  end
end

function PLUGIN.hook:PreRegisterSWEP(swep, className)
  if (className ~= "cw_base") then
    return
  end

  -- After a frame we are certain cw_base will exist
  versus.util.nextFrame(function()
    -- We include these weapons late, so cw_base has had time to register from the CW2.0 addon.
    versus.unit.IncludeWeapons(self.fullPath .. "/entities/late_weapons/")
    self:registerWeapons()
  end)
end

-- Do not allow switching to empty grenade weapons
function PLUGIN.hook:PlayerSwitchWeapon(player, oldWeapon, newWeapon)
  if (weapons.IsBasedOn(newWeapon:GetClass(), "cw_grenade_base")) then
    local primaryAmmoType = newWeapon:GetPrimaryAmmoType()

    if (newWeapon:Clip1() <= 0 and player:GetAmmoCount(primaryAmmoType) <= 0) then
      return true
    end
  end
end

if (SERVER) then
  -- Always give the player all grenade weapons, we will only show and let them switch to the ones they have
  -- grenade ammo for
  function PLUGIN.hook:PlayerLoadout(player)
    local grenadeItems = versus.item.findAllByBase("base_grenade")

    for _, item in pairs(grenadeItems) do
      local noAmmo = true
      local weapon = player:Give(item.weaponClass, noAmmo)

      if (not IsValid(weapon)) then
        -- This may happen if the player already has the weapon. Let's try to find it and give it to them if so.
        weapon = player:GetWeapon(item.weaponClass)

        if (not IsValid(weapon)) then
          ErrorNoHalt("Failed to give grenade weapon: " .. item.weaponClass .. "\n")
          continue
        end
      end

      weapon._VersusItem = item
      weapon:SetNWString("versus_ItemID", item.itemID)
    end
  end
end
