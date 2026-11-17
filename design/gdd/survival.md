# Survival layer: needs, bag, wounds, skills

Status: in progress (requested 2026-11-15). Code: `scripts/survival/`. Data: `data/survival/`.
Inspired by Project Zomboid's survival loop, kept light so it supports the crime-and-empire game
instead of replacing it. All crime stays fictional and game-oriented.

## 1. Overview

Four small systems share one controller (`SurvivalController`) and one save section (`survival`):

| System | Class | What it adds |
|---|---|---|
| Needs | `Needs` | Food, water and rest run down over game time; eat, drink and sleep to refill. |
| Bag | `Inventory` | A weight-limited bag, a stash at the safehouse, things to find by searching. |
| Wounds | `Wounds` | Gunshots can leave a bleeding wound that needs a bandage and time. |
| Skills | `Skills` | Shooting, driving, fitness, hustle and scavenging improve with use. |

## 2. Player Fantasy

You live here. You get hungry on a long day on the corner, you buy a gatsby at the cafe, you go home
to sleep. You check the bins behind the shops when money is short. A fight leaves a mark that you
have to look after. The longer you run these streets the better you get at it.

## 3. Detailed Rules

### Needs
- Three meters, each 100 (fine) down to 0 (empty): `food`, `water`, `rest`.
- They drain per game hour while the game runs (not while a menu pauses the clock). Sprinting drains
  water faster. Sleeping drains food and water at half rate.
- Below `warn_level` the HUD shows the need and a one-off message. At 0:
  - food or water at 0: health no longer regenerates and drops slowly to `starve_floor` (never a knock-out);
  - rest at 0: no sprinting, and walking is `tired_walk_factor` slower.
- Eat and drink by using items from the bag. Shops (cafe, spazas) sell food and drink from a menu.
- Sleep in your safehouse bed: the clock moves forward `sleep_hours` (or less if you are barely tired),
  rest refills, bandaged wounds heal. You cannot sleep with police heat on you or while wounded and bleeding.

### Bag and looting
- Items come from `data/survival/items.json` (id, name, kind, weight, price, effects).
- The bag holds up to `bag_capacity` kg. An item that does not fit is refused with a message.
- The safehouse stash holds up to `stash_capacity` kg; move items in and out from the safehouse menu.
- Search spots (bins, crates behind shops, cupboards in dens you raid) each use a loot table.
  A search takes `search_seconds`; a spot refills `refill_days` game days after it was emptied.
  What a spot holds is fixed by its id and the day it refilled (same result on every device and after loading).
- Junk and valuables sell at shops for their `sell` price.
- Street vendors (fruit stalls, the snoek bakkie in Westridge) sell through the same menu with their own stock
  (`shop_stock.fruit_stall`, `shop_stock.snoek_bakkie`).
- The bag opens with I (pad: D-pad right, touch: BAG): use, drop, and (at the safehouse) stash.

### Wounds
- A gunshot that hits the player has a `wound_chance` to leave a bleeding wound (at most `max_wounds`).
- Each bleeding wound: health regeneration is off, health drops `bleed_per_second`, walking is
  `limp_per_wound` slower (sprinting is off from two wounds).
- A bandage turns one bleeding wound into a bandaged one at once. Bandaged wounds do not bleed or limp;
  they heal after `heal_hours` game hours, or at once when you sleep.
- Bleeding never knocks you out by itself below `bleed_floor` health; a further hit can.
- Knocked out: you wake at the safehouse as before, with every wound bandaged.

### Skills
- Five skills, levels 0 to `max_level`: shooting, driving, fitness, hustle, scavenging.
- XP comes from doing: hitting a target, distance driven, distance sprinted, a completed sale, a search.
- Each level gives a small bonus (see Formulas). Levels never go down.
- The phone shows the levels and progress; a level-up shows a banner.

## 4. Formulas

- Drain per game hour: `need -= drain[need] * hours * modifier`, clamped to 0..100.
  `modifier` = `sprint_water_factor` for water while sprinting; 0.5 for food and water while asleep;
  `1 - fitness_level * fitness_rest_bonus` for rest.
  Example: food 100, drain 2.5/h, 8 h awake -> 80.
- XP needed for level `n` (1-based): `xp_base * n^xp_power`. With `xp_base` 100 and `xp_power` 1.5:
  100, 283, 520, 800, 1118.
- Skill bonuses per level: shooting `-spread_bonus` shot spread; driving `+drive_bonus` top speed;
  fitness `+sprint_bonus` sprint speed and less rest drain; hustle `+price_bonus` sale price;
  scavenging `+find_bonus` chance of an extra item.
- Walk speed factor: `(1 - limp_per_wound * bleeding_wounds) * (tired_walk_factor if rest == 0 else 1)`, never below 0.5.
- Loot roll for a spot: random generator seeded with `hash(spot_id) + refill_day`; each table entry is rolled once
  against its `chance`; scavenging adds one extra roll with probability `find_bonus * level`.

## 5. Edge Cases

- Loading an old save without a `survival` section: all needs start at 100, bag holds the starter items, no wounds, skills 0.
- Bag full when buying: the purchase is refused and no cash is taken.
- Using an item with no effect for the current state (bandage with no bleeding wound): refused, item kept.
- Sleeping with heat or while bleeding: refused with the reason.
- Driving: needs still drain; wounds still bleed; no sprint drain.
- Knocked out with food/water at 0: you wake with each raised to `wake_minimum` so you are not stuck.
- A search interrupted by moving away or by a menu: nothing is taken, the spot stays full.
- Survival can be switched off in Settings ("Survival needs"): needs stop draining and their effects stop;
  the bag, wounds and skills keep working.

## 6. Dependencies

- Uses: `SimClock` (game hours), `Health` (regen switch, damage), `Player` (speed factors, sprint lock, shot hits),
  `DealingController` (sale signal for hustle XP, price bonus), `DrivableCar` (distance, speed bonus),
  `CombatSystem` (spread bonus), `HUD` (meters, menu, banner), `GameSession` (save/load, shop and safehouse menus),
  `InteriorSystem` (bed in the safehouse), `District` (search spots).
- Used by: missions may later require items or skill levels (not in this slice).

## 7. Tuning Knobs

All in `data/survival/survival.json` unless noted.

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `drain.food` / `drain.water` / `drain.rest` | 2.5 / 4 / 4 per hour | 1 to 8 | How often you must eat, drink, sleep |
| `warn_level` | 25 | 10 to 40 | When the HUD starts nagging |
| `starve_floor` | 20 hp | 5 to 50 | How dangerous an empty need is |
| `starve_per_minute` | 0.5 hp | 0.1 to 2 | Speed of that health loss |
| `tired_walk_factor` | 0.85 | 0.6 to 1 | Walking speed when exhausted |
| `sprint_water_factor` | 2 | 1 to 4 | Extra thirst from running |
| `sleep_hours` | 8 | 4 to 10 | Length of a full sleep |
| `bag_capacity` / `stash_capacity` | 10 / 60 kg | 5 to 30 / 20 to 200 | How much you can carry and keep |
| `search_seconds` / `refill_days` | 2 / 2 | 1 to 5 / 1 to 7 | Pace of scavenging |
| `wound_chance` / `max_wounds` | 0.35 / 3 | 0 to 1 / 1 to 5 | How often fights leave wounds |
| `bleed_per_second` / `bleed_floor` | 0.15 / 15 hp | 0.05 to 0.5 / 5 to 40 | Urgency of bandaging |
| `limp_per_wound` / `heal_hours` | 0.1 / 6 | 0 to 0.2 / 2 to 24 | Cost of being hurt |
| `xp_base` / `xp_power` / `max_level` | 100 / 1.5 / 5 | 50 to 300 / 1 to 2 / 3 to 10 | Speed of skill growth |
| per-skill bonuses | 0.08 / 0.03 / 0.03 / 0.03 / 0.1 | 0 to 0.15 | Strength of each level |
| item `weight`, `price`, `sell`, `effects` (`items.json`) | per item | | Economy of food and loot |
| loot `chance` (`loot_tables.json`) | per entry | 0 to 1 | What searching gives |

## 8. Acceptance Criteria

Each has a check in `tests/run_tests.gd`.

1. Needs drain with game time at the data rates; sprinting drains water faster.
2. Eating and drinking raise the right meter and consume the item; nothing rises above 100.
3. Food or water at 0 stops regeneration and lowers health to the floor, never below.
4. Rest at 0 blocks sprinting; sleeping refills rest and moves the clock.
5. The bag refuses items over capacity; buying with a full bag takes no cash.
6. A search gives the same items for the same spot and day, empties the spot, and refills after `refill_days`.
7. A hit can add a bleeding wound; bleeding lowers health to the floor; a bandage stops it; time or sleep heals it.
8. XP raises levels at the formula's thresholds; each bonus is applied where the Formulas say.
9. Saving and loading keeps needs, bag, stash, wounds, searched spots and skills; old saves load with defaults.
10. The bag screen works with keyboard, gamepad and touch.
