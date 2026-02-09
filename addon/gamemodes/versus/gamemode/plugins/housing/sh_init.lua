local PLUGIN = PLUGIN

PLUGIN.convarHideoutServer = CreateConVar(
  "versus_hideout_server",
  "",
  { FCVAR_REPLICATED, FCVAR_ARCHIVE },
  "The IP address and port of the hideout server to advertise to clients. Format should be ip:port"
)
PLUGIN.baseRoomPrice = 1000 -- Base price for rooms, multiplied by the price scale on the target

function PLUGIN.hook:PlayerShouldSelectContract(player)
  -- Don't allow contract selection if we're in a hideout map
  if (GetGlobalBool("VersusHideoutMap", false)) then
    return false
  end
end
