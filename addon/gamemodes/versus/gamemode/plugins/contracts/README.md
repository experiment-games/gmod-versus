# Contract Phase Handler Documentation

This system provides declarative handlers for defining mission phases in Lua contracts. Each handler processes specific phase keys and executes the associated game logic.

The system is designed to be data-driven, allowing for this to potentially be loaded from JSON or another format in the future. For now, handlers are defined in Lua so we can easily setup dynamic loot tables. However since we want to later build contracts with JSON, we should avoid using any complex Lua logic in the contract definitions themselves and instead focus on simple data structures that can be easily represented in JSON (e.g: tables, strings, numbers, booleans, etc).

## Quick Start

To create a contract:

1. Create a new Lua file in `gamemode/plugins/contracts/contracts/` (e.g., `sv_my_contract.lua`)
2. Define your contract using `PLUGIN.register(contractID, contractTable)`
3. The contract table should include:
   - Basic info: `name`, `difficulty`, `reward`, `combatStyle`
   - `locations`: A table defining all locations used in the contract
   - `phases`: An array of phase tables that define the mission flow

**Minimal Example:**

```lua
local PLUGIN = PLUGIN

PLUGIN.register("simple_mission", {
  name = "Simple Mission",
  difficulty = PLUGIN.DIFFICULTY_EASY,
  reward = PLUGIN.REWARD_LOW,
  combatStyle = PLUGIN.COMBAT_STYLE_PVE,

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

### `difficulty`, `reward`, `combatStyle`

These are used for informational purposes and can be referenced in the contract's logic if desired. They can also be used by external systems to filter or sort contracts.

Values can be:

- `difficulty`: `PLUGIN.DIFFICULTY_EASY`, `PLUGIN.DIFFICULTY_MEDIUM`, `PLUGIN.DIFFICULTY_HARD`
- `reward`: `PLUGIN.REWARD_LOW`, `PLUGIN.REWARD_MEDIUM`, `PLUGIN.REWARD_HIGH`
- `combatStyle`: `PLUGIN.COMBAT_STYLE_PVE`, `PLUGIN.COMBAT_STYLE_PVP`, `PLUGIN.COMBAT_STYLE_MIXED`

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

When using locations in phase handlers, you must reference them using `PLUGIN.referToContractLocation(locationKey, distance)`.

**Distance Modifiers:**

- `PLUGIN.EXACT` (default) - Use the exact location entity
- `PLUGIN.NEAR_TO_LOCATION` - Find an entity of that type near the location
- `PLUGIN.FAR_FROM_LOCATION` - Find an entity of that type far from the location

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
    location = PLUGIN.referToContractLocation("objective", PLUGIN.NEAR_TO_LOCATION),
    count = 5
  }
}

-- Place indicator far from current position
indicators = {
  {
    name = "Distant Marker",
    location = PLUGIN.referToContractLocation("relay", PLUGIN.FAR_FROM_LOCATION)
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
    location = PLUGIN.referToContractLocation("relay", PLUGIN.NEAR_TO_LOCATION),
    count = 5,
    behavior = "defending", -- "defending" or "attacking"
    health = 100, -- Number or {min = 80, max = 120} for random range
    weapons = {"weapon_smg1"},
    lootTable = function(attacker, position, angles)
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

### `giveItems`

Grants items to the player's inventory.

```lua
giveItems = {
  {itemID = "ammo_pistol", quantity = 50},
  {itemID = "health_kit", quantity = 2}
}
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
        location = PLUGIN.referToContractLocation("objective", PLUGIN.NEAR_TO_LOCATION),
        behavior = "attacking",
        health = 150,
        weapons = {"weapon_ar2"},
        lootTable = function(attacker, pos, angles)
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
        location = PLUGIN.referToContractLocation("objective", PLUGIN.NEAR_TO_LOCATION),
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
  difficulty = PLUGIN.DIFFICULTY_MEDIUM,
  reward = PLUGIN.REWARD_MEDIUM,
  combatStyle = PLUGIN.COMBAT_STYLE_PVE,

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
          location = PLUGIN.referToContractLocation("objective", PLUGIN.NEAR_TO_LOCATION),
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
              location = PLUGIN.referToContractLocation("objective", PLUGIN.NEAR_TO_LOCATION),
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
              location = PLUGIN.referToContractLocation("objective", PLUGIN.NEAR_TO_LOCATION),
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
