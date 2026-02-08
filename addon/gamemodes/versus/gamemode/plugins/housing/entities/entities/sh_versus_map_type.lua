local PLUGIN = PLUGIN
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Versus Map Type"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.ValidMapTypes = {
  -- This order matches .fgd options order:
  "combat",  -- 0
  "hideout", -- 1
}

if not SERVER then
  return
end

function ENT:KeyValue(key, value)
  key = key:lower()

  if (key == "maptype") then
    value = self.ValidMapTypes[tonumber(value) + 1] or value -- Convert from .fgd 0-based index to value

    if (not value) then
      error("Invalid map type index: " .. tostring(value))
      return
    end

    self:SetMapType(value)
  end
end

function ENT:Initialize()
  self:SetModel("models/props_junk/PopCan01a.mdl")
  self:SetSolid(SOLID_NONE)
  self:SetMoveType(MOVETYPE_NONE)

  self:SetNoDraw(true)
  self:DrawShadow(false)
end

function ENT:SetMapType(mapType)
  mapType = mapType:lower()

  if (not table.HasValue(self.ValidMapTypes, mapType)) then
    error("Invalid map type: " .. tostring(mapType))
    return
  end

  self._VersusMapType = mapType

  SetGlobalBool("VersusHideoutMap", mapType == "hideout")
end

function ENT:GetMapType()
  return self._VersusMapType
end
