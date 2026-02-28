local PLUGIN = PLUGIN

function PLUGIN.hook:PlayerSpawn(player)
  local ammoTypes = game.GetAmmoTypes()

  for id, name in pairs(ammoTypes) do
    if PLUGIN.isGrenade(name) then
      continue
    end

    player:SetAmmo(9999, id)
  end
end

function PLUGIN.hook:PlayerAmmoChanged(player, ammoID, oldAmount, newAmount)
  if (newAmount < 9999) then
    if PLUGIN.isGrenade(game.GetAmmoName(ammoID)) then
      return
    end

    player:SetAmmo(9999, ammoID)
  end
end

function PLUGIN.hook:PlayerShouldReturnAmmo(player, ammoTypeID, amount)
  if PLUGIN.isGrenade(game.GetAmmoName(ammoTypeID)) then
    return
  end

  return false
end
