local PLUGIN = PLUGIN

function PLUGIN.hook:PlayerShouldSelectContract(player)
  -- Don't allow contract selection if we're in a hideout map
  if (GetGlobalBool("VersusHideoutMap", false)) then
    return false
  end
end
