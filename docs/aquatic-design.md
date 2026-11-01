# Veliron's Outpost: water monsters (design)

Status: **built** (all of it). Numbers live in `scripts/core/config.gd`
(`ENEMIES`, `AQUA`, `AQUA_FIRST`, `WAVE_MIX`, the generator's `COAST_INLET_*`, `LAGOON_*`,
`WATER_SPAWNS` and each map type's `"lagoon"`); this doc keeps the reasoning only. All numbers
are first guesses: tune with the bot and by playing.

Scope: four enemy kinds that travel through rivers, lakes and the sea (crab, leviathan, siren,
gigantic octopus), the rules they share (habitat, submerging, melee reach, corpses that sink),
how they join waves, and what the map and the world generator must provide.

## 1. Habitats

Every enemy kind has `"habitat"`: `"land"` (default), `"amphibian"` (crab, siren: road tiles and
water tiles, leaving the water only onto a road) or `"water"` (leviathan, octopus: deep water
only, never shallow, never land). Enemies are never slowed by terrain, so shallow water and
fords cost an amphibian no speed.

## 2. Submerging (all aquatic kinds)

- Only on a **deep** water tile. Shallow water, fords, bridges and land never allow it (the one
  exception is passing under a bridge, §15).
- States: surfaced, diving, submerged, surfacing. All but surfaced are **untargetable**.
- `Enemy.targetable()` is the one test every targeting site uses (the same sites that filter
  `flies()` and `dead`: towers, barracks, soldiers, the hero, elementals, mage splash, shots in
  flight). A shot in flight at a mob that dives fizzles; splash skips submerged mobs. Healing
  and auras don't care.
- A submerged mob is drawn as ripples and a bubble trail, so the player sees where it is even
  when it can't be hit. It is invisible in the fog like any enemy.
- Each kind decides when to dive and surface. No kind regenerates while down.

### 2.1 Melee reach *(decided)*

A mob in deep water can be hit by a **melee-category** attacker only while surfaced and only
from a non-deep tile next to it. Melee units can't enter deep water, so this is the whole melee
reach: a mob farther out is out of their reach. Ranged attacks reach it at their range. This is
what makes water monsters a tower problem rather than a hero problem. The hero, shield
bearers and earth elementals are melee; a halberdier is melee with a longer reach.

### 2.1a Who engages them *(decided)*

Not only towers: the hero (in Defend) and barracks sorties go for a surfaced water mob under
their usual rules. A mob is a target for a melee unit only if it can stand on a non-deep tile
next to it; ranged units use their range. Submerged mobs are never targets.

### 2.1b Fire

Water monsters resist *fire* (`resist` "fire", docs/enemies-design.md §4): it is the sea's own
element against the player's explosive answer, so fire mages are a weaker counter here.

### 2.2 Corpses *(decided)*

Every aquatic mob leaves a corpse that can be raised or gathered like any other, with one rule
for **deep water**: the corpse sinks (`AQUA.sink_time`) and is then removed, so it can't be
raised or gathered. The necromancer's channel is longer than the sinking leaves room for, so
only a channel started right after the kill can finish; the existing "corpse gone mid-spell
ends it" holds. Corpses in shallow water and on land stay as usual.

Leviathan and octopus corpses can never be raised (`"revivable": false`, the key the
necromancer's own corpse already used). A raised crab or siren never submerges.

## 3. Movement

- **Water bodies.** At map load the water tiles are labelled into connected bodies (`Pathing`),
  each with its deep tile count and widest point. A kind's `min_deep_tiles` and `min_width` say
  which bodies it can live in (§9).
- **Amphibians** use a second flow field per village (like the road field): a Dijkstra from the
  gates over road tiles plus water tiles. Land tiles off the roads are not in it. So on land they
  stay on the roads, and the only exits from the water are road tiles that touch it, bridges
  and fords: the "prefer bridges" rule *(decided)* without a special case. A bridge tile counts
  as both road and water. A crab spawned on a land edge spawn uses the same field and dives
  into a river only when that is the shorter way.
- **Water-bound kinds** don't follow routes. A behavior moves them over the deep tiles of their
  own body towards the best target.
- **Guards** (`Enemy.post`, `post_leash`; the campaign's octopus at the drowned abbey): a
  water-bound monster with a post looks for its spots only within the leash of the post.

## 4. Crab (amphibian)

A goblin that can swim: `"behavior": "melee"` with the amphibian field and goblin-like stats
(`ENEMIES.crab`). It exists to make rivers and the sea a second front without a new mechanic.
It submerges by itself while on deep tiles, never by choice, and at a gate burns a hut like a
goblin.

## 5. Leviathan (water)

A sea serpent. It never leaves deep water and never moves while surfaced. Tough, with a rare
heavy burst that hurts far more than any one land enemy.

- **Cycle.** It lurks submerged, swims towards the deep tile nearest the village's things
  (preferring one within blast range of something it can hurt), surfaces, picks a target and
  channels a water column onto it (a visible, telegraphed jet with a wind-up, then continuous
  damage). Targets: villagers outside, units outside, the hero, elementals; never units on
  towers, nobody inside the walls. Then it dives and moves to a new spot some tiles away.
- **It always comes up.** A wave only ends when it is dead, so it must be killable: with
  nothing to blast it still surfaces every `idle_surface` at the deep tile nearest the village,
  where towers can be placed to cover it.
- **Gets hit.** It dives early when it loses a share of its max HP in one surfacing, but must
  then stay up a minimum next time, so it can't dodge forever.
- **Range as a design lever.** Its blast range sits between level 2 and level 3 tower reach:
  level 1-2 watchtowers can't answer it, so the player must upgrade or place towers well. Tune
  against `TOWER_RANGE` / `TOWER_LEVELS`.
- It makes shore land dangerous to build on and work on (farms by water, foresters, gatherers)
  rather than threatening the walls.

## 6. Siren (amphibian)

A support monster: she doesn't storm in; she controls the fight. Frail, takes extra from melee
when it reaches her, resists magic and fire.

- **Song** (a static visible ring on the ground while she sings), no damage. Its strength falls
  linearly from 1 on top of her to 0 at the edge. It applies to every unit of ours: the hero,
  soldiers on a sortie, elementals, villagers outside, and stationed tower units (their shots
  slow; they can't walk). It never touches enemies.
  - **Pull:** a mobile unit walks towards her (a forced move over ground it can walk: it stops
    at the shore, never into deep water).
  - **Slow:** all its attack, cast, summon and heal timers run at a rate below 1 (the opposite
    of a war cry; `Combat.haste` takes rates).
  - A lured unit still fights what is in its reach, **except her**.
- **Not attackable by melee in water.** A melee-category attacker can't target her while she
  stands on a water tile (deep or shallow, so a ford counts; a bridge tile counts as land); on
  land they can (the hero attacks her there). Ranged attacks always can. So only ranged answers,
  or the High Priest, work against a siren in the water.
- **High Priest.** A unit inside a High Priest's aura (`Combat.in_holy_aura`) is immune to the
  song and may attack her in the water like on land, melee included: a deliberate counter that
  rewards the acolyte line.
- **Behavior (witch-like).** She keeps her distance from the nearest unit, building or villager
  of ours, sings and lets them come. After a patience timer without anyone lured, or an overall
  hold limit (`max_hold`), she walks on to the gate: villagers walking past to their work can't
  keep her out of the towers' reach and the wave going for good. At a gate she raids a hut like
  any other mob *(decided)*. She can't break walls (`siege` 0), so at intact walls
  she lurks, singing at whoever is in reach, and goes in only through a breach, or leaves
  (docs/enemies-design.md §7a).
- **Diving.** Submerged while travelling in deep water; surfaces when one of ours is within her
  song; dives briefly when she loses a share of her HP quickly.
- Ranged units are slowed by the song but can kill her: she is frail.

## 7. Forced movement (shared by siren and octopus)

One mechanism on `Unit` (a `forced` vector per frame with a source): the siren's pull and the
octopus's grapple both set it. It overrides the unit's own walking (path, leash, flee, work)
and is released when the source ends; the unit then rescans its surroundings normally
*(decided)*. It never moves a unit into a solid tile; only the octopus's grapple may pull into
deep water, and that is a death (§8). Units on towers, on benches and inside the walls are never
moved.

## 8. Gigantic octopus (water)

The strongest water monster, but an ordinary wave member, not a boss: no special waves. It is
rare: late, only where the conditions are right (§9), and only now and then (`chance`,
`max_count`).

- **HP.** Its base HP is tuned for the late waves where it appears, since it follows the wave
  HP rule like everyone; if the wave balancing changes, re-tune it.
- **Home.** Never leaves deep water, never in a river (`min_width`, `min_deep_tiles`: it needs
  a real lake or sea).
- **Targets.** Humans and units: villagers outside, the hero, soldiers on a sortie, elementals.
  One arm per target, **never two on the same one**, so with fewer targets than arms some stay
  idle. It ignores every enemy, aquatic or land *(decided)*: food-dropping land enemies as prey
  is only a maybe idea (§13). **Buildings:** an idle arm with nobody in reach smashes a building
  of ours within reach (not huts), slamming down on it (docs/siege-design.md §5.5). Anyone in
  reach still comes first.
- **Grapple.** A hit arm hooks its target and sets forced movement towards the octopus. The
  hooked unit takes damage and fights the arm to get free: its normal attacks go at the arm (an
  entity with HP, targetable by anyone in range, so towers and soldiers can cut an arm that
  holds a villager). Arm HP 0 frees the unit. Villagers don't fight back, so someone else has
  to cut the arm.
- **Arm HP** *(decided)*: every arm has its own HP, kept between grapples (no healing). An arm
  that reaches 0 HP is **gone for `arm_respawn`** and then comes back at full HP; the octopus
  has fewer arms meanwhile, so its parallel attacks drop with them. An arm is a target only
  while it is reaching or holding (an idle arm is part of the body); damage to an arm never
  hurts the octopus's own HP, and arms don't count as enemies for the wave.
- **Drowning.** A grappled unit whose tile becomes deep water dies; the hero is downed instead
  (loses her XP as always) and revives at the village centre *(decided)*. Fliers and amphibians
  (a fire elemental) can be pulled but don't drown.
- **Diving.** It dives when it loses a share of its max HP quickly: all arms retract, hooks
  release (a unit released over deep water has drowned already; the others stand free), it
  stays under a while, and can't dive again for a while.
- **Arms** are drawn as tentacles reaching from the body to the target.

## 9. Which maps and waves get them

- **Eligibility.** A kind joins a village's wave only if some water body fits its
  `min_deep_tiles` and `min_width` **and** has a deep tile within the kind's `reach` of a
  threatened tile: a land or shallow tile within `AQUA.threat_radius` of the village centre that
  a villager, unit or the hero can stand on. Crab and siren additionally need an amphibian path
  from some spawn to a gate (§3). Computed once per game (per village in co-op).
- **Killable.** Because they block the wave, a body is only eligible if a tower can be built on
  explored open land within a level 3 watchtower's reach of a deep tile in it, close enough to
  the village's threatened tiles. Otherwise nothing could ever kill the monster and the wave
  would never end.
- **Spawns** *(decided)*: explicit `water_spawns` in the map data, deep tiles only, on the map
  edge or inside the water, each in an eligible body. The generator and the editor place them
  (docs/map-editor-design.md). Amphibians may also use ordinary edge spawns. With no `water_spawns` in an eligible
  body the game picks a random deep tile of it away from the threatened shore.
- **Waves.** `WAVE_MIX` entries get `"needs": "water"`; where not eligible their share goes to
  the filler. Every water kind is an ordinary `WAVE_MIX` member and counts towards the wave's
  size. Two optional keys: `max_count` (cap per wave and village) and `chance` (rolled per wave
  and village by the waves' `_rng`, in `Waves._start_wave`, outside the pure `wave_composition`).
  There are no boss waves.
- **A wave ends only when they are dead** *(decided)*, with the one exception of water-bound
  monsters left alone (§15). They count in the top bar's enemies number. If the map offers no
  way to reach one the wave never ends: that is what the eligibility rule and the generator's
  guarantees are for.
- **Co-op:** a water mob is spawned for one village (its `target_village`) but hurts units of
  any village in range, like a witch's bolts. Eligibility is per village; bodies can be shared.
- Every kind follows the wave HP rule, no per-kind growth.

## 10. Config

`ENEMIES`: `crab`, `leviathan`, `siren`, `octopus`, `octopus_arm` (`habitat`, `submerges`,
`min_deep_tiles`, `min_width`, `revivable`, their numbers; HP, damage and loot scale with the
difficulty like every enemy's, `DIFFICULTY_SCALED`). `AQUA`: dive and surface times,
`sink_time`, `threat_radius`, grapple numbers. `WAVE_MIX` (+`needs`, `max_count`, `chance`). All
documented there.

## 12. Later

- The leviathan may blast buildings (the octopus already smashes them, docs/siege-design.md).
- The maybe idea of §13.

## 13. Open

- **Maybe idea, do not implement:** the octopus grapples land enemies that drop food (orcs,
  goblins). A good idea but against the game's logic (enemies never fight each other; who gets
  the gold, do they fight back?).
- All numbers are first guesses.

## 15. As built

**Decisions taken while building:**

- *Map and save:* `water_spawns` live in `MapData` and in the JSON map format (tolerant import,
  strict export); a map file from before they existed still reads, with no water spawns. The
  map is part of a save, so a change to its stored form means `SaveGame.FORMAT` + 1, and the
  title backdrop's baked maps must be rebaked (rebake-title-maps skill).

- *Width* of a body: twice the most Chebyshev steps from a tile that isn't deep water, minus 1,
  with the map's edge counting as water (the sea goes on). Bodies are 4-connected deep tiles;
  **a bridge over deep water is part of the body** (`MapData.is_deep_water`), joining the water
  on both sides; its "deep" count leaves bridges out.
- *Bridges* are road and water at once. Every water monster may pass under one, but must be
  under water on its tile (`Enemy.must_be_under`): it dives on the way in (also over shallow
  water, the one exception to "only on deep water"), can't come up there (`surface()` refuses)
  and comes up again past it if it wants (the octopus does, letting go of whatever its arms
  held). Water-bound monsters swim under bridges over deep water; amphibians under any bridge,
  when they swim across beneath it; one walking along the road over the bridge stays up. No
  spot, home tile or water spawn is ever under a bridge, and a corpse there lies on the bridge.
- *Body sizes:* crab and siren need only a small body (a one-tile pond is no home) and any
  width (rivers do); the leviathan and the octopus need ever bigger ones (`min_deep_tiles`,
  `min_width`). `"reach"` in each entry feeds eligibility; distances to threatened tiles are
  Chebyshev steps.
- *Melee reach* (§2.1): `AQUA.melee_reach`, so a unit on the tile beside (diagonals too) reaches
  it. Chasing a monster on deep water goes to the walkable tile next to it nearest to the
  attacker (`Pathing.stand_near`).
- *Who engages* (§2.1a): towers through `MilitaryBehavior.enemies_near` (targetable only); the
  hero, soldiers and earth elementals through `melee_ok`; barracks with only melee units on the
  benches don't turn out for what their blades can't reach.
- *Fire elementals* strike with magic: a siren in the water doesn't keep them off (they still
  need the tile next to a monster on deep water).
- *A lured unit fights what is in its reach, except her* (§6) is read as: the song doesn't
  change who it fights; she is out of melee's reach only while in water.
- *The spatial mage's push* doesn't move water-bound monsters (no road to be thrown back along);
  amphibians are thrown back along their route like anyone.
- *Ice* slows them like anyone (the leviathan doesn't move while up, so it doesn't matter there).
- *Spawning:* water-bound monsters always come from the village's water spawns (or §9's picked
  deep tile); an amphibian half of the time, else from the edge like the rest of the wave (a
  scenario may send them from the water only: `Scenario.amphibians_from_water`,
  `Waves.amphibians_from_water`). A co-op wave's shared extra brings no water monsters. Lairs
  never send them.
- *The leviathan* arrives under water; with nobody about it goes to the deep tile nearest the
  village and comes up there every `idle_surface`. After an early dive the next surfacing must
  last `flee_min_up` before it can dive early again (after a normal dive: no minimum).
- *The siren:* she holds once the nearest of ours is within `hold_range`; she comes up when one
  of ours is within her song; once her patience runs out (or `max_hold`) she walks to the gate,
  singing, and never holds again (so a wave can't stall on her). Each unit is pulled only by its
  strongest song; pulls stop a little short of her.
- *The octopus* is up except while it dives; it moves at its speed up or under. An arm takes a
  moment to reach (`arm_reach_speed`) and lets go when its catch gets out of reach. **Arm HP
  grows with the waves** like enemy HP, so arms keep their share of the fight late on. The arm
  is an `Enemy` of kind `octopus_arm` (no wave member: spawned by the octopus, never counted,
  pays nothing, leaves no corpse); a hooked unit's `held_by` is the arm, and the hero, soldiers
  and elementals fight it first. The grapple's damage is melee.
- *Drowning:* a villager dies ("drowned, dragged under by ..."), a soldier is downed, the hero
  is downed (her XP lost), an elemental crumbles; a fire elemental (a flyer) doesn't drown.
- *Water monsters left at the end of a wave:* once nothing but water monsters is left:
  - *Water-bound ones left alone go:* when all that is left is water-bound (habitat `"water"`),
    none named (a scenario's boss, like scenario 9's leviathan) or on a post (a guard), and none
    has been in a fight for `AQUA.leave_after`, they go back into the deep
    (`Waves._check_leave`, `Enemy.vanish`: no corpse, no gold) and the wave can end. Without
    this a leviathan the player can't reach would hold the wave forever. "In a fight"
    (`AquaBehavior.engaged`): hurt lately, a leviathan blasting, an octopus with an arm out.
  - Otherwise the wave ends only when they are dead. After `AQUA.warn_after` the villages they
    came for hear it once per wave (log, Important, and a toast) so the player knows to build
    towers by the water.
