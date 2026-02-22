local PLUGIN = PLUGIN

-- A cluster of zombies has gathered in the area.
-- No loot crate — just a horde to clear for experience and ammo drops.

PLUGIN.register("zombie_horde", {
  name        = "Zombie Horde",
  description = "A horde of infected has gathered nearby. Put them down.",

  monsters = {
    {
      class  = "npc_zombie",
      count  = 5,
      health = 80,
    },
    {
      class  = "npc_zombie_torso",
      count  = 3,
      health = 50,
    },
    {
      class  = "npc_headcrab_fast",
      count  = 4,
      health = 25,
    },
  },

  lootcrate = {}, -- default item pool
})
