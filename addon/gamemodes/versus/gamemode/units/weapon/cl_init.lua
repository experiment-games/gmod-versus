local UNIT = UNIT

UNIT.convarAutoEquipAmmo = CreateClientConVar("versus_inventory_auto_equip_ammo", "1", true, false)

function UNIT:createWeaponSelection()
  if IsValid(self.weaponSelection) then
    self.weaponSelection:Remove()
  end

  self.weaponSelection = vgui.Create("versus_WeaponSelection")
end

function UNIT:showWeaponSelection()
  if not IsValid(self.weaponSelection) then
    self:createWeaponSelection()
  end

  self.weaponSelection:SetToCurrentWeapon()
  self.weaponSelection.targetAlpha = 255
  self.weaponSelection.lastActivity = CurTime()
end

function UNIT:hideWeaponSelection()
  if IsValid(self.weaponSelection) then
    self.weaponSelection.targetAlpha = 0
  end
end

-- Rebuild on Lua auto refresh
if IsValid(UNIT.weaponSelection) then
  UNIT:createWeaponSelection()
end
