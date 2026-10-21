# Veliron's Outpost: map editor (design)

Status: **built** (stages 1 and 2). This describes what is built; §13 lists
what differs from the reviewed draft and what is left. Scenarios are out of
scope (§12).

## 1. Summary

- A **Map Editor** inside the game (its own scene, `scenes/map_editor.tscn`),
  opened from an always visible **Map Editor** button on the title screen. It
  runs wherever the game runs (desktop, web, Android); desktop is the target,
  mobile works on a good-effort basis (somewhat awkward is acceptable).
- It shows a map either **isometric** (the game's own renderers: what you see
  is what you play) or **top-down 2D** (a flat tile grid), switchable at any
  time; every tool works in both. It uses the game's generator, checks and
  pathing, so it keeps up with the world generator as that grows.
- Maps are stored as **pretty-printed JSON** (2-space indent, `.json`), one
  file per map, in a readable, diffable format (§6). Export is strict, import
  is tolerant within strict bounds (§6.8).
- A map from a file can be **played**: single player and co-op. In co-op the
  host picks the map, assigns players to its villages, and sends it to
  everyone (the host is the source of truth; the clients never need the file).
  Villages nobody plays stand as ownerless ruins (§8.2).
- Map sizes: **50, 75, 100, 125, 150, 175 and 200** tiles square.

## 2. Stages

| Stage | What | Done when |
|---|---|---|
| 1. Inspect | Generate (type, seed, size, villages), isometric and top-down view with overlays, tile and object inspector, problems list, save / open / import / export JSON, map library, play the map (single player and co-op, with village assignment) | the conversion tests pass (§10) and a saved map plays |
| 2. Edit | Brushes (terrain, zone, trees, decor, beach), roads, objects, villages and their pieces, spawns; undo / redo; automatic tidy-up (§5.3); live checks | a hand-made map passes the checks and plays |
| (3. Scenarios) | later, not in this scope | |

## 3. Map sizes

- `Config.MAP_SIZES := [50, 75, 100, 125, 150, 175, 200]`. A map's size is one of them.
- **Village slots** per size (how many villages a map of that size may hold),
  `Config.MAP_SIZE_SLOTS`: 50 → 1, 75 → 2, 100 → 4, 125 → 6, 150 / 175 / 200 → 8.
- Generated games keep today's automatic size (`Config.map_size(players)`:
  1-2 → 75, 3-4 → 100, 5-6 → 125, 7-8 → 150); the Singleplayer menu and the
  lobby get no size choice. Other sizes come from the editor.
- The **generator** takes the size as an argument instead of deriving it from
  the player count (the editor's *New* uses any size). Its per-slice amounts
  (treasures, ruins, lairs, mines, spawns) are tuned for today's slice area,
  so they get scaled by slice area where that matters (a 200×200
  single-village map is one huge slice), with the factors in `config.gd`.
  `mapgen_bot`'s sweep covers every size.
- **Big maps in the browser:** in the web build, opening a map of 150×150 or
  more (generating, opening, importing it in the editor, or picking it to
  play) always shows a warning first: "Maps this big may run slowly in the
  browser" (Continue / Cancel). The threshold is `EDITOR.web_large_size` (150).

## 4. The editor

### 4.1 Layout (desktop)

```
┌──────────────┬─────────────────────────────────────────────┬──────────────┐
│ Tools      ‹ │                                             │ › Inspector  │
│ ↶ ↷  [ 2D ]  │                                             │  selection   │
│ File  Terrain│          the map (isometric or              │ Under the    │
│ Zone  Trees  │          top-down 2D)                       │  pointer:    │
│ Decor Beach  │                                             │  tile 41,17  │
│ ...   Slice  │                                             │  grass ...   │
│ Objects      │                                             │ Layers ☑☐    │
│ (options of  │                                             │ Problems (2) │
│  the tool)   │                                             │  ⚠ ...       │
└──────────────┴─────────────────────────────────────────────┴──────────────┘
 status: map name · 75×75 · temperate (seed 38) · 2 villages · saved | tile
```

- No top bar: the tools panel (left, `EditorUi.LEFT_W`) starts with undo and
  redo (the usual curved-arrow icons) and the view toggle (2D / Isometric),
  then the tools. The first, **File**, holds New, Open, Save, Save as,
  Import, Export, Properties, Play and Exit (back to the title screen).
- **Folding** (landscape): each side panel's heading (*Tools* with a ‹,
  *Inspector* with a ›, the chevron on the map's side) folds it to its edge:
  only the heading stays, at the top (*Tools ›*, *‹ Inspector*); a tap opens
  it again. Play and back keep the panels as they were (the session).
- Camera as in the game (`camera_controller.gd`): WASD / arrows, a right or
  middle mouse drag (any tool) or, with the File tab open, a left drag to pan;
  wheel / pinch to zoom (out further than the game, `EDITOR.min_zoom`, so a
  200×200 map fits; the camera's `min_zoom` / `max_zoom` are per scene).
- With a mouse every tool acts on a left press (*place this*) and drags
  paint. A **right-click** (let go where it was pressed) is the tool's
  opposite, once (one brush stamp, one undo step), and only of that tool's
  kind: Terrain puts grass back (Fill: fills with grass), Decor, Beach and Road
  erase theirs, Volcano, Pieces, Spawn, Village and Objects remove the one
  there; Zone and Slice have no "nothing", so a right-click takes the tile's
  zone or slice as the current one; Trees, peaks does nothing. A right-click
  first cancels a pick or a road being laid (as Esc). Erasing along a drag is
  the tools' *Erase* options (with a finger the only way). With the File tab
  open the map isn't edited: a click selects the tile, object or village
  (the inspector shows it). Keys: Ctrl+Z / Ctrl+Y (Ctrl+Shift+Z) undo / redo,
  Ctrl+S save, Tab switches the view, Delete removes the selected object or
  village, Esc closes a dialog, then cancels a pick or a road being drawn,
  then clears the selection, then asks to leave.
- **Views** (the toggle under the tools' heading, or Tab), both fully editable:
  - *Isometric:* the game's renderers (ground, water, props, decor, village
    pieces, objects), with the overlays drawn on top.
  - *Top-down 2D:* one square per tile, coloured by terrain and tinted by
    zone (as `tools/map_shot`'s plan), with small icons for props, objects,
    village pieces and spawns, and optional grid lines and coordinates at the
    edges. Faster to read for layout and precise for painting; cheap to draw
    even at 200×200.
  - Switching keeps the tile under the view's centre and the zoom level
    (as far as the views allow).
- **Mobile / portrait** (or narrower than 760 px, `EditorUi.NARROW`): the two
  side panels are the pages of a bottom sheet, as the game's dock: a handle
  over two tabs, Tools and Inspector, always along the bottom. A tab opens
  the sheet on its page (at most `Hud.SHEET_MAX` of the screen, the rest
  scrolls by finger from anywhere on it), the open tab or the handle folds
  it; the handle, the tabs and the gap between them drag it (a flick,
  `Hud.SHEET_FLICK`, or else the nearer end decides). The grids take as many
  columns as fit (`SHEET_CELL` px a cell): tools, options, the File tab's
  buttons, the layer switches. With a finger a tap acts once where it lands
  and a drag pans; the tool options offer "Paint by dragging" so a drag
  paints instead. The inspector's tile is the last one tapped.
- Esc closes the newest popup, as in the game (`register_popup`); with none
  open it asks to leave if there are unsaved changes.

### 4.2 Stage 1: inspect

- **New / Generate:** size, map type (Temperate ... Random), seed (empty:
  random), village count (1 up to the size's slots). Runs the full generator
  (with a progress bar; big maps take seconds). The result has the standard
  village layout. Its checks' failures and warnings land in the problems list
  instead of retrying silently.
- **Overlays** (Layers panel, each on/off; `EditorOverlay`): zones (tinted,
  isometric view), slices (borders and numbers), grid lines, passability
  (red: blocked, blue: shallow), buildable land (green), a picked village's
  road steps (the number on every road tile), spawns (with their village's
  number), villages (outline, centre, number), objects (the 2D view always
  draws them, with their art), camp rings (`CAMP_AGGRO`, a line to the
  treasure) and lair / mine fronts, and the problems (a red or yellow cross).
  The layers are drawn again only when the map or a switch changes; the
  pointer's marks (brush, selection, a road being drawn) in a second overlay.
- **Inspector:** the selection (picked with the File tab open, by the
  Village and Objects tools, or from the problems list): an object with all
  its fields (§6.7), a village, or a tile. Under it always the tile under the
  pointer (with a finger: the last tapped): coordinates, terrain, zone,
  slice, prop / decor art, crossing, beach, village piece, road steps to each
  village's gates (the road fields are kept until the next edit).
- **Map properties:** name, author, description, map type (any string,
  §6.2), shown and edited in a dialog.
- **Problems:** the checks of §5.4, each an error or a warning, run 0.3 s after
  an edit; tapping one centres the view on its tile and marks it.
- **Files:** Save / Save as / Open (the map library, §7), Import / Export
  (a file anywhere: §7.2).
- **Play:** starts a single-player game on this map (difficulty and, if the map
  has several villages, which one you play, in the dialog). Its settings
  dialog then offers *Back to editor* (keeping the editor's state, unsaved
  changes included) besides *Back to title*.

### 4.3 Stage 2: edit

All edits are on the `MapData` in memory; every tool is one undoable step per
stroke (a drag counts as one).

- **Terrain brush:** grass, forest (trees), desert, mountain, deep water,
  shallow water, lava; sizes 1 / 3 / 5 / 9, square or round; a **fill** mode
  (flood fill of the same terrain).
- **Zone brush:** meadow, oak, pine, heath, steppe, swamp, ash, city (changes
  look, farm rules and walking speed, not terrain). The city is never
  generated (the campaign's capital): cobblestone ground, and on its
  mountain tiles houses (`ZONES.city.peaks`: standing and ruined) in place of
  peaks, drawn on the cobbles.
- **Trees / props:** paint a specific prop art, or "auto" (picked from the
  zone's mix like the generator does). **Decor** the same; besides the zones'
  decor it offers `Config.EXTRA_DECOR` (no zone scatters it: the dried-up well,
  `well_dry`, in scenario 5's fort). **Beach** on / off.
- **Roads:** draw a road from tile to tile (a straight / A* path between two
  taps, or freehand). Water or lava under it becomes a crossing
  automatically (bridge style by zone, ford on shallow), as in `GenRoads`.
  Erase removes road back to the zone's ground.
- **Volcano:** place / remove (3×3 mountain, crater prop, ash around on request).
- **Villages:**
  - *Place a village:* stamps the standard layout (`Config.VILLAGE_LAYOUT`,
    5×5: wall towers, walls, gates, huts) around a centre; move or delete a
    whole village; set its centre (where the hero and villagers gather).
  - *Pieces:* add, remove or change single pieces (wall, gate, wall tower,
    hut) of a village, and flip a wall. A village may have any layout; a
    layout that isn't the standard one is a warning, not an error (§5.4).
  - Village ids are 0..n-1; reorder in the inspector.
- **Spawns:** mark edge road tiles as spawns, each assigned to a village
  (default: the village of its slice).
- **Slices:** recomputed from the villages (every tile to the nearest village
  in steps, ties to the lower number), or painted by hand (the Slice brush);
  every tile belongs to one slice. The editor numbers them 1-8 (buttons,
  inspector, layer, checks; the file stores 0-7), each in the colour of the
  co-op lobby's village colours (`Config.VILLAGE_COLORS`): the Slice tool's
  buttons and the Slices layer's tint and numbers.
- **Objects:** place, move, delete treasures, monster camps, unlock sites,
  ruined watchtowers, lairs, mines; edit their fields in the inspector (§6.7).
  A camp is linked to the treasure it guards by picking it.
- **Regenerate parts** (objects only, roads only, "fill the rest"): not built
  (the generator's stages would have to accept a prepared map); see §13.

### 4.4 Undo / redo

- A stack of the map's packed bytes (`MapData.to_bytes`, compressed) from
  before each edit (a whole stroke is one); undo / redo swap them in and only
  the tiles that differ are drawn again. Ctrl+Z / Ctrl+Y (Ctrl+Shift+Z) and
  the undo / redo buttons. Limit: `EDITOR.undo_steps` (100). Undo survives Play
  and back (the session, §8.1).

## 5. Rules the editor keeps

### 5.1 What is free and what is checked

Editing is free: you can paint anything anywhere. The rules come back as
**tidy-up** (automatic, §5.3) and **checks** (reported, §5.4). A map with
errors can be saved (work in progress) but not played or offered in the lobby.
A file that breaks the *format* is a different matter: it is refused on import
(§6.8).

### 5.2 Derived data (never stored, rebuilt on load)

- Per village: `rect` (the bounding box of its pieces) and `gates` (its gate
  pieces); `MapData.village_rect`, `gates`, `edge_spawns` (the union of the
  villages' spawns) and `village_layout` (the pieces with their owner);
  slice centres (`slices`); each object's `slice` (from its tile); the art of
  objects whose art follows from their fields (§6.7).
- **No farm plots:** maps (generated or from files) keep no room for a farm.
  A game places its starting farm on the nearest free spot by the village,
  or, without one, starts without a farm.

### 5.3 Tidy-up after each edit (automatic)

- A road over water or lava gets its crossing; a crossing whose road is gone
  is removed (the tile goes back to its water / lava).
- Forest tiles without a prop get one from their zone's mix; non-forest,
  non-mountain tiles lose tree / peak props.
- Decor is removed under roads, village pieces, objects and non-walkable tiles.
- Beaches: kept only on land next to water.
- Tiles under village pieces are set to ground (gates: road).

### 5.4 Checks

The generator keeps its own, stricter rules for the maps it makes (its 2
approaches stay a requirement there). For a map in the
editor or played from a file:

Errors (block Play and the lobby):
- every village: inside the map, its pieces not overlapping another village or
  objects, at least one gate, at least one hut, at least one spawn, every spawn
  reaching one of its gates by road;
- spawns on an edge road tile;
- every object on passable land reachable from its slice's village; a lair or
  mine with a `front` that is a road tile linked to the network; a camp's
  treasure exists; nothing on a crater's neighbours;
- village count between 1 and the size's slots.

Warnings (never block):
- a village with fewer than 2 approaches (`GenRoads.approaches`; a single
  approach may be a deliberate feature);
- a village whose layout isn't the standard one (`Config.VILLAGE_LAYOUT`
  around its centre);
- in co-op: a village with no road to another village;
- `GenChecks`' zone fairness between slices; a slice without treasures; an
  unlock kind missing (the summoner, apprentice or acolyte can never be
  unlocked); no camp in a slice; a far treasure unguarded.

## 6. The JSON map format

### 6.1 Principles

- One file per map, `.json`, UTF-8.
- Readable as a picture: every tile layer is a list of **row strings**, one
  character per tile, so a text editor shows the map. Row `y` from 0 (top) to
  size-1, character `x` from 0 (left). Coordinates elsewhere are `[x, y]`.
  This is the grid (simulation) space, not the isometric screen.
- Only what can't be derived is stored (§5.2). The village layout *is* stored
  in full (§6.6): layouts may differ from village to village.
- Versioned: `format_version` (integer). The loader upgrades older versions
  and refuses newer ones with a clear message.
- Export is **strict and canonical** (§6.8): the same map always gives the
  same bytes. Import is **tolerant within strict bounds** (§6.8).

### 6.2 Top level

All keys in this order on export.

| key | type | |
|---|---|---|
| `format` | string | always `"velirons-outpost-map"` |
| `format_version` | int | 4 (format 1: no `water_spawns`; 2: no ruin `building`; 3: no city zone `c`) |
| `name` | string | 1-60 characters; shown in the map list and the lobby |
| `author` | string | 0-60 characters |
| `description` | string | 0-1000 characters |
| `size` | int | one of `Config.MAP_SIZES` |
| `map_type` | string | any name, 1-40 characters (letters, digits, space, `_`, `-`). The generator's types (`temperate`, `highlands`, `coast`, `desert`, `volcanic`) are shown by their names; any other is a custom type, shown as written. `random` is never stored (a generated map stores the type it resolved to). Nothing in the game depends on it but its display |
| `origin` | object | how it was made: `{"generator_seed": 38, "edited": true, "game_version": "1.4.0"}`; `generator_seed` is `null` for a map not made by the generator; information only |
| `legend` | object | the codes of the tile layers (§6.3), written out so a reader needn't look them up; ignored on import |
| `layers` | object | the tile layers (§6.3) |
| `crossings` | array | bridges and fords (§6.4) |
| `volcanoes` | array | `[x, y]` centres |
| `villages` | array | §6.6 |
| `village_links` | array | `[a, b]` village id pairs joined by road (co-op) |
| `objects` | array | §6.7 |

### 6.3 Tile layers

| layer | codes |
|---|---|
| `terrain` | `.` grass, `R` road, `F` forest, `D` desert, `M` mountain, `W` deep water, `S` shallow water, `L` lava |
| `zone` | `m` meadow, `o` oak, `p` pine, `h` heath, `s` steppe, `w` swamp, `a` ash, `c` city |
| `slice` | `0`-`7` |
| `beach` | `b` beach, `.` none |
| `props` | `.` none, else a letter from the layer's own `palette` (art names) |
| `decor` | `.` none, else a letter from its `palette` |

Grass is `.` so the eye picks out everything else. A road over water is `R`
in `terrain`; what's under it is in `crossings`. `props` and `decor` carry a
`palette` (letter → art name). On export the letters are assigned in order of
first use (row by row): `a`-`z`, then `A`-`Z`, then `0`-`9`; at most 62 arts
per layer.

### 6.4 Crossings

`{"tile": [x, y], "art": "bridge_timber_x", "under": "water"}`; `under` is
`water`, `shallow` or `lava`; `art` is a bridge (`bridge_<style>_x|y`) or
`tile_ford`. Sorted by `y`, then `x` on export.

### 6.5 Coordinates and numbers

`[x, y]` pairs of integers inside the map. Lists of tiles (spawns, volcanoes)
are sorted by `y`, then `x` on export.

### 6.6 Villages

```
{
  "id": 0,
  "center": [37, 37],
  "spawns": [[0, 12], [74, 50], [30, 74]],
  "pieces": [
    {"kind": "wall_tower", "tile": [35, 35], "flip": false},
    {"kind": "wall", "tile": [36, 35], "flip": false},
    ...
  ]
}
```
- `id` is the village's slot, 0..n-1 in order.
- `center`: where the hero and the villagers gather (today's village centre).
- `spawns`: the edge road tiles its waves come from.
- `pieces`: every piece of the village, one entry each: `kind` (`wall`,
  `gate`, `wall_tower`, `hut`), `tile`, `flip` (walls on a village's left and
  right sides are drawn mirrored, as the generator does today). Sorted by
  `y`, then `x` on export. Generated maps always have the standard 25 pieces.

### 6.7 Objects

Every object has `id` (unique in the file, an integer ≥ 1, referenced by other
objects instead of list positions), `kind`, `tile`, `size`, and the kind's
fields. Sorted by `id` on export.

| kind | fields |
|---|---|
| `treasure` | `treasure` (`chest`, `ruins`, `shrine`, `standing_stones`, `shipwreck`, `dragon_bones`), `tier` (1-3), `reward` (what looting it gives: `gold`, `food`, `materials`, `hero_xp`, `heal_units` as whole numbers, or `relic`: a `Config.RELICS` key; optional, default `{}`) |
| `camp` | `tier`, `guards` (the treasure's `id`), `monsters` (enemy kinds) |
| `unlock` | `site` (`stone_circle`, `mage_tower`, `chapel`), `unlocks` (unit kind), `wave` (from which wave it awakens) |
| `ruin` | `building` (`tower` or `barracks`: what it was and becomes again when restored; optional, default `tower`; a barracks ruin is 2x2. The editor sets it by the size placed: 1x1 a watchtower, 2x2 barracks) |
| `lair` | `art` (`lair_cave`, `lair_tree`, `lair_ruin`, `lair_pit`, `lair_crypt`, and the 2x2 `..._big` ones), `front` (the road tile its door joins) |
| `mine` | `front` |

The `art` of the other kinds follows from their fields (as the generator
names them) and isn't stored. Neither is an object's `slice`: its tile's, a
camp's that of its treasure (a camp may stand just over the border); nor a
treasure's `guard` (the camp naming it). `unlocks` and `wave` of an unlock
site and a camp's `monsters` are optional (default: the site's / the tier's
from `config.gd`).

### 6.8 Export (strict) and import (tolerant within bounds)

**Export** always writes the canonical form:
- 2-space indent, `\n` line ends, a final newline, no BOM; keys in the
  documented order; every key written, also optional ones with their default
  (`"author": ""`, `"flip": false`, `"size": 1`);
- integers as integers; sorted lists (§6.4-6.7);
- each object, crossing, piece and `[x, y]` pair on one line (as in §6.9), so
  a file stays short and readable;
- so: the same map always gives the same bytes (the tests compare files).

**Import** accepts, beyond the canonical form:
- any whitespace and layout, minified JSON included; `\r\n` line ends; a
  UTF-8 BOM;
- keys in any order;
- missing optional keys, with their defaults: `author`, `description`,
  `origin`, `legend`, `village_links` (`[]`), `volcanoes` (`[]`),
  `crossings` (`[]`), `beach` and `decor` layers (all `.`), `flip` (`false`),
  `size` (1);
- numbers written as floats when they are whole (`37.0`);
- lists in any order;
- palette letters in any order and unused palette entries.

**Import refuses the file** (a list of every problem, each with its place,
e.g. `layers.terrain row 12, column 40: unknown code "X"`) when:
- it isn't JSON, or not an object at the top;
- `format` is wrong or missing; `format_version` is missing, not a whole
  number, or newer than the game knows;
- a required key is missing (`format`, `format_version`, `name`, `size`,
  `map_type`, `layers.terrain`, `layers.zone`, `layers.slice`, `layers.props`,
  `villages`, `objects`), or any key is unknown (a newer format adds keys with
  a new version);
- a value has the wrong type, or a number isn't whole where one is needed;
- `size` isn't one of the map sizes; a layer hasn't `size` rows of `size`
  characters; a code is unknown; a palette letter is used but not defined; an
  art name (palette, crossing, lair) isn't one of the game's arts; an enemy,
  treasure, site or unit kind is unknown;
- a coordinate is outside the map; ids are duplicated; a reference points
  nowhere (`guards`); village ids aren't exactly 0..n-1; there are more
  villages than the size's slots;
- a string is longer than its limit, or `map_type` has other characters.

Gameplay problems (a spawn that can't reach its village, a missing hut) are
not format errors: the map loads, and the checks (§5.4) report them.

### 6.9 Sketch (a 12×12 excerpt; a real file has `size` rows of `size` characters)

```json
{
  "format": "velirons-outpost-map",
  "format_version": 2,
  "name": "Two Rivers",
  "author": "Chris",
  "description": "A river splits the valley; the ford in the north is the weak spot.",
  "size": 75,
  "map_type": "river valley",
  "origin": {
    "generator_seed": 38,
    "edited": true,
    "game_version": "1.4.0"
  },
  "legend": {
    "terrain": ". grass, R road, F forest, D desert, M mountain, W deep water, S shallow water, L lava",
    "zone": "m meadow, o oak, p pine, h heath, s steppe, w swamp, a ash, c city",
    "slice": "0-7 the slice (village area) a tile belongs to",
    "beach": "b beach, . none",
    "props": ". none, else a letter of props.palette",
    "decor": ". none, else a letter of decor.palette"
  },
  "layers": {
    "terrain": [
      "FFFF....SWW.",
      "FFF.....SWW.",
      "FF..RRRRRRR.",
      "F...R...SWW.",
      "....R...SWW.",
      "....R....WW.",
      "MM..R.....W.",
      "MMM.R.....W.",
      "MMM.R.....WS",
      "MM..R......S",
      "M...R.......",
      "....R......."
    ],
    "zone": [
      "ooooommmmmmm",
      "ooommmmmmmmm",
      "oommmmmmmmmm",
      "ommmmmmmmmmm",
      "mmmmmmmmmmmm",
      "mmmmmmmmmmww",
      "hhmmmmmmmmww",
      "hhhmmmmmmmww",
      "hhhmmmmmmmww",
      "hhmmmmmmmmmw",
      "hmmmmmmmmmmm",
      "mmmmmmmmmmmm"
    ],
    "slice": [
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000",
      "000000000000"
    ],
    "beach": [
      "............",
      "............",
      "............",
      "............",
      "............",
      "............",
      "............",
      "............",
      "............",
      "............",
      "............",
      "............"
    ],
    "props": {
      "palette": {
        "a": "tree_oak",
        "b": "tree_oak_2",
        "c": "peak_1",
        "d": "peak_2"
      },
      "rows": [
        "abab........",
        "bab.........",
        "ab..........",
        "a...........",
        "............",
        "............",
        "cd..........",
        "dcd.........",
        "cdc.........",
        "dc..........",
        "c...........",
        "............"
      ]
    },
    "decor": {
      "palette": {
        "a": "reeds",
        "b": "boulder"
      },
      "rows": [
        "............",
        ".......a....",
        "............",
        ".......a....",
        "............",
        "..b.........",
        "............",
        "............",
        "............",
        "............",
        "............",
        "............"
      ]
    }
  },
  "crossings": [
    {"tile": [8, 2], "art": "tile_ford", "under": "shallow"},
    {"tile": [9, 2], "art": "bridge_timber_x", "under": "water"},
    {"tile": [10, 2], "art": "bridge_timber_x", "under": "water"}
  ],
  "volcanoes": [],
  "villages": [
    {
      "id": 0,
      "center": [37, 37],
      "spawns": [[0, 12], [74, 50], [30, 74]],
      "pieces": [
        {"kind": "wall_tower", "tile": [35, 35], "flip": false},
        {"kind": "wall", "tile": [36, 35], "flip": false},
        {"kind": "gate", "tile": [37, 35], "flip": false},
        {"kind": "wall", "tile": [38, 35], "flip": false},
        {"kind": "wall_tower", "tile": [39, 35], "flip": false},
        {"kind": "wall", "tile": [35, 36], "flip": true},
        {"kind": "hut", "tile": [36, 36], "flip": false},
        {"kind": "hut", "tile": [37, 36], "flip": false},
        {"kind": "hut", "tile": [38, 36], "flip": false},
        {"kind": "wall", "tile": [39, 36], "flip": true}
      ]
    }
  ],
  "village_links": [],
  "objects": [
    {"id": 1, "kind": "treasure", "tile": [12, 60], "size": 1, "treasure": "standing_stones", "tier": 3, "reward": {"relic": "hawkeye"}},
    {"id": 2, "kind": "camp", "tile": [14, 58], "size": 1, "tier": 3, "guards": 1, "monsters": ["ork", "ork", "goblin"]},
    {"id": 3, "kind": "unlock", "tile": [55, 20], "size": 1, "site": "stone_circle", "unlocks": "summoner", "wave": 3},
    {"id": 4, "kind": "ruin", "tile": [48, 30], "size": 1, "building": "tower"},
    {"id": 5, "kind": "lair", "tile": [5, 8], "size": 2, "art": "lair_cave", "front": [4, 9]},
    {"id": 6, "kind": "mine", "tile": [3, 7], "size": 1, "front": [4, 7]}
  ]
}
```

(The village is cut short after its first two rows; a real one lists all its
pieces. The art and monster names are examples; the real ones are those in
`Config` and `art/`.)

Size: a 200×200 map is about 6 layers × 200 rows × ~205 bytes ≈ 250 KB, fine.

## 7. Files and the map library

### 7.1 Where maps live

- **Your maps:** `user://maps/<name>.json` (desktop: the Godot user folder;
  web: the browser's storage for the site; Android: the app's storage).
  *Open* lists them with name, size, villages, map type and date.
- **Built-in maps:** `res://data/maps/*.json`, shipped with the game,
  read-only, listed under "Built-in": so far the campaign's scenario maps
  (`homecoming.json`, scenarios 1 and 2; `wardline.json`, scenario 3, the home
  map grown to 100x100; docs/scenarios-design.md §7). Opened in
  the editor, one is saved as a new file under your maps; to change a
  scenario's map, Export it over its file in `data/maps/`. (If loading JSON turns out too slow for
  big maps, they can be baked into `.res` files like the title maps; not
  planned until measured.)
- **The map picker** (`MapPicker`; the editor's Open, Singleplayer's and the
  lobby's Custom...): your maps (newest first), then the built-in ones, each
  with its size and villages; the selected one with a preview (`MapPreview`:
  the plan, objects, spawns and village numbers), its name, size, villages,
  map type, author and description, and its problems: a file that breaks the
  format can't be chosen, and for playing neither can a map with errors.
  Import (into your maps), Delete (your maps; after a confirmation), Cancel /
  Esc.

### 7.2 Import and export

- **Desktop, Android:** Godot's file dialog (`use_native_dialog`) to read a
  `.json` from anywhere, or write one anywhere.
- **Web:** Export downloads the file (`JavaScriptBridge.download_buffer`).
  Import opens the browser's file picker (a small JavaScript snippet through
  `JavaScriptBridge`) and reads the chosen file.
- Import runs the format check (§6.8) and lists every problem instead of
  loading a broken file. The editor's Import opens the map as a new, unsaved
  one; the picker's Import adds it to your maps.

## 8. Playing a map

### 8.1 Picking a map

- **Single player:** the Singleplayer menu's *Map* button goes through the
  types, Random, then **Custom...** (the map picker); the chosen map's name
  then shows on it (`Settings.custom_map`), and the next press goes back to
  the first type. With several villages on the map, *Your village: n of m*
  picks the one you play (`Settings.custom_village`). The seed field hides.
  The game starts on `Settings.custom_map.for_game([village])` as its
  `Game.preset_map`, as the title backdrop does with its baked maps.
- **From the editor:** *Play* (no errors; with several villages, which one,
  and the difficulty) starts a single-player game on a copy of the map. The
  editor's state (map, file, unsaved changes, undo, view) waits in
  `Settings.editor_session`; the game's settings offer *Back to editor*
  (`Game.go_to_editor`), and the editor picks the session up again (also when
  opened from the title screen after *Back to title*).
- **Co-op:** the host's *Map* button goes the same way in the lobby
  (`Net.set_custom_map`); every client gets a copy of the map at once (for
  the preview; `Net.custom_map`), a late joiner too. Everyone sees the map's
  name and village count on the Map button and a preview with each player's
  name by their village.
  - **Village assignment:** every player row has a *Village n* button (the
    host's cycle it, `Net.set_slot`; for the others it only shows). Each
    village has at most one player: taking someone's village swaps the two.
    Picking the map gives the players villages in join order; new players
    get the first free one. The number of players can't exceed the map's
    villages (`Net.max_players`: the lobby is full, LAN discovery says so);
    a map with fewer villages than the lobby has players is refused. *Start*
    needs every player on a different village.
  - At start the game is made from `Net.custom_map.for_game(the players'
    villages in player order)` and sent as before (`MapData` bytes,
    `Net._start`), so clients never need the file.
- The settings dialog shows the map's name instead of type and seed for a
  custom map.

### 8.2 Villages nobody plays

A village of the map that no player plays is **ownerless**:
- it is built (walls, gates, wall towers) but every hut is a ruin, and its
  ruins can't be rebuilt;
- it has no owner: no villagers, hero, economy, army or fog of its own, no
  name label, nothing in the statistics;
- its spawns send nothing, and no wave share or co-op extra is counted for it;
- enemies never head for it (it can't fall or be raided), and its wall towers
  can't be manned by anyone;
- the objects in its slice are there for anyone to find.

This holds in single player too (a map with three villages played alone: two
ownerless ones).

How: `MapData.for_game(played)` makes the game's map: village i is the
played village of player i, the slices are renumbered to match (player i's
slice is i, the rest after them; objects keep theirs under the new numbers),
the other villages move to `MapData.abandoned` (centre, rect, pieces; it
travels in the packed map), and gates, spawns and links are only the played
villages'. `World` builds the abandoned pieces with no owner and the meta
`abandoned` (huts ruined); their rects are explored for every village.
`Game.building_info` shows them as "An abandoned village" without actions,
commands refuse them (they aren't the player's), and the replicator sends
them with owner -1.

## 9. Code

```
scripts/editor/
  map_editor.gd       MapEditor: the scene's root: the map, file, tool, options, layers, selection,
                      undo / redo, checks, input, views, Play and the session
  editor_ui.gd        EditorUi: the panels, the dialogs (New, properties / Save as, Play, confirm)
  editor_tools.gd     EditorTools: every edit on a MapData (returns the changed tiles or why not)
  editor_overlay.gd   EditorOverlay: the layers and the pointer's marks, for either view
  iso_view.gd         IsoView: the isometric view (the game's ground / water layers, sprites)
  plan_view.gd        PlanView: the top-down view (MapPlan's colours, one pixel per tile)
  map_json.gd         MapJson: MapData <-> JSON (canonical writer, tolerant reader, format check)
  map_library.gd      MapLibrary: user://maps and res://data/maps; import / export per platform
  map_tidy.gd         MapTidy: the automatic tidy-up after edits (§5.3)
  map_checks.gd       MapChecks: the checks for custom maps (§5.4)
  map_picker.gd       MapPicker: choosing a map file (editor, Singleplayer, lobby)
  map_preview.gd      MapPreview: a small plan with the villages' numbers and labels
scripts/world/map_plan.gd   MapPlan: a map's top-down colours (also tools/map_shot's plan)
scenes/map_editor.tscn
data/maps/            built-in maps (.json; none yet)
```

- `MapData`: `meta` (name, author, description, origin), `abandoned`,
  `village_pieces`, `derive` / `derive_slices` (what follows from pieces,
  centres, spawns and slices), `for_game`, `copy`, `row_order`. `meta` and
  `abandoned` are packed only when set, so maps made before stay byte-equal.
- `MapGenerator.generate(seed, players, type, size)`; `GenContext` scales the
  per-slice amounts by `Config.gen_area_scale` and spawns and rivers by
  `gen_length_scale` (both 1 at `map_size(players)`, so those maps are
  unchanged).
- `Settings.custom_map`, `custom_village`, `editor_session`, `editor_play`;
  `Net.custom_map`, `set_custom_map`, `set_slot`, `max_players`, the players'
  `"slot"`; `Game._use_custom_map`, `go_to_editor`; `World._spawn_piece`.
- Config: `MAP_SIZES`, `MAP_SIZE_SLOTS`, `gen_area_scale`, `gen_length_scale`,
  `EDITOR` (undo steps, brush sizes, zoom ranges, plan tile size,
  `web_large_size`, text limits, the map folders).
- Docs: this file; `world-design.md` gets the size scaling; `ui-design.md`
  the title button and the map pickers; `multiplayer-design.md` the custom map
  in the lobby, the village assignment and ownerless villages.

## 10. Tests

`tests/map_format_bot.*`, end-to-end tests of the conversions, on generated
maps: every map type, sizes 50, 75 and 200, one and several villages (some
seeds each). The forms: **MapData** (in memory), **JSON** (text), **packed**
(`MapData.to_bytes`, as in `BakedMap` and the co-op start message).

- MapData → JSON → MapData: equal in every stored field. The comparison
  is field by field, so a failure
  names the field and the first tile or entry that differs.
- MapData → packed → MapData → JSON: the same JSON text as MapData → JSON.
- JSON → MapData → JSON: byte-identical (export is canonical).
- Export twice: byte-identical (deterministic).
- A title map (`BakedMap`, packed) → JSON → MapData → packed → MapData: equal.
- Minified JSON (the same map, `JSON.stringify` without indent), with keys
  shuffled, `\r\n`, a BOM, whole floats, lists reordered and optional keys
  dropped: imports to the same MapData.
- Refusals, one broken file each (from a valid one): bad `format`, newer
  version, missing required key, unknown key, wrong type, a short row, an
  unknown code, an undefined palette letter, an unknown art or kind, a
  coordinate outside, duplicate ids, a dangling `guards`, too many villages,
  non-JSON text. Each must be refused with a message naming the place.
- A map loaded from JSON plays: a single-player game on it runs a wave.
- A custom map with a non-standard village layout and one approach: loads,
  the warnings are there, no errors, and it plays.
- Ownerless villages: a two-village map played alone: the other village's
  huts are ruins, can't be rebuilt, its spawns send nothing, no enemy heads
  there.

Also, `map_format_bot`: generated maps pass the custom-map checks, and
`for_game` (villages 3 and 1 of three played: renumbered villages and slices,
the abandoned one, spawns, gates, links, the packed map).

`editor_bot`: the title button; a map in both views (the same tile in the
middle, tiles under the pointer); New (sizes, types, villages, blank); every
tool's edit with its tidy-up, undo and redo (terrain, fill, zone, decor,
peaks, beach, road over water and erased, a road path, volcano, village
placed / moved / pieces / spawns / renumbered / deleted, objects placed /
changed / linked / moved / deleted, slices painted / recomputed); a real
mouse drag painting one undo step and the File tab panning and selecting;
the right button (a right-click erasing with each tool, Zone and Slice
picking, Trees doing nothing, a right drag panning); the inspector (the
selection, the tile under the pointer with its road steps), every layer in
both views, the problems, every tool's options; the panels (no top bar, the
File tab's buttons, undo / redo as icons, folding both sides, the slices'
names and colours) and the portrait sheet (tabs, columns, the handle dragged
and tapped); save, the map list,
reading back, the picker (also a broken file), Play's game with Back to
editor, the session coming back; the web's big-map warning
(`MapPicker.pretend_web`).

`net_bot --custom` (run by `tests/run_net_test.sh` after the usual session):
the lobby with a three-village map (max 3 players, the map reaches the
client, assignment and swapping), the game on villages 1 and 3, village 2
ownerless on both sides. `mapgen_bot`: every size (every type at one village,
and the most villages it holds) passes the custom-map checks, with treasures
and every unlock site.

## 11. Decisions (from review)

1. Co-op on custom maps: the host assigns players to villages; villages nobody
   plays are ownerless ruins (§8.2).
2. Village slots per size: 50 → 1, 75 → 2, 100 → 4, 125 → 6, 150+ → 8.
3. No size choice for generated games for now.
4. No "starts explored" areas yet: that comes with scenarios, but will be needed.
5. `map_type` is a free name; the village layout is
   stored piece by piece (standard layout for generated maps, a warning, not
   an error, when a custom map differs).
6. Isometric and top-down 2D views, switchable.
7. The web build warns whenever a map of 150×150 or more is opened.
8. Custom maps: fewer than 2 approaches is a warning.
9. End-to-end conversion tests (§10); export strict, import tolerant within
   bounds, refusing format violations.

## 12. Not in this scope

Scenarios (start resources, units, waves, triggers, objectives, win
conditions, areas that start explored), a scenario editor, and sharing maps
online. The format keeps room for them: a scenario will be its own file
pointing at a map by name.

## 12b. Water spawns

docs/aquatic-design.md adds `water_spawns` (deep-water tiles where water monsters spawn), built:
a *Water spawn* tool (after Spawn: a click on deep water adds one, a click on one or a right-click
removes it; refused off deep water), a *Water spawns* layer (blue tiles marked "~"), an inspector
line for the body of deep water under the pointer ("Water body: n deep tiles, w wide · fits
crab, siren, ..." or "too small for water monsters"), a check (a water spawn off deep water, or
in a body no water monster fits: an error; Tidy leaves them alone, the check reports them) and a
`"water_spawns"` key in the JSON format (format version 2, after `"volcanoes"`: a list of tiles in
row order; optional on reading, so format 1 files still read).

## 13. As built: differences from the draft, and what's left

- Slices are recomputed by steps to the nearest village, not walking distance.
- *Regenerate parts* (objects, roads, "fill the rest") isn't built.
- Treasures carry their `reward` in the file (the draft forgot it).
- Lairs can be the 2x2 `_big` arts; objects are 1x1 or 2x2 in the editor.
- For the checks, only walls, wall towers and lairs block walking (as in the
  game: huts, gates, treasures and camps don't).
- Problems name villages from 1 (as the editor shows them), slices from 0
  (as the file's codes).
- Left: performance of 200x200 maps in the web build is unmeasured (the
  warning stands in for it); no built-in maps are shipped yet.
