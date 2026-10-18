# Veliron's Outpost: water monsters (design)

Status: **proposal, nothing built yet.** Decisions from the review are marked *(decided)*; what
is only a maybe is in §13. Every number below is a first guess and lives in `scripts/core/config.gd`
once built (`ENEMIES`, `AQUA`, `WAVE_MIX`).

Scope: four new enemy kinds that travel through rivers, lakes and the sea (crab, leviathan,
siren, gigantic octopus), the rules they share (habitat, submerging, melee reach, corpses that
sink), how they join waves, and what the map and the world generator must provide.

## 1. Habitats

Every enemy kind gets `"habitat"`: `"land"` (default, all existing kinds), `"amphibian"` or
`"water"`.

| Habitat | Moves on | Kinds |
|---|---|---|
| land | road tiles | everything today |
| amphibian | road tiles and water tiles (deep, shallow, fords, bridges); leaves the water only onto a road tile | crab, siren |
| water | deep water only (never shallow, never land) | leviathan, octopus |

Enemies are never slowed by terrain, so shallow water and fords cost an amphibian no speed.

## 2. Submerging (all aquatic kinds)

- Only on a **deep** water tile (the octopus: all its tiles deep). Shallow water, fords, bridges
  and land never allow it.
- States: surfaced → diving (0.5 s) → submerged → surfacing (0.5 s). Diving, submerged and
  surfacing are all **untargetable**; surfaced is targetable like any enemy.
- `Enemy.targetable()` is the one test every targeting site uses (the same sites that filter
  `flies()` and `dead` today: towers, barracks, soldiers, the hero, elementals, mage splash,
  shots in flight). A shot in flight at a mob that dives fizzles. Splash and area damage skip
  submerged mobs. Healing and auras don't care.
- A submerged mob is drawn as ripples and a bubble trail, so the player sees where it is even
  when it can't be hit. It is invisible in the fog like any enemy.
- Each kind decides when to dive and surface (their sections). No kind regenerates while down.

### 2.1 Melee reach *(decided)*

A mob in deep water can be hit by a **melee-category** attacker only while surfaced and only from
a non-deep tile next to it (shallow water, ford, bridge or land; 8 neighbours). Melee units can't
enter deep water, so this is the whole melee reach: a mob two tiles out in deep water is out of
their reach. Ranged attacks (towers, archers, mages, fire elementals) reach it at their range.
The hero, shield bearers and earth elementals are melee; a halberdier is melee with reach 1.2.

### 2.1a Who engages them *(decided)*

Not only towers: the hero (in Defend) and barracks sorties go for a surfaced water mob under
their usual rules (alert radius, leash, the barracks' activation range). The mob counts as a
target for a melee unit only if it can stand on a non-deep tile next to it (§2.1); ranged units
use their range. Submerged mobs are never targets. Implementation: the hero's and soldiers'
target scans use `targetable()` plus a reachable-neighbour check.

### 2.2 Corpses *(decided)*

Every aquatic mob leaves a corpse and it can be raised or gathered like any other, with two
rules for **deep water**:

- The corpse sinks: it fades over `AQUA.sink_time` (6 s) and is then removed, so it can no
  longer be raised or gathered. (The necromancer's channel is 5 s: a channel started within the
  first second can finish, a later one can't. The existing "corpse gone mid-spell ends it" holds.)
- Corpses in shallow water and on land stay as usual and are cleared by the usual wave rule.

Leviathan and octopus corpses can never be raised (`"raisable": false`, like a raised enemy's
and a necromancer's own). A raised crab or siren never submerges.

## 3. Movement

- **Water bodies.** At map load the water tiles are labelled into connected bodies (`Pathing`):
  for each one the deep tile count and the widest point (distance from non-deep tiles). A kind's
  `min_deep_tiles` and `min_width` say which bodies it can live in (§9).
- **Amphibians** use a second flow field (per village, like the road field): a Dijkstra from the
  gates over road tiles ∪ water tiles. Land tiles off the roads are not in it. So on land they
  stay on the roads, and the only exits from the water are the road tiles that touch it: bridges
  and fords, which is the "prefer bridges" rule *(decided)* without a special case. A bridge tile
  counts as both road and water (a crab may swim under it). A crab spawned on a land edge spawn
  uses the same field and dives into a river only when that is the shorter way.
- **Water-bound kinds** don't follow routes. A behavior moves them (submerged or surfaced) over
  the deep tiles of their own body, towards the best target (§5, §8).

## 4. Crab (amphibian)

A goblin that can swim. `"behavior": "melee"` with the amphibian field, goblin stats.

| | |
|---|---|
| HP / speed | 20 / 1.1 |
| Blow | 4 damage, 1.0 s |
| Gold on kill / corpse | 3 / 3 gold, 2 food |
| From wave | 6, share 0.08 (`WAVE_MIX`, `"needs": "water"`) |

Submerges by itself: it is submerged while on deep tiles and surfaced on shallow tiles, fords,
bridges and land, never by choice. At a gate it burns a hut like a goblin.

## 5. Leviathan (water)

A sea serpent. It never leaves deep water, never moves while surfaced.

| | |
|---|---|
| HP | 220 (high) |
| Travel | submerged only, 1.3 tiles/s |
| Water blast | range 4.6, 6 damage/s for 4 s (a channel), cooldown 8 s, category *magical* |
| Surfaced | at least 5 s, at most 9 s |
| Kill gold | 40; corpse: nothing |
| From wave | 10, share 0.03, `max_count` 2 |

- **Cycle.** It lurks submerged, swims towards the deep tile nearest to the village's things
  (preferring one within blast range of something it can hurt), surfaces, picks a target and channels a water column onto it (a visible, telegraphed
  jet: 0.8 s wind-up, then continuous damage while the blast is active; the target is whoever is
  in range, villagers outside, units outside, the hero, elementals; never units on towers, nobody
  inside the walls). It may blast twice in one surfacing. Then it dives and moves on to a new
  spot at least 6 tiles away.
- **It always comes up.** Because a wave only ends when it is dead, it must be killable: with
  nothing to blast in range it still surfaces for its minimum time every `idle_surface` (20 s),
  at the deep tile nearest to the village, where the player's towers can be placed to cover it.
- **Gets hit.** While surfaced it loses HP to towers like anything else. When it loses 25 % of
  its max HP in one surfacing it dives early, but it must surface for at least 3 s the next time
  (it can't dodge forever).
- **Range.** 4.6 is below a level 3 watchtower's reach (5.2) and a wall tower's (4.8), above a
  level 2 watchtower's (4.4): it can't be answered by level 1-2 watchtowers, the player must
  upgrade or place barracks/towers well. Tune against `TOWER_RANGE` / `TOWER_LEVELS`.
- It makes shore land dangerous to build on and work on (farms by water, foresters, gatherers)
  rather than threatening the walls.

## 6. Siren (amphibian)

A support monster: she doesn't storm in.

| | |
|---|---|
| HP / speed | 24 / 0.9 |
| Resist | melee ×1.5, magical ×0.67 (`resist`) |
| Song | radius 4.5 tiles, no damage |
| Kill gold | 14; corpse: 1 food |
| From wave | 8, share 0.06 |

- **Song** (a static, visible ring on the ground around her, shown while she sings). Its strength
  at distance d is `s = 1 − d / radius` (0 at the edge, 1 on top of her). It applies to every
  unit of ours: the hero, soldiers on a sortie, elementals, villagers outside the walls, and
  stationed tower units (their shots slow down; they can't walk). It never touches enemies.
  - **Pull:** a mobile unit walks towards her at `0.9 × s` tiles/s (a forced move over the
    ground it can walk: it stops at the shore and never walks into deep water).
  - **Slow:** all its attack, cast, summon and heal timers run `1 − 0.6 × s` times as fast (a
    rate below 1, the opposite of a war cry; `Combat.haste` takes rates).
  - A lured unit still fights what is in its reach, **except her**.
- **Not attackable by melee in water.** A melee-category attacker can't target her while she
  stands on a water tile (deep or shallow, so a ford counts; a bridge tile counts as land); on land they can (the hero attacks her there). Ranged attacks always
  can. So only ranged answers, or the High Priest, work against a siren in the water.
- **High Priest.** A unit inside a High Priest's aura (`Combat.in_holy_aura`) is immune to the
  song (strength 0) and may attack her in the water like on land, melee included.
- **Behavior (witch-like).** She keeps to her max range: she holds at `hold_range` (4.0) from the
  nearest unit, building or villager of ours, sings, and lets them come. After `patience` (30 s)
  without anyone lured she walks on towards the gate (the amphibian field). At a gate she raids
  a hut like any other mob *(decided)*.
- **Diving.** Submerged while travelling in deep water; surfaces when one of ours is within her
  song radius; dives for 5 s when she loses 30 % of her HP within 6 s.
- Ranged units are slowed by the song but can kill her: she is frail (24 HP) and takes ×1.5
  from melee when it can reach her.

## 7. Forced movement (shared by siren and octopus)

One mechanism on `Unit` (a `forced` vector per frame with a source): the siren's pull and the
octopus's grapple both set it. It overrides the unit's own walking (path, leash, flee, work) and
is released when the source ends; the unit then rescans its surroundings normally *(decided)*.
It never moves a unit into a solid tile; only the octopus's grapple may pull into deep water, and
that is a death (§8). Units on towers, on benches and inside the walls are never moved.

## 8. Gigantic octopus (water)

The strongest water monster, but an ordinary wave member, not a boss: no special waves. It is
rare: it can only come from wave 20 on, only where the conditions are right (§9), and then only
now and then (`chance`, `max_count` 1).

| | |
|---|---|
| HP | 1200 (huge) at wave 1's scale, grown by the waves' HP rule like every enemy (so the base is tuned for wave 20+: with today's ×1.15 it would be about 17,000 at wave 20; to be set once the wave balancing is settled) |
| Speed | 0.5 tiles/s, surfaced or submerged |
| Arms | 8, each its own attack |
| Arm | range 4.5, cooldown 6 s each (the arms start staggered by 0.75 s: a grapple lands about every 0.75 s with all eight busy), 3 damage/s while grappling |
| Arm HP | 30 each, tracked per arm (scaled by difficulty) |
| Grapple pull | 0.6 tiles/s |
| Kill gold | 250; corpse: nothing |
| From wave | 20, `WAVE_MIX` entry with `chance` 0.25 per wave and village, `max_count` 1 |

- **Home.** Never leaves deep water, never in a river (`min_width` 3, `min_deep_tiles` 80).
- **Targets.** Humans and units: villagers outside, the hero, soldiers on a sortie, elementals.
  One arm per target, **never two on the same one**, so with fewer targets than arms some stay
  idle. It ignores every enemy, aquatic or land *(decided)*: food-dropping land enemies as prey
  is a maybe idea only (§13), not to be built. Buildings: nothing yet; it attacks them once they
  have HP (§12).
- **Grapple.** A hit arm hooks its target and sets forced movement towards the octopus. The
  hooked unit takes 3 damage/s and fights the arm to get free: its normal attacks go at the arm
  (an entity with HP, targetable by anyone in range, so towers and soldiers can cut an arm that
  holds a villager). Arm HP 0 frees the unit.
  Taking arm damage is part of the fight, not extra. Villagers don't fight back.
- **Arm HP** *(decided)*: every arm has its own HP, kept between grapples (no healing, a
  hurt arm stays hurt). An arm that reaches 0 HP is **gone for `arm_respawn` (30 s)** and then
  comes back with 100 % HP; the octopus has fewer than 8 arms meanwhile (its parallel attacks
  drop with them). An arm is a target only while it is reaching or holding (an idle arm is part
  of the body); damage to an arm never hurts the octopus's own HP, and arms don't count as
  enemies for the wave.
- **Drowning.** A grappled unit whose tile becomes deep water dies; the hero is downed instead
  (loses his XP as always) and revives at the village centre *(decided)*. Fliers and amphibians
  (a fire elemental) can be pulled but don't drown.
- **Diving.** It dives when it loses 15 % of its max HP within 6 s: all arms retract, hooks
  release (a unit released over deep water has drowned already; the others just stand free), it stays under 6 s, and can't dive again for 20 s.
- **Arms** are drawn as tentacles reaching from the body to the target.

## 9. Which maps and waves get them

- **Eligibility.** A kind joins a village's wave only if some water body has at least its
  `min_deep_tiles` and `min_width` **and** a deep tile within `reach` (its range + 1) of a
  threatened tile: a land or shallow tile within `AQUA.threat_radius` (12) of the village centre
  that a villager, unit or the hero can stand on. Crab and siren additionally need an amphibian
  path from some spawn to a gate (§3). Computed once per game (per village in co-op).
- **Killable.** Because they block the wave, a body is only eligible if a tower can be built on
  explored open land (a buildable tile) within a level 3 watchtower's reach (`TOWER_RANGE` +
  the last `TOWER_LEVELS` bonus) of a deep tile in it, close enough to the village's threatened
  tiles. Otherwise nothing could ever kill the monster and the wave would never end.
- **Spawns** *(decided)*: explicit `water_spawns` in the map data, deep tiles only, on the map
  edge or inside the water; each in an eligible body. The generator and the editor place them
  (§11). Amphibians may also use ordinary edge spawns. With no `water_spawns` in an eligible
  body the game picks a random deep tile of it at least 8 tiles from the threatened shore.
- **Waves.** `WAVE_MIX` entries get `"needs": "water"`; where not eligible their share goes to
  the filler. Every water kind is an ordinary `WAVE_MIX` member and counts towards the wave's
  size. Two optional keys are new: `max_count` (at most this many per wave and village) and
  `chance` (rolled per wave and village by the waves' `_rng`, in `Waves._start_wave`, outside
  the pure `wave_composition`). There are no boss waves.
- **A wave ends only when they are dead** *(decided)*: no timeout, no vanish timer. They count in
  the top bar's enemies number. (If the map offers no way to reach one, the wave never ends:
  that is what the eligibility rule and the generator's guarantees are for.)
- **Co-op:** a water mob is spawned for one village (its `target_village`) but hurts units of any
  village in range, like a witch's bolts. Eligibility is per village; bodies can be shared.
- Every kind follows the wave HP rule, no per-kind growth. The base HPs here assume today's rule and must be re-tuned if the wave balancing changes.

## 10. Config

`ENEMIES`: `crab`, `leviathan`, `siren`, `octopus` (with `habitat`, `submerges`,
`min_deep_tiles`, `min_width`, `raisable`, and their numbers; HP, damage and loot scale with the difficulty like every enemy's, `DIFFICULTY_SCALED`).
`AQUA`: dive and surface times,
`sink_time`, `threat_radius`, the siren's song numbers (or in her entry), grapple numbers.
`WAVE_MIX` (+`needs`, `max_count`, `chance`). All documented there.

## 11. Code and data

- `Enemy`: `habitat()`, `submerged`, `targetable()`, dive/surface state; behaviors
  `leviathan_behavior`, `siren_behavior`, `octopus_behavior` (+ an `Arm` entity); the crab
  reuses `melee_behavior`.
- `Pathing`: water bodies, the amphibian field, deep-tile BFS for water-bound movement.
- `Corpse`: sinking in deep water (`sink_time`), `raisable`.
- `Unit`: forced movement (§7). `Combat`: song slow as a rate, melee reach rule, the siren's
  melee filter, holy-aura immunity.
- `MapData`: `water_spawns: Array[Vector2i]` (packed form, `to_dict`/`from_dict`), JSON map
  format key `"water_spawns"` with a format version bump, tolerant import, strict export.
  `SaveGame.FORMAT` + 1 (the map is in the save). Rebake `data/title_maps/`.
- Editor: a *Water spawn* tool (like the spawns tool; only deep tiles), a layer, an inspector
  line for the water body (deep tiles, width, which kinds fit), checks (a water spawn must be on
  deep water in a body that fits at least one kind; error), Tidy leaves them alone.
- Replication: `submerged`, the arms and the song ring reach co-op clients; they see only what
  their village sees.
- Library: an entry per kind. Log (Important/Info): the first of each kind per game.
- Art (`tools/gen_art.py`): crab, leviathan (surfaced head and coils, a ripple when down),
  siren, octopus and tentacle, water column, song ring, dive splash.
- Test: `tests/aqua_bot` on hand-built maps (a test map made with `MapData` edits: a lake
  next to a village, a river with a bridge, an inlet).

## 12. Later

- Buildings with HP and destroyable by creatures: then the octopus attacks buildings in range
  when no edible target is (`buildings` in its target list), and the leviathan may blast them.
- The maybe idea of §13.

## 13. Open

- **Maybe idea, do not implement:** the octopus grapples land enemies that drop food (orks,
  goblins). It is a good idea but against the game's logic (enemies never fight each other; who
  gets the gold, do they fight back?).
- All numbers are first guesses, tune with the bot and by playing.

## 14. Phases

1. **Foundation and crab:** `habitat`, `targetable()`, the dive state, water bodies, the
   amphibian field, `water_spawns` (map, JSON, editor tool, check), deep-water corpses, wave
   eligibility and "blocks the wave", library, `aqua_bot`; tested on hand-built maps.
2. **Leviathan.**
3. **Forced movement, then siren.**
4. **Gigantic octopus** (and `max_count`, `chance`).
5. **World generator:** the map must really give them water (docs/world-design.md §9.8).
   Until then the new kinds only appear on maps from the editor or tests.
