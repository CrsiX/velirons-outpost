# Veliron's Outpost: the village (design)

Status: **built; describes the current code**. Tested by tests/sim_bot.gd (also fleeing), tests/rat_bot.gd
(villager HP, tear-down), tests/hud_bot.gd (the warnings, the villager list) and tests/build_bot.gd (placing).
Scope: one player's village: resources, huts and villagers, the buildings outside the walls,
the warnings and the villager list. Every number lives in `scripts/core/config.gd` (the tables
named below); this document says why they are shaped as they are. Military units, barracks
sorties and training are in docs/military-design.md. The map, special objects and mines are in
docs/world-design.md. Co-op transfers are in docs/multiplayer-design.md.

## 1. Summary

- **Three resources:** gold, food and building material. Food feeds and recruits villagers,
  material builds, gold buys soldiers (and material, at a poor rate, so gold never becomes
  a way around the foresters).
- **The village:** a small walled block of huts. One villager per intact hut, so the huts cap
  the population, and burning a hut is a real loss.
- **Villagers** work on their own. The player decides *where* buildings go, not who does what
  minute to minute. Farmers and foresters take free workplaces by themselves.
- **Defeat:** a village falls with no villagers or no intact huts.

## 2. Resources

Each resource has a clear source and sink (`START_RESOURCES`, `CIVILIANS`, `BUILDINGS`):

- **Gold:** earned from enemies (kills at once, corpses brought home), calling a wave early,
  treasures, lairs and mines. Spent on military units and upgrades, military buildings, buying
  material, the Spatial Archmage.
- **Food:** grown by farms (carried home by farmers), from corpses and some treasures. Spent
  on recruiting villagers and on upkeep of villagers and army.
- **Material:** chopped by foresters, bought, refunded by tear-down and cancel, found in
  treasures. Spent on buildings, upgrades, repairs and rebuilding huts.

- **Upkeep:** every villager eats (`FOOD_UPKEEP`), the miner and the Spatial Archmage too. The
  army eats as well (§2a); the hero never.
- **Buying material** (tap the material counter, `MATERIALS_TRADE`): a deliberately poor rate,
  an emergency valve rather than an economy. Command `buy_materials`.
- **Calling a wave early** pays gold per second left on the countdown (`EARLY_CALL_GOLD_PER_SECOND`)
  to every village: a reward for confidence, which also shortens the game.
- **Food flow** next to the food counter: worked farms' average output minus villagers' and
  army's upkeep (`Population.food_per_second`). Corpses and rats aren't counted: they are
  windfalls and losses the player can't plan with.
- Rats at a gate eat food, and thieves steal gold (enemy rules: docs/enemies-design.md).

## 2a. Feeding the army, hunger and starvation

**Why:** one farm feeds several villagers and the village has few huts, so two farms feed a
full village and, late in a game, food piles up and stops mattering. The army grows all game,
so it is what should eat: food becomes a late-game constraint that pushes the player to more
farms and defended farms.

### Army upkeep

- Every military unit of a village eats, scaled by level and more for a specialisation
  (`MILITARY_UPKEEP`, `Config.unit_upkeep`, `Population.army_upkeep`). Tuned so a fresh unit eats
  well under a villager's share and a late specialisation nearly a villager's. Early on (a few
  level 1 archers) it hardly shows; the target for a late village (9 villagers, about 15
  units around level 6) is roughly two and a half worked farms, so a bigger army needs a
  third. Check the curve against the table when changing `MILITARY_UPKEEP`.
- **Who eats:** every unit the village owns wherever it is (post, bench, walking, sortie,
  reserve, downed), so a unit can't be "parked" to save food. Scenario units that take no
  orders (druids, Fiona's mages) eat too. A unit sent to another village (co-op) eats from its
  sender until it joins the other army.
- **Who doesn't:** the hero (it would punish playing her), summons, caravans. The Spatial
  Archmage is a villager and eats as one.
- **Shown:** in the Army tab's recruit entries, the unit's, tower's and reserve's panels
  (`MilitaryUnit.food_lines`), each upgrade option and the library, so the cost of an upgrade
  is visible before it is paid.
- **Scenarios:** `Scenario.army_upkeep` scales it per scenario (default 1.0). Some scenarios
  set it to 0 for now: their food is tight by design and the texts then don't mention upkeep.

### Hunger (food at 0)

- The village is **hungry** while its food is at 0 and something is due (`Population.starving`;
  it ends the moment any food comes in). One number, `HUNGER_PENALTY`, sets all three effects.
  Every military unit of that village then:
  - **moves** slower (`Soldier._walk_factor`);
  - **takes** more damage, from every source and category (`Soldier.take_damage`);
  - **acts** slower: every timer of its attack, shot, cast, summon and heal (`MilitaryUnit.rate`
    × `hunger_rate`; it multiplies with a war cry's haste, a siren's song and a berserker's
    rage) and a warrior's war-cry interval.
- Not affected: the hero, summons already out (their summoner just summons more slowly),
  revive and regeneration times, range. The penalty hits tempo, not reach, so a hungry army is
  worse but never useless.
- **Showing it:** an empty bowl beside the head (`UnitFx.add_hunger_mark`; a co-op client sees it
  for its own village from the replicated `starving`), the unit's panel says so, and the
  food counter turns red.

### Starvation

- While the village stays hungry, a villager starves every `STARVATION_INTERVAL`, counted up in
  `Population.starve_timer` (replicated to co-op clients). Any food coming in resets the timer.
  The death is logged (Important) with a toast.
- **Who starves first** (`Population.starve_victim`): the lowest tier present, at random
  within it:
  1. ordinary villagers (no `given_name`), the miner and the Spatial Archmage included;
  2. named villagers no objective needs;
  3. villagers the scenario needs (`Scenario.must_live`). One of them starving loses the
     scenario.

  So named villagers are spared as long as anyone else is left: a story character dying of
  hunger while a nameless farmer lives would feel arbitrary. In a free game nobody is named, so
  it stays random.
- **Warning:** the food-shortage banner (§10) shows only in the last `STARVATION_WARNING` seconds
  of each period, as a countdown, so it signals "now" without being on screen all the time. It
  follows the starvation timer (game seconds): faster at higher speed, stopped while paused.

## 3. Village, huts, raids and defeat

- **Layout** (`VILLAGE_LAYOUT`): a 5×5 block, walls round it, a gate in the middle of each
  side, a wall tower at each corner, huts inside. Walls, gates and wall towers come in several
  materials (docs/siege-design.md §2a).
  - Wall towers take units like watchtowers, with their own range (`TOWER_RANGE.wall_tower`).
  - Walls, gates and wall towers have HP and hold enemies back until broken; gates and walls
    level up for more HP (docs/siege-design.md).
- **Inside the walls is safe** while no enemy is in there. Villagers there don't flee and
  can't be hurt (`Civilian.inside_walls`), so builders rebuild huts during an attack: the
  player's fix for a burnt hut shouldn't stop because a wave is on. Once an enemy has broken
  in (`Siege.breached`), villagers walking inside are exposed until it is gone; those at home
  stay safe, so the cap on losses is the hut, not the household.
- **Huts:** every villager lives in exactly one intact hut (`Hut.resident`). Recruiting needs a
  free hut, so `Population.cap()` is the number of intact huts.
- **Raids:** an enemy that breaks in walks to the nearest intact hut and burns it
  (`Game.on_enemy_reached_gate`, docs/siege-design.md §5), on every difficulty. Only that hut's
  resident dies; an empty hut costs no life. Exceptions belong to the enemies (rats eat food,
  thieves steal gold, small slimes burn only sometimes, a vampire bat does nothing).
- **Rebuilding:** a ruined hut can be rebuilt on its lot for a share of its price
  (`REPAIR_SHARE`, `Hut.rebuild_cost`, `Construction.order_rebuild`), all or nothing. Builders
  take hut rebuilds before nearly any other job (§5): a hut is the population cap, and every
  empty one is a villager the player can't have. Cancelling (§7) turns it back into a ruin and
  refunds the unbuilt share.
  - The villager list has **Rebuild all huts (n)**: it queues as many ruined huts as the
    material pays for, nearest the centre first, and says how many are left over.
- **Defeat:** a village falls when it has no villagers or no intact huts
  (`Village.is_standing`). In single player that ends the game. In co-op a fallen village can
  stand again and the game is lost when all have fallen (docs/multiplayer-design.md).

## 4. The start

- **Villagers** (`START_CIVILIANS`): builder, farmer, forester, explorer. There is no explorer
  without fog (`Game.disable_fog`: only the title backdrop and tests).
- **Free buildings** (`START_BUILDINGS`): a farm and a worker camp, finished
  (`Construction.build_starting`), so the first minutes are about defence and growth rather than
  waiting on foundations.
  - They are placed on the finished map, which keeps no room for them: each goes on the
    nearest free spot within `START_BUILDING_RADIUS` of the centre that keeps clear of the gates,
    isn't hidden behind walls or trees on screen and is reachable on foot. A farm needs farmland;
    a camp needs trees nearby and prefers the forest's edge (the tutorial pins it:
    `TUTORIAL.camp_tile`).
  - Where no spot fits, the village starts without that building (logged). On a harsh map (ash,
    desert, swamp, dense forest) that is a harder start on purpose: the farmer waits for a farm.
  - The starting farmer and forester take them at once (§6).
- `START_REVEAL_RADIUS` around the centre starts explored, and each starting building reveals a
  little around it.
- The tutorial starts smaller (docs/tutorial-design.md).

## 5. Villagers

Roles, costs, speeds, rests and work times are in `CIVILIANS` and the `*_REST` / `*_TIME`
constants. Roles that don't work from a recruit button: the **merchant**, **guild master**,
**priest** and **princess** exist only in the campaign (docs/scenarios-design.md §7; the last
three are `Resident`s who stay home), the **miner** is locked until anyone walks up to a mine
(`LOCKED.miner`), and the **Spatial Archmage** can't be recruited.

- **Every villager** has HP (`CIVILIAN_HP`) and heals at home (`CIVILIAN_REGEN`).
  - Outside, any enemy that gets at them hurts them; they never fight back. At 0 HP they die
    (Important, with the cause).
  - **Fleeing:** outside the walls, a villager looks several times a second for an enemy within
    `EVADE_RADIUS`. If there is one, they shout, drop or pause the job, run home and rest
    `EVADE_REST`.
  - **Setting off** (`Civilian.head_out`): a path out starts from where the villager stands, not
    from the tile's centre, so a new target never makes it step back first.
  - **Coming back** (`Config.FLEE`, `Civilian._back_to_work`): while running, they periodically
    check whether any enemy that scares villagers is still within `clear_radius`. If none is, they
    go back to work from where they stand (`resume_work`, as after a load): no walk home, no
    rest, so a single enemy killed at the far edge doesn't cost the economy a full trip. A campaign
    resident with nothing to do out there runs on home.
  - **Running away** (`FLEE.away_roles`: the explorer, and the hero in Explore mode): going home
    would waste the exploring done, so they run `away_distance` off in a direction that doesn't
    lead towards the enemies, onto explored land the village can reach, as far from the nearest
    enemy as can be (`Civilian._away_tile`). Meeting another enemy, they pick again. Once there:
    back to work if the coast is clear, else away again. Home only when no such place exists.
- **Builder** (`BuildJob`, shared with the hero at half speed): claims the best job in the
  build queue (`Construction.claim`, `BUILD_QUEUE`), walks there and builds; one second of work
  is one second of the building's build time. A site left halfway keeps its progress. The same
  job does upgrades, ruined-tower restorations, hut rebuilds, repairs and tear-downs.

  **Why the queue ranks the way it does.** Only picking a *new* job looks at the queue (also after
  fleeing, which gives the job back); work under way is never taken away, or builders would
  thrash between sites. The rules:
  - **Only jobs it can do now:** one it can walk to (`Pathing.can_reach`; one it can't is given
    back and skipped for `unreachable_retry`), and none with a visible enemy near it
    (`Construction.in_danger`, `danger_radius`). Jobs inside the walls count as safe while
    nobody has broken in, as for fleeing. Otherwise a builder would walk to a site it cannot
    reach, or into the enemy.
  - **Buckets** (`BUILD_QUEUE.buckets`, `Construction.bucket`) rank by what matters for
    survival, by job type (repair, upgrade, build, teardown) and kind: first restoring what holds
    the enemy off or houses people (gate and wall repairs, hut rebuilds, wall tower repairs), then
    strengthening it (gate, wall and wall tower upgrades), then the army's buildings (repair,
    then new, then upgrade: a standing watchtower comes before a better one), and
    everything else (farms, camps, light stones, tear-downs) last. A player who queues a farm
    during a siege still sees the walls repaired first.
  - **Within a bucket:** started jobs first (finishing beats starting), then the lowest score:
    distance from the builder (from the village centre while at home) minus a credit for age
    (`age_tiles_per_min`, `Building.queued_at`), so the nearest goes first (little walking) but
    an old job wins in the end (nothing starves).
  - **Demotion:** a job the builder fled from (`BuildJob.on_evade`, `Building.interrupts`) enough
    times (`demote_after`) drops one bucket, so builders don't keep running back to a spot that
    is still under fire. It returns when its wave is over, or after `demote_calm` without an enemy
    near. The queue time and the count are saved.
  - **Chaining:** done with a job, the builder takes the best next one within `chain_radius` and
    walks straight there, otherwise home to rest (`BuildJob._take_next`): a cluster of sites is
    built without a round trip to the village each time.
- **Farmer:** walks to their farm, takes its stored food (whole units), carries it home and rests;
  fleeing, they still deliver the food they carry. The farm grows food only while it has a farmer
  and no rats are on it (§7).
- **Forester:** camp → nearest tree within `FORESTER_SEARCH_RADIUS` → chops a session → walks back
  and drops a little material (so material trickles in even while a tree takes long) → rests →
  the same tree again; a tree falls after its total chop time (`TREE_CHOP_TIME`: oaks take longest,
  dead trees and stumps are quick) and its tile becomes meadow. Fleeing, he keeps his load and
  delivers it at home (`Forester._deliver`).
- **Explorer** (`ExploreJob`, shared with the hero's Explore mode; tunables `Config.EXPLORE`):
  - **Where to go** (`ExploreJob._best_within`): every walkable tile within reach scores the fog it
    would uncover from there per step walked, with a bonus for keeping the heading
    (`momentum`) and a penalty near another scout's target. A tile whose whole view is fog
    scores highest, so targets lie about a sight radius into the fog and sweeps are a sight
    width apart: no overlap, no gaps.
  - **Sticks to its target:** it picks again only on arriving, or once the target has lost most
    of the fog it was picked for (looked at every `think_every`), not as soon as the target tile
    itself is seen. This stops dithering.
  - **Finishes the fog within reach first:** with nothing within reach it takes the nearest fog;
    it turns back to the fog nearest the village only when its local target is much farther
    from the village than that (`EXPLORER_WANDER_FACTOR`, `EXPLORER_WANDER_SLACK`), so it doesn't
    leave patches behind it.
  - Avoids fog another explorer is heading for (`EXPLORER_CLAIM_RADIUS`).
  - Keeps away from monster camp guards: fog by a camp waits until the camp is cleared. When it
    flees from guards on its way to some fog, it sets that fog aside while they live
    (`EXPLORER_BLOCKED_RADIUS`); otherwise it would walk into them again and again.
  - Fog over forest, rock or water it can't enter is looked into from the nearest walkable edge.
- **Gatherer** (`GatherJob`, shared with the hero's Gather mode, who carries less):
  - stays home until there are corpses, and only goes for **safe** ones (no living enemy within
    `CORPSE_SAFE_RADIUS`, on land its village has explored): the job is to be a risk the player
    manages, not a suicide the player has to micro-manage;
  - carries up to `GATHERER_CAPACITY` per trip; at home each corpse pays its `gold_on_collect`
    and `food_on_collect` (a thief's also pays what it stole);
  - a sack the hero dropped is picked up first;
  - corpses rot after `CORPSE_LIFETIME`, and a wave's corpses go once the next wave is over, so
    gathering is a race against the clock and the next wave.
- **Miner** (docs/world-design.md): walks to the nearest free mine their village has found and
  stays inside, safe (no fleeing); one miner per mine, the first to arrive; still lives in a hut
  and dies with it. Income is `MINE_GOLD_RATE`.
- **Spatial Archmage:** a level 10 spatial mage becomes one (`ARCHMAGE_COST`, needs a free hut;
  docs/military-design.md §7). Decoration for now.
- **Code:** `Unit` → `Civilian` (evasion, HP, home); one class per role in scripts/units/; the
  shared jobs in scripts/units/jobs/.

## 6. Automatic worker assignment

A role with `works_at` in `CIVILIANS` (farmer, forester) is a worker (`Config.worker_role`).
The player's decisions are about *where*, so *who* is automatic:

- A new worker, or one freed by a tear-down, takes the vacant finished workplace of its kind
  nearest the village (`Population.vacant_workplaces`). The recruit toast says where it went.
- A newly finished farm or camp takes an idle worker of its role.
- The building panel can still **unassign** and **assign** by hand. One unassigned by hand
  stays idle until a workplace takes him.
- A workplace being torn down frees its worker (`Population.free_workplace`).
- Miners aren't `works_at` workers: they pick a free mine themselves (`Population.free_mine`).

## 7. Buildings outside the walls

Every building has HP (`BUILDING_HP`). Enemies can wear it down; at 0 it is devastated and does
nothing until a builder repairs it for material (docs/siege-design.md). Which enemies go for
buildings outside the walls is in docs/siege-design.md (so far the octopus's arms, the
wrathwood and, in the campaign, the guild warehouse).

Costs, sizes and build times are in `BUILDINGS`. What each is for:

- **Watchtower:** holds one military unit; the cheap, flexible way to extend the defence.
- **Farm:** one farmer; grows food.
- **Worker camp:** one forester.
- **Barracks:** benches for units that turn out (docs/military-design.md §5).
- **Training grounds:** one unit and the hero, who trains it with XP.
- **Light stone:** gives sight, nobody inside (`LIGHTSTONE_SIGHT`).
- **Hut:** only rebuilt on its ruined lot (§3).
- **Campaign-only buildings** (`"campaign": true`: trade stall, guild warehouse, graveyard,
  druids' grove) are placed by their scenario or only where it lists them; they are prebuilt or
  not torn down: docs/scenarios-design.md §7 and docs/military-design.md §6.

- **Farm output** (`Farm.rate`, `FARM_RATE`): while it has a farmer and no rats. A bonus when
  more than half its tiles are meadow (`ZONES.meadow.farm_bonus`) and when a tile borders water
  (`FARM_WATER_BONUS`), so *where* the player puts a farm matters. Relics can add more
  (`relic_bonus("food")`). It stores up to `FARM_CAPACITY`, which is what rats eat and what a
  farmer lost to a raid costs. One plain farm feeds fewer villagers than the village has huts,
  so a full village needs a bonus or a second farm.
- **Watchtower and wall-tower levels** (`TOWER_LEVELS`): a builder does the work while the tower
  keeps fighting. Levels add range (and HP, decorations), not new abilities.
- **Barracks levels** (`BARRACKS_LEVELS`): the level adds benches and turn-out range.
- **Placing** (`Construction.placement_error`, first failing rule wins): every tile must be on the
  map and explored by this village, outside the walls, free of other buildings and objects, and
  buildable terrain (not road, trees, mountains, water, lava, nor near a crater:
  `VOLCANO_NO_BUILD`, `MapData.near_crater`; a farm also not in a `no_farms` zone). Towers and
  light stones block their tile (`SOLID_KINDS`), so one neighbouring tile must be walkable and
  reachable from the village ("Nobody could get to it"): else a unit could never take its
  post. The price must be affordable. The player can't place a building for free; only the
  start's buildings and ruin restorations skip the checks.
- **Cancelling** (command `cancel_site`, `Construction.cancel`): a site's panel has *Cancel*, an
  ordered upgrade *Cancel upgrade*, an ordered repair *Cancel repair*.
  - The refund is the price paid × the share of work still undone, rounded down per resource
    (`Building.cancel_refund`, `refund_share`): all of it before a builder starts, nothing near
    the end, so a cancel is a real choice rather than a free undo. A hut rebuild refunds from
    its half price.
  - The panel says what comes back, or that it is too far along.
  - A cancelled site disappears; a cancelled hut rebuild turns back into a ruin; a cancelled
    upgrade leaves the building at its level.
- **Placing controls** (one building per pick, mouse / touch preview / dragging from the Build
  tab) are in CLAUDE.md "Controls" and tested by build_bot.
- **Code:** `Building` (site / complete base, tear-down); `Workplace` → `Farm`, `WorkerCamp`;
  `MilitaryPost` → `Tower`, `Barracks`, `TrainingGrounds`; `LightStone`, `Hut`, `StaticPiece`, all
  in scripts/buildings/; `Construction` (scripts/systems/construction.gd) validates, places, keeps
  the job queue, handles upgrades, repairs, devastation, rebuilds and tear-downs.

## 8. Tear-down

Lets the player undo a placement (a farm in the wrong spot) and get part of the cost back,
without making building free.

- **Which buildings:** every building the player can place (`Construction.KIND_SCRIPTS`), also
  the free starting farm and camp. Huts, walls, gates and wall towers can't be torn down (they
  are the village).
- **Ordering it** (*Tear down*, the last action in the panel; `order_tear_down`) stops the
  building at once: units on it or marching to it walk back to the reserve (downed ones revive
  there); its worker is freed and takes another vacant workplace; an ordered upgrade or repair
  is cancelled and refunded like a cancel (§7).
- **The work:** a builder (or the hero in Build mode) comes as to a site and works a share of the
  build time (`TEARDOWN_TIME_SHARE`). The bar counts down and the building shows see-through.
- **The refund:** `TEARDOWN_REFUND` of the material spent, scaled by the building's HP share, rounded
  down. Material spent is the price plus paid upgrades (`materials_spent`); gold is never
  refunded. A damaged building gives back less, a devastated one nothing (docs/siege-design.md §3),
  so tearing down isn't a way to cash out a wreck.
  - The free starting buildings refund a share of their list price too.
  - A restored ruined watchtower counts its full list price (`materials_spent`), so it refunds
    more than was paid for it: accepted, because restoring is rare and the amount small.
- ***Stop tear-down*** spares it; units stay in the reserve.

## 9. Sight and fog

The fog has three states: unexplored (black), explored (terrain known, enemies hidden), and
under surveillance (clear). The rendering is `FogLayer`; the observers are anything in the
"observers" group. Sight radii are constants in config.gd (`HUT_SIGHT`, `GATE_SIGHT`,
`BUILDING_SIGHT`, `LIGHTSTONE_SIGHT`, `TOWER_SIGHT_BONUS`, `UNIT_SIGHT`); a manned tower sees a
little beyond its range, so a unit is never shot at from the dark.

- Building sight is measured from the anchor tile (`Building.sight_radius`, `sight_center`), not
  the footprint's edge.
- Every unit of ours outside also **explores** the fog close around it (`UNIT_REVEAL`): villagers,
  the hero, soldiers, summons and caravans, so the map opens up wherever the player's people go.
- Explorers reveal a wider radius (`EXPLORER_REVEAL`).
- Only explorers and the hero in Explore mode *go looking* for fog.

## 10. Warnings

Both are red banners under the top bar, checked a few times a second in `Hud`. Their timing is in
config.gd and counts game seconds; paused time doesn't count. They exist because both situations
are silent failures: nothing visibly breaks, the village just stops progressing or starves.

- **No builder** (`NO_BUILDER_DELAY`, `Hud.nobody_builds`): shown when something waits in the build
  queue, the village has no builder, and the hero is alive but not in Build mode. While the hero is
  downed it doesn't show (she'll be back). It says what to do.
- **Food shortage** (`STARVATION_WARNING`, `Hud.food_warning_due`, `Hud.food_warning_text`): shown
  only in the last seconds before a villager starves (§2a), as a countdown. It sits under the
  builder warning when both show. A tip says what is missing (no working farm; farms but no
  farmer; a farm without a farmer and a farmer without a farm), or nothing when every farm is
  worked (say, farmers kept home by enemies: nothing the player can fix by building).

## 11. Villager list and Retire

- **Opening it:** the people button in the top bar (villagers / huts). On top **Rebuild all huts
  (n)** with its cost (§3), then every villager by role (`CIVILIAN_ORDER`), with what they are
  doing now and their HP when hurt.
- **View** moves the camera to the villager, or to the village centre for those at home.
- **Retire** asks for confirmation. The villager leaves for good; their hut and workplace are free
  again, and nothing is refunded. It exists so a villager with nothing left to do (an explorer
  with all fog seen) doesn't block a hut.
  - The last villager can't retire (`Population.retire_error`), or the village would fall.
  - The campaign's merchant and residents never retire.

## 12. Code map

- `Village` (scripts/systems/village.gd): one player's village. It holds the `Economy`,
  `Population`, `Construction`, `Army`, the hero and the `EventLog`, plus the centre, walls,
  gates and home spawns.
- `Economy`: the three amounts, `spend` / `refund` / `add`, food consumption, `buy_materials`.
- `Population`: recruiting, spawning into a free hut, upkeep and starvation, kill / retire,
  worker and mine assignment.
- `Construction`: placement rules, sites, the job queue, upgrades, hut rebuilds, the starting
  buildings, tear-down.
- `Commands` (scripts/systems/commands.gd): every player action as a checked command. Co-op
  clients send the same commands.
- `Game` (scripts/game.gd): raids (`on_enemy_reached_gate`), thieves' theft, defeat
  (`_check_defeat`).
