local UNIT = UNIT

function UNIT.drawRarityBadge(rarityID, x, y, isLeftAligned)
  if (rarityID) then
    local rarity = versus.item.getRarity(rarityID)
    local rarityColor = rarity and rarity.color or Color(141, 153, 174)
    local rarityText = rarityID:upper()
    surface.SetFont("VersusSmall")
    local rarityW, rarityH = surface.GetTextSize(rarityText)

    local backgroundX = x - (rarityW + 16) / 2
    local backgroundY = y - 4

    if (isLeftAligned) then
      backgroundX = x
      x = x + (rarityW + 16) / 2
    end

    -- Background for rarity badge
    draw.RoundedBox(
      4,
      backgroundX,
      backgroundY,
      rarityW + 16,
      rarityH + 8,
      ColorAlpha(rarityColor, 60)
    )

    draw.SimpleText(
      rarityText,
      "VersusSmall",
      x,
      y,
      rarityColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
  end
end
