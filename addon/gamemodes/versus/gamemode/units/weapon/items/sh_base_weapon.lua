local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Weapon Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_weapon"
ITEM.isWeapon = true
ITEM.category = "Weapons"
ITEM.size = 1

-- Default slot. Individual weapon items should override this (e.g. "melee", "secondary", etc.)
ITEM.equipSlot = "primary"

ITEM.model = "models/weapons/w_rif_ak47.mdl"
ITEM.skin = 0

ITEM.description = "A reliable weapon for combat situations."

function ITEM:onEquip(player)
  versus.weapon.equipWeaponItem(player, self)
end

function ITEM:onUnequip(player)
  local weapon = player:GetWeapon(self.weaponClass)

  if (IsValid(weapon)) then
    versus.weapon.holsterWeaponItem(player, weapon)
  end
end

function ITEM:onUse(player)
  if (player:HasWeapon(self.weaponClass)) then
    versus.message.notify(player, "You already have a weapon like this equipped!", NOTIFY_ERROR)
    return false
  end

  versus.equipment.equipItem(player, self)
end

function ITEM:onDrop(player, position)
  if (versus.equipment.getEquippedItem(player, self.equipSlot) == self) then
    versus.equipment.unequipItem(player, self.equipSlot, false)
  end
end

function ITEM:getPacData(player, entity)
  local model = self.model
  local skin = self.skin or 0
  local angles = Angle(0, 171.61497497559, 120.91650390625)
  local position = Vector(-13.103469848633, -8.0999450683594, -3)
  local bone = "spine 4"
  local size = 1

  if (self.equipSlot == "secondary") then
    angles = Angle(0.31408932805061, 34.682437896729, 87.08406829834)
    position = Vector(-1.1979808807373, 3.0851440429688, -3.2235870361328)
    bone = "right thigh"

    if not entity:GetModel():find("female") then
      local right = angles:Right()
      position = position + (right * 1.5)
    end
  elseif (self.equipSlot == "melee") then
    size = 0.8
    angles = Angle(3.3501310348511, -6.4628057479858, 36.53511428833)
    position = Vector(-6.3181228637695, -1.9189147949219, 5.6197128295898)
    bone = "spine 4"
  end

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Model"] = model,
            ["Bone"] = bone,
            ["Skin"] = skin,
            ["Angles"] = angles,
            ["Position"] = position,
            ["Size"] = size,
            ["UniqueID"] = "dbee57452b0cd12b0f3b7e4b69e7e31ebab236ea88e5f30e28ce45ae7a099f96",
            ["NoLighting"] = false,
            ["AimPartName"] = "",
            ["IgnoreZ"] = false,
            ["AimPartUID"] = "",
            ["Notes"] = "",
            ["Materials"] = "",
            ["Name"] = "",
            ["LevelOfDetail"] = 0,
            ["NoTextureFiltering"] = false,
            ["PositionOffset"] = Vector(0, 0, 0),
            ["IsDisturbing"] = false,
            ["EyeAngles"] = false,
            ["DrawOrder"] = 0,
            ["TargetEntityUID"] = "",
            ["Alpha"] = 1,
            ["Material"] = "",
            ["Invert"] = false,
            ["ForceObjUrl"] = false,
            ["Color"] = Vector(1, 1, 1),
            ["AngleOffset"] = Angle(0, 0, 0),
            ["BoneMerge"] = false,
            ["ClassName"] = "model2",
            ["NoCulling"] = false,
            ["Hide"] = false,
            ["Brightness"] = 1,
            ["Scale"] = Vector(1, 1, 1),
            ["LegacyTransform"] = false,
            ["EditorExpand"] = false,
            ["Translucent"] = false,
            ["BlendMode"] = "",
            ["ModelModifiers"] = "",
            ["EyeTargetUID"] = "",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "04b605de8a0cafb142a3449fdb7cd33497db7336595e0d8f0c41d4775e220460",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "secondary weapon",
        ["TargetEntityUID"] = "",
        ["EditorExpand"] = true,
        ["OwnerName"] = "self",
        ["Duplicate"] = false,
        ["IsDisturbing"] = false,
        ["ClassName"] = "group",
      },
    },
  }
end
