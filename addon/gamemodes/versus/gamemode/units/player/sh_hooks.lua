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
    "models/humans/pandafishizens/female_01.mdl",
    "models/humans/pandafishizens/female_02.mdl",
    "models/humans/pandafishizens/female_03.mdl",
    "models/humans/pandafishizens/female_04.mdl",
    "models/humans/pandafishizens/female_06.mdl",
    "models/humans/pandafishizens/female_07.mdl",
    -- "models/humans/pandafishizens/female_11.mdl",
    -- "models/humans/pandafishizens/female_17.mdl",
    -- "models/humans/pandafishizens/female_18.mdl",
    -- "models/humans/pandafishizens/female_19.mdl",
    -- "models/humans/pandafishizens/female_24.mdl",
    -- "models/humans/pandafishizens/female_25.mdl",
    "models/humans/pandafishizens/male_01.mdl",
    "models/humans/pandafishizens/male_02.mdl",
    "models/humans/pandafishizens/male_03.mdl",
    "models/humans/pandafishizens/male_04.mdl",
    "models/humans/pandafishizens/male_05.mdl",
    "models/humans/pandafishizens/male_06.mdl",
    "models/humans/pandafishizens/male_07.mdl",
    "models/humans/pandafishizens/male_08.mdl",
    "models/humans/pandafishizens/male_09.mdl",
    -- "models/humans/pandafishizens/male_10.mdl",
    -- "models/humans/pandafishizens/male_11.mdl",
    -- "models/humans/pandafishizens/male_12.mdl",
    -- "models/humans/pandafishizens/male_15.mdl",
    -- "models/humans/pandafishizens/male_16.mdl",
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
