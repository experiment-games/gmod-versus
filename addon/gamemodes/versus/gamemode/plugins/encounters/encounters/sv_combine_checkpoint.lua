local PLUGIN = PLUGIN

-- A Combine checkpoint has been established in the area.
-- Regular soldiers defend the perimeter; a commander leads them.

PLUGIN.register("combine_checkpoint", {
  name        = "Combine Checkpoint",
  description = "A Combine checkpoint has been set up in the area. Clear it out.",

  monsters    = {
    {
      class   = "npc_combine_s",
      count   = 3,
      health  = 100,
      weapons = { "weapon_ar2" },
    },
    {
      class    = "npc_combine_s",
      count    = 1,
      health   = 250,
      weapons  = { "weapon_shotgun" },
      isBoss   = true,
      bossName = "Checkpoint Commander",
    },
  },

  lootcrate   = {}, -- default item pool

  -- Commented as the crate seems to spawn inside it sometimes and it looks ugly place around randomly
  -- props       = {
  --   {
  --     model     = "models/props_combine/combine_barricade_short02a.mdl",
  --     placement = "against_wall",
  --   },
  --   {
  --     model     = "models/props_combine/combine_barricade_med04b.mdl",
  --     placement = "against_wall",
  --   },
  -- },
})
