# Veliron's Outpost: world generation (design)

Status: **built** (all decisions in §16; milestones 1-6 of §15). Tested by
`tests/world_bot.gd`. §17 lists details of the build and what's left.
Scope: the map generator with vegetation zones, roads, water (lakes,
rivers, coasts) and volcanoes; map types; special objects (treasures,
guarded camps, unit-unlock sites, ruined watchtowers, monster lairs, mines
and the miner). No eruptions.
Every number lives in `scripts/core/config.gd` (and the generator under
`scripts/world/gen/`); this document gives the reasons, not the values.
Maps can be looked at with `tools/map_shot.sh` (see its header).

## 1. Summary

- **Allocations:** every player gets an equal-area **slice** of the map
  around its centre, so every village has its own stretch of map edge. The
  terrain is generated for the whole map; then each village is put on good
  land near its slice's centre, well away from any other village.
- **Zones:** large vegetation zones: pine forest, oak woods, meadow, heath,
  steppe/desert, swamp, and ash land around volcanoes. Each has its own
  ground, tree mix and density. Where most zones fall depends on two
  large-scale noise maps (height and moisture), so neighbouring zones blend
  naturally.
- **Roads** are planned as a network first (in co-op every village is linked
  to others, so nobody is cut off). Then each road is routed with a
  terrain-weighted pathfinder. Roads curve naturally, go around mountain
  ranges (or through a pass when there's no other way) and merge instead of
  running side by side.
- **Water:** small lakes, rivers with **bridges** and **fords** where roads
  cross, and coast maps where map edges are sea. Bridges look different
  depending on the zone (only the look).
- **Volcanoes** as scenery, with ash land around them. Ash land never
  exists without a volcano. No eruptions.
- **Map types:** Temperate, Highlands, Coast, Desert, Volcanic
  (`Config.MAP_TYPES`).
- **Special objects:**
  - treasures, looted automatically by the hero in Explore mode (unguarded
    ones), first come first served;
  - monster camps guarding some treasures;
  - **unit-unlock sites** (summoner, apprentice, acolyte): whoever unlocks
    one first unlocks that unit for **every** player;
  - **ruined watchtowers**, claimed by the hero in Explore mode, then
    restored by a builder for a share of the cost;
  - **monster lairs** (a cave, a giant hollow tree...) that wake up late in
    the game and send part of every wave;
  - **mines** in mountain ranges, worked by the **miner** villager for
    gold. The miner becomes available to everyone once anyone reaches a
    mine.
- **Fair in multiplayer:** every slice gets the same number and tiers of
  treasures, and the land around every village is repaired to the same
  minimum. Zone shares per slice are a soft goal. Not every kind of feature
  has to appear in every slice.
- Generation speed doesn't matter for now.

## 2. Sizes and counts at a glance

The numbers are in `config.gd` (`MAP_SIZES`, `Config.map_size`, `SP_SPAWNS`,
`COOP_SPAWNS`, `LAKE_COUNT`, `RIVER_COUNT`, `MOUNTAIN_SHARE`, `MAP_TYPES`,
`TREASURE_COUNT`, `RUINED_TOWERS`, `LAIRS_PER_SLICE`, `MINES_PER_SLICE`,
`UNLOCK_SITE_SHARE`). The shape:

- The map grows with the player count, so a co-op slice is about as roomy as
  a single-player map. The map editor makes other sizes; the per-slice
  amounts (treasures, ruins, lairs, mines) then scale with the slice's area
  against the usual size, and edge spawns and rivers with the width
  (`Config.gen_area_scale`, `gen_length_scale`; 1 at the usual size, so
  those maps don't change; docs/map-editor-design.md §3).
- Slices have equal tile counts (± 1).
- Per-slice counts are small ranges, never fixed totals, except treasures:
  the same count and tiers in every slice.
- Lakes, rivers, mountains, volcanoes and mines scale with the map type's
  multipliers.
- Unlock sites: per kind, about one copy per two players (at least one).

## 3. The generator, in stages

Each stage only reads what earlier stages made. Everything comes from the
map seed (no global random numbers), so a seed and map type always make the
same map. In co-op only the host generates; clients receive the finished map.

### 3.1 Allocations (slices)

First, the map is divided into one **slice** per player, each covering the
same number of tiles:

- **1 player:** the whole map.
- **2 or more:** equal-area slices around the map centre, with a random
  rotation. On a square map equal angles don't give equal areas (corners
  hold more), so the tiles are sorted by their angle around the centre and
  cut into N runs of equal length.
- Every slice reaches the map edge (its own stretch of edge for spawns) and
  touches the middle (its neighbours on both sides). That holds for 8 players
  too: the slices get narrow but always keep some world edge.
- A slice's **centre** is the centre of mass of its tiles (the map centre
  with one player).

The slice is then used for:

- **village position** (§3.2, step 6);
- **home spawns** on its own stretch of the map edge;
- the **road network**: links between neighbouring slices (§5.1);
- **fairness** and **objects**, counted per slice (§4.3, §9);
- **ownership** of land (which village's area a tile is in).

The terrain itself doesn't know about slices: it's generated for the whole
map. Slices only decide where things go and what gets checked. Some stages
keep away from the slice centres (where the villages will go): lakes, river
sources, mountains and volcanoes (§6, §7).

### 3.2 Stages

1. **Slices** (§3.1).
2. **Fields:** height and moisture noise (Godot's `FastNoiseLite`), each
   value replaced by its rank (0..1) so shares are predictable on every seed,
   then shifted by the map type (§8). Plus a small "detail" noise for ragged
   edges.
3. **Water:** sea along the coast edges (Coast type), lakes in low ground,
   rivers downhill from high ground to a lake, the sea or the map edge (§6).
4. **Mountains and volcanoes** (§7). Ash land is marked around each volcano.
5. **Zones and vegetation:** each tile gets a zone from height × moisture
   (§4), ash land where marked; then trees and decoration by zone.
6. **Villages:** for each slice, pick the best tile near its centre. A tile
   qualifies if it keeps clear of water, mountains and lava round the walls,
   keeps its distance from the sea and from volcanoes, from every other
   village, from its slice's border (co-op) and from the map edge, and lies
   in its own slice (`VILLAGE_*` in config). Among those, the nearest to the
   centre wins, with meadow a little preferred and pine forest, steppe,
   swamp and ash land held back. If no tile qualifies, the rules are loosened
   in steps; if still nothing, the village goes on the slice's centre and the
   map counts as failed. The 5×5 village is then stamped in, with a clearing
   ring cleared of trees; steppe, swamp and ash land in that ring become
   meadow. In single player the same rule applies, around the map centre.
7. **Road network:** which places are linked (§5.1).
8. **Road routing:** the route of each link on a cost map (§5.2); roads
   replace the trees on their tiles, with bridges, fords and mountain passes.
9. **Fix steps**, per village, each a small local repair after the big
   stages:
   - **fair land** (§4.3): repaint land around a village that falls short;
   - **starting camp:** make sure there are trees within reach of the
     worker camp.
10. **Special objects** (§9), including the road spurs to mines and the
    roads to lairs.
11. **Checks** (§5.3): if a check fails, the map is made again from another
    seed (`MAP_TRIES` tries at most); the best try is kept. A missed soft
    goal (slice fairness) is retried only once.

The code is split along these stages (§12).

## 4. Zones

### 4.1 The zones

The zone is a per-tile value next to the terrain. **Terrain** says what a
tile does (walkable, buildable, road, water, mountain). **Zone** says how it
looks and what grows there. The values (ground, tree share and mix, farm
rules, walking factor) are in `Config.ZONES`; the intent:

| Zone | Where | What it is for |
|---|---|---|
| Pine forest | wet | dense, dark; lots of wood, hard to see through |
| Oak woods | middling moisture, or higher ground | fewer trees per area, but an oak takes longest to chop, so it lasts the most trips |
| Meadow | drier, low ground | open, farm land with a food bonus |
| Heath | high ground | sparse, dead trees and boulders |
| Steppe / desert | very dry | sand, almost no trees, no farms |
| Swamp | very wet, low, near water | slows walking off the road, no farms |
| Ash land | only around volcanoes | charred, no farms, no building near the crater |
| City | never generated: map files only (the campaign's capital) | cobblestones; houses on its mountain tiles; no farms |

- A zone's tree share is a base value; a clumping noise makes it denser in
  patches and thinner elsewhere. Tiles with trees are forest terrain, which
  is what foresters chop.
- **Meadow bonus:** a farm gets its food bonus only when more than half of
  its tiles are meadow, so a farm has to be placed with care, not just
  anywhere.
- **Swamp** slows walking only off the road: on any road tile the factor is
  1, so enemies (who walk only roads) are never slowed by swamp. The player
  pays for the swamp, the enemy doesn't.
- **Ash land** doesn't come from the noise maps. It's painted in a ring
  around each volcano (§7.2), and on lava rivers, so every patch of ash land
  has a volcano.

### 4.2 How big zones are

The noise scale (`ZONE_SIZE`) sets the size of a zone, so a normal map has a
handful of zone patches rather than noise confetti. Zone borders are made
ragged by a little extra noise (`ZONE_BLEND`). Steppe is capped
(`DESERT_MAX_SHARE`, and the Desert type's `steppe_max`) so no map is all
sand: the wettest of the rest becomes meadow. None stays near a village
(§4.3).

### 4.3 Fair land around villages

Within `ZONE_FAIR_RADIUS` of every village centre (`ZONE_FAIR_*`):

- no steppe, swamp or ash land close to the village: it is repainted as
  meadow;
- a minimum share of meadow: the nearest open tiles become meadow;
- a minimum share of trees: woods are planted (below).

The generator keeps **no room for a farm**: the game places the starting
farm on the finished map, on the nearest free spot by the village, or not
at all (docs/village-design.md §4). A harsh map can mean a harder start.

This is repaired in a fix step (§3.2, step 9), never by regenerating the
map, so a seed's character survives. In single player the same rule applies
to the one village.

In multiplayer, the zone shares of whole slices should differ by at most
`ZONE_FAIR_SPREAD` (for example 30 % vs 45 % forest). This is a soft goal
(§5.3), not repaired: repairing whole slices would flatten the map.

Missing trees grow as **oak woods** (`ZONE_FAIR_WOODS`): each planted tile
becomes zone `oak` (its ground and tree mix, so no green trees on sand), one
tile at a time on the open tile that scores best: forest next to it (woods
grow on), a noise value (patches, not an even spread), a little distance from
the village, and meadow last (kept for farms). Not within the clearing ring
plus one, not on or next to a road. If no spot near the village has enough
trees around it, the worker camp gets a grove, grown the same way in a round
patch beside the village, so the forester always has something to chop.

## 5. Roads

### 5.1 The network (what gets linked)

- **Single player:** a few edge spawns (`SP_SPAWNS`), spread around the map
  edge. Each gets a road from the gate facing it out to the edge. Existing
  road is cheap to follow, so later roads join earlier ones: roads branch and
  merge on their way in. If the village still has fewer than 2 approaches, a
  free gate gets a road straight out to the map edge (a few tries), which is
  one more spawn.
- **Co-op:**
  - A **ring road** runs round every village just outside its walls and joins
    its four gates.
  - **Village ↔ village links:** two players: one link. Three: a triangle.
    Four to eight: the villages, ordered by their angle around the map
    centre, are linked in a ring; with more players, a few extra links
    (chords) join a village to the one opposite it. The aim is that losing
    one road never isolates a village.
  - **Every village keeps at least `VILLAGE_MIN_LINKS` links** (fewer with two
    players). A link whose road would be much longer than the straight
    distance (`ROAD_DETOUR_MAX`) is tried once more through a mountain pass;
    if that's still too long or impossible, it's dropped. A village left
    with too few links is linked to its next-nearest villages. If that
    doesn't work either, the map fails its check and is made again.
  - **Spawns:** each village gets a few edge spawns (`COOP_SPAWNS`) spread
    along its slice's stretch of land edge, each with a road from the gate
    facing it. Every road tile on the map edge is a spawn of the village
    whose slice it lies in (its `home_spawns`).
- **Gates:** a road leaves by the gate facing where it goes. A gate that
  already has a road counts as a little worse in the choice, so roads
  spread over the gates, but two roads may still leave by the same gate. A
  gate with a road leading away is an **approach**; every village needs at
  least 2 (§5.3), so enemies never have exactly one way in.
- Roads never pass through a village's walls.
- **Mines** get a short road spur to the nearest road; **lairs** get a
  winding road (§9.6).

### 5.2 Routing (where a road goes)

Each road is routed with A* (`AStarGrid2D`, 4 directions only) on a cost
map (`ROAD_COSTS`). The ordering of the costs is the design:

- existing road is cheapest, so roads merge like rivers;
- open land is cheap, woods and heath dearer, pine forest and swamp dearest
  of the land;
- shallow water and river tiles are expensive (a ford / bridge is a last
  resort, not a habit);
- mountains are impassable on the first try and merely very expensive on a
  second (a pass);
- villages and the ring around their walls, deep lakes, the sea and volcanoes
  are impassable; so is the map edge except the road's own end.

Other rules:

- A low-frequency noise scales the cost (`ROAD_COST_NOISE`), so roads curve
  gently instead of running in straight lines.
- A tile right next to a road costs extra (`ROAD_BESIDE_COST`), so a new
  road either joins the existing one (cheap) or keeps a tile away from it.
- Only four directions: a road tile that only touches the next one at a
  corner wouldn't connect visually.
- **Passes:** spawn roads, the single-player extra approaches and village
  links that can't get through (or, for links, only by a long detour) are
  routed again with every mountain tile (not volcanoes) open at a high cost.
  Mine spurs and lair roads never cut passes.
- Lair roads keep off the other objects.

Carving a road: river tiles of deep water or lava get a **bridge** (§6.3 for
the look; lava always the charred one), shallow tiles a **ford**, mountain
tiles become road (drawn as a rocky pass where two or more mountains are
beside it). Trees and decoration on the road are removed.

### 5.3 Checks

Hard (the map is made again, §3.2 step 11):

- Every village has at least one spawn, and every home spawn reaches its
  village's gates by road.
- Every village has at least 2 approaches.
- Every village found a spot (§3.2); in co-op, every village has its links
  (§5.1).
- Every kind of unlock site has at least one copy (§9.4).

Soft (retried once, the better try kept):

- In co-op, the zone shares of the slices differ by at most
  `ZONE_FAIR_SPREAD`.

## 6. Water

### 6.1 Kinds

- **Deep water** (terrain `WATER`): impassable for everyone, not
  buildable. It doesn't block sight.
- **Shallow water** (terrain `SHALLOW`): the rim of lakes and the sea, the
  banks of rivers here and there, and fords. Slows walking (`SHALLOW_WALK`)
  for units, villagers and the hero, and for enemies on a ford. Not
  buildable. Enemies only cross it at a ford on their road.
- **Shore:** a sand rim on the land side of the sea (beaches).

### 6.2 Lakes

- A few per map (`LAKE_COUNT`) × the type's `lakes`, in a size range
  (`LAKE_SIZE`). Each starts at a low point and grows into its lowest
  neighbouring tiles, with a little noise for ragged shores. The rim is
  shallow.
- Kept well away from every slice centre (`LAKE_VILLAGE_DIST`), so a village
  isn't flooded; §9.8 adds the lagoons that deliberately come close.
- Swamp forms on the wet, low ground near water (§4.1).

### 6.3 Rivers, bridges and fords

- A few per map (`RIVER_COUNT`) × the type's `rivers`. A river starts on
  high ground well away from every slice centre and other water, and runs
  downhill to a lake, the sea or the map edge. It is one tile of deep water,
  with shallow banks here and there, so it is a narrow obstacle, not a
  barrier.
- They wind instead of running straight to the nearest edge:
  - they head for a random water or edge tile within `RIVER_GOAL_SLACK` of
    the distance of the nearest one;
  - they follow the low lines of a ridged noise (`RIVER_MEANDER`,
    `RIVER_MEANDER_FREQ`), plus a little jitter (`RIVER_JITTER`);
  - they keep well clear of the slice centres.

  In hills the height still leads them along the valleys.
- Where a road crosses a river's deep water it gets a **bridge**. Where it
  crosses shallow water (a river bank, the rim of a lake or the sea) it gets
  a **ford** (a road on stepping stones, slowing like any shallow tile). Deep
  lakes and the sea are never crossed. Bridges and fords are natural choke
  points, good for towers.
- **How bridges look:** always man-made, in a style that depends on the zone
  around them (`BRIDGE_STYLES`). Only the look changes, never the behaviour:
  a sturdy stone arch in meadow and oak woods, weathered timber in pine
  forest and heath, sun-bleached timber and rope on steppe, mossy sagging
  planks on stilts in swamp, charred beams in ash land and over any lava.

### 6.4 Coast (map type Coast)

- One or two neighbouring map edges become sea (only one with many players,
  whose slices are narrow), a share of the map (`COAST_SHARE`), with a
  ragged coastline. Only water connected to the chosen edges is sea. The
  sea's rim is shallow; the land tiles along it are beaches.
- Slices are cut as usual. A slice left with almost no land on its stretch
  of edge gets a land strip cut from the middle of that stretch inwards, so
  it keeps some land edge for its spawns. Waves only come from land edges.
  Villages keep their distance from the sea (§9.8 for the inlets that bring
  it back close).

### 6.5 In the game

- Pathing: deep water and lava are solid; shallow water and swamp off the
  road are walkable at a higher cost (`MapData.walk_factor`).
- Farms can't stand on water. A farm with water next to it gets a small food
  bonus (`FARM_WATER_BONUS`).
- Fog and sight: no change (water is terrain like any other).
- Art: water tiles with a light shimmer (a small shader on the water layer)
  and a foam rim where water meets land.

## 7. Mountains and volcanoes

### 7.1 Mountains

- Every land tile gets a score: mostly the ridges of a ridged noise (its
  zero lines), some height, a little detail noise. The best-scoring share
  of the map (`MOUNTAIN_SHARE` × the type's `mountains`) becomes mountain,
  anywhere except near a slice centre. Small clumps are removed again, so
  ranges follow the noise ridges, with gaps here and there.
- A range may lie between two villages; the road goes around it, cuts a pass
  through it, or that link is dropped (§5.1).
- **Mines** sit on the outer edge of ranges (§9.6).

### 7.2 Volcanoes

- How many depends on the map type (`MAP_TYPES` "volcanoes"): none on
  Coast, most on Volcanic. A volcano that finds no spot is left out.
- Placed after the mountains, before the zones and the villages. Each is the
  best of many random spots, scored by height and nearby mountain tiles (so
  they often stand in or by a range). A spot needs land or mountain under its
  whole footprint, distance from other volcanoes and a good distance from
  every slice centre (`VOLCANO_SLICE_DIST`, relaxed in steps if no spot is
  found). Villages then keep their own distance from every volcano
  (`VILLAGE_VOLCANO_DIST`, also relaxed when the village rules are loosened,
  §3.2).
- A volcano is a block of impassable mountain tiles (roads never cut a pass
  through it): a peak with a glowing crater and rising smoke (animated).
- **Ash land** within `VOLCANO_ASH_RADIUS` (ragged with the detail noise):
  grey ground, lava rock, charred stumps, no farms. The ring is painted over
  every tile in reach as a zone; water and mountains under it keep their
  terrain. Nothing can be built near the crater (`VOLCANO_NO_BUILD`,
  `MapData.near_crater`).
- **Lava rivers** (Volcanic only, instead of water rivers): from each
  volcano towards the nearest map edge, stopping at a mountain. Lava is
  impassable and glows; roads cross it on charred bridges. Lava tiles count
  as ash land.
- **No eruptions.** Volcanoes are scenery and obstacles.

## 8. Map types

A type only changes the fields, water and counts (`Config.MAP_TYPES`).
Everything else stays the same. Each type has a character:

- **Temperate** (default): the generator as is.
- **Highlands:** higher and drier, so more heath; fewer lakes, more rivers,
  more mountains and mines.
- **Coast:** one or two sea edges; a little wetter and lower; fewer
  mountains, no volcanoes.
- **Desert:** much drier, steppe up to a larger cap; almost no water.
- **Volcanic:** a little higher and drier; **lava rivers** instead of water
  rivers; the most volcanoes.

- Chosen in the single-player menu and in the lobby (host). "Random" is also
  allowed: it picks a type from the seed.
- The seed and type are shown in the settings dialog, so a good map can be
  played again. An optional "Seed" field in the menus allows typing one in.

## 9. Special objects

These are neutral things on the map. They are **hidden in the fog** until
explored. When a village finds one, its log says so at **Info** level,
saying who can use it, e.g.:

- "Found a ruined watchtower. The hero can claim it (Explore mode)."
- "Found an old stone circle. Nothing stirs here yet." (awake: "Found the
  awakened stone circle. The hero can unlock the summoner there (Explore
  mode).")
- "Found a buried chest. The hero loots it in Explore mode."
- "Found a monster camp guarding a treasure. Tap it and order: Attack with
  the hero."
- "Rivermoor's explorer 2 reached a mine: every village can recruit miners
  now." (for everyone)

**Placement:** objects are placed per slice (§3.1), but **not every kind has
to appear in every slice**. Mines only come where there are mountains,
lairs and ruins are spread over the map, and unlock-site copies are fewer
than slices. What is kept fair is the **treasures** per slice (the same
count and tiers at the same distances from each village). Every object
stands on open land (not on a road, in a village, on the map edge, or right
next to a village centre), keeps `OBJECT_SPACING` from other objects, and is
reachable on foot from its slice's village. Objects are replicated like
buildings (id, kind, state: hidden / found / looted / claimed / taken).

### 9.1 The hero in Explore mode

The hero's Explore mode has a priority list. She takes the nearest thing of
the highest priority there is, among what her village has found and she can
walk to:

1. **claims:** unlock sites that have awakened (§9.4) and ruined
   watchtowers (§9.5);
2. **looting** unguarded treasures and dropped loot (§9.2);
3. then **exploring** unknown land.

- There is **no range limit**: she goes wherever the nearest target is, in
  any slice.
- She doesn't loot guarded treasures until their camp is cleared (§9.3), and
  she never attacks a camp on her own.
- The explorer villager only reveals objects. He can't claim, unlock or
  loot. Gatherers don't loot treasures either: besides corpses they only
  pick up dropped loot (§9.2).
- **No hover hints or markers.** The player learns about objects through the
  Info messages in the log (above, and §9.4).

### 9.2 Treasures

Kinds (`Config.TREASURES`: where each can lie, its loot time and reward):
buried chest (anywhere), overgrown ruins (woods, forest, heath), shrine
(meadow, heath; XP for the hero or a full heal for every unit), standing
stones (heath, hills), shipwreck (beach), dragon bones (ash land). The
kinds differ from slice to slice because they need their terrain, but the
count and tiers are the same.

- **Tiers** by distance from the slice's village (`TREASURE_TIER_DIST`),
  scaled by `TREASURE_TIER_SCALE`. Far is worth more and is more dangerous.
- **Relics** give a small permanent bonus to the village that finds one
  (`RELICS`: tower range, revive speed, hero rest healing, farm food).
  Standing stones and dragon bones of the higher tiers hold a relic instead
  of gold some of the time, at most `RELIC_MAX` per map, so relics stay
  special. Cleared lairs can drop one too (§9.6).
- **Looting:**
  - The **hero** loots automatically in Explore mode (§9.1). She walks there,
    loots for the loot time, and carries the reward home. There is no "Send
    hero" button: fewer choices. Each treasure looted earns her XP
    (`HERO_XP_PER_ACTION` "loot"); picking up dropped loot earns none.
  - The reward is paid when the looter gets home, like corpses. If the hero
    is downed on the way home, or switched to another mode, she drops the
    loot where she is (a small sack), and anyone can pick it up: a hero in
    Explore mode or a gatherer.
- **First come, first served:** anyone can loot any treasure, in anyone's
  slice. Whoever finishes looting first gets it, and the log tells everyone.
- **Counts:** `TREASURE_COUNT` per slice (the same number for every slice,
  a third of each tier as near as it goes), within `TREASURE_DISTANCE` of
  the village.

### 9.3 Guarded treasures: monster camps

- Many treasures are guarded by a **camp** (`CAMP_CHANCE`): every far
  treasure, some of the middle ones and none of the near ones. Every slice
  has at least one far camp (its far treasure is placed where a camp fits,
  closer to the village if need be). A camp is a tent and a fire near its
  treasure, with neutral monsters by its tier (`CAMP_MONSTERS`), tougher
  than normal (`CAMP_HP_SCALE`). They stay by their camp (they don't walk
  the roads), attack what comes within `CAMP_AGGRO` and never follow it
  farther than `CAMP_LEASH` from the camp.
- The treasure can only be looted once the camp is cleared.
- **Sending the hero is an explicit choice**, because it's a real fight: the
  camp's panel has "Attack with the hero". The hero then goes there (whatever
  mode she was in), fights until the camp is cleared or she is downed, and then
  goes back to her mode. A mode button cancels the order; one she can't reach
  she gives up after `HERO.camp_give_up` (docs/hero-design.md §4.5).
- The guards are enemies, so towers and barracks fight any that come within
  their range without an order; only the hero needs it.
- Once cleared, the treasure counts as unguarded and the hero loots it in
  Explore mode.
- **A failed attack isn't wasted:** if the hero is downed at the camp, the
  monsters don't heal back and the ones killed stay dead. The next attack
  finishes the job.
- Cleared camps stay empty. This gives the hero something to do between
  waves.
- Explorers (and the hero in Explore mode) keep away from camp guards (and
  awake lairs' guards). They would only flee home from them again and again,
  so the fog right by a camp waits until it's cleared.
- **Fleeing uncovers the camp:** whoever flees from a camp's guards (an
  explorer, any villager, the hero in Build / Explore / Gather; every game
  type) uncovers the camp (`CAMP_REVEAL`) and finds it for their village
  (`Civilian._reveal_camps`, logged), so the hero can be sent to attack it at
  once. Otherwise a camp hidden in the fog could never be ordered.

### 9.4 Unit-unlock sites

Some units have to be found on the map instead of being in the Army tab
from the start: the summoner (stone circle), the apprentice (mage's tower
ruin) and the acolyte (ruined chapel). Each site awakens at a given wave,
the later units further out. Archers, shield bearers and barracks are there
from the start. The table lives in `config.gd` (`UNLOCK_SITES`; `LOCKED`
lists what has to be unlocked).

- **Global unlocks:** when anyone unlocks a site, that unit kind is unlocked
  for **every** player. The log tells everyone who did it.
- **How many:** per kind of site, `max(1, floor(players × UNLOCK_SITE_SHARE))`
  copies. Each copy is in a different slice (picked at random), at the
  site's distance from that slice's village (if no spot fits, a slightly
  wider band).
- **Before the wave**, the sites are already on the map as dormant scenery
  (a mossy circle of stones, an empty tower ruin, a roofless chapel). They
  can be found, but nothing can be done there yet.
- **At the given wave** every copy awakens at once (the stones glow, a light
  shines in the tower, light falls into the chapel). Each player gets an Info
  message, depending on whether **their own village** has already found a
  copy (another player's find doesn't count):
  - not found yet, a rumour ("Travellers speak of an old stone circle
    somewhere in the wilderness. Whoever finds it can call forth
    summoners."; likewise for the other two);
  - already found: "The stone circle has awakened. The hero can unlock the
    summoner there (Explore mode)." (and likewise for the others).

  There is no marker; the site has to be explored.
- **Unlocking:** the **hero** walks there (Explore mode goes for it first,
  §9.1) and spends `visit_time`. Then the unit kind appears in everyone's
  Army tab, with a toast and a log message.
- The other copies of that site then stay as scenery (nothing more to get
  there).
- Before a unit is unlocked, it isn't in the Army tab at all.
- **When new units are added later: ask how each one is unlocked** (from the
  start, a site, a wave, something else) before building it.

### 9.5 Ruined watchtowers

- Old watchtowers out in the land (`RUINED_TOWERS` per slice, within
  `RUIN_DISTANCE` of the village), always near a road (the more road
  nearby, the likelier the spot), so they can be reached and defended.
- The explorer (or anyone) can **reveal** one. Only the **hero** can
  **claim** it: in Explore mode she goes there before exploring new land
  (§9.1). Claiming takes `RUIN_CLAIM_TIME`.
- A claimed ruin belongs to the claiming village, but it's still a ruin.
  **Restoring** is an explicit order: its panel has "Restore (cost)". The
  ruin becomes a devastated watchtower of that village, and its repair is
  ordered at once: `REPAIR_SHARE` of a watchtower's price, done by a
  **builder** like any repair (docs/siege-design.md §4). Then it's a normal
  watchtower.
- A map file can also hold a **ruined barracks** (a ruin with `"building":
  "barracks"`; the campaign's Wardline, docs/scenarios-design.md §7.6):
  claimed and restored the same way, it becomes devastated barracks. The
  generator only makes watchtower ruins.
- First come, first served: once claimed, it's gone for everyone else. A
  village may claim a ruin in **any** slice, including another player's; it
  then owns a tower in their land. Restoring it is up to its owner.

### 9.6 Monster lairs and mines

**Monster lairs** (`LAIRS`) look different depending on where they are: a
cave entrance by a mountain (not a volcano), a hollow overgrown tree in
pine forest, a sunken mossy ruin in swamp, a smoking pit in ash land, a
half-buried crypt on steppe. Meadow, oak woods and heath get no lairs.
Some are 1×1, some 2×2. They lie far out (`LAIRS_PER_SLICE`,
`LAIR_DISTANCE`) and block walking.

Every lair is linked to the road network by its own road. These roads wind
more than the others: they bend through waypoints pushed off the straight
line (`LAIR_ROAD_BEND*`) and are routed over extra cost noise
(`LAIR_ROAD_NOISE`), so a lair's monsters take a long, visible way in. A
lair road starts at the tile in front of the lair (stored as the lair's
`front`), keeps off the other objects and ends where it first meets a road.
A lair that can't get a road is placed elsewhere.

**Lairs wake up** (`LAIR_FROM_WAVE`, `LAIR_EVERY`, `LAIR_THEMES`):

- **When:** per slice, the first lair wakes late (`LAIR_FROM_WAVE`), so the
  early game stays simple; each further one of that slice (in an order fixed
  by the map's seed) `LAIR_EVERY` waves later. Lairs sleep until then.
- **Notice:** its slice's village gets an Important log line, a toast, a
  sound, and the warning lights mark the new road in during that wave (easy
  and normal, after the usual early waves too). Found: "The crypt to the
  east has woken up! Skeletons, necromancers and vampires will come out of
  it with every wave. The hero can clear it…". Not found yet, roughly which
  way: "Something stirs in a crypt somewhere to the east…". An awake lair
  glows red.
- **What comes out:** an awake lair is **one more spawn point** for its
  slice's share of the wave. The wave keeps its size and mix: a lair's
  entries swap kinds with edge entries so it sends only **its theme's** kinds
  (`LAIR_THEMES`; e.g. a crypt sends the undead, a hollow tree goblins and
  rats), those whose wave has come (goblins before). In co-op its enemies go
  for its slice's village.
- **Guards:** awake, it has guards (as strong as that wave's enemies) that
  stay by it like camp monsters.
- **Clearing:** like a camp, on the player's order (Attack with the hero).
  Cleared, it leaves a **sack of loot** at its door (`LAIR_LOOT`,
  `LAIR_LOOT_GROWTH`, sometimes a relic the village doesn't have yet:
  `LAIR_RELIC_CHANCE`) and **sleeps** `LAIR_QUIET_WAVES` waves. Then it wakes
  up again, with new guards and a notice that says so ("…has woken up
  again!").

**Mines** (gold):

- **Where:** on the **outer edge** of a mountain range (a mountain tile, not
  a volcano, with a walkable land tile in front that its village can reach),
  a good distance from any village (`MINE_DISTANCE`) and from other objects.
  Each mine gets a road spur from its front tile to the nearest road (§5.1).
  A mine looks like a cave entrance with timber supports and a cart. It's
  related to the mountain lair, but clearly a mine.
- **How many:** per slice `MINES_PER_SLICE` × the type's `mines`, where its
  slice has a suitable range. If that places none on the whole map, one more
  is tried in any slice, so a map with mountains has at least one. A slice
  without mountains gets none.
- **The miner** (civilian role):
  - Not available at the start. It's unlocked for **every** player once
    anyone of any player (a villager, a unit or the hero) first **walks up to
    a mine** (within `MINE_REACH` of its front tile). That's logged at Info
    level for everyone ("Rivermoor's explorer 2 reached a mine: every village
    can recruit miners now").
  - Recruited like other villagers (food, a hut, food upkeep; `CIVILIANS`).
    He lives in the hut, but works entirely at the mine: he walks there once
    and stays. He only comes back when he's unassigned.
  - At the mine he's **safe** (inside). He's only at risk while walking
    there or back, like any villager.
  - He produces gold passively at `MINE_GOLD_RATE`.
  - If his hut is destroyed, the miner dies, wherever he is.
- **One miner per mine.** A mine can't be claimed, only worked by a single
  miner at a time. If two players send a miner to the same mine, the first
  to arrive gets it. The other one is told ("That mine is taken") and walks
  back home, unassigned.
- If the miner is unassigned or dies, the mine is free again.

### 9.7 Later (not in this scope)

Oases (farms in the desert) and a travelling merchant.

### 9.8 Water monsters: what the generator provides

docs/aquatic-design.md (crab, leviathan, siren, octopus) needs deep water
near villages, which the older maps didn't have (rivers one deep tile wide,
lakes kept away from villages, villages kept away from the sea). Built
(`GenWater.near_villages`, `landings`, `water_spawns`):

- **Water bodies:** `Pathing.label_water` labels every body of deep water
  (4-connected; a bridge over deep water joins both sides) with its deep
  tile count and width. The checks, the editor and the game use it.
- **Coast maps** (stage 6b, right after the villages, before the roads):
  every village whose sea isn't close already gets an **inlet**: a winding
  channel (A* over a noisy cost) from the sea, with a deep core and a
  shallow rim that comes close enough to the walls for water monsters to
  matter (`COAST_INLET_*`). It keeps away from other villages, mountains,
  lava, craters and the map's outer ring, and gives up (a soft warning,
  "village n gets no inlet from the sea") when no reasonable channel is
  found. Inlets join the sea (`c.sea`), so roads route around them (deep
  water is never crossed) and beaches line them. The sea keeps its
  distance from villages everywhere else.
  **Known rough:** the inlet generator's result looks ugly; it works but is
  due a rework.
- **Other map types:** with the type's `"lagoon"` chance a village gets a
  **lagoon**: a round lake (`LAGOON_SIZE`) on the side with the most open
  land, deep inside and shallow at the rim (deep enough for a leviathan; for
  an octopus only when big). Lagoons and inlets roll their own random
  numbers, so a map that gets neither is the same as before (old seeds keep
  their maps).
- **Landings** (after the roads): a short road from the shore nearest each
  inlet's or lagoon's tip to the network, so crabs and sirens can climb out
  there.
- **`water_spawns`** (last, after the objects): a few (`WATER_SPAWNS`) per
  body that fits a water monster and comes within reach of a village: at
  the map's edge if the body reaches it, else the deepest open water, away
  from the villages and from each other. Stored in `MapData` and the JSON
  format.
- **Checks:** the map editor's checks refuse a water spawn off deep water or
  in a body no water monster fits (an error); a Coast village without an
  inlet is the generator's soft warning.
- `data/title_maps/` has to be rebaked after changes like these.

## 10. Gameplay effects at a glance

| Thing | Effect |
|---|---|
| Pathing | deep water and lava solid; shallow water and swamp off the road slow; mountains and volcanoes solid |
| Building | not on water, shallow water, lava, mountains or near a crater; farms not in steppe, swamp or ash land |
| Farms | meadow and water bonuses |
| Foresters | trees depend on the zone (an oak lasts the most trips) |
| Enemies | still only walk roads (bridges and fords included; fords slow them, swamp doesn't); camp and lair guards are the exception |
| Hero | Explore mode: claims first (unlock sites, ruined watchtowers), then loots unguarded treasures and dropped loot, then explores unknown land |
| Villagers | miner role, unlocked globally by reaching a mine |
| Units | summoner, apprentice and acolyte unlocked globally at unlock sites |
| Fog | objects stay hidden until explored; no markers |
| Log | finding an object, and reaching the first mine, is logged at Info level, saying who can use it |
| HUD | no hover hints; each object has a panel (tap) with its info, "Attack with the hero" on camps and awake lairs, "Restore (cost)" on claimed ruins |
| Net | `MapData.to_bytes` also carries zones and objects; object states, global unlocks, relics, dropped loot and mine assignments are replicated |

## 11. Config layout (`config.gd`)

Everything is in `scripts/core/config.gd`, in two blocks: **world
generation** (map types and zones, village placement and fairness, roads,
water, mountains and volcanoes, retries; `FARM_WATER_BONUS` next to
`FARM_RATE`) and **special objects** (treasures, relics, camps, unlock
sites, ruins, lairs, mines; `LOCKED` next to `CIVILIAN_ORDER`; the miner in
`CIVILIANS`; `HERO_XP_PER_ACTION` "loot"). Look there for the names; the
constants used in this document keep their prefixes (`ZONE_*`, `VILLAGE_*`,
`ROAD_*`, `LAKE_*`, `RIVER_*`, `VOLCANO_*`, `TREASURE_*`, `CAMP_*`,
`UNLOCK_SITE*`, `RUIN*`, `LAIR*`, `MINE*`).

## 12. Code (as built)

- `scripts/world/gen/`: one script per stage, all static and seeded, sharing
  a `GenContext` (map, rng, fields, bookkeeping): slices, fields, water,
  relief, zones, villages, roads (network, router, bridges, fords, passes,
  mine spurs, lair roads), fixes, objects, checks. `map_generator.gd` is the
  short pipeline (and the retries).
- `MapData`: terrains `WATER`, `SHALLOW`, `LAVA`; zones, decor, crossings,
  beaches, volcanoes, slices, objects, map type and seed; `walk_factor()`,
  `near_crater()`; all in `to_bytes` / `from_bytes` (`Net.PROTOCOL`).
- Drawing: `GroundLayer` (zone ground, forest floors, rock under mountains,
  sand, roads and rocky passes; as the top layer: fords, bridges, shore foam;
  under the tiles, each tile's plain diamond in its art's average colour, so
  the mipmaps' thinned tile edges show no black grid lines when zoomed far
  out), `WaterLayer` (water and lava, each with a shimmer shader). Decoration
  and volcanoes are sprites in World.
- `Pathing`: deep water and lava solid; shallow water and swamp weighted.
  `Unit.step_path` applies `MapData.walk_factor` (flyers ignore it).
- Objects: `scripts/world/objects/` (`map_object.gd` is a neutral `Building`
  spawned by World on every side, with a fixed id `OBJECT_NID_BASE` + index;
  one script per kind; dropped loot is a `Treasure` "sack");
  `scripts/units/enemies/camp_behavior.gd`.
- Hero: `units/jobs/hero_explore_job.gd` (claims > loot > explore, carrying
  loot home, dropping it when downed); `Hero.attack_camp`.
- Miner: `units/miner.gd`; `Population.free_mine`.
- Unlocks: `Game.unlocks`, `is_unlocked`, `unlock` (global, logged for
  everyone); `Army.recruit` and `Population.recruit_error` check them; the HUD
  hides locked entries.
- Commands: `attack_camp`, `restore_ruin` (`Construction.restore_ruin`),
  `assign_miner`, `unassign_miner`.
- Map type and seed: `Settings.map_type` / `map_seed` (single-player page),
  `Net.set_map` (lobby, host), `Net.setup["map_type"]`, shown in the settings
  dialog.
- Replicator: objects' states, unlocks, relics and dropped-loot sacks in the
  village data.

## 13. Art (`tools/gen_art.py`)

The generator `tools/gen_art.py` is the list of every tile and prop; never
hand-edit `art/`. What matters for design:

- **Ground** per zone, water, shallow, foam, lava, rock, fords, a rocky road
  for passes.
- **Bridges** one style per bridge look (§6.3), two directions each.
- **Trees and peaks:** a zone's `mix` picks among several variants of each
  kind, weighted; every variant of a kind behaves alike (looks only). The
  game still mirrors and scales each decor a little.
- **Props:** reeds, boulders, cactus, charred stumps, lava rock, the volcano
  and its smoke; the city's houses and house ruins.
- **Village pieces:** the generator gives a village one material for its
  walls, gates and wall towers by map type (`PIECE_MATERIAL_BY_MAP_TYPE`;
  docs/siege-design.md §2a).
- **Objects:** each treasure kind with a "looted" version; the dropped-loot
  sack; camp and cleared camp; each unlock site with an awakened look; the
  ruined watchtower; the mine; the lairs (one per kind, most with a big 2×2
  version).
- **Units:** the miner (pickaxe, lamp).

## 14. Tests and tools

- `tools/map_shot.sh`: top-down plans by default (zones, water, roads,
  bridges and fords, slice borders, objects, spawns), isometric pictures
  with `iso` (drawn from the game's art like the game draws it), numbered in
  `maps/`.
- `tests/world_bot.gd`, on maps for 1-8 players and every map type:
  - slices: equal tile counts, every slice reaches the edge, every village
    in its slice and near its centre;
  - no steppe, swamp or ash land next to any village;
  - shares: ash land only around volcanoes (or on lava), steppe within its
    cap, enough meadow and trees; coast maps have water, volcanic maps a
    volcano and lava; no volcano next to a village;
  - roads: 4-connected; every home spawn reaches its village; enough
    approaches and links per village; crossings are road, fords over shallow
    water;
  - objects reachable and in the right zones; mines at the foot of a range
    with a road; unlock-site copies and their slices; at least one mine; the
    same number of treasures per slice;
  - determinism (same seed and type → identical bytes);
  - `to_bytes` / `from_bytes` round trip.
- Gameplay checks (in `world_bot` with a running game):
  - the hero in Explore mode: claims before loot, loot before exploring;
    guarded treasures skipped until the camp is cleared; dropped loot when
    downed;
  - a claimed ruin restored by a builder (only when ordered);
  - "Attack with the hero" on a camp: she clears it, then returns to her mode;
  - the unlock messages at a site's wave (found / not found yet);
  - a global unit unlock reaching every village; the Info log messages;
  - the miner: unlocked by walking up to a mine (with the Info log line),
    first to arrive wins, safe at the mine, gold rate, dies with his hut;
  - walking speeds in shallow water and swamp; building rules; a relic's
    bonus; the map type and seed from the menu.

## 15. Milestones

All built:

1. **Slices, zones and roads:** stages, slices and village placement,
   fields, zones, road network and routing, fix steps, `world_bot` basics,
   ground and prop art.
2. **Water:** lakes, swamp, rivers with bridges and fords (zone styles),
   coast type, water art and shader, pathing and building rules.
3. **Mountains and volcanoes:** ridge ranges and passes; volcanoes with ash
   land; map types in the menus; seed shown in settings.
4. **Treasures and camps:** objects, looting jobs, relics, replication.
5. **Unlock sites:** global unlocks, copies per player count, the hero's
   Explore priorities.
6. **Ruined watchtowers, lairs and mines:** claiming, lairs, mines and the
   miner.

## 16. Decisions (confirmed)

Concrete values of these decisions live in `config.gd`.

| # | Question | Decision |
|---|---|---|
| D1 | Zones | The ones in §4.1. Ash land always has a volcano. Swamp slows walking off the road only |
| D2 | Order | Milestones as in §15. **No eruptions** |
| D3 | Water kinds | Lakes, rivers (scaled by the type) and coast maps |
| D4 | Farm bonuses | Meadow bonus (more than half the farm on meadow), a smaller one next to water |
| D5 | Volcanoes | Scenery only; no eruptions |
| D6 | Volcanic map type | Lava rivers instead of water rivers |
| D7 | Map type and seed | Choosable in the single-player menu and lobby; seed shown in settings, typed in optionally |
| D8 | Multiplayer objects | Placed per slice. Loot: anyone, first come. Unlocks are **global** (for every player); copies per kind of site grow with the player count |
| D9 | Locked units | Summoner (stone circle), apprentice (mage's tower) and acolyte (ruined chapel); archer, shield bearer and barracks from the start. **Ask how future units are unlocked** |
| D10 | Neutral places | Ruined watchtowers (claimed by the hero in Explore mode, before new land; the explorer only reveals); lairs by zone, waking late (§9.6); mines on the outer edge of ranges, linked to the roads, worked by the miner (unlocked globally when a mine is first reached; one miner per mine, first to arrive; lives in a hut, dies with it; passive gold). Oases and merchant later |
| D11 | Water and swamp | Shallow water and swamp off the road slow walking; enemies cross water only at fords and bridges. Bridges always man-made, their look depends on the zone, look only |
| D12 | Downed looter | Drops the loot where she is; a hero in Explore mode or a gatherer can pick it up |
| D13 | Allocation shape | Equal-area **slices around the centre** for every player count, so every village has some map edge |
| D14 | Village spot | Best tile near the slice's centre (away from water, mountains, volcanoes, the sea, other villages and the border) |
| D15 | Road links | At least 2 per village for 3+ players (a full triangle for 3, a ring and chords for 4-8). Roads go around mountain ranges or through a pass, or a link is dropped. **2 players are always linked** (regenerate if impossible) |
| D16 | Ruined watchtower | Claimed by the hero; restoring is an explicit order, done by a builder for a share of a watchtower's cost |
| D17 | Miner unlock | Anyone walking up to a mine; an Info log line for everyone |
| D18 | Used unlock site | The other copies stay as scenery |
| D19 | Miner at the mine | Safe; at risk only while walking; dies if his hut is destroyed. Costs food, a hut and food upkeep |
| D20 | Looting | Automatic by the hero in Explore mode, only unguarded treasures. Priorities: claim > loot > explore. No range limit |
| D21 | Monster camps | Fight, as in §9.3 (milestone 4) |
| D22 | Placement | Not every kind of feature appears in every slice; the treasures per slice are kept fair |
| D23 | Lairs | 1×1 or 2×2; each with a winding road; wake late (per slice, one more every few waves), one more spawn point sending its theme; cleared by the hero for loot, then quiet for a while |
| D24 | Unlock-site distance | Further out for the later units |
| D25 | Clearing camps | The hero only on the order "Attack with the hero" in the camp's panel; towers and barracks fight guards in their range on their own |
| D26 | Gatherers | Don't loot treasures; only the hero does. Gatherers do pick up dropped loot |
| D27 | Hints | No hover hints and no markers. Info messages only: when an object is found, and when an unlock site awakens ("travellers speak of…" if not found yet) |
| D28 | Ruins in other slices | Claimable by any village, first come first served; restoring is up to the owner |
| D29 | Unlock message | "Found" means found by this village |
| D30 | Failed camp attack | Monsters don't heal back; killed ones stay dead |

## 17. As built: details and what's left

- **Slice fairness** is a soft goal: a map that misses it is made once more
  and the better of the two is kept. With many narrow slices it is often
  missed; land around every village (§4.3) is always repaired.
- **Generation time** grows with the map (speed wasn't a goal).
- **Dropped loot** (a downed or re-moded hero's, a cleared lair's) is a small
  sack, a map object of its own. Co-op clients get the sacks through the
  snapshots and see them where they have explored.
- **Camp monsters** are enemies (group "enemies") that never walk a road; they
  pay their kill gold like wave enemies and leave no corpse.
- **Relics** in the game: tower range, revive time, the hero's rest, farm food.
- **Water monsters:** the generator gives them water near the villages (§9.8).
- **Not built** (as agreed): eruptions, oases, the merchant, ships landing
  raiders on coasts.
- **Future units:** ask how each one is unlocked before building it (§9.4).
