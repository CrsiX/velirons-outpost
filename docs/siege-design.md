# Veliron's Outpost: building HP and sieges (design)

Status: **built; describes the current code**. Tested by tests/siege_bot.gd.
Scope: building HP, devastation, repairs, gate and wall levels, and how enemies break into a
village: the siege field, attacking barriers, slipping through, flying over, burning huts.
Every number lives in `scripts/core/config.gd` (`BUILDING_HP`, `PIECE_PRICES`,
`PIECE_LEVELS`, `REPAIR_SHARE`, `REPAIR_TIME_SHARE`, `SIEGE`, and each enemy's `"siege"` and
`"entry"`). The village itself is in docs/village-design.md, enemies in
docs/enemies-design.md.

## 1. Summary

- **Every building has HP:** the village's gates, walls and wall towers, watchtowers,
  farms, worker camps, light stones, barracks, training grounds, and huts (1 HP).
- **Damage stays.** Buildings never heal on their own. A builder (or the hero in Build mode)
  repairs them on an explicit order, for building material.
- **At 0 HP a building is devastated:** a ruin that does nothing until it is repaired.
- **Enemies break in.** Walls and gates hold them back. An intact gate is no longer the end
  of an enemy's road: it has to be broken first, or a weaker wall next to it. Once inside,
  an enemy walks to the nearest intact hut and burns it.
- **Flyers** (gargoyles) fly over walls and gates. Rats and thieves slip through a gate
  after a short hold.
- **Gates and walls** can be upgraded to level 3 for more HP, like towers.

## 2. HP

`BUILDING_HP` gives each kind's max HP per level (index = level − 1):

| Kind | Level 1 | Level 2 | Level 3 |
|---|---|---|---|
| Gate | 80 | 160 | 320 |
| Wall | 100 | 200 | 400 |
| Wall tower | 200 | 400 | 800 |
| Watchtower | 100 | 200 | 400 |
| Barracks | 150 | 250 | 400 |
| Farm | 100 | | |
| Worker camp | 50 | | |
| Light stone | 80 | | |
| Training grounds | 150 | | |
| Hut | 1 | | |

- A finished building starts at full HP (`Building.hp`, `Building.max_hp()`). Construction
  sites have no HP and take no damage.
- **Upgrades** raise the max HP. The building also gains the difference, so it keeps the
  HP it was missing (a gate at 50 / 80 becomes 130 / 160). A devastated building can't be
  upgraded, and neither can one being repaired.
- **Damage** (`Building.take_damage(amount, source)`): every damage category counts the
  same. It is logged at Debug level, the building flashes red, and its HP bar shows (see §7).
  The title backdrop's buildings take no damage.

## 3. Devastation

At 0 HP the building is **devastated** (`Building.devastated`). It is logged as Important
("goblin 4 devastated gate 2") and a toast says so.

- **What stops** (`Building.working()` is false):
  - Units stationed there, or marching there, walk back to the reserve (`Army.eject`), as on
    tear-down.
  - Its worker is freed and takes a vacant workplace of that kind if there is one.
  - Rats on a devastated farm leave it.
  - An ordered upgrade is cancelled and refunded, as a cancel.
  - Its sight is gone (a devastated gate keeps no watch).
- **Its look:** wall, gate and wall tower ruins (`wall_ruin`, `gate_ruin`, `wall_tower_ruin`),
  the ruined watchtower for watchtowers. Other kinds are drawn darkened with rubble on top
  (`rubble`).
- **Walls, wall towers, watchtowers and light stones** no longer block their tile once
  devastated. Villagers can walk through a broken wall (and enemies can, see §5).
- **Huts** keep their own ruin (`Hut.ruined`), as before: any enemy that reaches an intact
  hut burns it at once (1 HP). Whoever lives there dies.
- **Tear-down** works on a devastated building too. The refund is scaled by the HP share:
  `TEARDOWN_REFUND` × building material spent × hp / max HP, rounded down. A devastated
  building gives nothing back.

## 4. Repairs and upgrades

- **Repair** is an order in the building's panel (`repair` command,
  `Construction.order_repair`). It isn't offered while the building is under construction,
  being upgraded or being torn down, or while it has full HP.
- **Cost:** building material only, never gold. It is `REPAIR_SHARE` (0.5) × the material
  spent on the building (its list price plus paid upgrades; `Building.materials_spent`) ×
  missing HP / max HP, rounded up, at least 1. So a devastated building costs half of what
  went into it, and a building at 75 % HP costs an eighth. Barracks and training grounds
  count only their material part.
- **Time:** `REPAIR_TIME_SHARE` (1.0) × build time × missing share. A builder walks over as
  to a site, and the bar fills in blue-green. When it's done the building gets back the HP
  that was paid for (never above its max), and a devastated one works again. Damage taken
  during a repair doesn't add to it: order another repair afterwards.
- **Cancelling** a repair refunds like a site: all of it before any work, falling off evenly
  with the work done.
- **The village pieces were never bought.** `PIECE_PRICES` gives them a price for repairs:
  gate 40, wall 30, wall tower 60 material, with build times 10, 10 and 14 s.
- **Huts** are repaired all or nothing: *Rebuild* costs `REPAIR_SHARE` × the hut's price
  (80 → 40 material) and takes its build time (10 s). *Rebuild all huts* is unchanged.
- **The ruined watchtower** (a map object, docs/world-design.md §9.5) is claimed by the hero
  as before. *Restore* turns it into a devastated watchtower of the claiming village and
  orders its repair at once (half a watchtower's price, 15 material, 8 s).
- **Gate and wall levels** (`PIECE_LEVELS`): level 1 at the start, up to level 3 for building
  material and a builder's time, like towers. Gate: level 2 for 30, level 3 for 60. Wall:
  level 2 for 35, level 3 for 70. They only add HP and look (iron bands at level 2, gold trim
  at level 3). Wall towers level up with `TOWER_LEVELS`, as before, and also gain HP.

## 5. Enemies at the village

### 5.1 How an enemy gets in

Each enemy kind has an `"entry"`:

- **`"siege"`** (the default for anything walking): it breaks in (§5.2).
- **`"slip"`** (rats and thieves): it stays on its road to the gate. An intact gate holds it
  for `SIEGE.slip_time` (4 s), then it slips through without damaging the gate and does what
  it did before at a gate: a rat eats food, a thief steals gold and runs. A devastated gate
  doesn't hold it at all.
- **Flyers** (`"flying"`: gargoyles) keep to the roads until they are close, then fly
  straight over walls and gates to the nearest hut. A vampire bat still turns back at a
  gate (docs/enemies-design.md).
- **Water-bound monsters** (leviathan, octopus) never come ashore and don't break in.

### 5.2 The siege field

The siege field (`Siege`, `scripts/systems/siege.gd`; one per village, rebuilt on demand)
covers the village and a band of `SIEGE.approach` (3) tiles around its pieces.

- **Its targets** are the village's intact huts.
- **Its costs:** a 4-connected Dijkstra field, counted in tenths of a step:
  - open ground counts 10 per step (shallow water and swamp 20);
  - a ruined hut, a devastated piece or an open gate counts as ground;
  - an intact gate, wall or wall tower counts 10 + 10 × hp / `SIEGE.hp_per_step` (10 HP = one
    step's detour);
  - everything else an enemy can't walk on (trees, deep water, solid buildings) is out.
- **What follows from it:**
  - Enemies take the cheapest way in. A level 1 gate (80 HP) beats the walls beside it
    (100 HP). A gate upgraded to 320 HP sends them to a wall instead, if the detour is shorter
    than the difference. A devastated wall pulls them round an intact gate.
  - A damaged piece gets cheaper as it loses HP, so they keep at the weakest.
  - Moving is 4-connected: a devastated corner tower leads nowhere while both walls next to
    it stand, because the hut beside it is only diagonally adjacent.
- **Flyers** use the same field, where every tile counts as ground (walls and gates cost
  nothing extra).
- **Rebuilding:** the field is marked stale when a piece is devastated or repaired, a hut is
  burned or rebuilt, a building's solidity changes, or a piece's HP changes. A stale field is
  rebuilt when next needed, at most every `SIEGE.rebuild_interval` (0.4 s), at once after a
  devastation or a repair.

### 5.3 An enemy breaking in

- **Leaving the road:** an enemy with `"siege"` entry, sent against a village, follows its
  road (`enemy_route`) until it is within `SIEGE.approach` tiles of that village's pieces,
  on a tile the field reaches. From then on it is *sieging* (`Enemy.sieging`). It follows the
  field tile by tile, each step to the neighbour with the lowest cost of entering it plus its
  own value.
- **At a barrier:** when that next tile is an intact gate, wall or wall tower, the enemy
  stops in front of it and attacks it (`Enemy.breach`):
  - **Fighting comes first.** Its behaviour still picks melee foes first (the hero, soldiers,
    elementals, exposed villagers). A barrier is the least important target: shot at by a
    tower, a goblin keeps hitting the gate; walked up to by a shield bearer, it turns and
    fights.
  - **Its blows:** `damage` × `siege` every `attack_cooldown` (`EnemyBehavior.siege_attack`).
    A witch casts her bolt at it instead, `spell_damage` × `siege`, every `spell_cooldown`,
    when nothing better is in range.
  - **Changing its mind:** every `SIEGE.rescan` (0.5 s) it checks the field. It leaves its
    barrier only for a way at least `SIEGE.switch_margin` (3) steps cheaper, so it doesn't
    run back and forth.
- **Enemies that can't hurt a barrier** (`siege` 0: necromancer, siren) wait in front of it.
  After `SIEGE.stuck_slip` (45 s) they slip past that barrier as if it were open, so a wave
  can't stall at a gate nobody guards.
- **Inside:** the enemy walks on to the nearest intact hut. On its tile it burns that hut
  (Game.on_enemy_reached_gate, now given the hut) and is gone. A small slime first rolls its
  `raid_chance` and else melts away, as before.
- **While any enemy is inside a village's walls** (`Siege.breached(village)`), villagers
  walking in there are exposed: enemies can hurt them. Villagers at home are still safe.
- **Remaining distance** (`Enemy.remaining()`, what archers use to find the enemy closest to
  the gate): for a sieging enemy, whole tiles to the village's walls (0 at or inside them).
- **Spatial magic** throws a sieging enemy back up the field (away from the huts), tile by
  tile over ground it can walk.
- **Co-op:** each village has its own field. An enemy whose village falls turns to another
  village as before and leaves its siege.

### 5.4 Who attacks barriers

| Kind | `entry` | `siege` | At the village |
|---|---|---|---|
| goblin, skeleton, ork, slimes, crab, vampire (on foot) | siege | 1.0 | break in |
| witch | siege | 1.0 | spells at the barrier when nothing else is in range |
| necromancer, siren | siege | 0 | wait, slip past after 45 s |
| gargoyle | (flies) | 1.0 | over the walls |
| rat, thief | slip | 0 | held 4 s by an intact gate |
| leviathan, octopus | (water) | | stay in the water |

Raised enemies keep their kind's values.

### 5.5 Other buildings

Farms, worker camps, light stones, barracks, training grounds and watchtowers can be
devastated the same way. No enemy goes for them yet, except the octopus: an arm with nobody
in reach smashes a building of ours within `arm_range` instead. That deals `spell_damage` ×
`arm_smash` every `smash_cooldown`, and the arm is shown slamming down on it. This is the hook
for scenario tactics later.

## 6. The hero

In Defend mode she watches the whole wall ring, not just the gates: enemies within
`alert_radius` of any of her village's pieces (`HERO.alert_radius`). Enemies inside the walls
come first, then the nearest, then the strongest. In Build mode she repairs like a builder.

## 7. UI

- **HP bar:** a damaged building shows a thin HP bar (green, yellow below 50 %, red below
  25 %) under its work bar. A full or devastated building shows none.
- **Panels:**
  - Every panel gets an HP line ("HP 60 / 80").
  - A damaged building offers *Repair (+cost)* (greyed out while too poor); while it's being
    repaired it shows the progress and *Cancel repair*.
  - A devastated building's title says "Devastated …", and its panel says it does nothing
    until repaired.
  - Gates and walls have panels: level, HP, *Upgrade gate / wall*, *Repair*.
- **Log:**
  - Important: "gate 2 devastated by goblin 4".
  - Info: "gate 2 repaired" and level-ups.
  - Debug: each repair order.
  - The first blow at a village piece per wave toasts "The gate is under attack!".
- **Library:** every building entry lists its HP per level. Gates and walls get their own
  entries, with levels and prices.
- **Statistics:** buildings devastated, repairs done, and HP of damage taken by buildings
  (Summary, Village section; materials spent on repairs are under Economy as purpose
  "repairs").

## 8. Saving and co-op

- **Saving:** a save holds each building's HP, `devastated`, level (gates and walls too) and
  repair state (`rp`, `rpp`, `rpt`, `rph`, `rpc`). `SaveGame.FORMAT` 3.
- **Co-op:** clients get HP, devastation and repair progress in the building snapshots
  (`hp`, `dv`, `rp`).
