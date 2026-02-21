local PLUGIN = PLUGIN

util.AddNetworkString("versus.chucksWeaponry.detachAttachment")
util.AddNetworkString("versus.chucksWeaponry.attachToInventoryWeapon")

--- Finds an attachment item based on the attachmentID defined in the attachment item and the CW2 weapon's attachments table.
--- @param attachmentID string The attachmentID defined in the item and the CW2 weapon's attachments table.
--- @return VersusItem?
function PLUGIN.findAttachmentItemByID(attachmentID)
  local attachmentItems = versus.item.findAllBy("attachmentID", attachmentID, true)
  local foundItem

  for _, item in pairs(attachmentItems) do
    if (item.isAttachment and item.base == "base_attachment") then
      if (foundItem) then
        ErrorNoHalt(
          "Multiple items found for attachmentID " ..
          attachmentID .. ", this shouldn't happen. Check the item definitions."
        )
      end

      foundItem = item
    end
  end

  return foundItem
end

--- Detach any existing attachment in the slot, returning the item to the player's inventory.
function PLUGIN.detachAttachmentFromWeapon(player, weapon, groupID, networkUpdate)
  weapon._VersusItem.attachments = weapon._VersusItem.attachments or {}

  local existingPos = weapon._VersusItem.attachments[groupID]

  if (not existingPos) then
    return
  end

  local attachments = weapon.Attachments
  local existingAttachmentID = attachments[groupID].atts[existingPos]

  if (not existingAttachmentID) then
    print("Old position for groupID ", groupID, " was invalid. Did the weapon get changed to have fewer attachments?")
    return
  end

  local existingAttachmentItem = PLUGIN.findAttachmentItemByID(existingAttachmentID)

  -- Return the existing attachment to the player's inventory.
  if (not existingAttachmentItem) then
    print("No item found for attachmentID ", existingAttachmentID, ", this shouldn't happen. Check the item definitions.")
    return
  end

  versus.inventory.giveItem(player, existingAttachmentItem.itemID)

  weapon:detach(groupID)

  -- Remove this from the weapon's attachments table so we can update it with the new one.
  weapon._VersusItem.attachments[groupID] = nil

  if (networkUpdate ~= false) then
    versus.inventory.networkItemOverrides(player, weapon._VersusItem, "attachments")
  end
end

--- Detach any attachment in the specified groupID from the item.
--- @param player Player The player to return the attachment to
--- @param item VersusItemInstance The item to detach the attachment from
--- @param groupID number The groupID to detach
function PLUGIN.detachAttachmentFromItem(player, item, groupID)
  if (not item.attachments or not item.attachments[groupID]) then
    print("Player sent detachAttachmentFromItem message without a valid attachment in that group, ignoring.")
    return
  end

  local attachmentPos = item.attachments[groupID]
  local attachments = weapons.Get(item.weaponClass).Attachments

  if (not attachments) then
    print("Weapon class ", item.weaponClass, " has no attachments table, this shouldn't happen.")
    return
  end

  local attachmentID = attachments[groupID].atts[attachmentPos]

  if (not attachmentID) then
    print("Old position for groupID ", groupID, " was invalid. Did the weapon get changed to have fewer attachments?")
    return
  end

  local attachmentItem = PLUGIN.findAttachmentItemByID(attachmentID)

  if (attachmentItem) then
    versus.inventory.giveItem(player, attachmentItem.itemID)
  else
    print("No item found for attachmentID ", attachmentID, ", this shouldn't happen. Check the item definitions.")
  end

  item.attachments[groupID] = nil

  versus.inventory.networkItemOverrides(player, item, "attachments")
end

--[[
  Hooks
--]]

--- When equiping the weapon, we check if the item has attachments stored and re-attach them to the weapon.
function PLUGIN.hook:PlayerEquippedWeaponItem(player, item)
  local weapon = player:GetWeapon(item.weaponClass)

  if (IsValid(weapon) and item.attachments) then
    for groupID, attachmentPos in pairs(item.attachments) do
      -- Delay to ensure the weapon is fully equipped before attaching.
      timer.Simple(0.1, function()
        if (IsValid(weapon)) then
          -- Using the internal attach function to avoid attach messing with the pos (+1 for no reason)
          weapon:_attach(groupID, attachmentPos)
        end
      end)
    end
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.chucksWeaponry.detachAttachment", function(length, player)
  local itemKey = net.ReadUInt(versus.inventory.bitSizeItemKeys)
  local groupID = net.ReadUInt(8)

  local item = versus.inventory.getItem(player, itemKey)

  if (not item or not item.attachments) then
    print("Player sent detachAttachment message without a valid item or attachments, ignoring.")
    return
  end

  PLUGIN.detachAttachmentFromItem(player, item, groupID)
end)

--- Attach an attachment item (by inventory key) to a weapon item (by inventory key).
--- Handles slot conflicts by returning any displaced attachment to the player's inventory.
--- If the weapon is currently held, the attachment is also physically applied.
--- @param player Player
--- @param attachmentKey number Inventory key of the attachment item
--- @param weaponKey number Inventory key of the weapon item
function PLUGIN.attachAttachmentToInventoryItem(player, attachmentKey, weaponKey)
  local attachItem = versus.inventory.getItem(player, attachmentKey)
  local weaponItem = versus.inventory.getItem(player, weaponKey)

  if not attachItem or not weaponItem then
    ErrorNoHalt("[Versus/CW2] attachToInventoryWeapon: invalid item keys from " .. tostring(player) .. "\n")
    return
  end

  if not (attachItem.isAttachment and attachItem.attachmentID) then
    ErrorNoHalt("[Versus/CW2] attachToInventoryWeapon: item is not an attachment\n")
    return
  end

  if not weaponItem.weaponClass then
    ErrorNoHalt("[Versus/CW2] attachToInventoryWeapon: target item is not a weapon\n")
    return
  end

  local weaponReg = weapons.Get(weaponItem.weaponClass)

  if not weaponReg or not weaponReg.Attachments then
    ErrorNoHalt("[Versus/CW2] attachToInventoryWeapon: weapon has no attachment slots\n")
    return
  end

  -- Find the group and position in the weapon that accepts this attachment.
  local targetGroupID, targetPos

  for groupID, group in pairs(weaponReg.Attachments) do
    for pos, attID in pairs(group.atts) do
      if attID == attachItem.attachmentID then
        targetGroupID = groupID
        targetPos = pos
        break
      end
    end

    if targetGroupID then break end
  end

  if not targetGroupID then
    versus.message.notify(player, "This attachment is not compatible with that weapon.", NOTIFY_ERROR)
    return
  end

  -- Return any attachment currently occupying this slot to the player's inventory.
  if weaponItem.attachments and weaponItem.attachments[targetGroupID] then
    PLUGIN.detachAttachmentFromItem(player, weaponItem, targetGroupID)
  end

  -- Consume the attachment from the player's inventory.
  versus.inventory.takeItem(player, attachItem)

  -- Record the attachment on the weapon item so it is re-applied on equip.
  weaponItem.attachments = weaponItem.attachments or {}
  weaponItem.attachments[targetGroupID] = targetPos
  versus.inventory.networkItemOverrides(player, weaponItem, "attachments")

  -- If the weapon is currently held, apply the attachment physically right away.
  local heldWeapon = player:GetWeapon(weaponItem.weaponClass)

  if IsValid(heldWeapon) then
    timer.Simple(0, function()
      if IsValid(heldWeapon) then
        heldWeapon:_attach(targetGroupID, targetPos)
      end
    end)
  end
end

net.Receive("versus.chucksWeaponry.attachToInventoryWeapon", function(length, player)
  local attachmentKey = net.ReadUInt(versus.inventory.bitSizeItemKeys)
  local weaponKey = net.ReadUInt(versus.inventory.bitSizeItemKeys)

  PLUGIN.attachAttachmentToInventoryItem(player, attachmentKey, weaponKey)
end)
