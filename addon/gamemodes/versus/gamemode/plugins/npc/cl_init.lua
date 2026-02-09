local PLUGIN = PLUGIN

-- Fade out bodies after death and remove them after a certain time to prevent clutter and lag
function PLUGIN.hook:CreateClientsideRagdoll(entity, ragdoll)
  versus.util.decayEntity(ragdoll, 5)
end

--[[
  Net Messages
--]]

net.Receive("versus.npc.openNPCMenu", function(len, player)
  local menuClass = net.ReadString()
  local argCount = net.ReadUInt(3)
  local args = {}

  for i = 1, argCount do
    table.insert(args, net.ReadType())
  end

  if (hook.Run("OnNPCMenuOpen", player, menuClass, unpack(args)) ~= nil) then
    return
  end

  local menu = vgui.Create(menuClass)

  if (IsValid(menu)) then
    menu:Populate(unpack(args))
    menu:MakePopup()
  else
    print("Failed to create NPC menu: " .. menuClass)
  end
end)
