local PLUGIN = PLUGIN

--- Cost in money per hitpoint repaired by the Armor Welder NPC.
PLUGIN.armorHitPointCost = 5

if (SERVER) then
  -- Stalker playermodels (factions) https://steamcommunity.com/sharedfiles/filedetails/?id=355101935
  resource.AddWorkshop("355101935")
end

--- Get the cost to fully repair an armor item.
--- @param item VersusItemInstance The armor item being repaired
--- @return number? # The total repair cost, or nil if the item has no maxHealth
function PLUGIN.getRepairCost(item)
  if not item.maxHealth or item.maxHealth <= 0 then
    return nil
  end

  local damage = item.maxHealth - (item.health or item.maxHealth)

  if damage <= 0 then
    return 0
  end

  return damage * PLUGIN.armorHitPointCost
end
