ENT.Models = {
  {
    model = "models/props/cs_assault/money.mdl",
    maxAmount = 10000,
    label = "some loose money",
  },
  {
    model = "models/props_c17/briefcase001a.mdl",
    maxAmount = 100000,
    label = "a briefcase of money",
  },
  {
    model = "models/props/cs_assault/moneypallet03c.mdl",
    maxAmount = 10000000,
    label = "a pallet of money",
  }
}

-- This is called when the entity initializes.
function ENT:Initialize()
  self:SetMoveType(MOVETYPE_VPHYSICS)
  self:PhysicsInit(SOLID_VPHYSICS)
  self:SetSolid(SOLID_VPHYSICS)
  self:SetUseType(SIMPLE_USE)

  -- Get the physics object of the entity.
  local physicsObject = self:GetPhysicsObject()

  -- Check if the physics object is a valid entity.
  if (IsValid(physicsObject)) then
    physicsObject:Wake()
    physicsObject:EnableMotion(true)
  end
end

--- Gets a fitting model for the amount of money.
--- @param amount number The amount of money.
--- @return string # The model path.
--- @return string # The label for the model.
function ENT:GetFittingModelInfo(amount)
  for _, data in ipairs(self.Models) do
    if (amount <= data.maxAmount) then
      return data.model, data.label
    end
  end

  local lastModel = self.Models[#self.Models]

  return lastModel.model, lastModel.label
end

function ENT:SetAmount(amount)
  self._Amount = amount

  -- Set the networked variables so the client can get the information.
  self:SetNWInt("versus_Amount", self._Amount)

  local model, label = self:GetFittingModelInfo(amount)
  self._Label = label
  self:SetModel(model)
  self:Activate()
end

-- Called when the entity is used.
function ENT:Use(activator, caller)
  if (activator:IsPlayer()) then
    versus.finance.giveMoney(activator, self._Amount, "Picked up " .. tostring(self._Label))

    self:Remove()
  end
end
