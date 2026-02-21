local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Kevlar"
ITEM.category = "Armor"
ITEM.size = 2
ITEM.cost = 450
ITEM.seller = { "armoury" }
ITEM.model = "models/kevlarvest/kevlarvest.mdl"
ITEM.description = "Reduces damage the player receives by 50%."
ITEM.equipSlot = "armor"
ITEM.dropModel = "models/props_c17/suitcase_passenger_physics.mdl"

ITEM.inventoryFov = 30

-- Which hitgroups this item provides protection for.
ITEM.hitGroups = {
  [HITGROUP_CHEST] = true,
  [HITGROUP_GEAR] = true,
  [HITGROUP_STOMACH] = true,
}

-- How much the item reduces incoming damage by (0.5 means 50% damage reduction).
ITEM.damageScale = 0.4

-- How much damage the item can take before it breaks.
ITEM.health = 100

function ITEM:onDrop(player, position) end

-- Draw a little health bar above the name
function ITEM:onPaintOver(panel, width, height)
  local healthFraction = self.health / 100
  local barWidth = width * 0.6
  local barHeight = 5
  local barX = (width - barWidth) / 2
  local barY = panel.nameTextY - barHeight - 2

  -- Background of the health bar (dark red)
  surface.SetDrawColor(100, 0, 0, 150)
  surface.DrawRect(barX, barY, barWidth, barHeight)

  -- Foreground of the health bar (bright red)
  surface.SetDrawColor(255, 0, 0, 200)
  surface.DrawRect(barX, barY, barWidth * healthFraction, barHeight)
end

function ITEM:getPacData(player, entity)
  local size = 0.9
  local angles = Angle(-6.814248085022, -1.092275033443e-05, 3.2244284398075e-07)
  local position = Vector(5.541015625, 0.00146484375, -59.982360839844)
  local up = angles:Up()
  local forward = angles:Forward()

  -- Male needs a bit of an adjustment to fit properly, otherwise its too small
  if not entity:GetModel():find("female") then
    position = position - (up * 3)
    position = position + (forward * 1)
    size = 1.05
  else
    position = position + (up * 5)
    position = position - (forward * 1)
  end

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = 0,
            ["UniqueID"] = "6dd68a71db06d9b40ad9f76a72a6abded05c0a9f011f219fbe0a719c36317a3c",
            ["NoLighting"] = false,
            ["AimPartName"] = "",
            ["IgnoreZ"] = false,
            ["AimPartUID"] = "",
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
            ["Bone"] = "chest",
            ["Size"] = size,
            ["Angles"] = angles,
            ["Position"] = position,
            ["AngleOffset"] = Angle(0, 0, 0),
            ["BoneMerge"] = false,
            ["Color"] = Vector(1, 1, 1),
            ["ClassName"] = "model2",
            ["Brightness"] = 1,
            ["Hide"] = false,
            ["NoCulling"] = false,
            ["Scale"] = Vector(0.89999997615814, 0.89999997615814, 1),
            ["LegacyTransform"] = false,
            ["EditorExpand"] = false,
            ["ModelModifiers"] = "",
            ["Translucent"] = false,
            ["BlendMode"] = "",
            ["EyeTargetUID"] = "",
            ["Model"] = "models/kevlarvest/kevlarvest.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "6f0eac11464a427917765885d240b797877cde83f2430bba9f2861cdf2450084",
        ["Hide"] = false,
        ["TargetEntityUID"] = "",
        ["EditorExpand"] = true,
        ["OwnerName"] = "self",
        ["IsDisturbing"] = false,
        ["Name"] = "kevlar",
        ["Duplicate"] = false,
        ["ClassName"] = "group",
      },
    },
  }
end
