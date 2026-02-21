local PLUGN = PLUGN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Flip-Up Glasses"
ITEM.category = "Clothing (Face)"
ITEM.size = 0
ITEM.cost = 2000
ITEM.equipSlot = "face"
ITEM.model = "models/plet/huge_glasses_pack/codiw_graves_v2_glasses.mdl"
ITEM.description = "These glasses have flip-up lenses that can be lifted to different lenses. Ultimate solar protection."

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 1.2
  local angles = Angle(0, 0, 0)
  local position = Vector(-2.88, 0, -1.0)

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "1bea74181f1318bec07e44ab452d8509e61399ccae2cd07cf39395853dae83bd",
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
            ["Bone"] = "eyes",
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
            ["Model"] = "models/plet/huge_glasses_pack/codiw_graves_v2_glasses.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "fcdedd30c310f18f60c9f7ba4fcb52666665ac8dd68e636a562f77a9cce7b785",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "flip-up glasses",
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
