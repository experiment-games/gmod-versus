local PLUGIN = PLUGIN

-- An antlion nest has surfaced in the area.
-- Workers swarm freely; the Guard is a boss-tier threat.

PLUGIN.register("antlion_nest", {
  name        = "Antlion Nest",
  description = "An antlion nest has surfaced nearby. Neutralize the swarm and its guardian.",

  monsters = {
    {
      class  = "npc_antlion",
      count  = 5,
      health = 60,
    },
    {
      class    = "npc_antlionguard",
      count    = 1,
      health   = 800,
      isBoss   = true,
      bossName = "Antlion Guard",
    },
  },

  lootcrate = {}, -- default item pool
})
