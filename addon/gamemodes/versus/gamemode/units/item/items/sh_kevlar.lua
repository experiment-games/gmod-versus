local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Kevlar"
ITEM.category = "Armor"
ITEM.size = 2
ITEM.cost = 450
ITEM.seller = { "armoury" }
ITEM.model = "models/kevlarvest/kevlarvest.mdl"
ITEM.description = "Reduces damage the player receives by 50%."

ITEM.pacData = {
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
          ["Angles"] = Angle(-6.814248085022, -1.092275033443e-05, 3.2244284398075e-07),
          ["AngleOffset"] = Angle(0, 0, 0),
          ["BoneMerge"] = false,
          ["Color"] = Vector(1, 1, 1),
          ["Position"] = Vector(5.541015625, 0.00146484375, -59.982360839844),
          ["ClassName"] = "model2",
          ["Brightness"] = 1,
          ["Hide"] = false,
          ["NoCulling"] = false,
          ["Scale"] = Vector(0.89999997615814, 0.89999997615814, 1),
          ["LegacyTransform"] = false,
          ["EditorExpand"] = false,
          ["Size"] = 1,
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

-- TODO: Have kevlar be limited use
function ITEM:onUse(player)
  if (player._ScaleDamage == 0.5) then
    versus.message.notify(player, "You are already wearing Kevlar!", NOTIFY_ERROR)

    return false
  else
    -- TODO: Persist this across map changes, because the kevlar will
    player._ScaleDamage = 0.5
  end

  -- TODO: Call removeEquippedItem when the kevlar expires.
  versus.equipment.setEquippedItem(player, self.itemID)
end

function ITEM:onDrop(player, position) end
