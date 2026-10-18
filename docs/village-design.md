# Veliron's Outpost: the village (design)

Status: **built; describes the current code**. Tested by tests/sim_bot.gd, tests/rat_bot.gd
(villager HP, tear-down, the warnings) and tests/build_bot.gd (placing).
Scope: one player's village. That covers its resources, huts and villagers, the buildings
outside the walls, the warnings and the villager list. Every number lives in
`scripts/core/config.gd`. Military units, barracks
sorties and the training grounds' training are in docs/military-design.md. The map, special
objects and mines are in docs/world-design.md. Co-op transfers (caravans, sending units) are
in docs/multiplayer-design.md.

## 1. Summary

- **Three resources:** gold, food and building material.
  - Food feeds villagers and recruits them.
  - Material builds.
  - Gold buys soldiers (and material, at a poor rate).
- **The village:** a walled 5×5 block with 9 huts. One villager per intact hut, so the huts
  cap the population.
- **Villagers** work on their own. The player picks *where* buildings go. Farmers and
  foresters take free workplaces by themselves.
- **Defeat:** a village falls with no villagers or no intact huts.

## 2. Resources

| Resource | Start (`START_RESOURCES`) | Comes from | Spent on |
|---|---|---|---|
| Gold | 150 | kills (`gold_on_kill`, at once), corpses brought home (`gold_on_collect`), calling a wave early, treasures and lairs, mines | military units and upgrades, barracks / training grounds, buying material, the Spatial Archmage |
| Food | 120 | farms (carried home by farmers), corpses (`food_on_collect`), shipwreck treasures | recruiting villagers, upkeep |
| Material | 70 | foresters, buying it, tear-down and cancel refunds, treasures and lairs | buildings, tower / barracks / gate / wall upgrades, repairs, rebuilding huts |

- **Upkeep:** `FOOD_UPKEEP` 0.05 food per villager per second (3 per minute). Every villager
  eats, the miner and the Spatial Archmage too; the hero and soldiers eat nothing.
- **Starvation:** while food is at 0, a timer runs. Every `STARVATION_INTERVAL` (15 s) a
  random villager dies ("of starvation", Important) and a toast says so. The timer resets as
  soon as there is food again.
- **Buying material** (tap the material counter): `MATERIALS_TRADE`, 10 material for 15 gold.
  The dialog offers 1 or 5 bundles (`Economy.buy_materials`, command `buy_materials`).
- **Calling a wave early** pays `EARLY_CALL_GOLD_PER_SECOND` (0.5) gold for every second left
  on the countdown, to every village (`Waves.early_call_bonus`).
- **Food flow** shown next to the food (per minute): worked farms' average output minus
  upkeep (`Population.food_per_second`). Corpses and rats aren't counted.
- Rats at a gate eat food, and thieves steal gold. See the enemy rules in CLAUDE.md.

## 3. Village, huts, raids and defeat

- **Layout** (`VILLAGE_LAYOUT`): T tower, W wall, G gate, V hut.
  ```
  TWGWT
  WVVVW
  GVVVG
  WVVVW
  TWGWT
  ```
  - That gives 9 huts, 4 gates and 4 corner wall towers.
  - Wall towers take units like watchtowers, with range 4.8 (`TOWER_RANGE.wall_tower`).
  - Walls, gates and wall towers have HP and hold enemies back until they are broken; gates
    and walls level up to 3 for more HP (docs/siege-design.md).
- **Inside the walls is safe** while no enemy is in there. Villagers there don't flee and
  can't be hurt (`Civilian.inside_walls`), so builders rebuild huts during an attack. Once an
  enemy has broken in, villagers walking inside are exposed until it is gone
  (`Siege.breached`); those at home stay safe.
- **Huts:**
  - Every villager lives in exactly one intact hut (`Hut.resident`).
  - Recruiting needs a free hut ("No free hut (n/m)"). The cap is
    `Population.cap() = intact huts`.
- **Raids:** an enemy that breaks in walks to the nearest intact hut and burns it (huts have
  1 HP; `Game.on_enemy_reached_gate`, docs/siege-design.md §5), on every difficulty. Only
  that hut's resident dies; an empty hut costs no life. The exceptions belong to the enemies:
  - rats eat food instead;
  - thieves steal gold;
  - small slimes burn one only with their `raid_chance`;
  - a vampire bat does nothing.
- **Rebuilding:** a ruined hut can be rebuilt on its lot for `REPAIR_SHARE` of the hut's
  price (80 → 40 material, 10 s; `Hut.rebuild_cost`, `Construction.order_rebuild`). Builders take hut rebuilds before any other job in the queue (§5).
  Cancelling the rebuild (§7) turns it back into a ruin and refunds the unbuilt share.
  - The villager list has **Rebuild all huts (n)**. It queues as many ruined huts as the
    material pays for, nearest the centre first, and says how many are left over.
- **Defeat:** a village falls when it has no villagers or no intact huts
  (`Village.is_standing`). In single player that ends the game. In co-op see
  docs/multiplayer-design.md: a fallen village can stand again, and the game is lost when all
  have fallen.

## 4. The start

- **Villagers** (`START_CIVILIANS`): builder, farmer, forester, explorer. There is no explorer
  without fog (`Game.disable_fog`: only the title backdrop and tests).
- **Free buildings** (`START_BUILDINGS`): a farm and a worker camp, finished
  (`Construction.build_starting`).
  - Both are placed on the finished map; the map keeps no room for them. Each goes on the
    nearest free spot within `START_BUILDING_RADIUS` (9) tiles of the centre (square), not
    within 2 tiles of a gate, not hidden behind the walls or a tree on screen, and reachable
    on foot. The farm needs farmland (no steppe, swamp, ash, sand or trees under it).
  - The camp also needs at least 6 trees within 5 tiles and prefers the forest's edge. The
    tutorial pins it (`TUTORIAL.camp_tile`).
  - Where no spot fits, the village starts without that building (logged, Info: "No room
    for a farm near the village: it starts without one"). On a harsh map (ash, desert,
    swamp, dense forest) that is a harder start on purpose: the farmer waits for a farm.
  - The starting farmer and forester take them at once (automatic assignment, §6).
- `START_REVEAL_RADIUS` 7.5 tiles around the centre start explored. Each starting building
  reveals 2.5 tiles around it.
- The tutorial starts smaller (docs/tutorial-design.md).

## 5. Villagers

| Role | Cost | Speed (tiles/s) | Works at | Notes |
|---|---|---|---|---|
| Builder | 30 food | 1.7 | construction sites | rests `BUILDER_REST` 3 s at home between jobs |
| Farmer | 25 food | 1.5 | a farm (`works_at`) | rests `FARMER_REST` 4 s; harvesting takes `HARVEST_TIME` 2.5 s |
| Forester | 25 food | 1.5 | a worker camp (`works_at`) | see below |
| Explorer | 25 food | 2.0 | — | reveals `EXPLORER_REVEAL` 2.6 tiles |
| Gatherer | 30 food | 1.6 | — | see below |
| Miner | 30 food | 1.5 | a mine | locked until anyone walks up to a mine (`LOCKED.miner`) |
| Spatial Archmage | — | 0.6 | — | can't be recruited |

- **Every villager** has `CIVILIAN_HP` 20 HP.
  - At home they heal `CIVILIAN_REGEN` 2 HP/s.
  - Outside, any enemy that gets at them hurts them; they never fight back. At 0 HP they die
    (Important, with the cause).
  - **Fleeing:** outside the walls, a villager checks 4 times a second for an enemy within
    `EVADE_RADIUS` 4.5 tiles. If there is one, they shout "Enemies!", drop or pause the job,
    run home and then rest `EVADE_REST` 6 s.
- **Builder** (`BuildJob`, shared with the hero at half speed):
  - claims the oldest hut rebuild in the queue, else the oldest other job (FIFO;
    `Construction.claim`), walks there and builds. Only picking a new job looks at this (also
    after fleeing, which gives the job back); work under way is never taken away;
  - one second of work is one second of the building's `build_time`;
  - walks home and rests. A site left halfway keeps its progress.
  - The same job does tower and barracks upgrades, ruined-tower restorations, hut rebuilds and
    tear-downs.
- **Farmer:**
  - walks to their farm, takes its stored food (whole units), carries it home and rests;
  - fleeing, they still deliver the food they carry when they get home;
  - the farm grows food only while it has a farmer and no rats are on it (§7).
- **Forester:**
  - camp → nearest tree within `FORESTER_SEARCH_RADIUS` 10 tiles of the camp → chops
    `FORESTER_CHOP_SESSION` 4 s → walks back and drops `FORESTER_MATERIAL_PER_TRIP` 3 material
    at the camp → rests `FORESTER_REST` 3 s at the camp → same tree again;
  - a tree falls after its total chop time. Its tile becomes meadow and the forester moves on;
  - fleeing, he keeps his load and delivers it when he gets home (`Forester._deliver`).

  | Tree (`TREE_CHOP_TIME`) | Chop time | Trips (≈ material) |
  |---|---|---|
  | `tree_pine_0` | 20 s | 5 (15) |
  | `tree_pine_1` | 28 s | 7 (21) |
  | `tree_oak` | 36 s | 9 (27) |
  | `tree_dead` | 10 s | 3 (9) |
  | `stump_charred` | 8 s | 2 (6) |

- **Explorer** (`ExploreJob`, shared with the hero's Explore mode):
  - heads for the nearest unexplored tile and keeps pushing into the unknown from wherever it
    is (a greedy depth-first sweep);
  - turns back to fog nearer the village when its local frontier is much farther out than
    the village's nearest frontier (`EXPLORER_WANDER_FACTOR` 1.6, `EXPLORER_WANDER_SLACK` 8);
  - avoids fog another explorer is heading for (`EXPLORER_CLAIM_RADIUS` 7, penalty 30);
  - keeps away from monster camp guards: fog by a camp waits until the camp is cleared;
  - fog over forest, rock or water it can't enter is looked into from the nearest walkable
    edge.
- **Gatherer** (`GatherJob`, shared with the hero's Gather mode, who carries 2):
  - stays home until there are corpses;
  - only goes for **safe** corpses: no living enemy within `CORPSE_SAFE_RADIUS` 6 tiles, on
    land its village has explored;
  - takes up to `GATHERER_CAPACITY` 6 per trip, `GATHERER_LOOT_TIME` 1 s each, and rests
    `GATHERER_REST` 3 s;
  - at home each corpse pays its `gold_on_collect` and `food_on_collect` (a thief's corpse
    also pays the gold it stole);
  - a sack of loot the hero dropped is picked up first;
  - corpses rot after `CORPSE_LIFETIME` 240 s, and a wave's corpses go once the next wave is
    over.
- **Miner** (details in docs/world-design.md):
  - walks to the nearest free mine their village has found, and stays inside, safe (no
    fleeing);
  - earns `MINE_GOLD_RATE` 0.25 gold/s, paid in whole coins (the mine's panel shows the rate
    with two decimals);
  - one miner per mine: the first to arrive works it, a later one walks home unassigned;
  - still lives in a hut and dies with it.
- **Spatial Archmage:** a level 10 spatial mage becomes one (`ARCHMAGE_COST` 600 gold, needs a
  free hut; docs/military-design.md §7). It strolls just outside the walls, glowing faintly.
  Decoration for now.
- **Code:**
  - `Unit` → `Civilian` handles evasion, HP and home.
  - Each role has its own class: `Builder`, `Farmer`, `Forester`, `Explorer`, `Gatherer`,
    `Miner`, `Archmage` in scripts/units/.
  - The shared jobs are in scripts/units/jobs/.

## 6. Automatic worker assignment

- A role with `works_at` in `CIVILIANS` (farmer → `farm`, forester → `camp`) is a worker
  (`Config.worker_role`).
- Workers are always assigned automatically. A new worker, or one freed by a tear-down, takes
  the vacant finished workplace of its kind nearest the village
  (`Population.vacant_workplaces`). The recruit toast says where it went.
- A newly finished farm or camp takes an idle worker of its role (`assign_worker(..., true)`).
- The building panel can still **unassign** and **assign** by hand. A worker unassigned by
  hand stays idle until a workplace takes him.
- A workplace being torn down frees its worker, who takes another vacant one if there is one
  (`Population.free_workplace`).
- Miners aren't `works_at` workers: they pick a free mine themselves (`Population.free_mine`).

## 7. Buildings outside the walls

Every building has HP (`BUILDING_HP`). Enemies can wear it down; at 0 it is devastated and
does nothing until a builder repairs it, for building material (docs/siege-design.md). No
enemy goes for the buildings outside the walls yet, except the octopus's arms.

| Building | Size | Cost | Build time | What it does |
|---|---|---|---|---|
| Watchtower (`tower`) | 1×1 | 30 material | 8 s | holds one military unit; range 3.6 (+ level) |
| Farm (`farm`) | 3×3 | 50 material | 12 s | one farmer; grows food |
| Worker camp (`camp`) | 1×1 | 25 material | 6 s | one forester |
| Barracks (`barracks`) | 2×2 | 20 material + 30 gold | 16 s | benches for units that turn out (docs/military-design.md §5) |
| Training grounds (`training`) | 2×2 | 40 material + 40 gold | 14 s | one unit and the hero, who trains it with XP |
| Light stone (`lightstone`) | 1×1 | 20 material | 10 s | sees `LIGHTSTONE_SIGHT` 5.5 tiles, nobody inside |
| Hut (`hut`) | 1×1 | 40 material | 10 s | only rebuilt on its ruined lot (§3) |

- **Farm output** (`Farm.rate`): `FARM_RATE` 0.4 food/s (24 per minute) while it has a farmer
  and no rats.
  - **+20 %** (`ZONES.meadow.farm_bonus`) when more than half its tiles are meadow.
  - **+10 %** (`FARM_WATER_BONUS`) when any tile borders water.
  - Relics can add more (`relic_bonus("food")`).
  - It stores at most `FARM_CAPACITY` 40 food.
  - One plain farm feeds 8 villagers (0.4 / 0.05), so the full 9 huts need a bonus or a
    second farm.
- **Watchtower and wall-tower levels** (`TOWER_LEVELS`). A builder does the work while the
  tower keeps fighting. Levels add range only, plus decorations.

  | Level | Range bonus | Cost | Work time |
  |---|---|---|---|
  | 1 | — | — | — |
  | 2 | +0.8 | 30 material | 8 s |
  | 3 | +1.6 | 55 material | 12 s |

- **Barracks levels** (`BARRACKS_LEVELS`): the level adds benches and turn-out range.

  | Level | Benches | Range | Cost | Work time |
  |---|---|---|---|---|
  | 1 | 1 | 4.0 | — | — |
  | 2 | 2 | 5.0 | 60 material | 10 s |
  | 3 | 3 | 6.0 | 90 material | 14 s |

- **Placing** (`Construction.placement_error`, first failing rule wins). Every tile of the
  footprint must be:
  - in the map, and explored by this village;
  - outside the walls, and free of other buildings and map objects;
  - not road, trees, mountains, deep or shallow water, or lava;
  - not within `VOLCANO_NO_BUILD` + 1 (4) tiles of a crater's centre tile (`MapData.near_crater`);
  - for a farm, not desert terrain and not a `no_farms` zone (steppe, swamp, ash).

  Then:
  - towers and light stones block their tile (`SOLID_KINDS`), so one of the 8 tiles around
    them must be walkable and reachable from the village centre ("Nobody could get to it");
  - the price must be affordable.

  The player can't place a building for free; only the start's buildings and ruin
  restorations skip the checks.
- **Cancelling** (command `cancel_site`, `Construction.cancel`): a construction site's panel has
  *Cancel*, a tower's, barracks', gate's or wall's panel *Cancel upgrade* while an upgrade is
  ordered, any building's *Cancel repair* while a repair is.
  - The refund is the price paid × (1 − the work done), rounded down per resource
    (`Building.cancel_refund`, `refund_share`): all of it before a builder starts, nothing near
    the end. A hut rebuild paid half price, so it refunds from that.
  - The panel says what comes back ("... back if you cancel now"), or "Too far along to get
    anything back".
  - A cancelled site disappears; a cancelled hut rebuild turns back into a ruin; a cancelled
    upgrade leaves the building at its level.
- **Placing controls** (one building per pick, mouse / touch preview / dragging from the
  Build tab) are in CLAUDE.md "Controls" and tested by build_bot.
- **Code:**
  - `Building` (site / complete base, tear-down);
  - `Workplace` → `Farm`, `WorkerCamp`;
  - `MilitaryPost` → `Tower`, `Barracks`, `TrainingGrounds`;
  - `LightStone`, `Hut`, `StaticPiece` (walls, gates), all in scripts/buildings/;
  - `Construction` (scripts/systems/construction.gd) validates, places, keeps the FIFO job
    queue, handles upgrades, repairs, devastation, rebuilds and tear-downs.

## 8. Tear-down

- **Which buildings:** every building the player can place (`Construction.KIND_SCRIPTS`:
  watchtower, farm, camp, barracks, training grounds, light stone), also the free starting
  farm and camp. Huts, walls, gates and wall towers can't be torn down.
- **Ordering it** (*Tear down*, the last action in the panel; `order_tear_down`) stops the
  building at once:
  - units on it or marching to it walk back to the reserve (downed ones revive there);
  - its worker is freed and takes another vacant workplace of its kind;
  - an ordered upgrade is cancelled and refunded like a cancel (§7): its cost × (1 − the
    upgrade work done), rounded down.
  - so is an ordered repair.
- **The work:** a builder (or the hero in Build mode) comes as to a site and works
  `TEARDOWN_TIME_SHARE` (0.5) of the build time. The bar counts down and the building shows
  see-through.
- **The refund:** `TEARDOWN_REFUND` (0.33) of the material spent × the building's HP share,
  rounded down. The material spent is the price plus paid tower or barracks upgrades
  (`materials_spent`); gold is never refunded. A damaged building gives back less, a
  devastated one nothing (docs/siege-design.md §3).
  - Examples at full HP: a watchtower gives 9 material; a level 3 watchtower 37 ((30+30+55) × 0.33); a
    farm 16.
  - The free starting buildings also refund a third of their list price.
  - So does a restored ruined watchtower: `materials_spent` uses the full list price, so it
    refunds 9 (33 % of 30) though only 15 was paid.
- ***Stop tear-down*** spares it; units stay in the reserve.

## 9. Sight and fog

The fog has three states: unexplored (black), explored (terrain known, enemies hidden), and
under surveillance (clear). The rendering is `FogLayer`; the observers are anything in the
"observers" group.

| Who watches | Radius (tiles) | Constant |
|---|---|---|
| Intact hut | 4.0 | `HUT_SIGHT` |
| Gate (manned or not) | 3.0 | `GATE_SIGHT` |
| Any other finished building (walls, ruined huts too) | 3.0 + size / 2 (whole tiles): 3 for 1×1, 4 for 2×2 and 3×3 | `BUILDING_SIGHT` |
| Light stone | 5.5 | `LIGHTSTONE_SIGHT` |
| Manned tower | its range + 1.5 | `TOWER_SIGHT_BONUS` |
| Villagers and soldiers outside the walls | 4.0 | `UNIT_SIGHT` |

- Building sight is measured from the anchor tile (`Building.sight_radius`, `sight_center`):
  the centre of a 3×3, the top-left tile of a 2×2, not the footprint's edge.
- Every unit of ours outside also **explores** the fog within `UNIT_REVEAL` 1.8 tiles. Units
  that explore it are villagers, the hero, soldiers, summons and caravans.
- Explorers reveal `EXPLORER_REVEAL` 2.6 tiles.
- Only explorers and the hero in Explore mode *go looking* for fog.

## 10. Warnings

Both are red banners under the top bar, checked every 0.25 s in `Hud`. Their delays are in
config.gd and count real seconds, whatever the game speed; paused time doesn't count.

- **No builder** (`NO_BUILDER_DELAY` 5 s, `Hud.nobody_builds`):
  - shown when something waits in the build queue, the village has no builder, and the hero
    is alive but not in Build mode. While the hero is downed it doesn't show;
  - the text: "No builder: nothing will be built. Recruit a builder (Village tab) or set the
    hero to Build."
- **Food shortage** (`FOOD_SHORTAGE_DELAY` 5 s, `Hud.food_short`, `Hud.food_warning_text`):
  - shown when food has been at 0 with a negative food flow for 5 s. It sits under the
    builder warning when both show;
  - "Food shortage: villagers will starve." plus a tip, by what is missing:
    1. no working farm → "Build a farm (Build tab).";
    2. farms but no farmer → "Recruit a farmer (Village tab).";
    3. a farm without a farmer and a farmer without a farm → "Assign a farmer to a farm (tap
       the farm).";
    4. otherwise (every farm worked, say, farmers kept home by enemies) → no tip.

## 11. Villager list and Retire

- **Opening it:** the people button in the top bar (villagers / huts) opens it (`Hud`, the
  people panel).
  - On top: **Rebuild all huts (n)** with its cost (§3).
  - Then every villager by role (`CIVILIAN_ORDER`), with what they are doing now and their HP
    when hurt.
- **View** moves the camera to the villager, or to the village centre for those at home.
- **Retire** asks for confirmation. Then the villager leaves for good (Info: "... retired and
  left the village"). Their hut and workplace are free again, and nothing is refunded.
  - The last villager can't retire (`Population.retire_error`), or the village would fall.
- Buttons keep their size and sit centred in their row.

## 12. Code map

- `Village` (scripts/systems/village.gd): one player's village. It holds the `Economy`,
  `Population`, `Construction`, `Army`, the hero and the `EventLog`, plus the centre, walls,
  gates and home spawns. It also has `intact_huts()`, `relic_bonus()` and
  `is_standing()`.
- `Economy`: the three amounts, `spend` / `refund` / `add`, food consumption,
  `buy_materials`.
- `Population`: recruiting, spawning into a free hut, upkeep and starvation, kill / retire,
  worker and mine assignment.
- `Construction`: placement rules, sites, the job queue, upgrades, hut rebuilds, the starting
  buildings, tear-down.
- `Commands` (scripts/systems/commands.gd): every player action as a checked command
  (`place_building`, `recruit_villager`, `buy_materials`, `rebuild_hut`, `rebuild_all_huts`,
  `retire_villager`, `assign_worker` / `unassign_worker`, `tear_down` / `stop_tear_down`,
  `upgrade_tower` ...). Co-op clients send the same commands.
- `Game` (scripts/game.gd): raids (`on_enemy_reached_gate`), thieves' theft, defeat
  (`_check_defeat`).
