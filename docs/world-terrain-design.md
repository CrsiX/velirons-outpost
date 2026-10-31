# World terrain design: zones, water, mountains and volcanoes
Part of the world design; index in world-design.md.

## 4. Zones

**Drawing invariant.** The ground layer (`GroundLayer`) also draws each tile's plain diamond, in its art's average colour, underneath the tile art. Without it the mipmaps' thinned tile edges show black grid lines when the map is zoomed far out. Keep it when changing how tiles are drawn.

### 4.1 The zones

The zone is a per-tile value next to the terrain. **Terrain** says what a
tile does (walkable, buildable, road, water, mountain); **zone** says how it
looks and what grows there. Values live in `Config.ZONES`. The intent of each:

| Zone | Where | What it is for |
|---|---|---|
| Pine forest | wet | dense, dark; lots of wood, hard to see through |
| Oak woods | middling moisture, or higher ground | fewer trees, but an oak takes longest to chop, so it lasts the most trips |
| Meadow | drier, low ground | open farm land with a food bonus |
| Heath | high ground | sparse, dead trees and boulders |
| Steppe / desert | very dry | almost no trees, no farms |
| Swamp | very wet, low, near water | slows the player off the road, no farms |
| Ash land | only around volcanoes | charred, no farms, no building near the crater |
| City | map files only (the campaign's capital) | cobblestones; houses on its mountain tiles; no farms |

- A tree share is a base value; clumping noise makes patches denser and
  others thinner, so woods look like woods. Tree tiles are forest terrain,
  which is what foresters chop.
- **Meadow bonus** needs more than half a farm's tiles to be meadow, so
  placement matters.
- **Swamp** slows walking only off the road, so enemies (who walk only roads)
  are never slowed. The player pays for the swamp, the enemy doesn't.
- **Ash land** doesn't come from the noise maps: it is painted around
  volcanoes (§7.2) and on lava, so every patch of it has a volcano.

### 4.2 How big zones are

The noise scale sets zone size so a normal map has a handful of patches
rather than noise confetti; a little extra noise roughens the borders.
Steppe is capped so no map is all sand (the wettest of the rest becomes
meadow), and none stays near a village (§4.3).

### 4.3 Fair land around villages

Near every village centre the generator repaints bad land: no steppe, swamp
or ash land (meadow instead), a minimum share of meadow and of trees. The
repair is a fix step (world-design.md §3.2), never a regeneration, so a
seed's character survives. Single player gets the same rule for its one
village.

The generator keeps **no room for a farm**: the game places the starting farm
on the finished map, on the nearest free spot or not at all (docs/village-design.md
§4). A harsh map can mean a harder start; that is accepted.

In multiplayer the zone shares of whole slices should differ by at most a
set spread. This is a soft goal checked in world-roads-design.md §5.3, not
repaired: repairing whole slices would flatten the map.

Missing trees grow as **oak woods** (its ground and tree mix, so no green
trees on sand), one tile at a time on the best-scoring open tile: forest
next to it (woods grow on), noise (patches, not an even spread), a little
distance from the village, meadow last (kept for farms). Not in the clearing
ring plus one, nor on or beside a road. If no spot near the village has
enough trees, the worker camp gets a round grove beside the village, so the
forester always has something to chop.

## 6. Water

### 6.1 Kinds

- **Deep water**: impassable for everyone, not buildable, doesn't block
  sight.
- **Shallow water**: lake and sea rims, river banks here and there, and fords.
  Slows walking for everyone (enemies only on a ford, the one place they may
  cross). Not buildable.
- **Shore:** a sand rim on the land side of the sea.

### 6.2 Lakes

Each starts at a low point and grows into its lowest neighbours with a little
noise for ragged shores; the rim is shallow. Lakes keep well away from every
slice centre so a village isn't flooded (world-objects-design.md §9.8 adds the
lagoons that deliberately come close). Swamp forms on wet low ground near
water (§4.1).

### 6.3 Rivers, bridges and fords

- A river starts on high ground away from slice centres and other water and
  runs downhill to a lake, the sea or the map edge. It is one tile of deep
  water with shallow banks: a narrow obstacle, not a barrier.
- Rivers wind rather than run to the nearest edge (that looks like a ruler
  line): they aim at a random goal near the nearest distance, follow the low
  lines of a ridged noise plus jitter, and keep clear of slice centres. In
  hills the height still leads them along valleys.
- A road over deep river water gets a **bridge**, over shallow water a
  **ford** (stepping stones, slowing like any shallow tile). Deep lakes and
  the sea are never crossed. Bridges and fords are natural choke points, good
  for towers.
- Bridges are always man-made; the zone around them changes only the look
  (`BRIDGE_STYLES`), never the behaviour.

### 6.4 Coast (map type Coast)

- One or two neighbouring edges become sea (one with many players, whose
  slices are narrow), with a ragged coastline. Only water connected to the
  chosen edges counts as sea; its rim is shallow and the land along it is
  beach.
- Slices are cut as usual. A slice left with almost no land on its stretch of
  edge gets a land strip cut inwards from the middle of that stretch, so it
  keeps land edge for spawns: waves only come from land edges. Villages keep
  their distance from the sea (world-objects-design.md §9.8 for the inlets that
  bring it back close).
- **Known rough:** the inlet that brings the sea back to a village looks ugly
  today; it works but is due a rework.

### 6.5 In the game

- Deep water and lava are solid; shallow water and swamp off the road are
  walkable at a cost. Farms can't stand on water; a farm beside water gets a
  small food bonus.
- Fog and sight are unchanged (water is terrain like any other).
- Art: a light shimmer shader on the water layer and a foam rim at the shore.

## 7. Mountains and volcanoes

### 7.1 Mountains

Each land tile gets a score, mostly the ridges (zero lines) of a ridged
noise, some height, a little detail. The best-scoring share becomes mountain
anywhere except near a slice centre; small clumps are removed, so ranges
follow noise ridges with gaps. A range between two villages makes the road go
around, cut a pass, or drop that link (world-roads-design.md §5.1). Mines sit
on a range's outer edge (world-objects-design.md §9.6).

### 7.2 Volcanoes

- The count depends on the map type: none on Coast, most on Volcanic. A
  volcano that finds no spot is left out.
- Placed after mountains, before zones and villages. Each is the best of many
  random spots, scored by height and nearby mountain (so they often stand in
  or by a range); it needs land or mountain under its whole footprint and
  distance from other volcanoes and from slice centres (relaxed in steps if
  no spot is found). Villages then keep their own distance from every volcano
  (also relaxed when village rules loosen, world-design.md §3.2).
- A volcano is a block of impassable mountain tiles (roads never cut a pass
  through it) with an animated glowing crater and smoke.
- **Ash land** is painted in a ragged ring round it as a zone; water and
  mountains under it keep their terrain. Nothing can be built near the crater.
- **Lava rivers** (Volcanic only, instead of water rivers) run from each
  volcano toward the nearest edge, stopping at a mountain. Lava is impassable
  and glows, roads cross it on charred bridges, and it counts as ash land.
- **No eruptions:** volcanoes are scenery and obstacles.
