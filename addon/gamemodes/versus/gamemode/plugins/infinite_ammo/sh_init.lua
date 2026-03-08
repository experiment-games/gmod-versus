local PLUGIN = PLUGIN

-- Grenades are not infinite
function PLUGIN.isGrenade(ammoName)
  return string.find(ammoName:lower(), "grenade") ~= nil
end

-- Go through all items and mark all non-grenade ammo hidden
function PLUGIN.hook:VersusInitialized()
  local allItems = versus.item.all()

  for itemID, item in pairs(allItems) do
    if (item.isBaseItem or item.hidden) then
      continue
    end

    if item.ammoType and not PLUGIN.isGrenade(item.ammoType) then
      item.hidden = true
    end
  end
end
