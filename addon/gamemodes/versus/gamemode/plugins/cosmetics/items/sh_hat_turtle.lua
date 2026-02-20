local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "I <3 Turtles Hat"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.cost = 4000
ITEM.equipSlot = "hat"
ITEM.model = "models/props/de_tides/vending_hat.mdl"
ITEM.description = "Oh boy do you love turtles! Show off your passion for turtles with this stylish hat."

function ITEM:onUse(player)
  versus.equipment.setEquippedItem(player, self)
end

function ITEM:onDrop(player, position) end

function ITEM:getPacData(player)
  local size = 0.87

  -- Female playermodels have smaller heads, so scale down the hat slightly to fit better.
  if player:GetModel():find("female") then
    size = 0.8
  end

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
            ["Angles"] = Angle(-87.146606445313, 43.999717712402, 152.95086669922),
            ["Position"] = Vector(3.823, -0.968, 0.158),
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
            ["Model"] = "models/props/de_tides/vending_hat.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "31d689271cccd479b35b0a8696a6e955c4ef51a761c21bd8c907cab2d660fa50",
        ["Notes"] = "",
        ["Hide"] = false,
        ["Name"] = "turtle hat",
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
