local PLUGIN = PLUGIN

-- Ensure that damage scale doesn't go beyond 90% damage reduction
PLUGIN.maxReductionTo = 0.1

--- Gets the player's equipped defensive gear items and calculates the total damage scale from them.
--- @param player Player # The player to get the defensive gear items for.
--- @return table, number # A table of the player's equipped defensive gear items and the total damage scale from them
function PLUGIN.getDefensiveGearItems(player)
  local equippedItems = versus.equipment.getEquippedItems(player)
  local defensiveGearItems = {}
  local totalDamageScale = 1
  local hitGroup = player:LastHitGroup()

  for slot, item in pairs(equippedItems) do
    if (item.damageScale and (not item.hitGroups or item.hitGroups[hitGroup])) then
      table.insert(defensiveGearItems, {
        slot = slot,
        item = item,
      })

      local damageScale = item.damageScale

      -- If the item has rarity, scale down even further based on the rarity
      if (item.rarity) then
        local rarity = versus.item.getRarity(item.rarity)

        if (rarity and rarity.modifier) then
          damageScale = damageScale / rarity.modifier
        end
      end

      totalDamageScale = totalDamageScale * damageScale
    end
  end

  totalDamageScale = math.max(totalDamageScale, PLUGIN.maxReductionTo)

  return defensiveGearItems, totalDamageScale
end

--- Applies the given amount of damage to the player's equipped defensive gear items.
--- @param player Player # The player whose defensive gear items should be damaged.
--- @param defensiveGearItems table # A table of the player's equipped defensive gear items to damage.
--- @param damage number # The amount of damage to apply to the defensive gear items.
function PLUGIN.damageDefensiveGearItems(player, defensiveGearItems, damage)
  local damagePerItem = damage / #defensiveGearItems

  for _, itemInfo in pairs(defensiveGearItems) do
    local item = itemInfo.item

    if (item.health) then
      item.health = item.health - damagePerItem

      versus.equipment.networkEquippedItem(player, item, "health")

      if (item.health <= 0) then
        item.health = 0
        versus.equipment.unequipItem(player, itemInfo.slot, false)

        local consequence

        -- If it fits in inventory, move it there, otherwise drop it on the ground
        -- Add an exception for items that cannot be dropped (possible premium items), which we force into the inventory.
        if (item.undroppable or versus.inventory.canFit(player, item.size)) then
          versus.inventory.giveItem(player, item)
          consequence = "It has been unequipped into your inventory."
        else
          local position = player:GetPos() + Vector(0, 0, 2)
          versus.item.make(item, position)
          consequence = "It has been dropped on the ground as it couldn't fit in your inventory."
        end

        versus.message.notify(
          player,
          "Your " .. item.name .. " has been completely ruined. " .. consequence,
          NOTIFY_GENERIC
        )
      end
    end
  end
end

--[[
  Hooks
--]]

-- Called when an entity takes damage.
function PLUGIN.hook:EntityTakeDamage(entity, damageInfo)
  local attacker = damageInfo:GetAttacker()
  local amount = damageInfo:GetDamage()

  if (not IsValid(attacker)) then
    return
  end

  -- Check if the entity that got damaged is a player.
  if (entity:IsPlayer()) then
    if (not entity._KnockedOut) then
      local defensiveGearItems, totalDamageScale = self.getDefensiveGearItems(entity)

      if (totalDamageScale ~= 1) then
        local damagePrevented = amount - (amount * totalDamageScale)

        -- Scale the damage based on the player's equipped defensive gear.
        damageInfo:ScaleDamage(totalDamageScale)

        self.damageDefensiveGearItems(entity, defensiveGearItems, damagePrevented)
      end
    end
  end

  -- Check if the entity is a knocked out player.
  if (IsValid(entity._Player)) then
    local defensiveGearItems, totalDamageScale = self.getDefensiveGearItems(entity._Player)

    if (totalDamageScale ~= 1) then
      local damagePrevented = amount - (amount * totalDamageScale)

      -- Scale the damage based on the player's equipped defensive gear.
      damageInfo:ScaleDamage(totalDamageScale)

      self.damageDefensiveGearItems(entity._Player, defensiveGearItems, damagePrevented)
    end
  end
end
