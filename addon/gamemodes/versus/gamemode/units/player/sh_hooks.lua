local UNIT = UNIT

-- TODO: This also blocks combat?! Why?
-- -- Don't let players collide with eachother
-- function UNIT.hook:ShouldCollide(ent1, ent2)
--   if (ent1:IsPlayer() and ent2:IsPlayer()) then
--     print("Preventing collision between players " .. ent1:Nick() .. " and " .. ent2:Nick())
--     return false
--   end
-- end

function UNIT.hook:BuildDefaultModelList(defaultModels)
  table.Merge(defaultModels, {
    "models/versus/player/female_01.mdl",
    "models/versus/player/female_02.mdl",
    "models/versus/player/female_03.mdl",
    "models/versus/player/female_04.mdl",
    "models/versus/player/female_06.mdl",
    "models/versus/player/female_07.mdl",
    "models/versus/player/male_01.mdl",
    "models/versus/player/male_02.mdl",
    "models/versus/player/male_03.mdl",
    "models/versus/player/male_04.mdl",
    "models/versus/player/male_05.mdl",
    "models/versus/player/male_06.mdl",
    "models/versus/player/male_07.mdl",
    "models/versus/player/male_08.mdl",
    "models/versus/player/male_09.mdl",
  })
end

function UNIT.hook:BuildBodygroupOptions(allBodygroups)
  table.Merge(allBodygroups, {
    torso = {
      [0] = "Default",
      [8] = "Shirt A",
      [10] = "Shirt B",
      [11] = "Shirt C",
      [12] = "Shirt D",
      [13] = "Shirt E",
    },
    legs = {
      [0] = "Default",
      [1] = "Light Jeans",
    },
    facialhair = {
      [0] = "Default",
      [3] = "Mustache",
      [5] = "Scruffy Beard",
    },
  })
end

function UNIT.hook:BuildDefaultBodygroups(defaultBodygroups)
  table.Merge(defaultBodygroups, {
    torso = 0,
    legs = 0,
    hands = 0,
    headgear = 0,
    bag = 0,
    glasses = 0,
    satchel = 0,
    headstrap = 0,
    kevlar = 0,
    belt = 0,
    armband = 0,
    facialhair = 0, -- Only for males
  })
end
