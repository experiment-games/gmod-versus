local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Stealth Camo"
ITEM.category = "Utility"
ITEM.size = 1
ITEM.cost = 5500
ITEM.seller = { "armoury" }
ITEM.model = "models/weapons/w_c4_planted.mdl"
ITEM.description = function()
  local stealthKey = versus.message.lookupBinding("+menu_context") or "C"

  return string.format(
    "A device that makes you temporarily invisible. Hold %s to activate camouflage.",
    stealthKey
  )
end
ITEM.equipSlot = "utility"

function ITEM:onUnequip(player)
  versus.stealth.disableStealth(player)
end
