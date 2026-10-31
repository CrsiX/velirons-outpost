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
- Maps are stored as **pretty-printed JSON**, one file per map, in a
  readable, diffable format (§6). Export is strict, import is tolerant
  within strict bounds (§6.3).
- A map from a file can be **played**: single player and co-op. In co-op the
  host picks the map, assigns players to its villages, and sends it to
  everyone (the host is the source of truth; the clients never need the file).
  Villages nobody plays stand as ownerless ruins (§8.2).
- Map sizes: `Config.MAP_SIZES`.

## 2. Stages

| Stage | What | Done when |
|---|---|---|
| 1. Inspect | Generate (type, seed, size, villages), isometric and top-down view with overlays, tile and object inspector, problems list, save / open / import / export JSON, map library, play the map (single player and co-op, with village assignment) | the conversion tests pass (§10) and a saved map plays |
| 2. Edit | Brushes (terrain, zone, trees, decor, beach), roads, objects, villages and their pieces, spawns; undo / redo; automatic tidy-up (§5.3); live checks | a hand-made map passes the checks and plays |
| (3. Scenarios) | later, not in this scope | |

## 3. Map sizes

- A map's size is one of `Config.MAP_SIZES`.
- **Village slots** per size (how many villages a map of that size may hold):
  `Config.MAP_SIZE_SLOTS`. Bigger maps hold more villages.
- Generated games keep the automatic size from the player count
  (`Config.map_size(players)`); the Singleplayer menu and the lobby get no
  size choice. Other sizes come from the editor.
- The **generator** takes the size as an argument instead of deriving it from
  the player count (the editor's *New* uses any size). Its per-slice amounts
  (treasures, ruins, lairs, mines, spawns) are tuned for the usual slice
  area, so they get scaled by slice area where that matters (a 200×200
  single-village map is one huge slice), with the factors in `config.gd`.
  `mapgen_bot`'s sweep covers every size.
- **Big maps in the browser:** in the web build, opening a big map
  (generating, opening, importing it in the editor, or picking it to play)
  always shows a warning first, with Continue / Cancel. The threshold is
  `EDITOR.web_large_size`.

## 4. The editor

### 4.1 Layout (desktop)

Tools panel on the left, the map in the middle, inspector on the right, a
status line at the bottom (map name, size, type, seed, villages, saved
state, the tile under the pointer).

- No top bar: the tools panel (`EditorUi.LEFT_W`) starts with undo and
  redo and the view toggle, then the tools. The first, **File**, holds the
  file operations (New, Open, Save, Save as, Import, Export), Properties,
  Play and Exit (back to the title screen).
- **Folding** (landscape): each side panel's heading folds it to its edge so
  the map gets the room; a tap opens it again. Play and back keep the panels
  as they were (the session).
- Camera as in the game (`camera_controller.gd`): WASD / arrows, a right or
  middle mouse drag (any tool) or, with the File tab open, a left drag to pan;
  wheel / pinch to zoom, out further than the game (`EDITOR.min_zoom`) so the
  biggest map fits; the camera's zoom limits are per scene.
- With a mouse every tool acts on a left press (*place this*) and drags
  paint. A **right-click** (let go where it was pressed) is the tool's
  opposite, once (one brush stamp, one undo step), and only of that tool's
  kind: Terrain puts grass back, Decor, Beach and Road erase theirs,
  Volcano, Pieces, Spawn, Village and Objects remove the one there; Zone and
  Slice have no "nothing", so a right-click takes the tile's zone or slice as
  the current one; Trees, peaks does nothing. A right-click first cancels a
  pick or a road being laid (as Esc). Erasing along a drag is the tools'
  *Erase* options (with a finger the only way). With the File tab open the map
  isn't edited: a click selects the tile, object or village (the inspector
  shows it). The editor's keys (undo / redo, save, view switch, delete, Esc)
  are in `map_editor.gd`; Esc closes a dialog, then cancels a pick or a road
  being drawn, then clears the selection, then asks to leave.
- **Views** (the toggle, or Tab), both fully editable:
  - *Isometric:* the game's renderers, with the overlays drawn on top.
  - *Top-down 2D:* one square per tile, coloured by terrain and tinted by
    zone (as `tools/map_shot`'s plan), with small icons for props, objects,
    village pieces and spawns. Faster to read for layout and precise for
    painting; cheap to draw even at the biggest size.
  - Switching keeps the tile under the view's centre and the zoom level
    (as far as the views allow).
- **Mobile / portrait** (or narrow, `EditorUi.NARROW`): the two side panels
  are the pages of a bottom sheet, as the game's dock: a handle over two
  tabs, Tools and Inspector, always along the bottom (same behaviour and
  constants as the game's: `Hud.SHEET_MAX`, `Hud.SHEET_FLICK`). The grids
  take as many columns as fit (`SHEET_CELL`). With a finger a tap acts once
  where it lands and a drag pans; the tool options offer "Paint by dragging"
  so a drag paints instead. The inspector's tile is the last one tapped.
- Esc closes the newest popup, as in the game (`register_popup`); with none
  open it asks to leave if there are unsaved changes.

### 4.2 Stage 1: inspect

- **New / Generate:** size, map type (Temperate ... Random), seed (empty:
  random), village count (up to the size's slots). Runs the full generator
  (with a progress bar; big maps take seconds). The result has the standard
  village layout. Its checks' failures and warnings land in the problems list
  instead of retrying silently, so the author sees what the generator would
  have hidden.
- **Overlays** (Layers panel, each on/off; `EditorOverlay`): zones, slices,
  grid lines, passability, buildable land, a picked village's road steps,
  spawns, villages, objects, camp rings and lair / mine fronts, and the
  problems. The layers are drawn again only when the map or a switch
  changes; the pointer's marks (brush, selection, a road being drawn) are in
  a second overlay, so moving the mouse stays cheap.
- **Inspector:** the selection (picked with the File tab open, by the
  Village and Objects tools, or from the problems list): an object with all
  its fields (§6.2), a village, or a tile. Under it always the tile under the
  pointer (with a finger: the last tapped): terrain, zone, slice, props,
  crossing, beach, village piece, road steps to each village's gates (the
  road fields are kept until the next edit).
- **Map properties:** name, author, description, map type (any string,
  §6.2), shown and edited in a dialog.
- **Problems:** the checks of §5.4, each an error or a warning, run shortly
  after an edit; tapping one centres the view on its tile and marks it.
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
  shallow water, lava; brush sizes (`EDITOR`), square or round; a **fill**
  mode (flood fill of the same terrain).
- **Zone brush:** every zone (changes look, farm rules and walking speed,
  not terrain). The city is never generated (the campaign's capital):
  cobblestone ground, and on its mountain tiles houses (`ZONES.city.peaks`:
  standing and ruined) in place of peaks, drawn on the cobbles.
- **Trees / props:** paint a specific prop art, or "auto" (picked from the
  zone's mix like the generator does). **Decor** the same; besides the zones'
  decor it offers `Config.EXTRA_DECOR` (no zone scatters it, e.g. scenario 5's
  dried-up well). **Beach** on / off.
- **Roads:** draw a road from tile to tile (a straight / A* path between two
  taps, or freehand). Water or lava under it becomes a crossing
  automatically (bridge style by zone, ford on shallow), as in `GenRoads`.
  Erase removes road back to the zone's ground.
- **Volcano:** place / remove (mountain block, crater prop, ash around on
  request).
- **Villages:**
  - *Place a village:* stamps the standard layout (`Config.VILLAGE_LAYOUT`)
    around a centre; move or delete a whole village; set its centre (where
    the hero and villagers gather).
  - *Pieces:* add, remove or change single pieces (wall, gate, wall tower,
    hut) of a village, and flip a wall. A village may have any layout; a
    layout that isn't the standard one is a warning, not an error (§5.4),
    because scenarios need ruined or odd villages.
  - *Materials* (docs/siege-design.md §2a): the Village and Pieces tools
    share a material choice (`opts.material`). A new village is all of it; so
    is a new piece (a changed piece keeps its own); the Pieces tool's *Paint
    material* gives the clicked piece, a hut too, the chosen one. The
    village's inspector lists its materials and makes all its pieces one with
    a click (`MapEditor.set_village_material`).
  - Village ids are 0..n-1; reorder in the inspector.
- **Spawns:** mark edge road tiles as spawns, each assigned to a village
  (default: the village of its slice).
- **Slices:** recomputed from the villages (every tile to the nearest village
  in steps, ties to the lower number), or painted by hand (the Slice brush);
  every tile belongs to one slice. The editor numbers them from 1 (the file
  stores them from 0), each in the colour of the co-op lobby's village colours
  (`Config.VILLAGE_COLORS`).
- **Objects:** place, move, delete treasures, monster camps, unlock sites,
  ruined watchtowers, lairs, mines; edit their fields in the inspector (§6.2).
  A camp is linked to the treasure it guards by picking it.
- **Water spawns** (docs/aquatic-design.md): a tool for deep-water tiles where
  water monsters come from (refused off deep water), a layer, and an inspector
  line naming the body of deep water under the pointer and which water
  monsters fit it. The check reports a water spawn off deep water or in a
  body no water monster fits (an error); Tidy leaves them alone.
- **Regenerate parts** (objects only, roads only, "fill the rest"): not built
  (the generator's stages would have to accept a prepared map); see §13.

### 4.4 Undo / redo

- A stack of the map's packed bytes (`MapData.to_bytes`, compressed) from
  before each edit (a whole stroke is one); undo / redo swap them in and only
  the tiles that differ are drawn again. Limit: `EDITOR.undo_steps`. Undo
  survives Play and back (the session, §8.1).

## 5. Rules the editor keeps

### 5.1 What is free and what is checked

Editing is free: you can paint anything anywhere. The rules come back as
**tidy-up** (automatic, §5.3) and **checks** (reported, §5.4). A map with
errors can be saved (work in progress) but not played or offered in the lobby.
A file that breaks the *format* is a different matter: it is refused on import
(§6.3).

### 5.2 Derived data (never stored, rebuilt on load)

- Per village: its bounding box and its gates; the union of the villages'
  spawns; the pieces with their owner (`MapData.village_rect`, `gates`,
  `edge_spawns`, `village_layout`); slice centres; each object's slice (from
  its tile); the art of objects whose art follows from their fields (§6.2).
  Storing these would only let them disagree with what they derive from.
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

The generator keeps its own, stricter rules for the maps it makes (its
minimum number of approaches stays a requirement there). For a map in the
editor or played from a file (`MapChecks`):

Errors (block Play and the lobby), the things the game can't run without:
- every village: inside the map, its pieces not overlapping another village or
  objects, a gate, a hut, a spawn, every spawn reaching one of its gates by
  road;
- spawns on an edge road tile;
- every object on passable land reachable from its slice's village; a lair or
  mine whose `front` is a road tile linked to the network; a camp's
  treasure exists; nothing on a crater's neighbours;
- village count within the size's slots.

Warnings (never block), the things that may be deliberate:
- a village with fewer than the generator's minimum of approaches (a single
  approach may be a deliberate feature);
- a village whose layout isn't the standard one;
- in co-op: a village with no road to another village;
- `GenChecks`' zone fairness between slices; a slice without treasures; an
  unlock kind missing (it could never be unlocked); no camp in a slice; a far
  treasure unguarded.

## 6. The JSON map format

The format is defined by `scripts/editor/map_json.gd` (`MapJson`: the key
order, the tile codes, `VERSION`, the limits and the refusals) and the files
in `data/maps/` are living examples. This section keeps the reasons.

### 6.1 Principles

- One file per map, `.json`, UTF-8.
- Readable as a picture: every tile layer is a list of **row strings**, one
  character per tile, so a text editor shows the map. Row `y` from 0 (top),
  character `x` from 0 (left); coordinates elsewhere are `[x, y]`. This is
  the grid (simulation) space, not the isometric screen. Grass is `.` so the
  eye picks out everything else.
- Only what can't be derived is stored (§5.2). The village layout *is* stored
  in full, piece by piece: layouts may differ from village to village.
- Versioned: `format_version` (an integer). The loader upgrades older versions
  by filling what they lacked with defaults (e.g. a piece's material follows
  the map type, as the generator would have given it) and refuses newer ones
  with a clear message. The version history is in `MapJson`.
- Export is **strict and canonical** (§6.3): the same map always gives the
  same bytes (so files diff cleanly and the tests compare bytes). Import is
  **tolerant within strict bounds** (§6.3).
- `map_type` is a free name: nothing in the game depends on it but its
  display. `random` is never stored (a generated map stores the type it
  resolved to). `origin` is information only (the seed the generator used,
  whether it was edited, the game version).
- A road over water is `road` in the terrain layer; what is under it lives in
  the `crossings` list (the bridge or ford art and what it spans). Props and
  decor carry a `palette` (letter → art name) whose letters are assigned in
  order of first use, so files don't depend on an art list that changes.
- The `legend` is written out so a reader needn't look the codes up; it is
  ignored on import.

### 6.2 Objects

Every object has an `id` (unique in the file, referenced by other objects
instead of list positions, so reordering never breaks a link), `kind`,
`tile`, `size`, and the kind's fields (`MapJson`; `Config.TREASURES`,
`Config.RELICS`, `Config.UNLOCK_SITES`).

- The `art` of the kinds whose art follows from their fields isn't stored.
  Neither is an object's `slice` (its tile's; a camp's that of its treasure,
  since a camp may stand just over the border) nor a treasure's `guard` (the
  camp naming it).
- Treasures carry their `reward` in the file (a hand-made map decides what
  its treasure gives); an unlock site's `unlocks` and `wave` and a camp's
  `monsters` are optional and default to the site's / the tier's from
  `config.gd`.
- A ruin's `building` says what it was and becomes again when restored
  (tower or barracks); the editor sets it by the size placed.
- Lairs and mines store a `front`: the road tile their door joins.

### 6.3 Export (strict) and import (tolerant within bounds)

**Export** always writes the canonical form: fixed layout, fixed key order,
every key written (also optional ones with their default), sorted lists,
each object, crossing, piece and coordinate pair on one line so a file stays
short and readable.

**Import** accepts, beyond the canonical form: any whitespace and layout
(minified JSON, `\r\n`, a UTF-8 BOM), keys and lists in any order, missing
optional keys (with their defaults), whole numbers written as floats,
palette letters in any order and unused palette entries. It is meant for
files that people edit by hand or other tools write.

**Import refuses the file**, with a list of every problem and its place
(e.g. `layers.terrain row 12, column 40: unknown code "X"`), when it breaks
the format: not JSON; wrong or missing `format` / `format_version`, or a
newer version; a required key missing or any key unknown (a newer format adds
keys with a new version, so an unknown key means a file this game can't
read faithfully); a wrong type; a size, row, code, palette letter, art, enemy,
treasure, site, unit kind or material the game doesn't know; a coordinate
outside the map; duplicate ids, a dangling reference, village ids that aren't
exactly 0..n-1, or more villages than the size's slots; a string over its
limit.

Gameplay problems (a spawn that can't reach its village, a missing hut) are
not format errors: the map loads, and the checks (§5.4) report them. That
keeps a half-finished map openable.

## 7. Files and the map library

### 7.1 Where maps live

- **Your maps:** `user://maps/<name>.json` (desktop: the Godot user folder;
  web: the browser's storage for the site; Android: the app's storage).
  *Open* lists them with name, size, villages, map type and date.
- **Built-in maps:** `res://data/maps/*.json`, shipped with the game,
  read-only, listed under "Built-in": the campaign's scenario maps
  (docs/scenarios-design.md §7). Opened in the editor, one is saved as a new
  file under your maps; to change a scenario's map, Export it over its file in
  `data/maps/`. (If loading JSON turns out too slow for big maps, they can be
  baked into `.res` files like the title maps; not planned until measured.)
- **The map picker** (`MapPicker`; the editor's Open, Singleplayer's and the
  lobby's Custom...): your maps (newest first), then the built-in ones, each
  with its size and villages; the selected one with a preview (`MapPreview`),
  its details and its problems: a file that breaks the format can't be
  chosen, and for playing neither can a map with errors. Import (into your
  maps), Delete (your maps; after a confirmation), Cancel / Esc.

### 7.2 Import and export

- **Desktop, Android:** Godot's file dialog to read a `.json` from anywhere,
  or write one anywhere.
- **Web:** Export downloads the file (`JavaScriptBridge.download_buffer`).
  Import opens the browser's file picker (a small JavaScript snippet through
  `JavaScriptBridge`) and reads the chosen file.
- Import runs the format check (§6.3) and lists every problem instead of
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
    villages (`Net.max_players`); a map with fewer villages than the lobby
    has players is refused. *Start* needs every player on a different
    village.
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
ownerless ones). The point: one map serves any number of players up to its
village count, and a half-played map has no phantom opponents.

How: `MapData.for_game(played)` makes the game's map: village i is the
played village of player i, the slices are renumbered to match (objects keep
theirs under the new numbers), the other villages move to
`MapData.abandoned` (it travels in the packed map), and gates, spawns and
links are only the played villages'. `World` builds the abandoned pieces with
no owner and the meta `abandoned` (huts ruined); their rects are explored for
every village. `Game.building_info` shows them as "An abandoned village"
without actions, commands refuse them (they aren't the player's), and the
replicator sends them with owner -1.

## 9. Code

The files under `scripts/editor/` each own one concern: the scene root
(`map_editor.gd`: state, input, undo, files, Play, session), the panels and
dialogs (`editor_ui.gd`), every edit (`editor_tools.gd`: returns the changed
tiles or why not), the overlays (`editor_overlay.gd`), the two views
(`iso_view.gd`, `plan_view.gd`), the format (`map_json.gd`), files
(`map_library.gd`), tidy-up (`map_tidy.gd`), checks (`map_checks.gd`) and the
picker and preview (`map_picker.gd`, `map_preview.gd`).
`scripts/world/map_plan.gd` draws a map's top-down colours (also
`tools/map_shot`'s plan).

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
  `EDITOR`.
- Docs: this file; `world-design.md` carries the size scaling; `ui-design.md`
  the title button and the map pickers; `multiplayer-design.md` the custom map
  in the lobby, the village assignment and ownerless villages.

## 10. Tests

`tests/map_format_bot.*`, end-to-end tests of the conversions, on generated
maps (every map type, several sizes, one and several villages). The forms:
**MapData** (in memory), **JSON** (text), **packed** (`MapData.to_bytes`, as
in `BakedMap` and the co-op start message). What is guarded:

- every round trip between the forms is lossless and the comparison names the
  field and the first tile or entry that differs;
- export is canonical and deterministic (byte-identical);
- tolerant import: the same map reshaped (minified, shuffled keys, other line
  ends, a BOM, floats, reordered lists, dropped optional keys) imports to the
  same `MapData`;
- every refusal, one broken file each, with a message naming the place;
- a map loaded from JSON plays; a custom map with a non-standard village
  layout and one approach loads with warnings and no errors, and plays;
- ownerless villages (§8.2): their huts are ruins and can't be rebuilt, their
  spawns send nothing, no enemy heads there; generated maps pass the
  custom-map checks; `for_game` renumbers villages and slices and keeps the
  abandoned one.

`editor_bot`: the title button, both views, New, every tool's edit with its
tidy-up, undo and redo, a real mouse drag as one undo step, the right button,
the inspector, every layer, the problems, the panels (folding, the portrait
sheet), save, the map list, the picker, Play and Back to editor, the web's
big-map warning (`MapPicker.pretend_web`).

`net_bot --custom` (run by `tests/run_net_test.sh`): the lobby with a
multi-village map, assignment and swapping, the game on some villages with
the others ownerless on both sides. `mapgen_bot`: every size passes the
custom-map checks, with treasures and every unlock site.

## 11. Decisions (from review)

1. Co-op on custom maps: the host assigns players to villages; villages nobody
   plays are ownerless ruins (§8.2).
2. Village slots per size grow with the size (`MAP_SIZE_SLOTS`).
3. No size choice for generated games for now.
4. No "starts explored" areas yet: that comes with scenarios, but will be needed.
5. `map_type` is a free name; the village layout is stored piece by piece
   (standard layout for generated maps, a warning, not an error, when a
   custom map differs).
6. Isometric and top-down 2D views, switchable.
7. The web build warns whenever a big map is opened.
8. Custom maps: too few approaches is a warning.
9. End-to-end conversion tests (§10); export strict, import tolerant within
   bounds, refusing format violations.

## 12. Not in this scope

Scenarios (start resources, units, waves, triggers, objectives, win
conditions, areas that start explored), a scenario editor, and sharing maps
online. The format keeps room for them: a scenario is its own file pointing
at a map by name (docs/scenarios-design.md).

## 12b. Water spawns

docs/aquatic-design.md adds `water_spawns`, built; the editor side (tool,
layer, inspector line, check) is in §4.3, the format key is optional on
reading so older files still read.

## 13. As built: differences from the draft, and what's left

- Slices are recomputed by steps to the nearest village, not walking distance.
- *Regenerate parts* (objects, roads, "fill the rest") isn't built.
- Treasures carry their `reward` in the file (the draft forgot it).
- Lairs can be the 2x2 `_big` arts; objects are 1x1 or 2x2 in the editor.
- For the checks, only walls, wall towers and lairs block walking (as in the
  game: huts, gates, treasures and camps don't).
- Problems name villages from 1 (as the editor shows them), slices from 0
  (as the file's codes).
- Left: performance of the biggest maps in the web build is unmeasured (the
  warning stands in for it).
