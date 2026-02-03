# Conventions

## Indentation and spacing

**Indentation:** 2 spaces

_Good examples:_

```lua
-- Note no spaces after if and before then:
if(isActivated)then
  -- Note no spaces within the parentheses
  for _, contraband in pairs(playerContraband) do
    -- etc...
  end
end
```

## Variables

**Guidelines:**

* No abbreviations
* Rather long and descriptive than short and cryptic
* Describes the meaning, not the content of the variable (e.g: rather `age` than `number`)

### Members to objects/libraries/units

_Good examples:_

```lua
-- lowerCamelCase, except when private
player.amountOfContraband = 10

-- Private members are prefixed with _ and continue UpperCamelCase
-- Members are only private if changing them from outside breaks other code
UNIT._InternalCheck = true

-- Methods and functions are also lowerCamelCase
function UNIT:calculateContrabandValue()
  -- rest of code...
end
```

### Members to `PANEL` definitions

Methods to `PANEL` definitions are `UpperCamelCase`.

_Good examples:_

```lua
function PANEL:RebuildWithData(data)
  -- rest of code...
end
```

### Local variables & Parameters

_Good examples:_

```lua
function checkContrabandActivation()
  local contrabandDescription = "something"
  -- bools always start with "is" or "has"
  local isActivated = true

  -- Note useful variable names
  -- Use _ to indicate unused key variable
  for _, contraband in pairs(playerContraband) do
    -- etc...
  end

  -- rest of code...
end
```

## Comments

There is still some "kuro-comments" that add nothing to the code other than
green text.

**Guidelines:**

* Describe why the code does something in a certain way, not what it does
* Make note when something needs to be done with `-- TODO: etc...`
* Rather less comments and more descriptive variable and function names

_Bad examples (a.k.a. "kuro-comments"):_

```lua
-- Check if the entity has run out of health.
if(self:Health() <= 0)then
  -- etc...
end

--Get the contraband table.
local contraband = versus.config["Contraband"][self:GetClass()]

```

**TODO: The rest of the conventions**
