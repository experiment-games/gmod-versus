local PLUGIN = PLUGIN

PLUGIN.name = "Item Editor"

versus.includePrefixed("cl_hooks.lua")

if (SERVER) then
  util.AddNetworkString("versus.plugin.item_editor.editName")

  net.Receive("versus.plugin.item_editor.editName", function(len, player)
    if (not player:IsSuperAdmin()) then
      return
    end

    local itemKey = net.ReadUInt(versus.inventory.bitSizeItemKeys)
    local newName = net.ReadString()

    local item = versus.inventory.getItem(player, itemKey)

    if (not item) then
      versus.message.notify(player, "Invalid item!", NOTIFY_ERROR)
      return
    end

    item.memberOverrides.name = newName

    versus.inventory.networkItemOverrides(player, item, "name")
  end)
end
