local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Helmet"
ITEM.category = "Clothing (Hat)"
ITEM.size = 0
ITEM.cost = 4000
ITEM.equipSlot = "hat"
ITEM.model = "models/pac_helmet_02.mdl"
ITEM.description = "A technical helmet to protect your cranium."

-- Which hitgroups this item provides protection for.
ITEM.hitGroups = {
  [HITGROUP_HEAD] = true,
}

-- How much the item reduces incoming damage by (0.5 means 50% damage reduction).
ITEM.damageScale = 0.5

-- How much damage the item can take before it breaks.
ITEM.maxHealth = 50
ITEM.health = ITEM.maxHealth

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 0.8
  local angles = Angle(-4.0949168205261, -86.952667236328, -88.617546081543)
  local position = Vector(3.0522766113281, -0.79864501953125, -0.25716972351074)

  -- Male needs a bit of an adjustment to fit properly, otherwise it clips into the head
  if not entity:GetModel():find("female") then
    local up = angles:Up()
    position = position + (up * 1)
    size = 0.9
  end

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "1e8763be5555ac8ddbc55b5860616197638e7aff59f8e94e3708946d244f88d1",
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
            ["Model"] = "models/pac_helmet_02.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "6079c58370c3f9bf8bb2e24d62d9f1733aaf1628e491168df06b9cac32dde0cd",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "helmet",
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
