local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.name = "Armor Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_armor"
ITEM.base = "base_equipment"
ITEM.isArmor = true
ITEM.category = "Armor"
ITEM.equipSlot = "replacement"
ITEM.size = 1
ITEM.skin = 0

-- Model to show in inventory and when dropping
ITEM.model = "models/stalker/outfit/bandit1.mdl"

-- Model to replace the player's model with when equipped.
ITEM.equipModel = "models/stalkertnb/bandit1.mdl"

ITEM.description = "A reliable piece of armor for protecting yourself in combat situations."
ITEM.actionTexts = {
  ["Use"] = "Equip",
}

function ITEM:onEquip(player)
  player:SetModel(self.equipModel)
  player:SetSkin(self.skin or 0)
  player:SetBodyGroups(self.bodygroups or "00000000000000000000")
end

function ITEM:onUnequip(player)
  versus.player.reloadAppearance(player)
end

function ITEM:onUse(player)
  versus.equipment.equipItem(player, self)
end

function ITEM:onDrop(player, position)
  if (versus.equipment.getEquippedItem(player, self.equipSlot) == self) then
    versus.equipment.unequipItem(player, self.equipSlot, false)
  end
end
