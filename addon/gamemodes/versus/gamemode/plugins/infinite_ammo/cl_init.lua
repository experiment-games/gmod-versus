local PLUGIN = PLUGIN

function PLUGIN.hook:PreDrawAmmoBar(bar, data)
  if (data.isGrenade) then
    return
  end

  data.reserveAmmo = "∞"

  -- Grenades are not infinite
  -- if (data.isGrenade) then
  --   data.currentAmmo = "∞"
  --   data.maxAmmo = "∞"
  -- end
end

function PLUGIN.hook:PreDrawWeaponSelectionAmmo(weaponSelection, weapon, data)
  if (data.itemTable and data.itemTable.isGrenadeWeapon) then
    -- data.ammoText = "∞"
    return
  else
    data.ammoText = string.format("%d / %s", weapon:Clip1(), "∞")
  end
end
