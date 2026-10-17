# Veliron's Outpost: saving and loading games (design)

Status: **built** (decisions in §12). Tested by tests/save_bot.gd and
tests/net_bot.gd (`--resume`). Scope: save, load and
continue a game, an autosave after every wave, all stored locally; single
player first, and a co-op host can save and later resume a co-op game from a
lobby. Every number lives in `scripts/core/config.gd` (`SAVE`).

## 1. Summary

- **Save** (settings dialog) writes the running game to a save file on this
  device. **Load** (settings dialog, Singleplayer menu) opens a list of saves.
  **Continue** (Singleplayer menu) loads the newest single-player save at once.
- **Autosave:** after every finished wave the game saves itself, one autosave
  file per game, overwritten each wave.
- **When:** only **between waves** (no enemy of a wave on the map, §3). That
  is the moment the autosave runs anyway; during a wave *Save* is greyed out
  ("You can save between waves"). A game left in the middle of a wave (Back
  to title, the app closed or sent to the background, a crash) goes on from
  its last autosave: the end of the wave before. Nothing of a running wave is
  ever stored.
- **Co-op:** only the host saves (manually and the autosave). The host
  resumes a co-op save in a new lobby with **exactly as many players as the
  save has villages**; who plays which village is picked in the lobby and
  may differ from last time. A village takes the name of its new player and
  keeps its colour. Clients never need the file.
- **View:** when any game is loaded or resumed, every player's view starts
  centred on their own village (the host's too); the camera isn't saved.
- **Where:** `user://saves/` (desktop: the Godot user folder; web: the
  browser's storage for the site; Android: the app's storage). Nothing leaves
  the device; no import / export (could come later, §11).

## 2. Goals and non-goals

Goals:
- A game can be stopped and continued later, also after closing the app or
  the browser tab, and after a crash (the last autosave).
- A loaded game plays on as if it had never stopped: same map, fog, villages,
  buildings and their progress, villagers, army, hero, corpses, monster
  camps, waves, statistics.
- Small, quick files (tens of KB in single player), quick to write: no frame
  hitch worth noticing on the autosave.
- Testable headless: saving a loaded game gives the same save again (§10).

Non-goals:
- **Saving in the middle of a wave** (§12, decision 1), also no extra
  save on quitting.
- Exact replay: gameplay randomness (speed rolls, raids, the waves' RNG) isn't
  seeded, so the future after a load is not the future the save would have
  had. Every *state* is kept; the dice are rolled anew.
- Saving the tutorial, the title backdrop or the map editor's Play test
  (the editor has its own files).
- Saves that survive any change of the game: a save of another format
  version is refused (§8.3), not migrated.
- Cloud saves, sync between devices, import / export of saves.

## 3. Between waves

A game is **between waves** when `Waves.countdown > 0` (before wave 1 too)
and the game isn't over. Then, from the waves' point of view, nothing is
moving on the map (`_queue` empty, `_alive == 0`): rats, thieves, bats,
raised enemies and slime halves all count as alive, so the wave can't have
ended while any of them lives. What may still be there, and is saved:

- monster-camp and lair guards (`CampBehavior`; their lost HP doesn't heal,
  so it is kept);
- corpses (with their age);
- every unit of the players wherever it is, doing whatever it does: villagers
  at work or on their way, units marching, walking back, travelling to
  another village, or out of barracks against camp guards, earth elementals,
  caravans, the hero (also downed, also carrying loot).

Debug-spawned enemies (*Spawn enemy...*, the waves' `_uncounted`) are not
saved.

## 4. The player's view

### 4.1 Title screen

- The Singleplayer page gets **Continue** as its first button, above *Play*,
  when there is at least one loadable single-player save (§8.3). It loads the
  newest one, autosave or manual (never a co-op save), and shows under its
  label what it is: "Wave 7 · Highlands · Normal". It is the page's primary
  button then (Enter); without a save, *Play* is.
- The Singleplayer page also gets **Load...** under *Play*: the save list
  (§4.3).
- The main page has no Continue: continuing is a single-player thing.

### 4.2 In a game

- The settings dialog gets **Save...** and **Load...** under *Continue*:
  - *Save...* opens a page in the dialog with a name, prefilled "<map> ·
    wave N" (at most `SAVE.name_max` characters), and *Save*. A name in use
    asks first: the button becomes *Save over it*. During a wave the button
    reads "Save... (between waves)" and is greyed out. Done: a toast "Game
    saved".
  - *Load...* opens the save list (§4.3); loading asks first ("Leave this
    game? Progress since the last save is lost.").
  - Co-op: only the host sees *Save...*; nobody sees *Load...* (a co-op save
    is resumed from the lobby, §6).
  - Neither in the tutorial. A game started from the map editor's Play has
    *Save...* only, and isn't autosaved.
- **Autosave** (§5) shows a small "Autosaved" toast; a failed write shows
  "Couldn't autosave: <reason>" (red) and the game goes on.
- **Back to title**, closing the app or sending it to the background save
  nothing: the autosave at the end of each wave is what *Continue* goes on
  from.
- **Loaded:** the view starts centred on the player's village, at the
  default zoom, at 1×; the log starts with "Game loaded: wave N" (Info).
- **Defeat screen** (single player): **Load last save** between *Try again*
  and *Main menu*, loading the newest save of this game (its last autosave or
  a later manual save), when there is one.

### 4.3 The save list

A dialog like the map picker (`MapPicker`): the saves, newest first, each a
row with its name, *Autosave* or *Saved*, wave, map, difficulty, villages
(co-op: their names), play time and date. The selected one shows the map's
preview (`MapPreview` of the saved map: the plan as it is now, felled trees
included) with the villages marked. Buttons: **Load** (or *Use* in the
lobby), **Delete** (after a confirmation), **Cancel** / Esc. Saves that can't
be loaded (another version, broken file) are listed greyed out with the
reason, so they can still be deleted. The single-player list shows
single-player saves; the lobby's shows co-op saves (§6).

## 5. Autosave

- Runs once after each wave is finished (`Waves.wave_finished`), on the next
  frame (the signal fires inside the last enemy's death or gate handler, and
  a defeat may follow in the same call), and only if the game isn't over and
  is still between waves then.
- **One autosave file per game**, overwritten after every wave. Every game
  gets a random id when it starts (`Game.game_id`), kept through loads, so a
  loaded game keeps writing its own autosave, and a game loaded from a manual
  save writes the autosave of the game it came from.
- Autosaves of the newest `SAVE.keep_autosaves` (5) games are kept, older
  ones deleted. Manual saves are never deleted by the game.
- Not in the tutorial, the title backdrop, a game from the map editor's
  Play, or on a co-op client.

## 6. Co-op: saving and resuming

### 6.1 Saving

- The host saves like a single player (*Save...* between waves, the
  autosave after each wave). The file
  holds every village, whoever plays it, also villages whose player is
  offline and villages that have fallen.
- Nothing is sent to the clients; they see the toast "The host saved the
  game".

### 6.2 Resuming in the lobby

1. The host hosts a game as usual (name, colour, *Host game*).
2. Next to the **Map** button the host has **Saved game...**, which opens
   the save list with the co-op saves. The pick shows on the Map button
   ("Saved: <name> · wave N"), and the button now reads *New game*
   (pressing it, or the Map button, goes back to a new game).
   Difficulty and seed are fixed by the save: the difficulty button is
   greyed out, the seed field hidden.
3. **Exactly as many players as the save has villages** (`n`). The lobby
   takes at most `n` players (`Net.max_players`, LAN discovery says "full"),
   and *Start* needs exactly `n` players, all ready ("This save needs n
   players; m are here"). Picking a save with fewer villages than players in
   the lobby is refused, as with a map file. Who the players are isn't
   checked: only their number.
4. **Village assignment:** every player row gets a *Village* button with the
   saved village's name in its saved colour (the host cycles it; for the others it
   only shows), like the slots of a map file: each village has one player,
   taking someone's swaps the two. At the pick, a player whose name equals a
   saved village's name gets that village, the others the free ones in join
   order; a late joiner gets the first free one. The host can play any of
   them, not only the first.
5. Everyone sees the save's preview: the map, each village with its saved
   name and colour and the player assigned to it, the wave.
6. *Start*: the host builds the game from the save (§8.4), then sends every
   client the setup and the **saved map** as for a new game
   (`Net._start`); each client builds its world and gets a full snapshot,
   which already carries its fog, its village and everything it may see.
   Every player's view, the host's too, starts centred on their village.

### 6.3 Who a village is

A resumed village **takes the name of the player who now plays it** and
**keeps its saved colour** (§12, decision 3). The lobby's names are unique,
so the villages' names stay unique; the colour the player picked in the
lobby is not used for a resumed game (the *Village* button shows the colour
the village will have).

Each village whose name changes is logged for everyone at the start (Info):
"Village Foo is now played as Bar". From then on logs, labels over the
villages and the statistics (also the rows and samples from before the save)
use the new name.

Rejoining during a resumed game works as before, by the player's (and so the
village's) name. (The host logs the renames while it builds the game, before
anyone is connected, so each client logs them itself from the save's header,
which it has from the lobby.)

## 7. What is saved

Everything durable; what an AI is doing *right now* (its path, target,
cooldowns, timers, claims) is not saved and starts afresh after a load from
the saved position and loads.

| Part | Saved | Starts afresh |
|---|---|---|
| **Game** | `game_id`, difficulty, map type and seed (the name of a map file), `clock`, entity ids (`_next_nid`, every entity keeps its nid), the label counters `_ids`, `unlocks` | speed (1×), selection, input mode, the camera (centred on the player's village) |
| **Map** | the whole `MapData` as it is now (`to_bytes`: felled trees, cleared decor, dropped sacks), the live map objects (indices), tree chop progress (`World._chopped`) | pathing, derived layers, tree claims |
| **Fog** | `explored_of` per village | surveillance (recomputed every 0.2 s) |
| **Map objects** | `found_by`, and what each kind sends a co-op client (`net_state`): treasure `looted`, camp `cleared`, lair `awake` and `quiet_until`, unlock site `awake` / `used`, ruined tower's claiming village; lair `woke_at`; every living guard (kind, HP, position, home spot, colour, ids); a mine's miner (from the miner) | `claimed_by` (hero, gatherer), lair `wake_wave` (seeded from the map) |
| **Waves** | `wave`, `countdown` | the waves' RNG |
| **Corpses** | kind, wave, tile, time left, stolen gold, `hp_scale`, uid / nid | who claimed it |
| **Village** | name, colour, `fallen`, relics, `corpses_delivered`, resources, the log level shown | the log's lines (a loaded game starts with "Game loaded: wave N") |
| **Buildings** | kind, tile, uid / nid, `complete`, progress, `paid_share`, level, upgrade (and its progress), tear-down (and its progress); hut `ruined` and resident; workplace worker; farm `stored`; post slots; the build queue in order | builders' claims |
| **Villagers** | role, uid / nid, hut, HP, position, at home; the farmer's farm and food carried, the forester's camp, tree and load, the gatherer's corpses, gold and loot carried, the miner's mine and whether inside | job state: a villager out in the field walks home first (delivering what it carries there), rests and goes back to work, as after fleeing from enemies (`Civilian.resume_outside`); a miner inside his mine stays there |
| **Military units** | kind (the specialisation), level, HP, state, post and slot, `revive_left`, `revive_at_post`, `train_xp`, uid / nid, `original_owner`, `travel_to`, war-cry haste (`cry_bonus`, `cry_until`), the body's position for units on the way (`Army.resume_walk`) | cooldowns, targets, the body's path (re-pathed to where its state says); a unit out of its barracks against camp guards is back on its bench (the barracks turn it out again if they're still in range) |
| **Earth elementals** | of summoners on duty: summon kind, HP, max HP, damage, home, position, summoner, war-cry haste (those of a summoner out on a sortie crumble, as when it goes back to its bench) | target, timers |
| **Hero** | mode, level, XP, HP, downed, position, support target, camp target, carried loot or corpses (Explore / Gather jobs), war-cry haste | target, training link, idle and snore timers, `train_pause` |
| **Caravans** | from, to, cargo, tax, uid / nid, position | path (re-pathed) |
| **Statistics** | all of `Stats` (counters, samples, wave marks, towers, awards' data, its timers) | |

Not saved: anything of a running wave (no save is made during one), debug
enemies, the event log's lines, warning lights (derived), the camera,
the replicator's state, Settings outside the game (custom map, editor
session).

## 8. Files

### 8.1 Layout

`user://saves/<file>.vsave`, one file per save:
- autosaves: `auto-<game_id>.vsave`;
- manual saves: `<slug of the name>.vsave` (lower case, letters and digits,
  the rest dashes; never beginning with "auto"). Saving under a name that
  makes the same file name saves over that file (after the question).

Each file:
```
"VOSV"            4 bytes, magic
format            u32, SaveGame.FORMAT (1)
header length     u32
header            var_to_bytes(Dictionary), uncompressed
body              zstd(var_to_bytes(Dictionary)), its raw size first (as MapData.to_bytes)
```
The **header** is all the save list needs, read without unpacking the body:
`name`, `auto`, `game_id`, `saved_at` (unix time), `play_time` (game
seconds), `wave`, `difficulty`, `map_type` / `map_name`, `seed`, `villages`
(names and colours), `coop` (more than one village), `size`.

The **body** holds §7 as plain Dictionaries and Arrays (no objects:
references are nids, villages by index, map objects by index), the map as
its own `to_bytes()` blob. `var_to_bytes` without objects, so a file can't
carry code.

Size estimate: single player 75×75 about 20-60 KB (map ~15 KB, fog, stats
samples growing ~1 KB per 10 minutes); 8-village co-op a few hundred KB.

### 8.2 Writing

Into `<file>.tmp`, then renamed over the old file, so a crash mid-write
leaves the previous save intact. Done on the main thread (the web build has
no threads); building the Dictionaries is a walk over a few hundred
entities.

### 8.3 Loading and refusing

A file is **loadable** when the magic and `FORMAT` match, the body unpacks,
and every kind in it (buildings, roles, units, guards and corpses, summons)
exists (`SaveGame.check`). Otherwise the list says why: "Made with another version
of the game", "Broken file". `FORMAT` goes up whenever the body's layout
changes; old saves are then listed but refused (no migration). Balance
changes in `Config` don't change the format: a save plays on with the new
numbers (a unit's HP is clamped to its new max).

A single-player save is one with one village; it loads only from the
single-player places (Continue, Load...). A co-op save (2+ villages) loads
only in the lobby.

### 8.4 How a game is built from a save

`Settings.pending_save` (the unpacked body) is taken by `Game._ready`, like
`tutorial_next`:
1. Difficulty, map type and seed, `game_id` and the villages' colours come
   from the save; single player keeps the saved name, co-op takes each
   village's new player's name (villages in the order of the save; the
   assignment decides `Net.setup["local"]` per peer, `Net.setup["host"]`
   (`Game.host_village`), the names, and the colours as indices into
   `Config.VILLAGE_COLORS`). The host takes the body from `Net.resume_body`.
2. `preset_map` is the saved map; `world.setup` builds it as it builds a map
   file's map (no generation), without the camps' guards (`Game.restoring`).
   Then `SaveGame.restore_world`: the objects gone since are removed (looted
   sacks, restored ruins), the others get their state, the trees their
   chopping, every village its saved fog.
3. The villages are set up **empty** (`Village.setup_restored`: nothing
   spent, logged, counted or auto-assigned), then `SaveGame.restore_entities`
   fills them: the village pieces World built take their saved ids, the
   other buildings are built anew with theirs (`register_as`), then the
   build queues, villagers (into their huts and workplaces), heroes, units
   (onto their posts' slots, or walking on), elementals (into their
   summoners' lists), caravans, corpses, camp guards, the waves' counter,
   and last the label counters (`_ids`).
4. Statistics are restored instead of `Stats.start()`, the waves' `wave` and
   `countdown` set, `unlocks` set directly (no "unlocked" log), the camera
   centred on the player's village, and in co-op the renamed villages
   logged (§6.3).

`SaveGame` holds capturing and restoring for every part, in one place: a
new piece of durable state needs a line in `capture` and one in the
matching `_restore_*`. The classes got small helpers for it
(`Village.setup_restored`, `Civilian.resume_outside`, `Army.resume_walk`,
`World.restore_chopped`, `MonsterCamp.restore_guard`, `Stats.save_state` /
`load_state`). Restoring never goes through the gameplay mutators
(`recruit`, `place`, `kill`, `level_up`, `unlock`, `Economy.add`...), which
spend, log, count statistics or assign workers.

## 9. Code

```
scripts/systems/save_game.gd   class SaveGame: capture, restore_world / restore_entities, write / read /
                               list / delete, header and summary, check (refusals), autosave and pruning,
                               start (load a single-player save), dir_override (tests)
scripts/ui/save_list.gd        the save list (§4.3): the Singleplayer page, the settings dialog, the lobby
scripts/core/config.gd         SAVE: dir, keep_autosaves, name_max
scripts/core/settings.gd       pending_save (taken by Game)
scripts/game.gd                game_id, restoring, loaded; the restore path in _ready; save_error() (between
                               waves, not over, not tutorial / backdrop / client), save_named, load_save,
                               the autosave after wave_finished, the "is now played as" log; host_village
                               from Net.setup["host"]
scripts/net/net.gd             resume / resume_map / resume_body, set_resume, slot_count, max_players /
                               can_start with the save's villages, _start_resumed
scripts/ui/title_screen.gd     Continue and Load... on the Singleplayer page
scripts/ui/hud.gd              Save... / Load... and the save page in the settings dialog, toasts,
                               Load last save on the defeat screen
scripts/ui/multiplayer_menu.gd Saved game... next to Map, the Village buttons for a save
```

## 10. Tests

`tests/save_bot.*` (its saves in `user://save_bot`, `SaveGame.dir_override`):
- **Round trip:** a single-player game set up with every kind of state in
  §7 (a site in progress, a tower upgrade, a tear-down, a ruined hut being
  rebuilt, barracks at level 2 with a unit on its bench, units on towers,
  in the reserve, downed, marching, specialised, a summoner with an
  elemental, the hero out in the field carrying loot, a gatherer out with
  corpses, a corpse, a hurt camp guard, a felled and a half-chopped tree,
  explored land, a relic); saved (Save...), loaded paused into a new scene;
  **saving again gives the same body** (except the id counter: walking units
  get new bodies). Plus targeted checks on the loaded game, the log (only
  "Game loaded") and the view on the village.
- The loaded game runs on: a wave comes, can't be saved meanwhile, and is
  fought; the autosave follows (one file, marked, wave 1, now what Continue
  takes); a builder finishes the saved site.
- Files: no temporary file left, header-only listing, wrong magic, another
  format and an unknown kind refused (listed with why), delete, a newer
  co-op save ignored by Continue, autosaves pruned to `keep_autosaves`, safe
  file names; the title screen's Continue (on the Singleplayer page only).
- The tutorial: can't be saved, no Save or Load in its settings.
- Two villages (`Game.test_villages`): a caravan on its way, a unit
  travelling, the hero supporting, a fallen village; round trip.

`tests/net_bot` has a third run (`--resume`, in `tests/run_net_test.sh`):
the host saves a game of two villages made on the spot, hosts, picks it
(two players at most; alone it can't start; a third player is turned
away), the client joins, the two swap villages, start; each side plays its
village under its own name in the saved colour, with its saved buildings,
the log saying who plays which village now, the view on its village.

## 11. Later (not in this design)

- Saving in the middle of a wave (left out on purpose, §12, decision 1).
- Export / import of save files (as the map editor's maps: a file dialog, a
  download on the web).
- Scenarios (docs/map-editor-design.md's roadmap) can start from a save-like
  start setup.

## 12. Decisions

1. **Only between waves.** No mid-wave state is ever stored, also not on
   quitting: a game left during a wave goes on from the autosave at the end
   of the wave before.
2. **Manual saves by name**, several per game, the name prefilled (§4.2).
3. **A resumed co-op village takes the new player's name and keeps its
   colour**, logged as "Village Foo is now played as Bar" (§6.3).
4. **Continue** is on the Singleplayer page only and loads the newest
   single-player save, autosave or manual; never a co-op save.
5. **Autosave only at the end of each wave**: nothing extra on Back to title,
   closing the app or sending it to the background.
6. **The camera isn't saved:** every loaded or resumed game, co-op too (the
   host's view included), starts with each player's view centred on their
   village.
