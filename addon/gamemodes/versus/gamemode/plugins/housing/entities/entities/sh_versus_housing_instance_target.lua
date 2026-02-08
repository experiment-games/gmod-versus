local PLUGIN = PLUGIN
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Housing Instance Target"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:SetupDataTables()
  self:NetworkVar("String", 0, "InstanceID")
  self:NetworkVar("String", 1, "TargetName")
  self:NetworkVar("Float", 0, "PriceScale")
end

if not SERVER then
  function ENT:Draw()
    if (GetConVar("developer"):GetInt() == 0) then
      return
    end

    self:DrawModel()
  end

  return
end

function ENT:UpdateTransmitState()
  return TRANSMIT_ALWAYS
end

function ENT:KeyValue(key, value)
  key = key:lower()

  if (key == "instanceid") then
    self:SetInstanceID(value)
  elseif (key == "targetname") then
    self:SetTargetName(value)
  elseif (key == "pricescale") then
    self:SetPriceScale(tonumber(value) or 1)
  end
end

function ENT:Initialize()
  self:SetModel("models/editor/playerstart.mdl")
  self:SetSolid(SOLID_NONE)
  self:SetMoveType(MOVETYPE_NONE)

  self:DrawShadow(false)
end
