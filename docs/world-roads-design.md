# Veliron's Outpost: roads (design)

Part of the world generation design (core and stages: docs/world-design.md).
Numbers live in `scripts/core/config.gd` (`ROAD_*`, `SP_SPAWNS`,
`COOP_SPAWNS`, `VILLAGE_MIN_LINKS`); the code is `scripts/world/gen/`.

## 5. Roads

Enemies walk only roads, so the road network is the level design: it decides
where waves arrive and how many ways in a village has.

### 5.1 The network (what gets linked)

The network is planned first and routed second, so that no village can end up
cut off.

- **Single player:** a few edge spawns spread around the map edge, each with
  a road from the gate facing it. Existing road is cheap to follow, so later
  roads join earlier ones and branch and merge on the way in. A village with
  fewer than 2 approaches gets a free gate a road straight out to the edge.
- **Co-op:**
  - A **ring road** round every village, just outside the walls, joins its
    four gates.
  - **Village links:** two players one link, three a triangle, four to eight
    a ring ordered by angle around the map centre, with a few chords to the
    opposite village for bigger games. Aim: losing one road never isolates a
    village.
  - Every village keeps at least `VILLAGE_MIN_LINKS` links. A link much
    longer than the straight distance (`ROAD_DETOUR_MAX`) is retried through
    a mountain pass, then dropped. A village left short is linked to its
    next-nearest ones; if that fails too, the map fails its check and is
    remade. Two players are always linked (D15, world-design.md).
  - **Spawns:** each village gets a few edge spawns along its own slice's
    stretch of edge; every road tile on the edge is a spawn of the village
    whose slice it lies in.
- **Gates:** a road leaves by the gate facing where it goes. A gate that
  already has a road counts a little worse, so roads spread over the gates
  without forbidding two on one. A gate with a road leading away is an
  **approach**; every village needs at least 2, so enemies never have exactly
  one way in.
- Roads never pass through a village's walls.
- Mines get a short spur, lairs a winding road (world-objects-design.md §9.6).

### 5.2 Routing (where a road goes)

Each road is routed with A* (4 directions) on a cost map (`ROAD_COSTS`). The
ordering of the costs is the design:

- existing road cheapest, so roads merge like rivers;
- open land cheap, woods and heath dearer, pine forest and swamp dearest of
  the land;
- shallow water and river tiles expensive: a ford or bridge is a last
  resort, not a habit;
- mountains impassable on the first try, merely very expensive on a second
  (a pass);
- villages and their wall ring, deep lakes, the sea and volcanoes
  impassable, and the map edge except the road's own end.

Other rules, with their reasons:

- Low-frequency cost noise (`ROAD_COST_NOISE`) makes roads curve gently
  instead of running straight.
- A tile beside a road costs extra (`ROAD_BESIDE_COST`), so a new road either
  joins the old one or keeps a tile away: no parallel doubles.
- Only four directions, because a road that touches the next tile only at a
  corner would not connect visually.
- **Passes:** spawn roads, the extra single-player approaches and links that
  can't get through (or only by a long detour) are routed again with every
  non-volcano mountain tile open at a high cost. Mine spurs and lair roads
  never cut passes (they would turn rare terrain into a shortcut).
- Lair roads keep off the other objects.

Carving: deep river water or lava gets a **bridge** (look by zone, see
world-terrain-design.md §6.3; lava always charred), shallow tiles a **ford**,
mountain tiles become road (a rocky pass where two or more mountains flank
it). Trees and decor on the road are removed.

### 5.3 Checks

Hard (the map is remade, world-design.md §3.2 step 11):

- every village has a spawn, and every home spawn reaches its gates by road;
- every village has at least 2 approaches;
- every village found a spot, and in co-op has its links;
- every kind of unlock site has a copy (world-objects-design.md §9.4).

Soft (retried once, the better try kept): in co-op, the zone shares of the
slices differ by at most `ZONE_FAIR_SPREAD`. Whole slices are not repaired,
because that would flatten the map.
