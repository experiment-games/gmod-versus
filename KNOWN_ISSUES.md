# Known Issues with Versus

## (Development) Auto-Refresh

### Commands currently don't auto refresh

Command callbacks don't update after auto refresh. The old script is executed.

### Note: Build reset into auto-loading content

The following code could cause duplicate waypoints and stages to be added after each refresh...

```lua
MISSION.markerPickupPoint = MISSION:registerWaypoint("Pickup Point", "icon16/flag_green.png")
MISSION.stagePickupPoint = MISSION:addStage("Go to the pickup point", MISSION.markerPickupPoint)
```

Fix it by building a reset into the loading script (see mission and command for example). E.g:

```lua
function missionMeta:init()
 self:reset()

 return self
end

function missionMeta:reset()
  self._stages = {}

  -- TODO: Check the data/ folder and load the waypoints
  self._waypoints = {}

  self.name = "No name"
  self.description = "No description"
end
```

### Items and units reloading old methods

**Problem demonstration:**
*Old code:*

```lua
local ITEM = ITEM
ITEM.isSpecial = true
```

*New code:*

```lua
local ITEM = ITEM
-- ITEM.isSpecial has been removed
```

Both the item and unit loading in these cases do not know if the isSpecial
has purposefully been removed. Therefor the old isSpecial member will
survive an auto-refresh and stay effective.

This means you may have to restart in order to test the removal of
non-function members or explicitly set these members to nil, e.g:

```lua
ITEM.isSpecial = nil
```

This problem is fixed for hooks and functions in units and items through
their `unitMeta:reset()` and `itemMeta:reset()` functions respectively.
These functions are called on reloading of units or items.

I believe it's impossible to fix this for other types of members, since
those may be added at runtime.
