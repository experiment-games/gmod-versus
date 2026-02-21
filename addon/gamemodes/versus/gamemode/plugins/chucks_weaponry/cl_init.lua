local PLUGIN = PLUGIN

local blurMaterial = Material("pp/blurscreen")

--- Returns true if the given attachment item can be attached to the given weapon item.
--- @param attachItem table Versus item instance with isAttachment = true
--- @param weaponItem table Versus item instance with weaponClass set
--- @return boolean
function PLUGIN.isAttachmentCompatibleWithWeapon(attachItem, weaponItem)
  if not (attachItem and attachItem.isAttachment and attachItem.attachmentID) then
    return false
  end

  if not (weaponItem and weaponItem.weaponClass) then
    return false
  end

  local weaponReg = weapons.Get(weaponItem.weaponClass)

  if not weaponReg or not weaponReg.Attachments then
    return false
  end

  for _, group in pairs(weaponReg.Attachments) do
    for _, attID in pairs(group.atts) do
      if attID == attachItem.attachmentID then
        return true
      end
    end
  end

  return false
end

function PLUGIN.hook:InitPostEntity()
  -- Drop zone: highlight any compatible weapon item panel in the inventory while
  -- dragging an attachment.  Drawn per-frame by the dragDrop DrawOverlay hook.
  versus.dragDrop.registerDropZone("cw_attach_to_weapon", {
    text      = "ATTACH",
    color     = Color(180, 120, 255, 255),
    condition = function(sessionId, drag)
      return sessionId == "inventory"
          and versus.menu.open
          and drag.item ~= nil
          and drag.item.isAttachment == true
    end,
    --- Walk up from the hovered panel to find a compatible versus_Inventory_Item.
    --- Returns its screen rect so the dragDrop system can draw the zone over it.
    getRect   = function(sessionId, drag)
      if not (versus.menu.open and drag.item and drag.item.isAttachment) then
        drag.attachTargetWeaponKey = nil
        return nil
      end

      local panel = vgui.GetHoveredPanel()

      while IsValid(panel) do
        if panel:GetName() == "versus_Inventory_Item"
            and panel.item
            and PLUGIN.isAttachmentCompatibleWithWeapon(drag.item, panel.item) then
          drag.attachTargetWeaponKey = panel.key
          local x, y = panel:LocalToScreen(0, 0)
          return x, y, panel:GetWide(), panel:GetTall()
        end

        panel = panel:GetParent()
      end

      drag.attachTargetWeaponKey = nil
      return nil
    end,
    onDropped = function(sessionId, drag, itemPanel)
      local weaponKey = drag.attachTargetWeaponKey
      if not weaponKey then
        return
      end

      net.Start("versus.chucksWeaponry.attachToInventoryWeapon")
      net.WriteUInt(itemPanel.key, versus.inventory.bitSizeItemKeys)
      net.WriteUInt(weaponKey, versus.inventory.bitSizeItemKeys)
      net.SendToServer()

      surface.PlaySound("physics/metal/weapon_footstep1.wav")
    end,
  })

  -- Drop zone: highlight any compatible *equipped* weapon item panel while
  -- dragging an attachment from the inventory.
  versus.dragDrop.registerDropZone("cw_attach_to_equipped_weapon", {
    text      = "ATTACH",
    color     = Color(180, 120, 255, 255),
    condition = function(sessionId, drag)
      return sessionId == "inventory"
          and versus.menu.open
          and drag.item ~= nil
          and drag.item.isAttachment == true
    end,
    --- Walk up from the hovered panel to find a compatible versus_Equipment_Item.
    --- Returns its screen rect so the dragDrop system can draw the zone over it.
    getRect   = function(sessionId, drag)
      if not (versus.menu.open and drag.item and drag.item.isAttachment) then
        drag.attachTargetEquippedSlot = nil
        return nil
      end

      local panel = vgui.GetHoveredPanel()

      while IsValid(panel) do
        if panel:GetName() == "versus_Equipment_Item"
            and panel.item
            and PLUGIN.isAttachmentCompatibleWithWeapon(drag.item, panel.item) then
          drag.attachTargetEquippedSlot = panel.slot
          local x, y = panel:LocalToScreen(0, 0)
          return x, y, panel:GetWide(), panel:GetTall()
        end

        panel = panel:GetParent()
      end

      drag.attachTargetEquippedSlot = nil
      return nil
    end,
    onDropped = function(sessionId, drag, itemPanel)
      local slot = drag.attachTargetEquippedSlot
      if not slot then return end

      net.Start("versus.chucksWeaponry.attachToEquippedWeapon")
      net.WriteUInt(itemPanel.key, versus.inventory.bitSizeItemKeys)
      net.WriteString(slot)
      net.SendToServer()

      surface.PlaySound("physics/metal/weapon_footstep1.wav")
    end,
  })
end

function PLUGIN.hook:RenderScreenspaceEffects()
  local ply = LocalPlayer()

  -- Intensity is accumulated each frame by cw_teargas_impact entity Thinks.
  -- Read the value here then immediately reset it so the next frame starts fresh.
  local intensity = ply._VersusTeargasIntensity or 0
  ply._VersusTeargasIntensity = 0

  if intensity <= 0 then
    return
  end

  -- Reduce the effect for players wearing gas-resistant gear (e.g. gasmask).
  -- The highest resistanceAgainstGas value across all equipped items is used.
  local gasResistance = 0
  local equippedItems = versus.equipment.getEquippedItems(ply)

  for _, item in pairs(equippedItems) do
    if item.resistanceAgainstGas and item.resistanceAgainstGas > gasResistance then
      gasResistance = item.resistanceAgainstGas
    end
  end

  intensity = intensity * (1 - gasResistance)

  if intensity <= 0 then
    return
  end

  -- Yellow-green color shift: simulates the eyes reacting to the irritant gas.
  -- Desaturates vision and adds a slight yellow tint.
  DrawColorModify({
    ["$pp_colour_addr"]       = intensity * 0.04,
    ["$pp_colour_addg"]       = intensity * 0.02,
    ["$pp_colour_addb"]       = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"]   = 1,
    ["$pp_colour_colour"]     = 1 - (intensity * 0.3),
    ["$pp_colour_mulr"]       = 0,
    ["$pp_colour_mulg"]       = 0,
    ["$pp_colour_mulb"]       = 0,
  })

  DrawMotionBlur(
    0.25 * intensity,
    0.7 * intensity,
    0.1 * intensity
  )

  -- Blur vision to simulate tearing eyes and involuntary blinking.
  render.UpdateScreenEffectTexture()
  blurMaterial:SetFloat("$blur", intensity * 5)
  render.SetMaterial(blurMaterial)
  render.DrawScreenQuad()
end

local DETACH_TEXT = "Detach Attachments"

local function countAttachments(item)
  if not item.attachments then
    return 0
  end

  local count = 0
  for _, groupID in pairs(item.attachments) do
    if groupID then
      count = count + 1
    end
  end

  return count
end

local function setupDetachItemFunctionOption(item, key, itemFunctions)
  if (countAttachments(item) > 0) then
    table.insert(itemFunctions, DETACH_TEXT)
  end
end

local function setupDetachItemFunction(item, keyOrSlot, menu, originalText, text, itemPanel)
  if (originalText ~= DETACH_TEXT) then
    return
  end

  if (countAttachments(item) == 0) then
    return
  end

  -- Builds a menu of all attachments currently on the weapon, so the player can choose which one to detach.
  local childMenu, option = menu:AddSubMenu(text)
  option:SetIcon("icon16/cross.png")

  local weaponRegistration = weapons.Get(item.weaponClass)

  -- Send a message to the server to detach
  for groupID, attachmentPos in pairs(item.attachments) do
    local group = weaponRegistration.Attachments[groupID]
    local attachmentID = group.atts[attachmentPos]
    local attachment = CustomizableWeaponry.registeredAttachmentsSKey[attachmentID]
    local name = string.format("%s (%s)", attachment.displayName, group.header)

    childMenu:AddOption(name, function()
      net.Start("versus.chucksWeaponry.detachAttachment")
      local isSlot = isstring(keyOrSlot)
      net.WriteBool(isSlot)
      if (isSlot) then
        net.WriteString(keyOrSlot)
      else
        net.WriteUInt(keyOrSlot, versus.inventory.bitSizeEquippedSlots)
      end
      net.WriteUInt(groupID, 8)
      net.SendToServer()
    end)
  end
end

local function paintOverAttachmentHint(panel, width, height)
  local item = panel.item
  local count = countAttachments(item)
  if not item or count == 0 then
    return
  end

  draw.SimpleText(
    string.format("(%d attachment%s)", count, count > 1 and "s" or ""),
    "VersusSmall",
    width * .5,
    panel.nameTextY + 2,
    Color(255, 255, 255, 100),
    TEXT_ALIGN_CENTER,
    TEXT_ALIGN_BOTTOM
  )
end

function PLUGIN.hook:PaintInventoryItemOver(panel, width, height)
  paintOverAttachmentHint(panel, width, height)
end

function PLUGIN.hook:PaintEquippedItemOver(panel, width, height)
  paintOverAttachmentHint(panel, width, height)
end

-- If the item has attachments, we add an option to detach them.
function PLUGIN.hook:BuildInventoryItemFunctions(item, key, itemFunctions)
  setupDetachItemFunctionOption(item, key, itemFunctions)
end

function PLUGIN.hook:BuildEquippedItemFunctions(item, key, itemFunctions)
  setupDetachItemFunctionOption(item, key, itemFunctions)
end

function PLUGIN.hook:BuildInventoryItemFunction(item, key, menu, originalText, text, itemPanel)
  setupDetachItemFunction(item, key, menu, originalText, text, itemPanel)
end

function PLUGIN.hook:BuildEquippedItemFunction(item, slot, menu, originalText, text, itemPanel)
  setupDetachItemFunction(item, slot, menu, originalText, text, itemPanel)
end

function PLUGIN.hook:EquipmentItemOverridesNetworked(item, instanceData)
  hook.Run("DoRefreshEquippedItemButtons")
end

-- Lists all weapons that can accept this attachment
function PLUGIN.hook:BuildItemTooltipRows(tooltip, item)
  if not item.isAttachment or not item.attachmentID then
    return
  end

  local compatibleWeapons = {}

  for _, wep in pairs(weapons.GetList()) do
    if wep.Attachments then
      for _, group in pairs(wep.Attachments) do
        for _, attID in pairs(group.atts) do
          if attID == item.attachmentID then
            table.insert(compatibleWeapons, wep.PrintName or wep.ClassName)
          end
        end
      end
    end
  end

  if #compatibleWeapons > 0 then
    local compatibleText = "Compatible with: " .. table.concat(compatibleWeapons, ", ")
    local row = tooltip:AddRow("compatibleWeapons")
    row:SetText(compatibleText)
    row:SetBackgroundColor(Color(50, 50, 50, 255))
    row:SizeToContents()
  end
end

-- Ensure the weapon scroll doesn't show when we have a weapon with telescopics
function PLUGIN.hook:ShouldShowWeaponSelection(ply, bind, pressed, code)
  if (bind ~= "invnext" and bind ~= "invprev") then
    return
  end

  local activeWeapon = ply:GetActiveWeapon()
  if IsValid(activeWeapon) and activeWeapon.CW20Weapon then
    if wep.dt then
      if wep.dt.State == CW_AIMING then
        -- TODO: Why is this flipped in CW2.0? Hacking it the way it makes sense for me.
        -- Scroll up is zoom in, scroll down is zoom out.
        activeWeapon.magnificationIncreaseButton = "invprev"
        activeWeapon.magnificationDecreaseButton = "invnext"

        return false
      end
    end
  end
end
