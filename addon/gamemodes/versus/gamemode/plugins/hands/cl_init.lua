local PLUGIN = PLUGIN

PLUGIN.name = "Bonemerge Hands Fix"
PLUGIN.description = "Will make sure hands look like the player model, by bonemerging."
PLUGIN.fakeHandsIndex = PLUGIN.fakeHandsIndex or -1

local translateFarAway = 123456

-- Check if we should hide bones. We will hide everything that is not visible from the eyes of the player.
local function shouldHideBone(hand, boneName, parentBoneName)
  local hiddenBonesList = {
    "Head",
    "Neck",
    "Clavicle",
    "Spine",
    "Shoulder",
    "Trapezius",
    "Thigh",
    "Calf",
    "Foot",
    "Toe0"
  }

  local invalidBone = not hand:LookupBone(boneName) and not hand:LookupBone(parentBoneName)

  for _, listedBoneName in ipairs(hiddenBonesList) do
    if (string.find(boneName, listedBoneName)) then
      return true
    end
  end

  return invalidBone
end

local function getClientHands(client)
  local playerModelName = player_manager.TranslateToPlayerModelName(client:GetModel())
  local playerHands = player_manager.TranslatePlayerHands(playerModelName)

  playerHands.isDefault = playerHands.model == "models/weapons/c_arms_citizen.mdl"
      or playerHands.model == "models/weapons/c_arms_refugee.mdl"

  return playerHands
end

local function setupFakeHandsHidingReal(hands, viewModel, player)
  player:SetupBones()

  hands.versusActiveBonemergedHandsIndex = PLUGIN.fakeHandsIndex

  local modifiedBones = {}

  if (IsValid(PLUGIN.handsModelOverlayClientsideModel)) then
    PLUGIN.handsModelOverlayClientsideModel:Remove()
  end

  for i = 0, player:GetBoneCount() - 1 do
    local boneName = player:GetBoneName(i)
    local parentBoneName = player:GetBoneName(player:GetBoneParent(i))

    if (shouldHideBone(hands, boneName, parentBoneName)) then
      modifiedBones[i] = true
    end
  end

  hands.versusHandsModifiedBones = modifiedBones

  local replacementHands = ClientsideModel(player:GetModel())

  if (not replacementHands) then
    return
  end

  PLUGIN.handsModelOverlayClientsideModel = replacementHands

  for _, bodygroupInfo in pairs(player:GetBodyGroups()) do
    local current = player:GetBodygroup(bodygroupInfo.id)
    replacementHands:SetBodygroup(bodygroupInfo.id, current)
  end

  for k, _ in ipairs(player:GetMaterials()) do
    replacementHands:SetSubMaterial(k - 1, player:GetSubMaterial(k - 1))
  end

  replacementHands:SetSkin(player:GetSkin())
  replacementHands:SetMaterial(player:GetMaterial())
  replacementHands:SetColor(player:GetColor())
  replacementHands.GetPlayerColor = function()
    return player:GetPlayerColor()
  end

  replacementHands:SetNoDraw(true)
  replacementHands:SetParent(viewModel)
  replacementHands:AddEffects(EF_BONEMERGE)
  replacementHands:AddEffects(EF_PARENT_ANIMATES)

  local buildBonePositions = function(fakeHands, bonesCount)
    for i = 0, bonesCount - 1 do
      local boneMatrix = fakeHands:GetBoneMatrix(i)

      if (not boneMatrix or not modifiedBones[i]) then
        continue
      end

      boneMatrix:Scale(Vector(0, 0, 0))
      boneMatrix:SetTranslation(boneMatrix:GetTranslation() - player:GetAimVector() * translateFarAway)

      fakeHands:SetBoneMatrix(i, boneMatrix)
    end
  end

  replacementHands:AddCallback("BuildBonePositions", buildBonePositions)
end

local function cleanupFakeHandsRestoringReal(hands, player)
  hands.versusActiveBonemergedHandsIndex = false

  local defaultHands = getClientHands(player)

  hands:SetModel(defaultHands.model)
  hands:SetSkin(defaultHands.skin)

  local modelHandsBodygroup = player:FindBodygroupByName("hands")
  local handsGlovesBodygroup = 1

  if (modelHandsBodygroup > -1) then
    local hasGloves = player:GetBodygroup(modelHandsBodygroup) > 0
    hands:SetBodygroup(handsGlovesBodygroup, hasGloves and 1 or 0)
  else
    hands:SetBodygroup(handsGlovesBodygroup, 0)
  end

  if IsValid(PLUGIN.handsModelOverlayClientsideModel) then
    PLUGIN.handsModelOverlayClientsideModel:Remove()
  end

  player.versusHandsInitialized = true
end

-- When the player model changes, we check if we get default hands. If we do, we enable the fake hands.
function PLUGIN:PlayerModelChanged(client, model, oldModel)
  if (not IsValid(client) or client ~= LocalPlayer()) then
    return
  end

  local playerHands = getClientHands(client)
  local modelFitsWithDefaultHands = model:lower():StartsWith("models/hl2rp/citizens/")
  client.versusHandsInitialized = false

  if (playerHands.isDefault and not modelFitsWithDefaultHands) then
    self.fakeHandsIndex = self.fakeHandsIndex + 1
    return
  end

  -- If the hands fit the model, disable the fake hands.
  self.fakeHandsIndex = -1
end

--[[
  Hooks
--]]

function PLUGIN.hook:PreDrawPlayerHands(hands, viewModel, client, weapon)
  if (not IsValid(hands)) then
    ErrorNoHaltWithStack(
      "Tracking whether this ever happens. If you see this tell the developer: YES IT DOES #001 - Thanks!"
    )
    return
  end

  local overrideDefaultHands = true

  if (not IsValid(viewModel)) then
    viewModel = hands
  end

  local enabled = self.fakeHandsIndex > -1
  local initializedIndex = hands.versusActiveBonemergedHandsIndex

  if (enabled and not initializedIndex) then
    setupFakeHandsHidingReal(hands, viewModel, client)
    return overrideDefaultHands
  end

  local handsAreOutdated = initializedIndex ~= self.fakeHandsIndex

  if (not client.versusHandsInitialized or (not enabled and initializedIndex) or (enabled and handsAreOutdated)) then
    cleanupFakeHandsRestoringReal(hands, client)
    return
  end

  if (not enabled) then
    return
  end

  self.handsModelOverlayClientsideModel:DrawModel()

  return overrideDefaultHands
end

-- When we load ensure we have the correct hands.
gameevent.Listen("player_spawn")
function PLUGIN.hook:player_spawn(data)
  local id = data.userid -- Same as Player:UserID()
  local player = Player(id)

  if (not IsValid(player)) then
    return
  end

  self:PlayerModelChanged(player, player:GetModel(), nil)
end

function PLUGIN.hook:Think()
  if (not IsValid(LocalPlayer())) then
    return
  end

  local model = LocalPlayer():GetModel()

  if (not LocalPlayer().versusLastModel or model ~= LocalPlayer().versusLastModel) then
    LocalPlayer().versusLastModel = model
    self:PlayerModelChanged(LocalPlayer(), model, nil)
  end
end

function PLUGIN.hook:PlayerBodyGroupChanged(player, index, value, oldValue)
  if (not IsValid(player)) then
    -- May happen if player changing bodygroup is outside of the local player's PVS.
    return
  end

  self:PlayerModelChanged(player, player:GetModel(), nil)
end

function PLUGIN.hook:PlayerBodyGroupsChanged(player, bodygroups, oldBodygroups)
  if (not IsValid(player)) then
    -- May happen if player changing bodygroup is outside of the local player's PVS.
    return
  end

  self:PlayerModelChanged(player, player:GetModel(), nil)
end
