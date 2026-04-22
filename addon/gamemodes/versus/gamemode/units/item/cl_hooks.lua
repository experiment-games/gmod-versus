local UNIT = UNIT

--[[
function UNIT.hook:BuildItemTooltipRows(tooltip, item)
  if (not item.ammoType) then
    return
  end

  for _, weapon in ipairs(LocalPlayer():GetWeapons()) do
    if (not IsValid(weapon)) then
      return
    end

    local ammoType1 = weapon:GetPrimaryAmmoType()
    local ammoName1 = game.GetAmmoName(ammoType1)

    local ammoType2 = weapon:GetSecondaryAmmoType()
    local ammoName2 = game.GetAmmoName(ammoType2)

    -- Outline the item if we have a weapon equipped that can use this ammo
    if (ammoName1 == item.ammoType or ammoName2 == item.ammoType) then
      local hint = tooltip:AddRow("ammoHint" .. item.ammoType)
      hint:SetText("Your " .. weapon:GetPrintName() .. " can use this ammo!")
      hint:SetTextColor(COLOR_ACCENT)
    end
  end
end
]]
local hitGroupNames = {
  [HITGROUP_HEAD] = "head",
  [HITGROUP_CHEST] = "chest",
  [HITGROUP_STOMACH] = "stomach",
  [HITGROUP_LEFTARM] = "left arm",
  [HITGROUP_RIGHTARM] = "right arm",
  [HITGROUP_LEFTLEG] = "left leg",
  [HITGROUP_RIGHTLEG] = "right leg",
  [HITGROUP_GEAR] = "gear",
}

local function buildDamageNames(damageScale, hitGroups)
  local names = ""

  if (hitGroups) then
    local hitGroupCount = table.Count(hitGroups)

    if (hitGroupCount > 0) then
      local i = 0
      names = " for "

      for hitGroup, _ in pairs(hitGroups) do
        i = i + 1

        if (not hitGroupNames[hitGroup]) then
          continue
        end

        if (i > 1) then
          names = names .. ", "
        elseif (i == hitGroupCount and hitGroupCount > 1) then
          names = names .. "and "
        end

        names = names .. hitGroupNames[hitGroup]
      end
    end
  end

  return math.Round((1 - damageScale) * 100) .. "% damage reduction" .. names
end

-- Adds some common useful information for certain item properties.
function UNIT.hook:BuildItemTooltipRows(tooltip, item)
  if (item.undroppable) then
    local undroppable = tooltip:AddRow("undroppable")
    undroppable:SetText("This item cannot be dropped.")
    undroppable:SetBackgroundColor(Color(99, 210, 255))
    undroppable:SizeToContents()
  end

  if (item.resistanceAgainstGas) then
    local resistance = tooltip:AddRow("gasResistance")
    resistance:SetText(
      "Provides " .. math.Round(item.resistanceAgainstGas * 100) .. "% resistance against gas-based attacks."
    )
    resistance:SetBackgroundColor(Color(144, 194, 144))
    resistance:SizeToContents()
  end

  if (item.hitGroups and item.damageScale) then
    local damageReduction = tooltip:AddRow("damageReduction")
    damageReduction:SetText(buildDamageNames(item.damageScale, item.hitGroups))
    damageReduction:SetBackgroundColor(Color(146, 55, 77))
    damageReduction:SizeToContents()
  end
end
