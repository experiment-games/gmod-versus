local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "Military Backpack #1"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.sizeEquipped = -35
ITEM.cost = 9500
ITEM.equipSlot = "backpack"
ITEM.model = "models/vex/fallout76/backpacks/backpack_01.mdl"
ITEM.description = "A military backpack that is both functional and stylish."

function ITEM:onUse(player)
  versus.equipment.setEquippedItem(player, self)
end

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 1
  local angles = Angle(-3.5563669204712, -90.334625244141, -84.620628356934)
  local position = Vector(-4.5987548828125, -5.1813354492188, 0.43966674804688)

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "cff0865ae6fd1136881e481093c65dd340169e2fac422c9a0b22002023b2a780",
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
            ["Bone"] = "spine 4",
            ["Color"] = Vector(1, 1, 1),
            ["AngleOffset"] = Angle(0, 0, 0),
            ["BoneMerge"] = false,
            ["Angles"] = angles,
            ["Position"] = position,
            ["ClassName"] = "model2",
            ["NoCulling"] = false,
            ["Hide"] = false,
            ["Brightness"] = 1,
            ["Scale"] = Vector(1, 1, 1),
            ["LegacyTransform"] = false,
            ["EditorExpand"] = false,
            ["Size"] = size,
            ["Translucent"] = false,
            ["BlendMode"] = "",
            ["ModelModifiers"] = "",
            ["EyeTargetUID"] = "",
            ["Model"] = "models/vex/fallout76/backpacks/backpack_01.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "55749521794acc8273546ac795ba711dfab0cf57fa850586e32a220244549c6d",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "military backpack #1",
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
