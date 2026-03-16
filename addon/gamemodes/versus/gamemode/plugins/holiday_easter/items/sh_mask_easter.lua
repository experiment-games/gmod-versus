local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Easter Bunny Mask"
ITEM.category = "Clothing (Face)"
ITEM.size = 0
ITEM.cost = 10000
ITEM.equipSlot = "face"
ITEM.model = "models/touka mask/touka_mask.mdl"
ITEM.description = "A mask resembling a cute Easter Bunny. It has long ears and a cute face."
ITEM.inventoryFov = nil
ITEM.rarity = "epic"

function ITEM:getPacData(player, entity)
  local size = 1
  local angles = Angle(89.999992370605, 9.1774988174438, 0)
  local position = Vector(-0.62606811523438, -6.4463958740234, 0.0003662109375)
  local forward = angles:Right()
  local model = entity:GetModel()
  local up = angles:Up()

  position = position + up * -0.8

  if (model:find("female")) then
    position = position + forward * -0.5
  elseif (not (model:find("male_01") or model:find("male_06"))) then
    position = position + forward * -0.2
  end

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "f7047e314c5dd5a1ac78a5c1d53bcc355455feddeb76c03c2d5df8649968ea5f",
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
            ["Model"] = "models/touka mask/touka_mask.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "995e9fdc721590241ad8fc35081879a78bb2dec7d781f4b88d57085c0e62278b",
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
