local PLUGIN = PLUGIN

function PLUGIN.hook:ServerShouldLoadManifest()
  -- Don't load the manifest on hideout maps
  if (GetGlobalBool("VersusHideoutMap", false)) then
    return false
  end
end
