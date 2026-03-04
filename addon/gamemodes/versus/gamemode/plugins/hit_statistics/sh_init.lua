local PLUGIN = PLUGIN

PLUGIN.name = "Hit Statistics"
PLUGIN.author = "Experiment Redux"
PLUGIN.description = "Tracks body part hit statistics."

PLUGIN.libraryKey = "hitStatistics"

-- Body part mappings for Source Engine hitgroups
PLUGIN.hitgroupNames = {
  [HITGROUP_GENERIC] = "Generic",
  [HITGROUP_HEAD] = "Head",
  [HITGROUP_CHEST] = "Chest",
  [HITGROUP_STOMACH] = "Stomach",
  [HITGROUP_LEFTARM] = "Left Arm",
  [HITGROUP_RIGHTARM] = "Right Arm",
  [HITGROUP_LEFTLEG] = "Left Leg",
  [HITGROUP_RIGHTLEG] = "Right Leg",
  [HITGROUP_GEAR] = "Gear",
}
