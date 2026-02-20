local PLUGIN = PLUGIN

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

      totalDamageScale = totalDamageScale * item.damageScale
    end
  end

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

      if (item.health <= 0) then
        item.health = 0
        versus.equipment.unequipItem(player, itemInfo.slot, false)

        versus.message.notify(player, "Your " .. item.name .. " has been destroyed!", NOTIFY_GENERIC)
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
