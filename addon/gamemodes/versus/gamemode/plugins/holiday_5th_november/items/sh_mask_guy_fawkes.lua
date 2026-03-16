local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Guy Fawkes Mask"
ITEM.category = "Clothing (Face)"
ITEM.size = 0
ITEM.cost = 10000
ITEM.equipSlot = "face"
ITEM.model = "models/v/mask.mdl"
ITEM.description =
"A mask resembling Guy Fawkes, the infamous English conspirator. It has become a symbol of rebellion and protest, often associated with the phrase 'Remember, remember the 5th of November.'"
ITEM.inventoryFov = 6

function ITEM:getPacData(player, entity)
  local size = 1
  local angles = Angle(3.3317577617709e-05, -79.866523742676, -90)
  local position = Vector(-64.750198364258, -8.9876251220703, 0)
  local model = entity:GetModel():lower()
  local up = angles:Up()
  position = position + up * 0.2

  if model:find("female") then
    size = 0.98

    local up = angles:Up()
    position = position + up * 0.5
  elseif (model:find("male_01") or model:find("male_06")) then
    local forward = angles:Forward()
    position = position + forward * 0.5
  end

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "43c568dd516d37f8f1790fbf2a5bb4101eb0ef061bd9689458d6aee3ce4df7c3",
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
            ["Model"] = "models/v/mask.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "33bcbef9d37437cd96954bae55d9a45553b7e7e0033b3d341c81bdc4bd70f664",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "my outfit",
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
