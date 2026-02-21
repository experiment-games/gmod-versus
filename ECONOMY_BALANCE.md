# Economy & Progression Balance Breakdown

> **Scope:** Covers all buyable item prices, scrap values, XP/leveling parameters, contract rewards,
> smuggler network economics, and identifies balance issues with suggestions.

---

## Table of Contents

1. [Starting State](#1-starting-state)
2. [Leveling & XP System](#2-leveling--xp-system)
3. [Buyable Items — Consumables](#3-buyable-items--consumables)
4. [Buyable Items — Defensive Gear](#4-buyable-items--defensive-gear)
5. [Buyable Items — Cosmetics](#5-buyable-items--cosmetics)
6. [Rare Items — Loot & Scrap Values](#6-rare-items--loot--scrap-values)
7. [Scrap Value Formula](#7-scrap-value-formula)
8. [Contract System — Costs & Rewards](#8-contract-system--costs--rewards)
9. [Smuggler Network — Fees & Risk](#9-smuggler-network--fees--risk)
10. [Other Services & Costs](#10-other-services--costs)
11. [Passive Systems](#11-passive-systems)
12. [Balance Analysis & Issues](#12-balance-analysis--issues)
13. [Suggested Balance Changes](#13-suggested-balance-changes)

---

## 1. Starting State

| Parameter | Value | Source |
| ----------- | ------- | -------- |
| Starting money | $500 | `sh_configuration.lua` |
| Starting inventory | 5× Health Vials (worth $500 at buy price) | `sh_configuration.lua` |
| Minimum drop amount | $25 | `sh_configuration.lua` |
| Inventory size | 25 slots | `sh_configuration.lua` |

A fresh player has $500 cash and starter supplies worth $500. Their immediate purchasing power covers roughly one Kevlar vest or 5–6 Health Vials.

---

## 2. Leveling & XP System

**Source:** `plugins/rewards/sh_init.lua`, `plugins/rewards/sv_init.lua`

### XP Income Sources

| Source | XP Gained | Condition |
| -------- | ----------- | ----------- |
| Damage dealt to NPC | `0.5 × damage` | Active contract required |
| NPC kill | 100 flat | Active contract required |
| Contract completion (base) | 1,000 | On extract |
| Contract completion per item held | +1,000 per item | Each Contract-category item in inventory at end |

> **Important:** XP from damage and kills is only awarded while the player has an active contract.
> Exploration, trading, and smuggling runs grant **no XP**.

### XP per Contract Run (Completion Multiplier)

| Items held at extraction | Total completion XP |
| -------------------------- | --------------------- |
| 0 items | 1,000 |
| 1 item | 2,000 |
| 2 items | 3,000 |
| 3 items | 4,000 |

### Level Thresholds (Total XP required)

Formula: `XP(level) = floor(1000 × (level − 1)^1.5)`

| Level | Total XP required | XP from previous level |
| ------- | ------------------- | ------------------------ |
| 1 | 0 | — |
| 2 | 1,000 | 1,000 |
| 3 | 2,828 | 1,828 |
| 4 | 5,196 | 2,368 |
| 5 | 8,000 | 2,804 |
| 6 | 11,180 | 3,180 |
| 8 | 19,798 | — |
| 10 | 27,000 | — |
| 15 | 52,026 | — |
| 20 | 82,820 | — |
| 30 | 158,114 | — |
| 50 | 343,000 | — |

### Sample XP per Contract (Combat estimate)

Assuming a 10-minute contract; enemy encounters dealing ~200 total damage to NPCs and 5 kills:

| Activity | XP |
| ---------- | ---- |
| 200 damage × 0.5 | 100 |
| 5 kills × 100 | 500 |
| Completion (1 item held) | 2,000 |
| **Total per run** | **~2,600** |

At this rate, reaching **level 10** (~27,000 XP) takes approximately **10–11 successful runs**.

---

## 3. Buyable Items — Consumables

### Health (sold by `medic` NPC)

| Item | Buy Price | Heal Amount | Sell Value (auto-calc 50%) | Scrap Value (25%) |
| ------ | ----------- | ------------- | ---------------------------- | ------------------- |
| Health Vial | $100 | 25 HP | $50 | $25 |
| Health Kit | $300 | 50 HP | $150 | $75 |

**Cost per HP healed:**

- Health Vial: $4/HP
- Health Kit: $6/HP

> Health Vials are the most efficient healing.

### Ammunition (sold by `armoury` NPC)

| Item | Buy Price | Rounds | $/Round | Scrap (25%) |
| ------ | ----------- | -------- | --------- | ------------- |
| 9x19mm | $800 | 60 | $13.3 | $200 |
| .45 ACP | $900 | ~36 | $25.0 | $225 |
| 12 Gauge | $1,000 | 32 shells | $31.3 | $250 |
| 5.45x39mm | $1,100 | 60 | $18.3 | $275 |
| 5.56x45mm | $1,100 | 60 | $18.3 | $275 |
| 7.62x39mm | $1,200 | 60 | $20.0 | $300 |
| 5.7x28mm | $1,300 | — | — | $325 |
| .44 Magnum | $1,400 | 36 | $38.9 | $350 |
| 7.62x51mm | $1,500 | 50 | $30.0 | $375 |
| 7.62x54mm | $1,600 | — | — | $400 |
| .50 AE | $1,800 | 35 | $51.4 | $450 |
| .338 Lapua | $2,000 | 30 | $66.7 | $500 |
| Smoke Grenade | $1,500 | 1 | $1,500 | $375 |
| Flashbang | $1,800 | 1 | $1,800 | $450 |
| Frag Grenade | $2,500 | 1 | $2,500 | $625 |
| 40mm Grenade | $3,000 | 1 | $3,000 | $750 |

**Weapons** are priced from their `weapon.Price` field in Chuck's Weaponry definitions.

---

## 4. Buyable Items — Defensive Gear

Note that currently these items cannot be purchased anywhere.

**Source:** `plugins/defensive_gear/items/`

| Item | Buy Price | Scrap (25%) | Sell (50%) | Slot | Damage Scale | Durability | Hitgroups Protected |
| ------ | ----------- | ------------- | ------------ | ------ | -------------- | ------------ | --------------------- |
| Kevlar | $450 | $112 | $225 | armor | 0.4 (–60%) | 100 HP | Chest, stomach, gear |
| Helmet | $4,000 | $1,000 | $2,000 | hat | 0.5 (–50%) | 50 HP | Head |
| Canvas Tank Helmet | $4,000 | $1,000 | $2,000 | hat | 0.4 (–60%) | 35 HP | Head |
| Helmet with Visor | $4,000 | $1,000 | $2,000 | hat | 0.5 (–50%) | 50 HP | Head |

> **Notable disparity:** Kevlar costs only $450 but helmets are $4,000. Head shots deal 2× damage
> (`Scale Head Damage = 2`), making helmets extremely valuable but priced as a luxury item.
> A full body-armoured player (Kevlar + Helmet) costs $4,450 upfront.

---

## 5. Buyable Items — Cosmetics

Note that currently these items cannot be purchased anywhere.

**Source:** `plugins/cosmetics/items/`

| Category | Price | Function |
| ---------- | ------- | ---------- |
| Glasses (all ~17 styles) | $2,000 | Cosmetic only |
| Hats (all ~13 styles) | $4,000 | Cosmetic only |
| Belt (Soviet) | $1,000 | Cosmetic only |
| Gas Mask | $4,000 | Cosmetic only |
| Gear Pouches (3 variants) | $1,000 each | **-8 inventory slots** (expand capacity) |
| Backpacks (7 variants) | $9,000–$10,000 | **–35 inventory slots** (expand capacity) |

Sell value for cosmetics = 50% of buy price (auto-calculated).

> **Backpacks** are the only cosmetics with mechanical effect. At $9,000–$10,000 each
> they are the most expensive buyable items in the game.

---

## 6. Rare Items — Loot & Scrap Values

Note that currently these items cannot be purchased anywhere.

**Source:** `plugins/rare_items/sh_init.lua`

Rare items drop during contract NPC kills. They scrap at **100% of their `cost` value** (not 25%),
making them pure money-from-playtime when sold to the Scrapper NPC.

| Item | Scrap Value | Loot Chance (per NPC kill roll) | Expected value per kill |
| ------ | ------------- | -------------------------------- | ------------------------ |
| Black Mesa ID Badge | $350 | 15.0% | $52.5 |
| Combine Alloy Scrap | $250 | 10.0% | $25.0 |
| Barnacle Adhesive Sample | $450 | 12.5% | $56.3 |
| Pulse Cell | $500 | 12.5% | $62.5 |
| Headcrab Venom Gland | $600 | 11.0% | $66.0 |
| Antlion Extract Sac | $800 | 10.0% | $80.0 |
| Synth Hydraulic Fluid | $900 | 9.0% | $81.0 |
| Combine Optical Lens | $1,100 | 7.5% | $82.5 |
| City Scanner Core | $750 | 7.5% | $56.3 |
| Overwatch Data Chip | $1,500 | 6.0% | $90.0 |
| Stalker Neural Implant | $1,200 | 5.0% | $60.0 |
| Advisor Membrane Sample | $2,000 | 2.5% | $50.0 |

Rolling all rare items simultaneously (per NPC kill):

- **Average total rare income per kill ≈ $710** (sum of all expected values above)
- This stacks with ammo drops (30–40% chance of your current ammo type)
  and health vial drops (20–25% chance)

---

## 7. Scrap Value Formula

**Source:** `plugins/npc/sh_init.lua`

```lua
scrap_value = max(1, floor(item.cost × scrapFraction))
```

| Item category | `scrapFraction` | Scrap value relative to buy |
| --------------- | ----------------- | ----------------------------- |
| Most items (default) | 0.25 | 25% of buy price |
| Rare items | 1.0 | 100% of buy (their entire purpose) |
| Items with custom `getScrapFraction()` | varies | e.g., rarity modifier: 1.1×–2.0× |

Sell value (shop sell-back) = **50%** of buy price (auto-calculated in `sh_init.lua`).

---

## 8. Contract System — Costs & Rewards

**Source:** `plugins/contracts/sh_init.lua`, `plugins/rewards/sh_init.lua`

### Fees

| Action | Cost |
| -------- | ------ |
| Re-roll contracts | $5,000 |
| Re-roll cooldown | 60 seconds |

### XP Rewards (detailed in section 2)

- 100 XP per kill + 0.5 × damage dealt
- 1,000 XP base on completion (×N multiplier from items held)

### Item Loot During Contracts

Per NPC killed, rolls fire independently:

| Drop | Chance |
| ------ | -------- |
| Health Vial | 20–25% |
| Ammo (current weapon type) | 30–40% |
| Any rare item (combined rolls) | Each rolls independently at above rates |

> Contracts are the **only XP source** and the **main item loot source**.
> Failing (dying) ends the contract with no XP or items, and forces a fresh contract.

---

## 9. Smuggler Network — Fees & Risk

**Source:** `plugins/smuggler_network/sh_init.lua`

### Runners

| Runner | Fee | Success modifier | Heat gain modifier |
| -------- | ----- | ----------------- | ------------------- |
| Rookie | $50 | +0.10 (worse) | 1.0× |
| Veteran | $200 | −0.10 (better) | 1.0× |
| Fixer | $500 | −0.05 (slightly better) | 0.5× (less heat) |

### How risk works

```lua
effectiveRisk = route.baseRisk + (heat / 100) × 0.40 + runner.successModifier
effectiveRisk = clamp(0.05, 0.95)
```

- Roll > `effectiveRisk` → **Success**: full reward (route range)
- Roll > `effectiveRisk × 0.5` → **Partial**: 30% of normal reward
- Roll ≤ `effectiveRisk × 0.5` → **Burned**: $0

### Heat mechanics

| Heat level | Threshold |
| ------------ | ----------- |
| Cool | 0 |
| Warm | 26 |
| Hot | 51 |
| Burned (locked) | 76 |
| Max | 100 |

- Heat decays from 100 → 0 in **30 minutes** real time
- Bribe base cost: $100 + heat × $3 multiplier (per node)

---

## 10. Other Services & Costs

| Service | Cost | Source |
| --------- | ------ | -------- |
| Vortigaunt weapon upgrade | $5,000 | `plugins/vortigaunt_services/sh_init.lua` |
| Housing room (base) | $1,000 × priceScale | `plugins/housing/sh_init.lua` |
| Furniture (material cost) | N× Raw Furniture Material items | `plugins/furniture_builder/sv_init.lua` |

Raw Furniture Material drops from NPC kills during active contracts at a **15% chance** each.

---

## 11. Passive Systems

**Source:** `plugins/health_regeneration/sh_init.lua`

| Parameter | Value |
| ----------- | ------- |
| Regen delay after damage | 10 seconds |
| Regen rate | 1 HP/sec |
| Regen cap | 60% of max HP |

Players regenerate up to 60 HP passively between fights. Health items are needed to reach
full HP (100) before entering dangerous situations.

---

## 12. Balance Analysis & Issues

### 12.1 XP — Only Earned During Contracts

All XP comes from active-contract gameplay. Players who spend time trading, using the
smuggler network, furnishing their hideout, or socializing earn **zero XP**. This creates a
sharp divide: active contract players level up while passive players are permanently locked at
level 1 regardless of hours played.

**Impact:** Level has little meaning for non-combat players.

---

### 12.2 Starting Money vs. Early-Game Costs

| Item | Cost | % of starting $500 |
| ------ | ------ | -------------------- |
| Kevlar | $450 | 90% |
| Health Vial | $100 | 20% |
| Any ammo pack | $800–$3,000 | 160–600% |

A new player cannot afford ammo for a weapon. Contract loot compensates somewhat (ammo drops
30–40%), but the player must enter combat with only their starter vials, no vest (if they
bought anything else), and no ammo refill.

**Impact:** First contract is by far the most dangerous and punishing.

---

### 12.3 Helmet vs. Kevlar Price Disparity

Head damage is scaled 2× (`Scale Head Damage = 2`). A helmet costing $4,000 provides
critical protection but is inaccessible early. Kevlar ($450) protects the torso only.
The price gap (10×) is steep:

- Kevlar: $450 → immediately affordable
- Helmet: $4,000 → requires ~4–8 successful contract completions to afford

Players are effectively forced into headshot vulnerability for a long time.

---

### 12.4 Re-roll Fee is Prohibitive Early

The $5,000 re-roll fee is 10× the starting money and costs more than the richest ammo pack.
New players cannot re-roll until after several contracts. This removes agency when the
presented contracts are hard or unsuitable for a player's loadout.

---

### 12.5 No Level-Gated Progression

Levels don't gate anything — items, contracts, and services are accessible to all players
regardless of level. The XP/level system is purely cosmetic/prestige with no mechanical
feedback. Players have little reason to pursue the level track beyond acknowledgement.

---

### 12.6 Scrap Value Inconsistency

Most items scrap at 25% while rare items scrap at 100%. This means:

- Buying a $1,100 ammo pack and scrapping it yields $275 — a loss of $825.
- Looting a $2,000 Advisor Membrane Sample yields the full $2,000.

The strong disparity incentivises players to focus exclusively on looting rare items rather
than purchasing and using consumables, since purchased items are economically "toxic" to
scrap.

---

### 12.7 Backpacks are Disproportionately Expensive

Backpacks cost $9,000–$10,000 but provide a purely practical benefit (35 extra inventory
slots). Players who loot heavily need inventory space, but the price is comparable to a
Vortigaunt weapon upgrade. A player with a full looting build may prioritise a backpack over
a helmet.

---

### 12.8 Smuggler Network Has No XP Component

Smuggler runs take real time and cost upfront money (route cost + runner fee) but yield only
cash and possibly items. The significant investment in the smuggler network (risk, time,
money) has no XP payoff, compounding the issue in 12.1.

---

### 12.9 Contract Completion XP Scaling Breaks at Item Counts

With 3+ contract items the bonus XP becomes linear and large:

| Items | XP | notes |
| ------- | ---- | ------- |
| 0 | 1,000 | Normal |
| 1 | 2,000 | 2× |
| 2 | 3,000 | 3× |
| 5 | 6,000 | 6× |
| 10 | 11,000 | 11× |

Ten items gives 11× base XP from a single contract. In a contract with a big ammo
cache this could be heavily exploited, rushing to L10 in 2–3 successful runs.

---

### 12.10 Health Vials Are Underpriced vs. Health Kits

- Health Vial: $100 / 25 HP = **$4/HP**
- Health Kit: $300 / 50 HP = **$6/HP**
- Health Kits cost 50% more per HP and take the same inventory slot.

Health Kits are a worse purchase at all times unless inventory slot conservation matters.

---

## 13. Suggested Balance Changes

### 13.1 Add Non-Contract XP Sources

Give XP for activities outside contracts to make levels meaningful for all playstyles:

- Smuggler run success: **+250–500 XP** (scales with route difficulty)
- Housing room purchase: **+100 XP one-time** per room
- Furniture built: **+25 XP** per piece
- Trade with NPC: **+10 XP per $1,000 spent** (capped)

### 13.2 Raise Starting Money to $1,000–$1,500

This allows new players to purchase Kevlar ($450) + at least one ammo pack ($800–$1,100)
before their first contract. Alternatively, add one ammo pack matching the starting weapon
to the default inventory.

> Suggested: `Default Money = 1500`, add `1× ammo_9x19` to `Default Inventory`

### 13.3 Level-Gate Expensive Items or Add Level Discounts

Add a `minLevel` field to items and lock expensive items behind levels:

- Helmet: `minLevel = 5` (roughly 5 successful contracts)
- Backpacks: `minLevel = 10`
- Vortigaunt upgrade: `minLevel = 8`

Alternatively, add a flat discount based on level to reward progression without hard locks:

```lua
effective_cost = base_cost × max(0.5, 1 - (level - 1) × 0.02)
```

This gives a 2% discount per level, capping at 50% off at level 25.

### 13.4 Reduce Re-roll Fee or Make It Scale with Level

- **Option A:** Lower to $1,000–$2,000 flat
- **Option B:** Make it `500 × level` (scales up as players accumulate wealth)
- **Option C:** First re-roll each server session is free; subsequent ones cost $5,000

### 13.5 Raise Health Kit Efficiency

Either lower Health Kit cost to $200, or increase its heal to 75–100 HP:

- New: Health Kit $300 / 75 HP = $4/HP (ties Vial)
- Or: Health Kit $200 / 50 HP = $4/HP

### 13.6 Cap the Contract Completion XP per Item

Cap the number of items that contribute to the XP multiplier (e.g., max 3 items = 4× cap)
to prevent potential XP exploitation:

```lua
-- In sv_init.lua:
local maxMultiplierItems = 3
contractItemMultiplier = math.min(contractItemMultiplier, maxMultiplierItems + 1)
```

### 13.7 Increase Default Scrap Fraction for Ammo / Consumables

Raising ammo scrap from 25% to 40% reduces the "toxicity" of stockpiling ammo across
contracts. Players no longer feel punished for buying excess supply.

| Category | Current fraction | Suggested |
| ---------- | ----------------- | ----------- |
| Ammo | 0.25 (25%) | 0.40 (40%) |
| Grenades | 0.25 (25%) | 0.35 (35%) |
| Health items | 0.25 (25%) | 0.30 (30%) |
| Defensive gear | 0.25 (25%) | 0.25 (keep — high sell-back already) |
| Cosmetics | 0.25 (25%) | 0.15 (15% — cosmetics shouldn't be liquid) |

### 13.8 Add a Kevlar Helmet at $1,500–$2,000

Introduce a mid-tier "ballistic helmet" with lower protection (damageScale ~0.6, 25 HP
durability, no visor) bridging the $450 Kevlar and $4,000 full helmet gap.

### 13.9 Add XP Bonuses for Smuggler Network Activity

Give XP directly from successful smuggler runs to allow passive playstyles to progress.
For example:

- Successful full run: **+300 XP**
- Partial success: **+100 XP**
- Burned run: **+0 XP** (punishment preserved)

### 13.10 Reduce Backpack Price or Add a Budget Option

Introduce a $4,000 small backpack that grants **+15 inventory slots** as a stepping stone
before the $9,500 military backpacks. This opens inventory expansion to mid-game players
rather than late-game only.

---

## Quick Reference: Economy Flow

```txt
Contracts (PvE)
  └─ Kills/Damage → XP, item drops (rare items, ammo, health vials)
  └─ Completion → XP spike (×N items held)
  └─ Failure (death) → nothing

Rare Items (looted)
  └─ Scrap at Scrapper NPC → 100% cash return ($250–$2,000 each)

Ammo / Health (purchased)
  └─ Scrap at Scrapper NPC → 25% cash return (not recommended)
  └─ Consume in contract → sustain combat

Smuggler Network
  └─ Invest (route cost + runner fee)
  └─ Wait (real time)
  └─ Receive cash reward + possible item (no XP currently)

Cash Sinks
  ├─ Ammo: $800–$3,000/pack
  ├─ Health: $100–$300/item
  ├─ Kevlar: $450 (frequent repurchases as it degrades)
  ├─ Helmets: $4,000
  ├─ Backpack: $9,000–$10,000
  ├─ Vortigaunt upgrade: $5,000
  ├─ Housing room: $1,000+ per room
  └─ Contract reroll: $5,000
```
