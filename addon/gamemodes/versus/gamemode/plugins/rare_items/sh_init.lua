local PLUGIN = PLUGIN

function PLUGIN.registerRareItem(id, name, description, model, scrapValue, lootChance, modelScale)
  local itemID = "#rare_" .. id
  local item = versus.item.getAndResetOrCreateItem(itemID)

  item.base = "base_rare_item"
  item.itemID = itemID
  item.path = itemID
  item.name = name
  item.description = description
  item.model = model
  item.modelScale = modelScale
  item.cost = scrapValue
  item.scrapFraction = 1 -- Full return of cost when scrapped
  item.lootChance = lootChance or 0.05

  versus.item.registerItem(item)
end

-- Add random items based on their lootChance to contract loot tables
function PLUGIN.hook:ModifyContractLootTable(npc, lootTable, attacker, position, angles)
  for _, item in pairs(versus.item.findAllByBase("base_rare_item")) do
    if (not item.lootChance) then
      continue
    end

    lootTable[item.itemID] = item.lootChance
  end
end

local items = {
  {
    id = "combine_alloy_scrap",
    name = "Combine Alloy Scrap",
    description =
    "Fragments of Combine-grade metal harvested from destroyed Overwatch units. Lightweight but highly conductive.",
    model = "models/gibs/metal_gib4.mdl",
    scrapValue = 250,
    lootChance = 0.1,
  },
  {
    id = "city_scanner_core",
    name = "City Scanner Core",
    description =
    "The optical processing unit ripped from a downed City Scanner. Still flickers with a faint blue light.",
    model = "models/gibs/scanner_gib05.mdl",
    scrapValue = 750,
    lootChance = 0.075,
  },
  {
    id = "pulse_cell",
    name = "Pulse Cell",
    description =
    "A depleted energy cell from a Combine pulse weapon. Enough residual charge to be worth something to the Resistance.",
    model = "models/items/battery.mdl",
    scrapValue = 500,
    lootChance = 0.125,
  },
  {
    id = "stalker_neural_implant",
    name = "Stalker Neural Implant",
    description = "A crude cybernetic chip extracted from a Stalker. Disturbing to hold. Valuable to the right engineer.",
    model = "models/computergibs.mdl",
    modelScale = 0.5,
    scrapValue = 1200,
    lootChance = 0.05,
  },
  {
    id = "synth_hydraulic_fluid",
    name = "Synth Hydraulic Fluid",
    description =
    "A sealed vial of lubricant harvested from a Combine Synth. Used in reverse-engineering Combine technology.",
    model = "models/props_junk/garbage_plasticbottle001a.mdl",
    scrapValue = 900,
    lootChance = 0.09,
  },
  {
    id = "advisor_membrane_sample",
    name = "Advisor Membrane Sample",
    description = "A leathery strip of tissue from a Combine Advisor. Biologically unlike anything on Earth.",
    model = "models/combine_helicopter/bomb_debris_1.mdl",
    modelScale = 0.5,
    scrapValue = 2000,
    lootChance = 0.025,
  },
  {
    id = "overwatch_data_chip",
    name = "Overwatch Data Chip",
    description = "Encrypted memory pulled from a terminal or soldier. The Resistance can always use intel.",
    model = "models/computergibs.mdl",
    scrapValue = 1500,
    lootChance = 0.06,
  },
  {
    id = "headcrab_venom_gland",
    name = "Headcrab Venom Gland",
    description =
    "Carefully extracted from a headcrab. Dr. Kleiner has been offering good money for live samples — this is the next best thing.",
    model = "models/gibs/antlion_gib_small_1.mdl",
    modelScale = 0.5,
    scrapValue = 600,
    lootChance = 0.11,
  },
  {
    id = "antlion_extract_sac",
    name = "Antlion Extract Sac",
    description = "A pressurized sac of antlion pheromones. Useful for extraction teams navigating infested areas.",
    model = "models/gibs/antlion_gib_large_3.mdl",
    modelScale = 0.5,
    scrapValue = 800,
    lootChance = 0.1,
  },
  {
    id = "barnacle_adhesive_sample",
    name = "Barnacle Adhesive Sample",
    description =
    "A severed barnacle tongue coated in its impossibly sticky secretion. Industrial applications unknown but promising.",
    model = "models/props_lab/jar01b.mdl",
    modelScale = 0.5,
    scrapValue = 450,
    lootChance = 0.125,
  },
  {
    id = "combine_optical_lens",
    name = "Combine Optical Lens",
    description = "A precision lens array from a Combine surveillance unit. Cleaner optics than anything human-made.",
    model = "models/gibs/shield_scanner_gib6.mdl",
    modelScale = 0.5,
    scrapValue = 1100,
    lootChance = 0.075,
  },
  {
    id = "black_mesa_id_badge",
    name = "Black Mesa ID Badge",
    description =
    "A battered employee badge from the Black Mesa Research Facility. Old world relic. Some survivors pay well for them.",
    model = "models/props_lab/clipboard.mdl",
    modelScale = 0.5,
    scrapValue = 350,
    lootChance = 0.15,
  }
}

for _, itemData in pairs(items) do
  PLUGIN.registerRareItem(
    itemData.id,
    itemData.name,
    itemData.description,
    itemData.model,
    itemData.scrapValue,
    itemData.lootChance,
    itemData.modelScale
  )
end
