local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "Gear Pouch (Left Thigh)"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.sizeEquipped = -2
ITEM.cost = 1000
ITEM.equipSlot = "gear_left_thigh"
ITEM.model = "models/pac_gearbag_06.mdl"
ITEM.description = "A tactical gear pouch that can be strapped to your left thigh for easy access to your equipment."

function ITEM:onUse(player)
  versus.equipment.equipItem(player, self)
end

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "0e75ce4a2a07fb1f206626ae5c0396d3b0fe6b875e54f42cfd8d465a19f5b1ce",
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
            ["Bone"] = "spine 1",
            ["Color"] = Vector(1, 1, 1),
            ["AngleOffset"] = Angle(0, 0, 0),
            ["BoneMerge"] = false,
            ["Angles"] = Angle(-42.564609527588, -90.847480773926, -88.205360412598),
            ["Position"] = Vector(-3.5435905456543, -2.2880554199219, 6.2336273193359),
            ["ClassName"] = "model2",
            ["NoCulling"] = false,
            ["Hide"] = false,
            ["Brightness"] = 1,
            ["Scale"] = Vector(1, 1, 1),
            ["LegacyTransform"] = false,
            ["EditorExpand"] = false,
            ["Size"] = 1,
            ["Translucent"] = false,
            ["BlendMode"] = "",
            ["ModelModifiers"] = "",
            ["EyeTargetUID"] = "",
            ["Model"] = "models/pac_gearbag_06.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "91a9bcb24028b196635763c35f0048f074de139d99193364a9cd5ac197ebe1bd",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "gear pouch",
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
