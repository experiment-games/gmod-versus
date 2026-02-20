local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "Ski Goggles"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.cost = 4000
ITEM.equipSlot = "glasses"
ITEM.model = "models/plet/huge_glasses_pack/ski_goggles.mdl"
ITEM.description = "These goggles will protect your eyes from the harshest of blizzards."

function ITEM:onUse(player)
  versus.equipment.setEquippedItem(player, self)
end

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player, entity)
  local size = 1.5
  local angles = Angle(0, 0, 0)
  local position = Vector(-3.6570129394531, -7.62939453125e-06, -1.2196338176727)

  if entity:GetModel():find("female") then
    size = 1.4
  end

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
            ["Model"] = "models/plet/huge_glasses_pack/ski_goggles.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "fcdedd30c310f18f60c9f7ba4fcb52666665ac8dd68e636a562f77a9cce7b785",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "ski goggles",
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
