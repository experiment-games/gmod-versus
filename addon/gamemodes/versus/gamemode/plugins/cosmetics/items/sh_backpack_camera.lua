local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "Camera Backpack"
ITEM.category = "Clothing (Backpack)"
ITEM.size = 0
ITEM.sizeEquipped = -25
ITEM.cost = 9000
ITEM.equipSlot = "backpack"
ITEM.model = "models/vex/fallout76/backpacks/score_s13_backpack_camera.mdl"
ITEM.description =
"A backpack with a non-functional camera attached to it. It doesn't actually do anything, but it looks cool."

function ITEM:onUse(player)
  versus.equipment.equipItem(player, self)
end

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 1
  local angles = Angle(-22.201805114746, -96.773933410645, -92.969947814941)
  local position = Vector(-6.3624420166016, -2.9090270996094, 4.4216156005859)

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
            ["Model"] = "models/vex/fallout76/backpacks/score_s13_backpack_camera.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "55749521794acc8273546ac795ba711dfab0cf57fa850586e32a220244549c6d",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "camera backpack",
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
