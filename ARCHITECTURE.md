# Architecture

## Units and Plugins

The gamemode is structured around two kinds of self-contained modules: **units** and **plugins**.

- **Units** (`gamemode/units/`) are core libraries that the gamemode depends on. They may only reference other units. They are loaded first.
- **Plugins** (`gamemode/plugins/`) are optional feature packages loaded on top of the core. They may reference both other plugins and units. They are loaded after all units are ready.

Both share the same loading mechanism (`versus.unit.loadUnits`). The only difference is the global variable exposed inside their files: `UNIT` for units, `PLUGIN` for plugins.

Loading order in `sh_init.lua`:

```lua
versus.unit.loadUnits("units/")            -- Core units, UNIT global
versus.unit.loadUnits("plugins/", "PLUGIN") -- Feature plugins, PLUGIN global
```

## Module Loading

Each unit/plugin lives in its own subdirectory. The loader discovers all subdirectories under `units/` or `plugins/` and loads each one in turn.

### Init files

The following init files are loaded automatically if present, in this order:

| File | Realm |
| --- | --- |
| `sh_init.lua` | Server send + server/client execute |
| `sv_init.lua` | Server only |
| `cl_init.lua` | Server sends to client; client executes |

### Optional loader guard

If a directory contains `sh_loader.lua`, it is executed first. Returning `false` (and optionally a reason string) causes the loader to skip that module:

```lua
-- sh_loader.lua
return false, "This plugin requires the database unit"
```

### Automatic subdirectories

The following subdirectories are handled automatically, without any code in the unit/plugin's init files:

| Directory | Loaded by |
| --- | --- |
| `metatables/` | The unit loader itself, after all init files |
| `entities/entities/` | The unit loader; each file/subdirectory registers an `ENT` |
| `entities/weapons/` | The unit loader; each file/subdirectory registers a `SWEP` |
| `entities/effects/` | The unit loader; each file/subdirectory registers an `EFFECT` |
| `panels/` | The `panel` unit via `SomeUnitInitialized` |
| `items/` | The `item` unit via `SomeUnitInitialized` |
| `sanctions/` | The `sanction` unit via `SomeUnitInitialized` |

The `panels/`, `items/`, and `sanctions/` directories work because those core units listen to the `SomeUnitInitialized` hook and call `versus.includeDirectory` (or a typed equivalent) on every other unit/plugin that finishes loading. This means any unit or plugin simply needs the directory to exist — no extra wiring required.

### Loading a directory manually

`versus.includeDirectory` loads all `*.lua` files in a path through `versus.includePrefixed`, so realm prefixes are respected:

```lua
versus.includeDirectory(UNIT.fullPath .. "/commands/")
```

### Loading a single file

`versus.includePrefixed` routes a file to the correct realm based on its `cl_`, `sh_`, or `sv_` prefix:

```lua
versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("cl_hooks.lua")
```

It also accepts an explicit base directory as a second argument:

```lua
versus.includePrefixed("sh_sanctions.lua", unit.fullPath)
```

## Hook System

Hooks are defined as methods on the `.hook` table of `UNIT` or `PLUGIN`:

```lua
function PLUGIN.hook:PostDrawHealthBar(bar, health, maxHealth)
  -- ...
end

function UNIT.hook:PlayerInitialized(player)
  -- ...
end
```

After all init files for a module are executed, the loader calls `unit:registerHooks()`. This iterates over every key in `.hook` and calls `hook.Add(eventName, self, wrappedCallback)` automatically. Each callback is wrapped in `xpcall` so that a runtime error in one module does not break hooks registered by other modules.

**Manual `hook.Add` calls are discouraged.** Using `.hook` methods keeps hook management consistent, benefits from the error-isolation wrapper, and ensures hooks are correctly cleaned up on hot-reload.

### Post-load hooks

Two hooks are fired by the unit loader:

- `SomeUnitLoaded` — fired immediately after an individual unit/plugin finishes executing its init files and registering its hooks.
- `SomeUnitInitialized` — fired for every unit/plugin once *all* modules in the current `loadUnits` batch have finished loading. This is the right place to react to other modules being available.

Example — a unit that extends every other unit with additional behaviour once they are all ready:

```lua
-- sh_hooks.lua
local UNIT = UNIT

function UNIT.hook:SomeUnitInitialized(unit)
  versus.includeDirectory(unit.fullPath .. "/sanctions/")
end
```

## Items

Items are data definitions that live in `items/` subdirectories. The `item` unit automatically loads every other unit's and plugin's `items/` folder once all modules are initialized (via `SomeUnitInitialized`), so no extra wiring is needed.

### File naming and the `ITEM` global

Each file in `items/` defines one item. The file must be prefixed `sh_` (items are always shared). The `itemID` is derived automatically by stripping the `sh_` prefix and `.lua` extension from the filename:

```txt
items/sh_health_kit.lua  →  itemID: "health_kit"
items/sh_base_weapon.lua →  itemID: "base_weapon"
```

While the file is being executed, the `ITEM` global points to the current item table, exactly like `UNIT`/`PLUGIN` for modules. Both locals should be captured at the top:

```lua
local UNIT = UNIT  -- the owning unit/plugin, if needed
local ITEM = ITEM  -- always capture this

ITEM.name = "Health Kit"
ITEM.size = 1
ITEM.cost = 300
ITEM.model = "models/items/healthkit.mdl"
ITEM.healAmount = 50
ITEM.base = "base_heal"
```

An item without a `name` will not be registered (a warning is printed server-side). `itemID` is derived from the filename but can be overridden explicitly — this is typically done only for base items.

### Inheritance

Items support single inheritance through `ITEM.base`. Setting it to another `itemID` causes all unset keys to fall through to the base item at runtime via `__index`. Base resolution is deferred if the base item has not yet been loaded, so the order items are loaded in does not matter.

```lua
-- sh_base_heal.lua — defines the base
ITEM.name = "Base Heal"
ITEM.isBaseItem = true  -- convention to mark items not meant to be used directly

function ITEM:onUse(player)
  player:SetHealth(player:Health() + self.healAmount)
end

-- sh_health_kit.lua — inherits from base_heal
ITEM.base = "base_heal"
ITEM.name = "Health Kit"   -- overrides base name
ITEM.healAmount = 50       -- read by base onUse
ITEM.cost = 300
```

Inheritance chains can be arbitrarily deep. `item:isBasedOf("base_heal")` walks the chain to check ancestry.

### Item callbacks

Unlike gamemode hooks (which use the `.hook` table), item behaviour callbacks are plain methods assigned directly on `ITEM`. The `item` unit calls these at the appropriate time:

| Callback | Called when |
| --- | --- |
| `ITEM:onUse(player)` | Player uses the item; return `false` to prevent removal |
| `ITEM:onEquip(player)` | Item is equipped |
| `ITEM:onUnequip(player)` | Item is unequipped |
| `ITEM:onDrop(player, position)` | Item is dropped |

Items also support the `.hook` table for gamemode hooks, registered with the same `xpcall`-wrapped `hook.Add` mechanism as units and plugins.

### Item instances

An **item instance** (`VersusItemInstance`) is a live, per-player copy of an item. The item definition (the `ITEM` table registered from the file) is shared and immutable; instances carry per-copy state on top of it.

Instances are created server-side via:

```lua
local instance = versus.item.createInstance("health_kit")
```

Internally an instance holds two fields:

- `itemTable` — a reference to the shared item definition
- `memberOverrides` — a flat key-value table of values that differ from the definition

`__index` on an instance resolves keys in this order:

1. Instance metatable methods
2. `memberOverrides`
3. `itemTable` (which itself falls through the `ITEM.base` chain)

`__newindex` routes all writes into `memberOverrides`, so the shared definition is never mutated:

```lua
instance.healAmount = 75  -- stored in memberOverrides, not in the item definition
print(instance.healAmount) -- 75
print(instance.name)       -- "Health Kit" (falls through to itemTable)
```

This means any field can be overridden per-instance — a renamed item, a stat-boosted weapon, a partially-consumed consumable, etc.

#### Networking

Only `memberOverrides` is ever sent across the network — the full item definition is already present on the client from the shared Lua files. The `inventory` unit handles this via two paths:

- **Full sync** (e.g. on join): `networkMessageWriteItem` serialises `itemID` + the full `memberOverrides` table and sends it as part of an unbounded message.
- **Partial update** (e.g. after equipping a weapon): `networkItemOverrides(player, item, specificOverride)` sends only the one changed key, keeping bandwidth minimal.

On the client the received overrides are merged into the existing instance's `memberOverrides`. If a value has been reset to `nil` server-side a sentinel `nilReplacement` value is used so the absence is transmitted correctly.

The `AdjustNetworkItemMemberOverrides` hook fires before any send and allows code to transform what goes over the wire (e.g. substituting a filepath stored internally with a processed value the client actually needs).

## Library Keys

A unit or plugin can expose itself in the `versus` global table by setting `libraryKey`:

```lua
-- sh_init.lua
PLUGIN.libraryKey = "contracts"
```

After loading, the module is accessible as `versus.contracts`. All functions and data added to `PLUGIN` are reachable through this table:

```lua
versus.contracts.getActive(player)
```

Only one module may claim a given key; a duplicate triggers a warning.

## Local Variable Capture

Every file in a unit or plugin captures the module reference in a local variable at the very top:

```lua
local PLUGIN = PLUGIN  -- or: local UNIT = UNIT
```

This is required because the global `PLUGIN`/`UNIT` variable is overwritten each time a new module starts loading. Without this capture, a file included late (such as a hooks file included from `sh_init.lua`) would, by the time its closures run, reference whatever was last assigned to the global rather than the module it belongs to.

```lua
-- BAD — hook closure captures the global, which changes over time
function PLUGIN.hook:PlayerSpawn(player)
  PLUGIN.doSomething()  -- 'PLUGIN' global may point to a different plugin by the time this runs
end

-- GOOD — local captures the reference at include-time
local PLUGIN = PLUGIN

function PLUGIN.hook:PlayerSpawn(player)
  PLUGIN.doSomething()  -- always the correct plugin
end
```

Every file in the codebase follows this pattern.
