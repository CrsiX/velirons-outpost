# Veliron's Outpost: world generation (design)

Scope: the map generator (vegetation zones, roads, water, volcanoes), map
types and special objects. Every number lives in `scripts/core/config.gd`
and the generator under `scripts/world/gen/`; this document gives the
reasons, not the values.

The design is split over four files; section numbers are kept, so a citation
like "world-design.md §9.4" still resolves:

| Section | File |
|---|---|
| §1 Summary, §2 Sizes, §3 Stages (3.1 slices, 3.2), §8 Map types, §10 Gameplay effects, §16 Decisions | this file |
| §4 Zones, §6 Water, §7 Mountains and volcanoes | world-terrain-design.md |
| §5 Roads (5.1-5.3) | world-roads-design.md |
| §9 Special objects (9.1-9.8) | world-objects-design.md |

## 1. Summary

- **Allocations:** every player gets an equal-area **slice** of the map
  around its centre, so every village has its own stretch of map edge. The
  terrain is generated for the whole map; each village is then put on good
  land near its slice's centre, well away from the others.
- **Zones:** large vegetation zones (pine, oak, meadow, heath, steppe, swamp,
  ash land around volcanoes), placed by two large-scale noise maps (height
  and moisture) so neighbours blend.
- **Roads** are planned as a network first, then routed with a
  terrain-weighted pathfinder: they curve, go around ranges (or through a
  pass) and merge.
- **Water:** lakes, rivers with bridges and fords, sea on Coast maps.
- **Volcanoes** are scenery with ash land around them; ash land never exists
  without one. No eruptions.
- **Map types:** Temperate, Highlands, Coast, Desert, Volcanic.
- **Special objects:** treasures, guarded camps, unit-unlock sites, ruined
  watchtowers, monster lairs, mines and the miner.
- **Fair in multiplayer:** every slice gets the same number and tiers of
  treasures, and the land round every village is repaired to the same
  minimum. Zone shares per slice are a soft goal; not every feature has to
  appear in every slice.
- Generation speed is not a goal.

## 2. Sizes and counts

Numbers: `MAP_SIZES`, `SP_SPAWNS`, `COOP_SPAWNS`, `LAKE_COUNT`, `RIVER_COUNT`,
`MOUNTAIN_SHARE`, `TREASURE_COUNT`, `RUINED_TOWERS`, `LAIRS_PER_SLICE`,
`MINES_PER_SLICE`, `UNLOCK_SITE_SHARE`. The shape:

- The map grows with the player count, so a co-op slice is about as roomy as
  a single-player map. The editor makes other sizes: per-slice amounts then
  scale with the slice's area, edge spawns and rivers with the width
  (`Config.gen_area_scale`, `gen_length_scale`; 1 at the usual size, so
  existing maps don't change; docs/map-editor-design.md §3).
- Slices have equal tile counts (plus or minus 1).
- Per-slice counts are small ranges, never fixed totals, except treasures:
  the same count and tiers in every slice.
- Lakes, rivers, mountains, volcanoes and mines scale with the map type.

## 3. The generator, in stages

Each stage reads only what earlier stages made. Everything comes from the
map seed (no global random numbers), so a seed and type always make the same
map. In co-op only the host generates; clients receive the finished map.

### 3.1 Allocations (slices)

The map is divided into one slice per player, each with the same tile count:

- **1 player:** the whole map.
- **2 or more:** equal-area slices around the centre with a random rotation.
  On a square map equal angles don't give equal areas (corners hold more),
  so tiles are sorted by angle around the centre and cut into N runs of equal
  length.
- Every slice reaches the map edge (spawns) and touches the middle (its
  neighbours). That holds for 8 players too: slices get narrow but keep some
  edge.
- A slice's **centre** is the centre of mass of its tiles.

Slices decide village position, home spawns, the road network (world-roads-design.md
§5.1), fairness and object counts, and land ownership. The terrain itself
doesn't know about them; only some stages keep away from slice centres
(lakes, river sources, mountains, volcanoes) so villages aren't flooded or
crushed.

### 3.2 Stages

1. **Slices** (§3.1).
2. **Fields:** height and moisture noise, each value replaced by its rank
   (0..1) so shares are predictable on every seed, then shifted by the map
   type (§8). Plus a small detail noise for ragged edges.
3. **Water** (§6).
4. **Mountains and volcanoes** (§7); ash land marked around volcanoes.
5. **Zones and vegetation** (§4): zone from height x moisture, ash land where
   marked, then trees and decor by zone.
6. **Villages:** per slice, the best tile near its centre. A tile qualifies if
   it keeps clear of water, mountains and lava round the walls and keeps its
   distance from the sea, volcanoes, other villages, its slice's border
   (co-op) and the map edge (`VILLAGE_*`). The nearest to the centre wins,
   meadow slightly preferred and pine, steppe, swamp and ash held back. If no
   tile qualifies the rules are loosened in steps; if still none, the village
   goes on the slice's centre and the map counts as failed. The village is
   stamped in with a clearing ring; steppe, swamp and ash inside it become
   meadow. Single player uses the same rule round the map centre.
   **Coast inlets** (stage 6b, Coast maps only; world-objects-design.md §9.8)
   follow the villages and come before the roads, so the road network sees
   them as sea and routes around their deep water.
7. **Road network** (§5.1) and 8. **road routing** (§5.2).
9. **Fix steps**, per village, small local repairs after the big stages: fair
   land (§4.3) and the starting camp (trees within reach of the worker camp).
   Repairs rather than regeneration, so a seed's character survives.
10. **Special objects** (§9), including mine spurs and lair roads.
11. **Checks** (§5.3): on a failed hard check the map is made again from
    another seed (`MAP_TRIES` at most, best try kept); a missed soft goal is
    retried once. With many narrow slices slice fairness is often missed;
    land round villages is always repaired.

## 8. Map types

A type only changes the fields, water and counts (`Config.MAP_TYPES`);
everything else stays the same.

- **Temperate** (default): the generator as is.
- **Highlands:** higher and drier (more heath); fewer lakes, more rivers,
  mountains and mines.
- **Coast:** one or two sea edges; a little wetter and lower; fewer
  mountains, no volcanoes.
- **Desert:** much drier, steppe up to a larger cap; almost no water.
- **Volcanic:** a little higher and drier; lava rivers instead of water
  rivers; the most volcanoes.

Type and seed are chosen in the single-player menu and the lobby (host);
"Random" picks a type from the seed. Both are shown in the settings dialog so
a good map can be played again.

## 10. Gameplay effects at a glance

| Thing | Effect |
|---|---|
| Pathing | deep water and lava solid; shallow water and swamp off the road slow; mountains and volcanoes solid |
| Building | not on water, lava, mountains or near a crater; farms not in steppe, swamp or ash land |
| Farms | meadow and water bonuses |
| Foresters | trees depend on the zone (an oak lasts the most trips) |
| Enemies | still only walk roads (bridges and fords included; fords slow them, swamp doesn't); camp and lair guards are the exception |
| Hero | Explore: claims first, then loots unguarded treasures and dropped loot, then explores |
| Villagers / units | miner and the three locked units are unlocked globally |
| Fog, HUD | objects stay hidden until explored; no markers or hover hints; each object has a tap panel |
| Net | `MapData.to_bytes` carries zones and objects; object states, unlocks, relics, dropped loot and mine assignments are replicated |

## 16. Decisions

Values are in `config.gd`; this keeps the reasons.

- **Slices around the centre for every player count** (D13): every village
  gets some map edge, so every village has spawns; equal area keeps it fair.
- **Village spot:** best tile near the slice's centre, away from hazards and
  neighbours (D14); loosened in steps rather than failing.
- **Road links** (D15): at least 2 per village for 3+ players, so one lost
  road never isolates one. Roads go around ranges or through a pass, or the
  link is dropped; two players are always linked (remake the map if not).
- **Zones** (D1): ash land always has a volcano; swamp slows walking only off
  the road, so the player pays for it and enemies don't.
- **No eruptions** (D2, D5): volcanoes are scenery and obstacles. Volcanic
  maps get lava rivers instead of water rivers (D6).
- **Water** (D3, D11): lakes, rivers (scaled by type) and coast. Shallow
  water and swamp slow walking; enemies cross water only at fords and
  bridges. Bridge looks depend on the zone and are look only.
- **Farm bonuses** (D4): meadow (over half the farm on it) and a smaller one
  beside water, so placement matters.
- **Map type and seed** (D7): choosable, shown in settings, typeable.
- **Objects per slice, not everywhere** (D8, D22): not every kind appears in
  every slice; treasures per slice are kept fair. Loot is first come, first
  served; unlocks are global, with copies growing with player count (D18:
  the other copies stay scenery; D24: later units further out; D29: "found"
  means found by this village).
- **Locked units** (D9): summoner, apprentice, acolyte; archer, shield bearer
  and barracks from the start. Ask how any future unit is unlocked before
  building it.
- **Ruins and neutral places** (D10, D16, D28): the hero claims ruined
  watchtowers (the explorer only reveals); restoring is an explicit order done
  by a builder for a share of a tower's cost; any village may claim a ruin in
  any slice.
- **Miner** (D17, D19): unlocked for everyone when anyone walks up to a mine
  (logged for all); safe at the mine, dies with his hut; costs food and a hut.
- **Looting** (D12, D20, D26): automatic by the hero in Explore mode, only
  unguarded treasures; priority claim, loot, explore, no range limit. A
  downed or re-moded hero drops the loot; a hero in Explore or a gatherer
  picks it up. Gatherers never loot treasures.
- **Camps and lairs** (D21, D23, D25, D30): the hero attacks only on the
  explicit order; towers and barracks fight guards in range on their own. A
  failed attack isn't wasted: monsters don't heal back and kills stay dead.
  Lairs (1x1 or 2x2) have winding roads, wake late, add one spawn point that
  sends their theme, and are cleared for loot, then quiet for a while.
- **Hints** (D27): no hover hints or markers; Info log lines only, including
  rumours when an unlock site awakens unfound.
- **Not built** (as agreed): eruptions, oases, a travelling merchant on the
  map, ships landing raiders on coasts.
