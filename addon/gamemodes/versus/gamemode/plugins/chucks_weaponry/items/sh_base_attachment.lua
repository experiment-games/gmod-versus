local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.name = "Attachment Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_attachment"
ITEM.isAttachment = true
ITEM.category = "Weapon Attachments"
ITEM.size = 0.1
ITEM.model = "models/cw2/attachments/microt1.mdl"
ITEM.description = "Used to modify your weapons. Attach it to a compatible weapon to gain its benefits."
ITEM.actionTexts = {
  ["Use"] = "Attach",
}

function ITEM:onDrop(player, position) end

function ITEM:onUse(player)
  local activeWeapon = player:GetActiveWeapon()

  if (not activeWeapon or not activeWeapon.Attachments or not activeWeapon._VersusItem) then
    versus.message.notify(player, "You must be holding a weapon that can accept attachments to use this.", NOTIFY_ERROR)
    return false
  end

  local attachments = activeWeapon.Attachments
  local attachmentID = self.attachmentID

  for groupID, attachmentGroup in pairs(attachments) do
    for attachmentPos, attachment in pairs(attachmentGroup.atts) do
      if (attachment == attachmentID) then
        -- activeWeapon:attach(groupID, attachmentPos)
        self:attachToWeapon(player, activeWeapon, groupID, attachmentPos)
        return true
      end
    end
  end

  versus.message.notify(player, "This attachment is not compatible with the weapon you're holding.", NOTIFY_ERROR)
  return false
end

function ITEM:attachToWeapon(player, weapon, groupID, attachmentPos)
  weapon._VersusItem.attachments = weapon._VersusItem.attachments or {}

  PLUGIN.detachAttachmentFromWeapon(player, weapon, groupID, false)

  -- Save it on the item, so it can be re-applied when the weapon is equipped.
  weapon._VersusItem.attachments[groupID] = attachmentPos

  weapon:_attach(groupID, attachmentPos)

  versus.inventory.networkItemOverrides(player, weapon._VersusItem, "attachments")
end
