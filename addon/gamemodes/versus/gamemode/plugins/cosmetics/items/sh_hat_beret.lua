local PLUGN = PLUGN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Beret"
ITEM.category = "Clothing (Hat)"
ITEM.size = 0
ITEM.cost = 4000
ITEM.equipSlot = "hat"
ITEM.model = "models/pac_beret.mdl"
ITEM.description =
"This beret is a symbol of pride and style. It adds a touch of sophistication to any outfit, making you look effortlessly cool."
ITEM.lootWeight = 2 / 100

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 1
  local angles = Angle(3.2721126079559, -72.477836608887, -96.075576782227)
  local position = Vector(5.4790000915527, -0.06280517578125, 0.44804382324219)

  if entity:GetModel():find("female") then
    local up = angles:Up()
    position = position - (up * 1)
  end

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "bbc70d2437cc777b810ca388ebb41aabe19e72ad6e79d4adb72a4b9bcee5f495",
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
            ["Model"] = "models/pac_beret.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "fdc72918d36eaeb50036ed9fcac7972039af9d93724390ab1b87e78608cbc80f",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "beret",
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
