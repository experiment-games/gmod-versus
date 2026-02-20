local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "First Responders Backpack"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.sizeEquipped = -25
ITEM.cost = 4000
ITEM.equipSlot = "backpack"
ITEM.model = "models/vex/fallout76/backpacks/atx_backpack_firstresponders.mdl"
ITEM.description =
"A backpack that is perfect for first responders. It has a lot of pockets and compartments for storing medical supplies and other emergency equipment."

function ITEM:onUse(player)
  versus.equipment.setEquippedItem(player, self)
end

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 1
  local angles = Angle(-18.202383041382, -93.540893554688, -87.205024719238)
  local position = Vector(-3.3361206054688, -4.9990081787109, 1.2652587890625)

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
            ["Model"] = "models/vex/fallout76/backpacks/atx_backpack_firstresponders.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "55749521794acc8273546ac795ba711dfab0cf57fa850586e32a220244549c6d",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "first responders backpack",
        ["TargetEntityUID"] = "",
        ["EditorExpand"] = true,
        ["OwnerName"] = "self",
        ["Duplicate"] = false,
        ["IsDisturbing"] = false,
        ["ModelTracker"] = "models/player/group03/male_04.mdl",
        ["ClassTracker"] = "player",
        ["ClassName"] = "group",
      },
    },
  }
end
