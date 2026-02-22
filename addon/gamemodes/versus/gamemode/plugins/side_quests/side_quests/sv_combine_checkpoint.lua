local PLUGIN = PLUGIN

-- A Combine checkpoint has been established in the area.
-- Regular soldiers defend the perimeter; a commander leads them.

PLUGIN.register("combine_checkpoint", {
  name        = "Combine Checkpoint",
  description = "A Combine checkpoint has been set up in the area. Clear it out.",

  monsters = {
    {
      class   = "npc_combine_s",
      count   = 3,
      health  = 100,
      weapons = { "weapon_ar2" },
    },
    {
      class     = "npc_combine_s",
      count     = 1,
      health    = 250,
      weapons   = { "weapon_shotgun" },
      isBoss    = true,
      bossName  = "Checkpoint Commander",
    },
  },

  lootcrate = {}, -- default item pool

  props = {
    {
      model     = "models/props_combine/combine_barricade_short01a.mdl",
      placement = "against_wall",
    },
    {
      model     = "models/props_combine/combine_barricade_long01a.mdl",
      placement = "against_wall",
    },
    {
      model     = "models/props_combine/combine_crate001a.mdl",
      placement = "between_walls",
    },
  },
})
