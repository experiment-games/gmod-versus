local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.base = "base_equipment"
ITEM.name = "Base Badge"
ITEM.category = "Clothing (Badge)"
ITEM.size = 0
ITEM.equipSlot = "badge"
ITEM.model = "models/versus/badge/badge.mdl"
ITEM.description = "The base badge item. This is not meant to be obtained by players."
ITEM.inventoryFov = 0.5
ITEM.modelScale = 2

function ITEM:onDrop(player, position) end

-- Because the badge model for some reason won't draw in model panels, we just draw the skin material
function ITEM:onPaintOver(panel, w, h)
  if (self.skinMaterial) then
    local size = w * 0.4
    surface.SetMaterial(CreateMaterial(
      "VersusBadgeSkin_" .. self.skin,
      "UnlitGeneric",
      {
        ["$basetexture"] = self.skinMaterial,
        ["$translucent"] = 1,
      }
    ))
    surface.SetDrawColor(255, 255, 255)
    -- surface.DrawTexturedRect(
    --   w * 0.5 - size * .5,
    --   h * 0.5 - size * .5,
    --   size,
    --   size
    -- )
    GAMEMODE:DrawCircleUV(
      w * 0.5,
      h * 0.5,
      size * 0.5
    )
  end
end

function ITEM:getPacData(player, entity)
  local size = 1
  local angles = Angle(-0, 113.27877044678, -11.861691474915)
  local position = Vector(4.6684875488281, 4.066951751709, 0.20680272579193)
  local forward = angles:Right()
  local model = entity:GetModel()

  if (model:find("female")) then
    position = position + forward * -2.75
  else
    position = position + forward * -1.5
  end

  return {
    [1] = {
      ["children"] = {
        [1] = {
          ["children"] = {
          },
          ["self"] = {
            ["Skin"] = self.skin or 0,
            ["UniqueID"] = "3e257dce98ddde96b6640c8db82684bc64d56a38788b048d0c57d43fbdc47c0b",
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
            ["Bone"] = "chest",
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
            ["Model"] = "models/versus/badge/badge.mdl",
          },
        },
      },
      ["self"] = {
        ["DrawOrder"] = 0,
        ["UniqueID"] = "4efc2ed770385018ad2479651342fafee229014d3b02df7a167b1ede35fe71fc",
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
