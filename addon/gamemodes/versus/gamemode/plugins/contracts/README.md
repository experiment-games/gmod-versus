# Contract Phase Handler Documentation

This system provides declarative handlers for defining mission phases in Lua contracts. Each handler processes specific phase keys and executes the associated game logic.

The system is designed to be data-driven, allowing for this to potentially be loaded from JSON or another format in the future. For now, handlers are defined in Lua so we can easily setup dynamic loot tables. However since we want to later build contracts with JSON, we should avoid using any complex Lua logic in the contract definitions themselves and instead focus on simple data structures that can be easily represented in JSON (e.g: tables, strings, numbers, booleans, etc).

## Quick Start

To create a contract:

1. Create a new Lua file in `gamemode/plugins/contracts/contracts/` (e.g., `sv_my_contract.lua`)
2. Define your contract using `PLUGIN.register(contractID, contractTable)`
3. The contract table should include:
   - Basic info: `name`, `tags`
   - `locations`: A table defining all locations used in the contract
   - `phases`: An array of phase tables that define the mission flow

**Minimal Example:**

```lua
local PLUGIN = PLUGIN

PLUGIN.register("simple_mission", {
  name = "Simple Mission",
  tags = {
    { label = "pve",   color = Color(100, 160, 220) },
    { label = "escort", color = Color(100, 200, 140) },
  },

  locations = {
    objective = PLUGIN.defineLocation("versus_objective_interaction", "my_objective"),
    spawnPoint = PLUGIN.defineLocation("versus_spawn_point", nil), -- nil = random
  },

  phases = {
    {
      spawn = {
        location = PLUGIN.referToContractLocation("spawnPoint")
      },
      objective = {
        title = "Go to Objective",
        description = "Find and interact with the objective"
      },
      indicators = {
        {
          name = "Objective",
          location = PLUGIN.referToContractLocation("objective"),
          text = "Objective Location"
        }
      },
      completeCallback = {"wait", 5}
    }
  }
})
```

## Generic Information

### `name`

Determines the name of the contract. Can be a string or an array of strings. If it's an array, one will be randomly selected for each contract instance.

### `tags`

An array of tag tables displayed as coloured pills below the contract description in the selection UI. Each tag has a `label` (string) and a `color` (`Color`). Use these to communicate the nature of a contract at a glance — e.g. `"boss"`, `"escort"`, `"defend"`, `"stealth"`, etc.

```lua
tags = {
  { label = "boss",   color = Color(220, 80, 80) },
  { label = "defend", color = Color(100, 160, 220) },
}
```

### `locations`

This is where you define the locations that will be used in the contract. Each location has a unique ID and is defined using `PLUGIN.defineLocation` or `PLUGIN.defineRelativeLocation`. These functions specify the type of location and any parameters needed to determine its position in the game world.

These are the signatures for the location definition functions:

```lua
--- Creates a location definition for use in the contract's "locations" table.
--- @param class string The entity class to search for
--- @param tag any The tag of the specific entity to find (can be nil for random selection)
--- @param hidden? boolean Optional. If true, this location won't be shown on the map preview. Defaults to false.
--- @return table # A location definition table
function PLUGIN.defineLocation(class, tag, hidden) end

--- Creates a relative location definition that will be resolved based on another location.
--- @param class string The entity class to search for
--- @param relativeToKey string The key of the location this should be relative to
--- @param distance number Distance modifier (NEAR_TO_LOCATION or FAR_FROM_LOCATION)
--- @param hidden? boolean Optional. If true, this location won't be shown on the map preview. Defaults to false.
--- @return table # A relative location definition table
function PLUGIN.defineRelativeLocation(class, relativeToKey, distance, hidden) end
```

**Examples:**

```lua
locations = {
  -- Random combine relay (any entity with this class)
  relay = PLUGIN.defineLocation("versus_objective_interaction", nil),

  -- Specific tagged entity
  mainGate = PLUGIN.defineLocation("prop_door_rotating", "main_entrance"),

  -- Spawn point far from the relay
  playerStart = PLUGIN.defineRelativeLocation("versus_spawn_point", "relay", PLUGIN.FAR_FROM_LOCATION),

  -- Extraction point (hidden from map preview)
  extraction = PLUGIN.defineLocation("versus_objective_interaction", "extraction_point", true),
}
```

## Location References

When using locations in phase handlers, you must reference them using `PLUGIN.referToContractLocation(locationKey)`.

**Examples:**

```lua
-- Exact location reference (default)
spawn = {
  location = PLUGIN.referToContractLocation("spawnPoint")
}

-- Spawn enemies near the objective
enemies = {
  {
    class = "npc_combine_s",
    location = PLUGIN.referToContractLocation("objective"),
    count = 5
  }
}

-- Place indicator far from current position
indicators = {
  {
    name = "Distant Marker",
    location = PLUGIN.referToContractLocation("relay")
  }
}
```

## Phase Progression

Phases automatically progress when their `completeCallback` returns `true`. The callback is checked every frame in the Think hook.

**The `completeCallback` Key:**

```lua
phases = {
  {
    objective = { title = "Wait", description = "Wait 5 seconds" },
    completeCallback = {"wait", 5} -- Progresses after 5 seconds
  },
  {
    objective = { title = "Talk to NPC", description = "Interact with the NPC" },
    completeCallback = {"checkContractValueEquals", "talked_to_npc", true}
    -- Progresses when bag.contract.talked_to_npc == true
  }
}
```

If `completeCallback` is `nil` or omitted, the phase will not auto-progress. You must manually call `completePhase` or `completeContract` functions (typically from an interaction callback).

## Built-in Contract Functions

These functions can be used in `completeCallback`, `shouldProgressCallback`, or any callback that expects `{func, arg1, arg2, ...}` format.

### Phase Completion

**`wait`** - Wait for a specified duration

```lua
completeCallback = {"wait", 10} -- Wait 10 seconds
```

**`completePhase`** - Manually complete the current phase

```lua
-- In an entity interaction callback:
InteractionCallback = {"completePhase"}
```

**`completeContract`** - Mark the contract as complete

```lua
InteractionCallback = {"completeContract"}
```

### Contract State Management

**`setContractValue`** - Store a value in contract-wide state

```lua
InteractionCallback = {"setContractValue", "door_opened", true}
```

**`checkContractValueEquals`** - Check if contract state equals a value

```lua
completeCallback = {"checkContractValueEquals", "door_opened", true}
```

**`checkContractValueNotEquals`** - Check if contract state does NOT equal a value

```lua
shouldProgressCallback = {"checkContractValueNotEquals", "download_paused", true}
```

### Phase State Management

**`setPhaseValue`** - Store a value in phase-specific state (cleared when phase ends)

```lua
InteractionCallback = {"setPhaseValue", "enemies_killed", 0}
```

**`checkPhaseValueEquals`** - Check if phase state equals a value

```lua
completeCallback = {"checkPhaseValueEquals", "all_enemies_dead", true}
```

## State Management (The "Bag")

Each player has a contract "bag" that stores state across phases and within phases:

- `bag.contract` - Persistent state across all phases in the contract
- `bag.phase` - Temporary state cleared when the phase changes

**Common Use Cases:**

```lua
-- Track progress across multiple phases
{"setContractValue", "keys_collected", 3}
{"checkContractValueEquals", "keys_collected", 3}

-- Track state within a single phase
{"setPhaseValue", "download_started", true}
{"checkPhaseValueEquals", "download_started", true}
```

You typically interact with the bag through the built-in functions above, but in custom contract functions you receive it as a parameter:

```lua
PLUGIN.registerContractFunction("myCustomFunction", function(player, bag, myArg)
  bag.contract.myValue = myArg
  return bag.phase.someCheck == true
end)
```

## Available Phase Handlers

These all go in the `phases` table of a contract phase definition.

### `enemies`

Spawns enemy NPCs at specified locations.

```lua
enemies = {
  {
    class = "npc_combine_s",
    location = PLUGIN.referToContractLocation("relay"),
    count = 5,
    behavior = "defending", -- "defending" or "attacking"
    health = 100, -- Number or {min = 80, max = 120} for random range
    weapons = {"weapon_smg1"},
    lootTable = function(npc, attacker, position, angles)
      return {
        ["health_vial"] = 0.3,  -- 30% chance
        ["ammo_pistol"] = 0.5   -- 50% chance
      }
    end,
    model = "models/combine_soldier.mdl", -- Optional custom model
    skin = 0, -- Optional skin index
    bodygroups = {[0] = 1} -- Optional bodygroup settings
  }
}
```

**Behavior Types:**

- `"defending"` - NPCs stay around the location and defend it
- `"attacking"` - NPCs actively chase the player

### `entities`

Configures world entities with custom properties and interactions.

```lua
entities = {
  {
    entity = PLUGIN.referToContractLocation("relay"),
    accessors = {
      InteractionName = "Hack Terminal",
      InteractionTime = 5,
      InteractionRadius = 128,
      InteractionCallback = {"onHackComplete"}, -- Function to call on interact
      -- Any Set* method from the entity can be used here
    }
  }
}
```

**Special Accessor: `InteractionCallback`**

This callback receives the player automatically as the first parameter and allows the entity to be interacted with in a player-specific way. This is critical for contracts where multiple players might interact with the same entity.

```lua
InteractionCallback = {
  "setContractValue",
  "hacked",
  true
}
```

### `fireInputs`

Fires inputs on all entities within a radius of each specified location. Each entry in the array defines an independent location/range/input combination, so multiple groups of entities can be triggered in a single phase key.

```lua
fireInputs = {
  {
    location = PLUGIN.referToContractLocation("someMarker"),
    range    = 64,   -- radius in units to search for entities
    input    = "Open", -- input name to fire on all found entities
    param    = "",   -- optional: value passed with the input (default "")
    delay    = 0,    -- optional: seconds before firing (default 0)
  },
  { ... } -- additional entries
}
```

**Example — open two doors from a single trigger point:**

Place a `versus_objective_interaction` in the gap between two doors. Both `prop_door_rotating` entities sit within 64 units of that marker, so a range of `64` catches both and fires `"Open"` on each. A second entry fires a separate input elsewhere in the same phase.

```lua
locations = {
  -- A marker placed in the corridor between the two doors
  doubleDoors = PLUGIN.defineLocation("versus_objective_interaction", "double_door_trigger", true),
  -- A separate breaker box that should lose power at the same moment
  breakerBox = PLUGIN.defineLocation("versus_objective_interaction", "breaker_box", true),
},

phases = {
  {
    -- ... other handlers ...

    fireInputs = {
      {
        location = PLUGIN.referToContractLocation("doubleDoors"),
        range    = 64,
        input    = "Open",
      },
      {
        location = PLUGIN.referToContractLocation("breakerBox"),
        range    = 32,
        input    = "TurnOff",
        delay    = 0.5, -- slight delay after the doors open
      },
    },
  }
}
```

The location entity itself is included in the sphere search but will silently ignore an input it does not handle, so this is safe to use with any marker class.

### `giveItems`

Grants items to the player's inventory.

```lua
giveItems = {
  {itemID = "ammo_pistol", quantity = 50},
  {itemID = "health_kit", quantity = 2}
}
```

### `escortNPCs`

Spawns NPCs that the player must escort to a location.

```lua
escortNPCs = {
  {
    npcClass        = "npc_citizen",
    -- Spawn location:
    location        = PLUGIN.referToContractLocation("detentionCell"),
    health          = 100,
    interactionName = "Escort Prisoner",
    followCallback  = { "setContractValue", "prisoner_freed", true },
    deathCallback   = { "failContract", "The prisoner was killed before they could be extracted." },
  },
},
```

### `indicators`

Creates waypoint markers for the player.

```lua
indicators = {
  {
    name = "objective_marker",
    location = PLUGIN.referToContractLocation("extraction"),
    text = "Extraction Point",
    icon = "icon16/flag_green.png",
    color = Color(0, 255, 0),
    removeOnReach = true
  }
}
```

### `lore`

Displays narrative messages to the player.

```lua
lore = {
  type = "radio",
  author = "Command",
  texts = {
    {
      delayInSeconds = 0,
      content = "Move to the objective."
    },
    {
      delayInSeconds = 3,
      content = {"Watch for hostiles.", "Stay alert."} -- Random choice from array
    },
    {
      delayInSeconds = 5,
      content = "Good luck, %PLAYER_NAME%." -- %PLAYER_NAME% is replaced with player name
    }
  }
}
```

**Current Types:**

- `"radio"` - Radio messages in radio panel (future: audio, panels)

**Content Variables:**

- `%PLAYER_NAME%` - Replaced with the player's name

### `objective`

Sets the player's current objective display.

```lua
objective = {
  title = "Secure the Area",
  description = "Eliminate all enemy forces"
}
```

### `progressBar`

Shows a timed progress bar with conditional logic.

```lua
progressBar = {
  duration = 30,
  type = "decrement", -- "decrement" or "increment"
  label = "Hacking in progress...",
  shouldProgressCallback = {"checkContractValueNotEquals", "paused", true},
  completeCallback = {"onHackComplete"} -- Optional, called when timer completes
}
```

The `shouldProgressCallback` is checked continuously. If it returns `false`, the progress bar pauses. When it returns `true` again, the progress bar resumes.

### `proximityRequirement`

Enforces player proximity to a location.

```lua
proximityRequirement = {
  location = PLUGIN.referToContractLocation("relay"),
  maxDistance = 512,
  warningMessage = "Stay near the relay!",
  returnInRangeMessage = "Back in range.",
  outOfRangeCallback = {"setContractValue", "paused", true},
  returnInRangeCallback = {"setContractValue", "paused", false}
}
```

This creates a radius around the specified location that the player must stay within. If they leave, `outOfRangeCallback` is triggered. When they return, `returnInRangeCallback` is triggered.

### `clearProximityRequirement`

Removes active proximity requirement.

```lua
clearProximityRequirement = {}
```

### `applyStatusEffect`

Applies a timed gameplay modifier to the player: periodic health drain and/or a movement speed penalty. Any speed change is automatically rolled back when the phase ends. Multiple effects can be active simultaneously as long as each has a unique `effectID`.

```lua
applyStatusEffect = {
  effectID        = "radiation",          -- unique key within the phase
  tickRate        = 1.0,                  -- seconds between ticks (default: 1)
  duration        = 30,                   -- total seconds; nil = lasts until phase ends
  tickDamage      = 3,                    -- HP removed each tick (optional)
  damageType      = DMG_RADIATION,        -- Source DMG_* flag (default: DMG_GENERIC)
  speedMultiplier = 0.7,                  -- walk/run multiplier, e.g. 0.7 = 30% slower (optional)
  hudLabel        = "Radiation",          -- text shown in the HUD strip (default: "Status Effect")
  hudColor        = Color(100, 200, 100), -- HUD strip colour (default: white)
  tickCallback    = { "myFunc" },         -- called each tick (optional)
  expiryCallback  = { "completePhase" },  -- called when duration expires (optional)
}
```

The HUD displays a labelled strip for each active effect with an optional draining duration bar.

`expiryCallback` is only fired when `duration` is set. If `duration` is `nil` the effect simply persists until the phase ends.

### `clearStatusEffect`

Restores any speed modification applied by a named status effect and removes its HUD entry before the phase ends. The tick timer keeps running until the phase naturally ends — only the speed change and HUD indicator are removed early.

Can be used as a **phase key handler** (in a later phase) or as a **contract function** inside a callback.

```lua
-- Used as a phase key:
clearStatusEffect = { effectID = "radiation" }

-- Used as a callback (e.g. from expiryCallback or InteractionCallback):
expiryCallback = { "clearStatusEffect", "radiation" }
```

### `screenEffect`

Sends a client-side post-process effect to the player for the duration of the current phase. The effect is automatically cleared when the phase ends. Only one screen effect can be active at a time per player.

```lua
screenEffect = {
  effect   = "bleeding",  -- effect name (see built-in effects below)
  duration = 20,          -- auto-clear after N seconds; nil = lasts until phase ends
}
```

**Built-in effects:**

| Name           | Description                                        |
|----------------|----------------------------------------------------|
| `"bleeding"`   | Red vignette, mild desaturation                    |
| `"drunk"`      | Heavy motion blur, warm colour boost               |
| `"nightvision"`| Green tint, high contrast                         |
| `"toxic"`      | Yellow-green tint, subtle motion blur, green vignette |
| `"radiation"`  | Pulsing green tint, desaturation                   |
| `"cold"`       | Blue desaturated tint                              |
| `"blinded"`    | Bright white flash that fades out over ~2 seconds  |

### `clearScreenEffect`

Removes the active screen effect before the phase ends. Takes no data.

```lua
clearScreenEffect = {}
```

### `spawn`

Teleports the player to a location.

```lua
spawn = {
  location = PLUGIN.referToContractLocation("spawnPoint")
}
```

This should typically be the first handler in your first phase to position the player at the start of the contract.

### `spawnWaves`

Spawns multiple enemy waves with delays. Each wave is spawned after a specified delay from the phase start.

```lua
spawnWaves = {
  {
    delayInSeconds = 5,
    enemies = {
      {
        class = "npc_combine_s",
        count = 3,
        location = PLUGIN.referToContractLocation("objective"),
        behavior = "attacking",
        health = 150,
        weapons = {"weapon_ar2"},
        lootTable = function(npc, attacker, pos, angles)
          return {["health_vial"] = 0.2}
        end
      }
    }
  },
  {
    delayInSeconds = 15, -- 15 seconds from phase start
    enemies = {
      {
        class = "npc_combine_s",
        count = 5,
        location = PLUGIN.referToContractLocation("objective"),
        behavior = "attacking",
        health = 200,
        weapons = {"weapon_ar2", "weapon_shotgun"}
      }
    }
  }
}
```

**Behavior Types:**

- `"attacking"` / `"chase"` - Chase the player
- `"assault"` - Assault a specific point
- `"defending"` - Defend an area
- `"idle"` - Stand still

## Custom Contract Functions

You can register your own functions to use in callbacks:

```lua
PLUGIN.registerContractFunction("myFunction", function(player, bag, arg1, arg2)
  -- Your logic here
  -- Return true/false for completion callbacks
  -- Return any value for other uses

  if arg1 == "something" then
    bag.contract.myValue = arg2
    return true
  end

  return false
end)

-- Use it in a contract:
completeCallback = {"myFunction", "something", 123}
```

## Complete Example

Here's a complete contract showing many features:

```lua
local PLUGIN = PLUGIN

PLUGIN.register("example_contract", {
  name = {"Mission Alpha", "Operation Beta"}, -- Random selection
  tags = {
    { label = "sabotage", color = Color(180, 120, 220) },
    { label = "pve",      color = Color(100, 160, 220) },
  },

  locations = {
    objective = PLUGIN.defineLocation("versus_objective_interaction", "my_obj"),
    spawnPoint = PLUGIN.defineRelativeLocation("versus_spawn_point", "objective", PLUGIN.FAR_FROM_LOCATION),
    extraction = PLUGIN.defineLocation("versus_objective_interaction", "extraction", true),
  },

  phases = {
    -- Phase 1: Spawn and introduction
    {
      spawn = {
        location = PLUGIN.referToContractLocation("spawnPoint")
      },
      lore = {
        type = "radio",
        author = "Command",
        texts = {
          {delayInSeconds = 1, content = "Welcome %PLAYER_NAME%, proceed to the objective."},
          {delayInSeconds = 3, content = "Watch for enemies."}
        }
      },
      objective = {
        title = "Reach Objective",
        description = "Travel to the marked location"
      },
      indicators = {
        {
          name = "Objective",
          location = PLUGIN.referToContractLocation("objective"),
          text = "Go here"
        }
      },
      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("objective"),
          count = 3,
          behavior = "defending",
          weapons = {"weapon_smg1"}
        }
      },
      completeCallback = {"wait", 5}
    },

    -- Phase 2: Interact with objective
    {
      objective = {
        title = "Hack Terminal",
        description = "Interact with the terminal"
      },
      entities = {
        {
          entity = PLUGIN.referToContractLocation("objective"),
          accessors = {
            InteractionName = "Hack",
            InteractionTime = 3,
            InteractionCallback = {"setContractValue", "hacked", true}
          }
        }
      },
      completeCallback = {"checkContractValueEquals", "hacked", true}
    },

    -- Phase 3: Hold position
    {
      objective = {
        title = "Defend Position",
        description = "Defend while data downloads"
      },
      progressBar = {
        duration = 30,
        type = "decrement",
        label = "Downloading...",
        shouldProgressCallback = {"checkContractValueNotEquals", "paused", true},
        completeCallback = {"completePhase"}
      },
      proximityRequirement = {
        location = PLUGIN.referToContractLocation("objective"),
        maxDistance = 512,
        warningMessage = "Stay close to the terminal!",
        returnInRangeMessage = "Download resumed.",
        outOfRangeCallback = {"setContractValue", "paused", true},
        returnInRangeCallback = {"setContractValue", "paused", false}
      },
      spawnWaves = {
        {
          delayInSeconds = 0,
          enemies = {
            {
              class = "npc_combine_s",
              count = 4,
              location = PLUGIN.referToContractLocation("objective"),
              behavior = "attacking",
              weapons = {"weapon_ar2"}
            }
          }
        },
        {
          delayInSeconds = 15,
          enemies = {
            {
              class = "npc_combine_s",
              count = 6,
              location = PLUGIN.referToContractLocation("objective"),
              behavior = "attacking",
              weapons = {"weapon_ar2"}
            }
          }
        }
      }
    },

    -- Phase 4: Extract
    {
      clearProximityRequirement = true,
      objective = {
        title = "Extract",
        description = "Reach the extraction point"
      },
      indicators = {
        {
          name = "Extraction",
          location = PLUGIN.referToContractLocation("extraction"),
          text = "Extract here"
        }
      },
      entities = {
        {
          entity = PLUGIN.referToContractLocation("extraction"),
          accessors = {
            InteractionName = "Extract",
            InteractionTime = 5,
            InteractionCallback = {"completeContract"}
          }
        }
      },
      giveItems = {
        {itemID = "reward_item", quantity = 1}
      }
    }
  }
})
```

## Bot Testing for Interception Contracts

The contracts system includes bot testing functionality to help test interference/subsequent contracts without requiring multiple human players.

### Console Commands

**`versus_bot_assign_contract <botname> <contractID>`**

Assigns a specific contract to a bot. The bot will be spawned and immediately start the contract.

```
// Example: Spawn a bot and assign signal_intercept contract
bot
versus_bot_assign_contract bot signal_intercept
```

**`versus_bot_contract_status [botname]`**

Shows the current contract status for one or all bots, including:

- Contract ID
- Current phase number
- Whether the phase is interferable
- Maximum subsequent players allowed
- Current subsequent player count

```
// Check all bots
versus_bot_contract_status

// Check specific bot
versus_bot_contract_status bot
```

**`versus_bot_progress_phase <botname>`**

Manually advances a bot to the next phase of their contract. Useful for quickly moving a bot to an interferable phase.

```
versus_bot_progress_phase bot
```

**`versus_regenerate_contracts`**

Regenerates your available contracts, which will pick up any new subsequent/interference contracts available from active bot contracts.

```
versus_regenerate_contracts
```

**`versus_list_contracts`**

Lists all registered contracts in the system with their properties (difficulty, reward, phase count).

```
versus_list_contracts
```

### Testing Workflow

1. **Spawn a bot:**

   ```
   bot
   ```

2. **Assign a contract to the bot:**

   ```
   versus_bot_assign_contract bot signal_intercept
   ```

3. **Check the bot's status:**

   ```
   versus_bot_contract_status bot
   ```

4. **Progress the bot to an interferable phase** (if not already there):

   ```
   versus_bot_progress_phase bot
   versus_bot_progress_phase bot
   ```

5. **Verify the bot is on an interferable phase:**

   ```
   versus_bot_contract_status bot
   ```

   Look for `Interferable: YES` in the output.

6. **Regenerate your contracts to see interference options:**

   ```
   versus_regenerate_contracts
   ```

7. **Select the interference contract** from the UI (it will have `[INTERFERENCE]` in the name)

### Bot Auto-Progression

Bots automatically progress through contract phases:

- Phases with `completeCallback` will auto-complete when the condition is met
- Phases requiring entity interaction will auto-trigger when the bot is within 200 units of the entity
- There's a 2-second delay between automatic interactions to make behavior observable

You can still manually progress bots using `versus_bot_progress_phase` if needed for faster testing.

### Notes

- Bots can only be assigned "first" role contracts with the command
- Subsequent contracts from active bots will appear in your contract list with `[INTERFERENCE]` tag
- Multiple bots can have different contracts simultaneously
- Bot contracts respect all the same entity reservation and phase synchronization rules as human players
