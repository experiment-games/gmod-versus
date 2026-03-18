local UNIT = UNIT
local SPACING = 16

function UNIT.hook:HUDShouldDraw(name)
  if (name == "CHudWeaponSelection") then
    return false
  end
end

function UNIT.hook:BuildInventorySettings(panel)
  panel.optionAutoEquipAmmo = vgui.Create("DCheckBoxLabel", panel)
  panel.optionAutoEquipAmmo:DockMargin(SPACING, SPACING, SPACING, SPACING)
  panel.optionAutoEquipAmmo:Dock(LEFT)
  panel.optionAutoEquipAmmo:SetText("Automatically equip ammo when you run out")
  panel.optionAutoEquipAmmo:SetConVar(self.convarAutoEquipAmmo:GetName())
  panel.optionAutoEquipAmmo:SizeToContents()
  panel.optionAutoEquipAmmo:SetTextColor(color_white)
end

-- Hook into weapon slot selection
function UNIT.hook:PlayerBindPress(ply, bind, pressed, code)
  if not pressed then
    return
  end

  -- Slot selection (1-9) - directly switch to weapon at that index
  local slot = string.match(bind, "slot(%d)")
  if slot then
    if not IsValid(UNIT.weaponSelection) then
      UNIT:createWeaponSelection()
    end

    UNIT.weaponSelection:SelectWeaponByIndex(tonumber(slot))
    return true
  end

  local shouldShowWeaponSelection = hook.Run("ShouldShowWeaponSelection", ply, bind, pressed, code)

  -- Weapon cycling
  if bind == "invnext" and not ply:KeyDown(IN_ATTACK) and shouldShowWeaponSelection ~= false then
    if not IsValid(UNIT.weaponSelection) then
      UNIT:createWeaponSelection()
    end

    if UNIT.weaponSelection.targetAlpha == 0 then
      UNIT:showWeaponSelection()
    end

    UNIT.weaponSelection:NextWeapon()
    return true
  elseif bind == "invprev" and not ply:KeyDown(IN_ATTACK) and shouldShowWeaponSelection ~= false then
    if not IsValid(UNIT.weaponSelection) then
      UNIT:createWeaponSelection()
    end

    if UNIT.weaponSelection.targetAlpha == 0 then
      UNIT:showWeaponSelection()
    end

    UNIT.weaponSelection:PreviousWeapon()
    return true
  end

  -- Confirm selection with attack
  if IsValid(UNIT.weaponSelection) and UNIT.weaponSelection.targetAlpha > 0 then
    if bind == "+attack" then
      UNIT.weaponSelection:ConfirmSelection()
      return true
    end
  end

  return hook.Run("PlayerBindPressLate", ply, bind, pressed, code)
end

-- Initialize on client spawn
function UNIT.hook:InitPostEntity()
  UNIT:createWeaponSelection()
end

--- When the player no longer has any ammo, we want to load any ammo they have in their inventory.
function UNIT.hook:PlayerThink(player)
  if (not self.convarAutoEquipAmmo:GetBool()) then
    return
  end

  local activeWeapon = player:GetActiveWeapon()

  if (not IsValid(activeWeapon)) then
    return
  end

  local itemID = activeWeapon:GetNWString("versus_ItemID", "")
  local itemTable = itemID ~= "" and versus.item.get(itemID)

  if (not itemTable) then
    return
  end

  local ammoType = activeWeapon:GetPrimaryAmmoType()
  local ammoCount = player:GetAmmoCount(ammoType)

  -- Also add the clip ammo to the total count
  ammoCount = ammoCount + activeWeapon:Clip1()

  if (ammoCount > 0) then
    return
  end

  if (itemTable.isGrenadeWeapon) then
    return
  end

  -- For non-grenade weapons, we want to try equip ammo from their inventory if they have it before switching them to another weapon.
  if (versus.util.throttled("versus_weapon_think_equip_ammo", 1)) then
    return
  end

  if (ammoType == -1) then
    return
  end

  local ammoName = game.GetAmmoName(ammoType)

  if (not ammoName) then
    return
  end

  for itemKey, item in pairs(versus.inventory.findAllBy(player, "ammoType", ammoName, true)) do
    if (item.isAmmunition) then
      versus.command.run("inventory", itemKey, "use")
      break
    end
  end
end

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
