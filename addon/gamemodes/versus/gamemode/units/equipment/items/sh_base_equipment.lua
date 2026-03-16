local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Equipment Base"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.isBaseItem = true
ITEM.isEquipment = true
ITEM.model = "models/props/de_tides/vending_hat.mdl"
ITEM.description =
"Base item for equipment. This item doesn't do anything on its own and is not meant to be used directly. It is meant to be inherited by other items that provide actual functionality."
ITEM.actionTexts = {
  ["Use"] = "Equip",
}

function ITEM:onUse(player)
  versus.equipment.equipItem(player, self)
end

-- Draw a little health bar above the name
function ITEM:onPaintOver(panel, width, height)
  if (not self.health) then
    return
  end

  local healthFraction = self.health / self.maxHealth
  local barWidth = width * 0.6
  local barHeight = 5
  local barX = (width - barWidth) / 2
  local barY = panel.nameTextY - barHeight - 2

  -- Background of the health bar (dark red)
  surface.SetDrawColor(100, 0, 0, 50)
  surface.DrawRect(barX, barY, barWidth, barHeight)

  -- Foreground of the health bar (bright red)
  surface.SetDrawColor(255, 0, 0, 50)
  surface.DrawRect(barX, barY, barWidth * healthFraction, barHeight)
end
