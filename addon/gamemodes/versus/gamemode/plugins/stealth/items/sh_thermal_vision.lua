local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Thermal Vision"
ITEM.category = "Utility"
ITEM.size = 1
ITEM.cost = 5000
ITEM.seller = { "armoury" }
ITEM.model = "models/gibs/shield_scanner_gib1.mdl"
ITEM.description =
"An implant that lets you see through stealth camouflage. Equipped players appear highlighted in red. Automatically active while equipped."
ITEM.equipSlot = "thermal_vision"

function ITEM:onEquip(player)
  player:SetNWBool(versus.stealth.nwKeyThermalActive, true)
end

function ITEM:onUnequip(player)
  player:SetNWBool(versus.stealth.nwKeyThermalActive, false)
end
