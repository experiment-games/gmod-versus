local PLUGIN = PLUGIN

util.AddNetworkString("versus.chucksWeaponry.detachAttachment")

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
