local PLUGIN = PLUGIN

PLUGIN.libraryKey = "npc"

PLUGIN.NO_HEALTH = -1

versus.includePrefixed("sv_hooks.lua")
versus.includePrefixed("sv_director.lua")

--- Don't have NPC's collide with each other (requires SetCustomCollisionCheck to be enabled on the NPCs)
function PLUGIN.hook:ShouldCollide(ent1, ent2)
  if (ent1:GetClass():StartWith("npc_") and ent2:GetClass():StartWith("npc_")) then
    return false
  end
end

--- Calculate scrap value as a percentage of the item's cost
--- Default to 25% of purchase price or nil if no cost.
--- @param item VersusItemInstance The item being scrapped
--- @return number? # The value of the scrap or nil if the item cannot be scrapped
function PLUGIN.getScrapValue(item)
  if (not item.cost or item.cost <= 0 or item.unscrappable) then
    return nil
  end

  local scrapFraction = 0.25
  local baseCost = item.cost or 0

  if (item.getScrapValue) then
    return item:getScrapValue()
  end

  if (item.getScrapFraction) then
    scrapFraction = item:getScrapFraction()
  elseif (item.scrapFraction) then
    scrapFraction = item.scrapFraction
  end

  return math.max(1, math.floor(baseCost * scrapFraction))
end
