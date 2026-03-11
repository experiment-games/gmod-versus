local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Derby Hat"
ITEM.category = "Clothing (Hat)"
ITEM.size = 0
ITEM.cost = 4000
ITEM.equipSlot = "hat"
ITEM.model = "models/blackterios_props/cosmetics/hat13.mdl"
ITEM.description = "For when you want to look fancy and like you know how to ride a horse, even if you don't."
ITEM.hidden = true

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 1
  local angles = Angle(4.1440000534058, -39.20299911499, -85.158996582031)
  local position = Vector(4.7230000495911, 0.63499999046326, 0.078000001609325)

  if entity:GetModel():find("female") then
    local up = angles:Up()
    position = position - (up * 2)
  end

  local forward = angles:Forward()
  position = position - (forward * 0.55)

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "5387fbf12c5a8b9b0073060f28b4942953400be03920a10428126e5395e255bd",
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
            ["Model"] = "models/blackterios_props/cosmetics/hat13.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "31d689271cccd479b35b0a8696a6e955c4ef51a761c21bd8c907cab2d660fa50",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "derby hat",
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
