local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "Santa Hat"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.cost = 4000
ITEM.equipSlot = "hat"
ITEM.model = "models/blackterios_props/cosmetics/hat4.mdl"
ITEM.description = "A festive hat that makes you look like Santa Claus."

ITEM.pacData = {
  [1] = {
    ["children"] = {
      [1] = {
        ["children"] = {
        },
        ["self"] = {
          ["Skin"] = 0,
          ["UniqueID"] = "00fda9dd71b2db808574d2944d2ec249e007ebe880a813670524355c630575d3",
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
          ["Bone"] = "head",
          ["Color"] = Vector(1, 1, 1),
          ["AngleOffset"] = Angle(0, 0, 0),
          ["BoneMerge"] = false,
          ["Angles"] = Angle(11.011713981628, -41.934158325195, -94.274719238281),
          ["Position"] = Vector(3.5509719848633, 0.32247924804688, -0.45124816894531),
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
          ["Model"] = "models/blackterios_props/cosmetics/hat4.mdl",
        },
      },
    },
    ["self"] = {
      ["DrawOrder"] = 0,
      ["UniqueID"] = "5fc22d7144e5c907f77587c47b33325d560612bf0ecb73590a15b3186e9f025b",
      ["Notes"] = "",
      ["Hide"] = false,
      ["Name"] = "santa hat",
      ["TargetEntityUID"] = "",
      ["EditorExpand"] = true,
      ["OwnerName"] = "self",
      ["Duplicate"] = false,
      ["IsDisturbing"] = false,
      ["ClassName"] = "group",
    },
  },
}

function ITEM:onUse(player)
  versus.equipment.setEquippedItem(player, self)
end

function ITEM:onDrop(player, position) end
