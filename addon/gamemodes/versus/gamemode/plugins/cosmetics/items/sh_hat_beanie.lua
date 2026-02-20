local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "Beanie"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.cost = 4000
ITEM.equipSlot = "hat"
ITEM.model = "models/pac_hat.mdl"
ITEM.description = "A dirty beanie that looks like it's been through a lot."

function ITEM:onUse(player)
  versus.equipment.setEquippedItem(player, self)
end

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  if entity:GetModel():find("female") then
    local size = 1
    local angles = Angle(10.430795669556, -59.201881408691, -91.589408874512)
    local position = Vector(3.5713806152344, -0.45101928710938, 0.23172760009766)

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
              ["Model"] = "models/pac_hat.mdl",
            },
          },
        },
        ["self"] = {
          ["DrawOrder"] = 0,
          ["UniqueID"] = "fdc72918d36eaeb50036ed9fcac7972039af9d93724390ab1b87e78608cbc80f",
          ["Notes"] = "",
          ["Hide"] = false,
          ["Name"] = "beanie",
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
            ["Angles"] = Angle(3.2721126079559, -72.477836608887, -93.956581115723),
            ["Position"] = Vector(4.9374046325684, -0.20614624023438, -0.016677856445313),
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
            ["Model"] = "models/pac_hat.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "fdc72918d36eaeb50036ed9fcac7972039af9d93724390ab1b87e78608cbc80f",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "beanie",
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
