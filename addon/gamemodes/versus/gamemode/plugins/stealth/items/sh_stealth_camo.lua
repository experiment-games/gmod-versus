local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Stealth Camo"
ITEM.category = "Utility"
ITEM.size = 1
ITEM.cost = 5500
ITEM.seller = { "armoury" }
ITEM.model = "models/weapons/w_c4_planted.mdl"
ITEM.description =
"A device that makes you temporarily invisible. Hold C to activate camouflage. Footsteps heard by nearby enemies or walking too close to them will break your cover — crouch to move silently."
ITEM.equipSlot = "utility"

function ITEM:onUnequip(player)
  versus.stealth.disableStealth(player)
end
