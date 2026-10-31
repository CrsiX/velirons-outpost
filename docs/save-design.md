# Veliron's Outpost: saving and loading games (design)

Status: **built** (decisions in §12). Tested by tests/save_bot.gd and
tests/net_bot.gd (`--resume`). Scope: save, load and continue a game, an
autosave after every wave, all stored locally; single player first, and a
co-op host can save and later resume a co-op game from a lobby. Numbers live in
`Config.SAVE`.

## 1. Summary

- **Save** (settings dialog) writes the running game to a save file on this
  device. **Load** (settings dialog, Singleplayer menu) opens a list of saves.
  **Continue** (Singleplayer menu) loads the newest single-player save at once.
- **Autosave:** after every finished wave the game saves itself, one autosave
  file per game, overwritten each wave.
- **When:** only **between waves** (§3). During a wave *Save* is greyed out
  with the reason. A game left mid-wave (Back to title, the app closed or
  backgrounded, a crash) goes on from the end of the wave before. Nothing of a
  running wave is ever stored (why: §12, decision 1).
- **Co-op:** only the host saves. The host resumes a co-op save in a new lobby
  with **exactly as many players as the save has villages**; who plays which
  village is picked in the lobby and may differ from last time. Clients never
  need the file.
- **View:** the camera isn't saved; every player's view starts on their own
  village.
- **Where:** `user://saves/`, which is the game's own data folder on desktop,
  the browser's storage on the web (the game asks for persistent storage at
  start-up, `Settings._keep_web_storage`, so the browser doesn't evict saves
  when space runs low) and the app's storage on Android. Nothing leaves the
  device; no import / export (§11).

## 2. Goals and non-goals

Goals:
- A game can be stopped and continued later, also after closing the app and
  after a crash (the last autosave).
- A loaded game plays on as if it had never stopped: every durable state kept.
- Small, quick files and no noticeable hitch on the autosave.
- Testable headless: saving a loaded game gives the same save again.

Non-goals:
- **Saving in the middle of a wave** (§12, decision 1), also no extra save on
  quitting.
- Exact replay: gameplay randomness isn't seeded, so the future after a load is
  not the one the save would have had. Every *state* is kept; the dice are
  rolled anew.
- Saving the tutorial, the title backdrop or the map editor's Play test (the
  editor has its own files).
- Saves that survive any change of the game: another format version is
  refused (§8.3), not migrated. A migration layer would cost more than losing
  old saves between releases of a game this young.
- Cloud saves, sync between devices, import / export of saves.

## 3. Between waves

A game is **between waves** when the waves' countdown is running (before wave 1
too) and the game isn't over. Then, from the waves' point of view, nothing is
moving on the map. Anything counted as alive by the wave (rats, thieves, bats,
raised enemies, slime halves) keeps the wave from ending, so none of those can
be in a save. This is the whole point: no enemy AI state ever needs to be
stored. What may still be there, and is saved:

- monster-camp and lair guards (their lost HP doesn't heal, so it is kept);
- wrathwoods (docs/enemies-design.md §15c: never part of a wave);
- corpses (with their age);
- every unit of the players wherever it is and whatever it does: villagers,
  marching or travelling units, units out of barracks against camp guards,
  earth elementals, caravans, the hero (also downed, also carrying loot).

Debug-spawned enemies aren't saved.

## 4. The player's view

### 4.1 Title screen

- The Singleplayer page gets **Continue** as its first button when a loadable
  single-player save exists. It loads the newest, autosave or manual (never a
  co-op save), and says under its label what it is. It is then the page's
  primary button (Enter); without a save, *Play* is.
- The Singleplayer page also gets **Load...** (the save list, §4.3).
- The main page has no Continue: continuing is a single-player thing.

### 4.2 In a game

- The settings dialog gets **Save...** and **Load...**:
  - *Save...* asks for a name (prefilled with map and wave, length limited by
    `SAVE.name_max`). A name in use asks first before overwriting. During a
    wave the button says why it is off.
  - *Load...* opens the save list; loading asks first, since progress since
    the last save is lost.
  - Co-op: only the host sees *Save...*; nobody sees *Load...* (a co-op save is
    resumed from the lobby, §6).
  - Neither in the tutorial. A game started from the map editor's Play has
    *Save...* only, and isn't autosaved.
- **Autosave** shows a small toast; a failed write shows the reason and the game
  goes on (a full disk mustn't end a game).
- **Back to title**, closing the app or sending it to the background save
  nothing: the end-of-wave autosave is what *Continue* goes on from.
- **Loaded:** the view starts on the player's village at default zoom and 1×;
  the log starts with a "Game loaded" line.
- **Defeat screen** (single player): **Load last save** loads the newest save
  of this game (its autosave or a later manual one).

### 4.3 The save list

A dialog like the map picker (`MapPicker`): the saves, newest first, each row
with name, kind, wave, map, difficulty, villages, play time and date. The
selected one shows the map preview with the villages marked, **only as far as
it was explored** (`SaveGame.seen`): the rest is black and no hidden object or
spawn is marked, so a save never gives the map away. Single player uses the
village's fog; co-op uses every village's fog together, so the players can
tell the villages apart (it shows each player what the others explored; fine
for co-op). Saves that can't be loaded (another version, broken file) are
listed greyed out with the reason, so they can still be deleted. The
single-player list shows single-player saves; the lobby's shows co-op saves.

## 5. Autosave

- Runs once after each wave is finished, on the *next* frame: the signal fires
  inside the last enemy's death or gate handler and a defeat may follow in the
  same call, so the game is checked again for "not over, still between waves".
- **One autosave file per game**, overwritten every wave. Every game gets a
  random id when it starts (`Game.game_id`), kept through loads, so a loaded
  game keeps writing its own autosave, and a game loaded from a manual save
  writes the autosave of the game it came from.
- Only the newest `SAVE.keep_autosaves` games' autosaves are kept, so
  abandoned games don't pile up. Manual saves are never deleted by the game.
- Not in the tutorial, the title backdrop, a game from the editor's Play, or
  on a co-op client.

## 6. Co-op: saving and resuming

### 6.1 Saving

The host saves like a single player. The file holds every village, whoever
plays it, also villages whose player is offline or that have fallen. Clients
only get a toast.

### 6.2 Resuming in the lobby

1. The host hosts a game as usual.
2. Next to **Map** the host has **Saved game...**, which lists the co-op
   saves. The pick shows on the Map button, which now reads *New game*.
   Difficulty and seed are fixed by the save, so those controls are off.
3. **Exactly as many players as the save has villages.** The lobby takes at
   most that many and *Start* needs exactly that many, all ready. Who the
   players are isn't checked, only their number (a friend can stand in).
   Picking a save with fewer villages than players present is refused, as
   with a map file.
4. **Village assignment:** each player row gets a *Village* button showing the
   saved village's name in its saved colour (the host cycles it; others only
   see it), like the slots of a map file: one player per village, taking
   someone's swaps the two. At the pick, a player whose name equals a saved
   village's gets that one, the others the free ones in join order. The host
   can play any of them.
5. Everyone sees the save's preview (every village's fog together, sent with
   the save's header; each village with its name, colour and assigned player).
6. *Start*: the host builds the game from the save (§8.4), then sends every
   client the setup and the **saved map** exactly as for a new game, so the
   client path needs no resume-specific code beyond the setup.

### 6.3 Who a village is

A resumed village **takes the name of the player who now plays it** and
**keeps its saved colour** (§12, decision 3). Names are unique in the lobby,
so village names stay unique; the colour a player picked in the lobby is not
used (the *Village* button shows the one the village will have).

Each village whose name changes is logged for everyone at the start. From
then on logs, labels and the statistics (also rows and samples from before
the save) use the new name. Rejoining works as before, by the player's (and so
the village's) name. The host logs the renames while building the game, before
anyone is connected, so each client logs them itself from the save's header.

## 7. What is saved

Everything durable; what an AI is doing *right now* (path, target, cooldowns,
timers, claims) is not saved and starts afresh from the saved position and
loads. The authoritative list is `SaveGame.capture` and its `_restore_*`
(§8.4); this section only states the rule and the exceptions worth knowing.

Saved, by part: the game (id, difficulty, map type and seed, clock, entity ids
and label counters, unlocks); the map as it is now (felled trees, cleared
decor) and its objects' state; each village's fog; the waves' counter and
countdown; wrathwoods and the per-village "forest remembers" state; corpses;
every village (resources, relics, fallen), its buildings with progress,
upgrades, repairs, tear-downs, HP and devastation, and the build queue in
order; villagers; military units; earth elementals of summoners on duty; the
hero; caravans; all of the statistics.

Starts afresh: speed, selection, input mode, camera, surveillance (recomputed
every few ticks), derived layers (pathing, warning lights), tree claims, the
waves' RNG, the event log's lines, builders' claims, the replicator, and
Settings outside the game (custom map, editor session).

Rules behind the table:
- **Entities keep their ids** (`nid`), so references between them are ids, not
  objects, and the co-op replication stays consistent.
- **A villager out in the field asks once what to do** from where it stands
  (`Civilian.resume_work`, `CivilianJob.resume`), rather than every job being
  serialised. The choice mirrors what the job would do next: loaded people go
  home with their load, others go on with their task, and with nothing to do
  they go home. A miner inside his mine stays there.
- **Units on a barracks sortie are back on their bench**; the barracks turn
  them out again if enemies are still in range. Elementals of a summoner out on
  a sortie crumble, as when it goes back to its bench.
- **The hero's Build / Explore / Gather job** asks what to do like a
  villager's (loot is carried home); her other modes and a camp to clear
  decide from where she stands.
- **Nothing of a running wave and no debug enemies.**

## 8. Files

### 8.1 Layout

One self-contained file per save, so a save can be copied, deleted or listed on its own and
never depends on a second file being in step with it. Autosaves and manual saves have
disjoint names (a manual slug never begins with "auto"), so one can never overwrite the other.
The header is uncompressed so the save list never unpacks a body. The body holds only plain
Dictionaries and Arrays, no objects, so a file can't carry code and the format doesn't depend
on class layouts. It is written to a temporary file and renamed over the old one, so a crash
mid-write leaves the previous save intact. It is written on the main thread because the web
build has no threads; the body is small enough that this costs no hitch.

### 8.3 Loading and refusing

A save naming a kind the game no longer has is refused, not half-loaded. `FORMAT` goes up
whenever the body's layout changes; old saves are then listed but refused. A migration layer
would cost more than losing old saves is worth (§2). Balance numbers in `Config` are not part
of the format: a save plays on with the new numbers (a unit's HP is clamped to its new
max).

A single-player save (one village) loads only from the single-player places (Continue,
Load...); a co-op save (two or more villages) only in the lobby.

### 8.4 How a game is built from a save

The order matters: the saved map is built like a map file's, but without camp guards; villages
are set up empty and then filled in dependency order; whoever is out in the field asks what to
do; statistics are restored, not started. The label counters (the numbers in "archer 5",
"tree 482") are set last, so entities created while restoring don't use up or reuse names.

Rule: restoring never goes through the gameplay mutators (`recruit`, `place`, `kill`,
`level_up`, `unlock`, `Economy.add`...), which spend, log, count statistics or assign workers.

## 11. Later (not in this design)

- Saving in the middle of a wave (left out on purpose, §12, decision 1).
- Export / import of save files (a file dialog, a download on the web, as for
  maps).
- Scenarios can start from a save-like start setup.

## 12. Decisions

1. **Only between waves.** A wave's enemies are many small AIs with paths,
   targets, spells in flight and mounts; storing them would make the format
   fragile and every new enemy kind a save-format change. Between waves none
   exists, so the format stays small and robust. A game left mid-wave goes on
   from the autosave at the end of the wave before.
2. **Manual saves by name**, several per game, the name prefilled.
3. **A resumed co-op village takes the new player's name and keeps its
   colour**, and the rename is logged.
4. **Continue** is on the Singleplayer page only and loads the newest
   single-player save, autosave or manual; never a co-op save.
5. **Autosave only at the end of each wave**: nothing extra on Back to title,
   closing the app or sending it to the background.
6. **The camera isn't saved:** every loaded or resumed game, co-op too,
   starts with each player's view on their village.
