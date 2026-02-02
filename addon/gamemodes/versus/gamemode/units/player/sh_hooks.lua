local UNIT = UNIT

function UNIT.hook:BuildDefaultModelList(defaultModels)
  table.Merge(defaultModels, {
    "models/player/group03/female_01.mdl",
    "models/player/Group03/Female_02.mdl",
    "models/player/Group03/Female_03.mdl",
    "models/player/Group03/Female_04.mdl",
    "models/player/Group03/Female_05.mdl",
    "models/player/Group03/Female_06.mdl",
    "models/player/Group03/Male_01.mdl",
    "models/player/Group03/Male_02.mdl",
    "models/player/Group03/Male_03.mdl",
    "models/player/Group03/Male_04.mdl",
    "models/player/Group03/Male_05.mdl",
    "models/player/Group03/Male_06.mdl",
    "models/player/Group03/Male_07.mdl",
    "models/player/Group03/Male_08.mdl",
    "models/player/Group03/Male_09.mdl",
  })
end

-- function UNIT.hook:BuildBodygroupOptions(allBodygroups)
--   table.Merge(allBodygroups, {
--     headgear = {
--       [0] = "None",
--       [1] = "Dirty Beanie",
--     },
--     torso = {
--       [0] = "Default",
--       [2] = "Green Jacket",
--       [4] = "Plain Shirt",
--     },
--     legs = {
--       [0] = "Default",
--       [1] = "Light Jeans",
--       [4] = "Dark Jeans"
--     },
--     glasses = {
--       [0] = "None",
--       [1] = "Simple",
--     }
--   })
-- end

-- function UNIT.hook:BuildDefaultBodygroups(defaultBodygroups)
--   table.Merge(defaultBodygroups, {
--     skin = 0,
--     torso = 0,
--     legs = 0,
--     hands = 0,
--     headgear = 0,
--     bag = 0,
--     glasses = 0,
--     satchel = 0,
--     pouch = 0,
--     badge = 0,
--     headstrap = 0,
--     kevlar = 0
--   })
-- end
