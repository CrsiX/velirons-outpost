# Veliron's Outpost

> **For Claude, not for humans.** Project reference for sessions that start without context. `README.md` is the user's: never read it for facts or touch it.

A dark-fantasy isometric village-defense game in Godot 4.7 (GL Compatibility renderer) for Web, Linux, Android and Windows, with mouse, keyboard and touch. The last outpost of Veliron sits on a generated map; monsters come down the roads from the map edge towards the village. Villagers work on their own; the player decides where things get built and who mans the towers. Modes: single player, a story campaign (eleven scenarios), LAN co-op (up to eight villages), a tutorial, a map editor, and a library of reference pages. The simulation runs in grid space; `Iso` projects it to the screen.

## Single source of truth (read first)

- **The code is the source of truth for every number and concrete value.** Balance numbers and tunables live in `scripts/core/config.gd`, documented there; a campaign scenario's own content and numbers live in its own `scripts/scenarios/scenario_<n>.gd` (the user doesn't want a bloated config.gd).
- **Never copy a number, stat table or schema into CLAUDE.md, `.claude/rules/`, `docs/` or a skill.** Point at the symbol instead (`Config.ENEMIES.goblin`). Docs explain *why*, never *what*.
- Where code and a doc disagree, the code wins; fix the doc in the same change.
- New design work goes into a `docs/*-design.md` first when it is big, as reasoning.

## Standing rules from the user

- Never modify anything in `exports/` (build outputs). Don't touch `README.md`.
- New player units: ask the user how each one is unlocked before building it. Work out a plan before adding new units.
- Every tunable goes into `config.gd` (see above), never hard-coded in scripts.
- Hand-edited scenario maps are never regenerated; see `.claude/rules/scenarios-and-maps.md` (and the edit-handmade-map skill).
- Run test bots one at a time, never in parallel.
- The memory directory (`~/.claude/projects/.../memory/`) can't be written (sandbox), so lasting notes go in the matching rules file or doc, only for very new concepts here.
- Keep this file under 150 lines; prefer rules or docs over adding here.
- Warnings are errors in this project (see `.claude/rules/gdscript-gotchas.md`).
- A change that alters a rule, a control, the code layout, a test or a working fact updates the matching place **in the same change**: this file for global facts, the matching `.claude/rules/*.md` for area rules, the matching doc for design reasoning, `docs/GLOSSARY.md` for terms. Write what is true now, not change history.

## Where things are documented

- `docs/GLOSSARY.md`: game terms (one line each; read when a term in code or docs is unfamiliar).
- `.claude/rules/*.md`: area rules, loaded when you touch matching files: gdscript-gotchas, tests-and-bots, art, scenarios-and-maps, military, enemies, village-hero, ui, multiplayer-save, web-build.
- `docs/*-design.md`: the reasoning behind each area. Keep the matching one up to date with a change:
  - `enemies-design` (waves, difficulty, damage categories, every enemy kind), `hero-design`, `village-design` (resources, villagers, buildings, tear-down, warnings), `military-design` (units, barracks, specialising), `acolyte-design` (holy damage), `world-design` (map generator core and an index; split into `world-terrain-design` (zones, water, mountains), `world-roads-design`, `world-objects-design` (special objects, water monsters' spawns); section numbers are kept, so "world-design §9.4" resolves through the index), `multiplayer-design`, `tutorial-design`, `ui-design` (title, HUD, dock, placing, dialogs, camera, log), `statistics-design`, `map-editor-design` (editor, JSON map format, maps from files), `aquatic-design` (water monsters), `save-design`, `siege-design` (building HP, repairs, enemies breaking in), `balance-bot-design`.
  - `story-design` (premise, characters, factions) and `scenarios-design` (campaign core and index, with a map from old section numbers to files; the scenarios themselves are in `scenarios-1-3-design`, `scenarios-4-6-design`, `scenarios-7-9-design`, `scenarios-10-11-design`, and how the scenario system is built in `scenario-system-design`).
- Skills (procedures): run-bots, ui-screenshots, rebake-title-maps, edit-handmade-map, balance-sweep.

## Environment

- **Godot** 4.7.2 is in `bin/Godot_v4.7.2-stable_linux.x86_64` (the sandbox can't download it). **gdlint** (gdtoolkit) is in `venv/`; run `GDLINT=venv/bin/gdlint tests/lint.sh` with `HOME=$TMPDIR` (it writes a cache under `~/.cache`). If `venv/bin/gdlint` "cannot execute" (the venv's scripts name the project's old folder), point `GDLINT` at a two-line script running `venv/bin/python3 -m gdtoolkit.linter "$@"`.
- The sandbox can't write `~/.local/share/godot`: run Godot through the `gd` wrapper described in the run-bots skill.
- Headless runs can't render. An X display exists for screenshots (ui-screenshots skill; needs the sandbox off, which the user allowed for this).
- This sandbox runs GDScript roughly 10x slower than a normal PC: judge timings relatively.
- After adding a `class_name`, import once (`gd --headless --path . --import`) or other scripts won't find it. After changing the map generator or the title scenes' map type / seed, rebake the title maps (rebake-title-maps skill).

## Test commands

Each bot is a scene: `gd --headless --path . --fixed-fps 60 res://tests/<bot>.tscn`. Run them in a background shell, one at a time, with `CI=true`. The run-bots skill has the exact command and the filter to use.

Bots: `sim_bot` (single player end to end), `military_bot`, `rat_bot`, `hud_bot`, `enemy_bot`, `aqua_bot`, `siege_bot`, `world_bot`, `tutorial_bot`, `scenario_bot` (`-- --only=N` for one scenario), `library_bot`, `stats_bot`, `save_bot`, `title_bot`, `build_bot`, `coop_bot`, `mapgen_bot`, `map_format_bot`, `editor_bot`, and the two-process net test `tests/run_net_test.sh <gd>`. `tests/run_all.sh` runs every bot in sequence. Lint: `tests/lint.sh`. Art: `python3 tools/gen_art.py`. Balancing bot: balance-sweep skill.

**Baseline:** all bots pass and lint is clean. CI allows no failures, so a fix that breaks a bot is fixed in the same change. The one local exception is title_bot's frame-time check (too tight for this slow sandbox; it passes with `CI` set). Anything else failing is new.

## Code layout (by directory; look inside for the rest)

```
scripts/
  core/       config.gd (all balance numbers), settings (autoload), screen_layout ("Layout" autoload), iso, art + generated art_manifest, sfx, build_info
  world/      map data and generator (gen/), pathing, fog, layers, objects/ (treasure, camp, unlock site, ruined tower, lair, mine)
  systems/    village (one player's village; economy, population, construction, army, hero, event log), commands (every action as a checked command), waves, corpses, stats, siege, aqua, wrathwoods, save_game, game_log
  buildings/  building base (HP, devastation, repairs) and every kind
  units/      unit -> civilian -> roles; hero; soldier and military_unit (+ military/ behaviours); enemy (+ enemies/ behaviours); jobs/
  tutorial/   the guided first game
  scenarios/  the campaign: scenario base, scenario_<n>, campaign, scenario_runner, cutscene, journal, scenario helpers
  ui/         title, campaign map, menus, hud, tactical map, library, statistics, camera, theme
  net/        Net autoload (ENet session, lobby), lan_discovery, replicator
  editor/     the map editor
  game.gd     composition root: villages, command entry, entity ids, speed, selection, raids, defeat; `clock`
tools/        gen_art.py, balancing bot (balance_bot.*, balance/), map tools, title-map baker, ui_shots, export/stamp scripts, explore_trace
data/maps/    built-in map files; data/title_maps/ baked backdrop maps
tests/        the bots, run_all.sh, lint.sh, run_net_test.sh
docs/         design docs and the glossary
scenes/       main.tscn, title.tscn
.github/workflows/  CI: tests, bots (lint + one job per bot), balance (manual), build, pages
```

## Cross-cutting facts

- `game.gd` modes: `tutorial_mode`, `scenario`, `backdrop`, `networked`; a game can be `loaded`. A new game-wide rule may need to respect all of them.
- Every player action is a command (`Commands`) so co-op clients work; the host simulates.
- Difficulty scales enemy strength and loot only (`DIFFICULTY_SCALED`), never cooldowns or ranges.
- Game speed is `Engine.time_scale`; real-time code must not be scaled by it.
- Save state: a field that must survive a load needs a `SaveGame.capture` / restore line; a layout change bumps `SaveGame.FORMAT`.
- The game log file (`GameLog`) goes in `user://game_logs`, never a folder named `logs` (Godot's own). It isn't written on the web, in the tutorial, the title backdrop or for a co-op client.
- The debug build adds a *Debug...* page to the settings (a debug export, the editor or the `godot` binary, so the bots too; never a release export).
- Known, not yet looked into: app start-up spends most of its time compiling scripts; the web build has no threads.
