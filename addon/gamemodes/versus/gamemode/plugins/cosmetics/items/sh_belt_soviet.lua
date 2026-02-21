local PLUGN = PLUGN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Old Soviet Belt"
ITEM.category = "Clothing (Belt)"
ITEM.size = 0
ITEM.cost = 1000
ITEM.equipSlot = "belt"
ITEM.model = "models/s_belt.mdl"
ITEM.description =
"A worn-out belt that was once part of a Soviet uniform. The symbol has been torn off, but you can still make out the star."

ITEM.inventoryFov = 50

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 1.1

  if entity:GetModel():find("female") then
    size = 1.05
  end

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "afecfd99e5c7bacf122b515f2d80b0f1c82b0648704b5b3318183dc1a904d316",
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
            ["Bone"] = "pelvis",
            ["Color"] = Vector(1, 1, 1),
            ["AngleOffset"] = Angle(0, 0, 0),
            ["BoneMerge"] = false,
            ["Angles"] = Angle(-81.268508911133, 56.382221221924, -147.55062866211),
            ["Position"] = Vector(0.82205963134766, -1.4420175552368, 0.4547119140625),
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
            ["Model"] = "models/s_belt.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "f5bdc64f55dcacde3f7118ad75c23dddd142a2cdabe8d6aecb7132b9e6c32450",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "old soviet belt",
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
