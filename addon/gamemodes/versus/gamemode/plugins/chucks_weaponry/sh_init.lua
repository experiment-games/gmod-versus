local PLUGIN = PLUGIN

if (SERVER) then
  resource.AddWorkshop("349050451") -- Chuck's Weaponry 2.0
end

if (not CustomizableWeaponry) then
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
