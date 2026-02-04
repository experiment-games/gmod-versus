local UNIT = UNIT
local g_Player = player

-- Called every server tick.
function UNIT.hook:Tick()
  local curTime = CurTime()
  local pastNextSecond = curTime >= UNIT.playerNextSecond
  local pastNextTenthSecond = curTime >= UNIT.playerNextTenthSecond

  for _, player in ipairs(g_Player.GetAll()) do
    if (player:getVersusID() > -1) then
      if (pastNextSecond) then
        hook.Run("PlayerSecond", player)
      end

      if (pastNextTenthSecond) then
        hook.Run("PlayerTenthSecond", player)
      end
    end
  end

  if (pastNextSecond) then
    UNIT.playerNextSecond = curTime + 1
  end

  if (pastNextTenthSecond) then
    UNIT.playerNextTenthSecond = curTime + 0.1
  end
end

-- Called when the main menu tabs can be built
function UNIT.hook:BuildMainMenuTabs(tabs)
  tabs:addTab(UNIT.characterTabLabel, vgui.Create("versus_Character"), "icon16/user.png", 1)
end

function UNIT.hook:LocalPlayerReceivedVariable(key, value, oldValue)
  if (key == "appearanceModel" and value ~= oldValue) then
    versus.inventory.updatePanel = true
  end
end

-- Called after all the entities are initialized.
function UNIT.hook:InitPostEntity()
  -- We only start loading from here because when this hook is called on
  -- the client, net messages will reliably be received.
  net.Start("versus.player.ready")
  net.SendToServer()
end

-- Give the player a first-person view of their corpse
function UNIT.hook:CalcView(player, origin, angles, fov)
  local ragdoll = player:GetRagdollEntity()

  if (not IsValid(ragdoll)) then
    return
  end

  local eyes = ragdoll:GetAttachment(ragdoll:LookupAttachment("eyes"))

  if (not eyes) then
    return
  end

  return {
    origin = eyes.Pos,
    angles = eyes.Ang,
    fov = 90
  }
end

-- (Predicted hook) Only allow administrators to NoClip
-- Serverside other paramters are also checked, but they aren't known to
-- the client.
function UNIT.hook:PlayerNoClip(player, desiredState)
  return player:IsAdmin()
end

-- Called when a player presses a bind.
function UNIT.hook:PlayerBindPress(player, bind, press)
  -- -- Check if they're trying to use a binded versus command.
  -- if(string.find(bind, "versus ", nil, false) or string.find(bind, "say /", nil, false))then
  -- if(not player:GetNWBool("versus_Donator"))then
  -- player:ChatPrint("Only Donators can use binded Versus commands!")

  -- return true
  -- end
  -- end
end

-- Called when an entity is created.
function UNIT.hook:OnEntityCreated(entity)
  if (LocalPlayer() == entity) then
    for key, value in pairs(GAMEMODE.variableQueue) do
      local oldValue = LocalPlayer()[key]

      LocalPlayer()[key] = value

      hook.Run("LocalPlayerReceivedVariable", key, value, oldValue)
    end
  end
end

function UNIT.hook:CanPopulateEntityInfo(entity)
  if (entity:IsPlayer() and entity:GetNWBool("versus_KnockedOut")) then
    return
  end

  if (not entity:IsPlayer()) then
    entity = entity:GetNWEntity("versus_Player")
  end

  if (IsValid(entity) and entity ~= LocalPlayer() and entity:IsPlayer()) then
    return true
  end
end

function UNIT.hook:OnPopulateEntityInfo(entity, info)
  local player = entity

  if (not player:IsPlayer()) then
    player = entity:GetNWEntity("versus_Player")
  end

  if (not IsValid(player)) then
    return
  end

  local teamColor = team.GetColor(player:Team())
  local infoList = setmetatable({}, FindMetaTable("VersusOrderedList")):init()

  infoList:add(1, {
    value = player:getCombinedName(),
    color = teamColor,
  })

  info:setColor(teamColor)

  hook.Run("HUDBuildTargetIDInformation", infoList, entity, info)

  for _, infoData in pairs(infoList:getSorted()) do
    local displayText = infoData.label and (infoData.label .. ": " .. infoData.value) or infoData.value
    info:addRow(displayText, infoData.color)
  end
end

net.Receive("versus.finance.changeMoney", function(len)
  local isReceiving = net.ReadBool()
  local amount = net.ReadUInt(32)
  local reason = net.ReadString()
  local currentMoney = net.ReadUInt(32)
  local changedAt = net.ReadFloat()
  local text = string.format("%s %s (%s)", isReceiving and "Gained" or "Lost",
    versus.util.formatMoney(amount), reason)

  if (isReceiving) then
    versus.message.notifyMessageAdd(text, NOTIFY_MONEY_GAINED)
  else
    versus.message.notifyMessageAdd(text, NOTIFY_MONEY_LOST)
  end

  if (not LocalPlayer()._LastMoneyChange or changedAt > LocalPlayer()._LastMoneyChange) then
    LocalPlayer()._LastMoneyChange = changedAt
    LocalPlayer().money = currentMoney
  end
end)

net.Receive("versus.player.initializeAppearance", function(len)
  local player = LocalPlayer()

  player.appearanceModel = net.ReadString()

  for i = 1, table.Count(versus.player.getDefaultBodygroupOptions()) do
    local bodygroupData = string.Explode(":", net.ReadString())

    player["appearanceBodygroup_" .. (bodygroupData[1])] = tonumber(bodygroupData[2])
  end

  if (player.appearanceModel ~= "") then
    net.Start("versus.player.initializedAppearance")
    net.WriteBool(true)
    net.SendToServer()
    return
  end

  local panel = vgui.Create("versus_Menu_Standalone")
  panel:BuildTabs(function(tabBuilder)
    UNIT.hook:BuildMainMenuTabs(tabBuilder)
  end)
  panel:ParentToHUD()
  panel:MakePopup()
end)

-- Hook into when the player has initialized.
net.Receive("versus.player.initialized", function(len)
  GAMEMODE.playerInitialized = true

  hook.Run("LocalPlayerInitialized")
end)

-- Hook into when the server sends us a variable for the local player.
net.Receive("versus.player.setPlayerVariable", function(len)
  local class = net.ReadUInt(5)
  local key = net.ReadString()

  -- Create the variable which we'll store our received variable in.
  local value = nil

  -- Check if we can get what class of variable it is.
  if (class == NWTYPE_STRING) then
    value = net.ReadString()
  elseif (class == NWTYPE_LONG) then
    value = net.ReadInt(32)
  elseif (class == NWTYPE_ULONG) then
    value = net.ReadUInt(32)
  elseif (class == NWTYPE_SHORT) then
    value = net.ReadInt(16)
  elseif (class == NWTYPE_USHORT) then
    value = net.ReadUInt(16)
  elseif (class == NWTYPE_BOOL) then
    value = net.ReadBool()
  elseif (class == NWTYPE_VECTOR) then
    value = net.ReadVector()
  elseif (class == NWTYPE_ENTITY) then
    value = net.ReadEntity()
  elseif (class == NWTYPE_ANGLE) then
    value = net.ReadAngle()
  elseif (class == NWTYPE_CHAR) then
    value = string.char(net.ReadUInt(8))
  elseif (class == NWTYPE_BYTE) then
    value = net.ReadInt(8)
  elseif (class == NWTYPE_UBYTE) then
    value = net.ReadUInt(8)
  elseif (class == NWTYPE_FLOAT) then
    value = net.ReadFloat()
  else
    ErrorNoHaltWithStack("Invalid class: ", class)
  end

  if (IsValid(LocalPlayer())) then
    local oldValue = LocalPlayer()[key]

    LocalPlayer()[key] = value

    -- Set the variable queue variable to nil so that we don't overwrite it later on.
    GAMEMODE.variableQueue[key] = nil

    hook.Run("LocalPlayerReceivedVariable", key, value, oldValue)
  else
    GAMEMODE.variableQueue[key] = value
  end
end)
