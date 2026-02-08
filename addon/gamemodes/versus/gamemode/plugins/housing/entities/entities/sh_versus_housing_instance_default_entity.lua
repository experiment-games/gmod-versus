--[[

@PointClass base(Targetname, Angles) studio() = versus_housing_instance_default_entity :
    "Designates the default spawn position for an entity that comes with the housing instance. Players can move this and it will save the new position. This is used for things like chests that come with the housing instance."
[
    instanceid(string) : "Instance ID" : "" : "Unique identifier for the instance this entity belongs to. This should match the instanceid of a versus_housing_instance_target entity."
    entityclass(string) : "Entity Class" : "" : "The class of the entity. This is used to determine what type of entity this is, so we can apply the correct behavior to it. For example, if it's a chest, we want to make it so players can open it and store items in it."
    model(studio) : "World Model" : "" : "The model of the entity. This is used to determine the appearance of the entity. For example, if it's a chest, we want it to look like a chest."
]
]]
local PLUGIN = PLUGIN
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Housing Default Entity"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminOnly = true

-- This is a server-side only entity, which will be looked up when the housing instance is loaded and entities need to be spawned.
if (not SERVER) then
  return
end

AccessorFunc(ENT, "InstanceID", "InstanceID", FORCE_STRING)
AccessorFunc(ENT, "EntityClass", "EntityClass", FORCE_STRING)
AccessorFunc(ENT, "EntityModel", "EntityModel", FORCE_STRING)

function ENT:Initialize()
  self:SetModel("models/props_c17/oildrum001.mdl")
  self:SetSolid(SOLID_NONE)
  self:SetMoveType(MOVETYPE_NONE)

  self:SetNoDraw(true)
  self:DrawShadow(false)
end

function ENT:KeyValue(key, value)
  key = key:lower()

  if (key == "instanceid") then
    self:SetInstanceID(value)
  elseif (key == "entityclass") then
    self:SetEntityClass(value)
  elseif (key == "model") then
    self:SetEntityModel(value)
  end
end
