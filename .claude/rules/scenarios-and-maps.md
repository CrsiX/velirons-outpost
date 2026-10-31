---
paths:
  - "scripts/scenarios/**"
  - "data/maps/**"
  - "tools/*map*.gd"
  - "tools/citadel_map.gd"
  - "tools/abbey_map.gd"
  - "scripts/editor/**"
  - "tests/scenario_bot.*"
  - "tests/editor_bot.*"
  - "tests/map_format_bot.*"
---

# Scenarios, maps and the map editor

Outline and reasoning: `docs/scenarios-design.md` (index of the campaign docs; the system itself is `docs/scenario-system-design.md`), `docs/map-editor-design.md`, `docs/story-design.md`.

## Where things live
- A campaign scenario is one file, `scripts/scenarios/scenario_<n>.gd` (a `Scenario`), listed in `Campaign.SCENARIOS`; `ScenarioRunner` plays it. **Its own content and numbers (baseline, waves, texts, cards, objectives) go in that file, not in `config.gd`.** Engine-wide tunables still go in `config.gd`.
- A scenario is a single-player game: no saving, its own map file, intro and outro cutscenes, cards, objectives. Progress is stored by title in `user://campaign.json`; release builds only open unlocked scenarios, debug builds open all.
- Maps are JSON files (`data/maps/` built in, `user://maps` the user's). The format is canonical and readable; export is strict, import tolerant but refuses anything outside the format. A format change bumps the version in `MapJson`, and older files get defaults.
- The scenarios' maps: `homecoming.json` for 1 and 2, `wardline.json` for 3 and 10, `guildtown.json` for 4, `old_fort.json` for 5, `battlefield.json` for 6, `refuge.json` for 7, `pale_court.json` for 8, `drowned_abbey.json` for 9, `capital.json` for 11. Some are laid out by tools (`citadel_map.gd`, `abbey_map.gd`, `make_scenario_map.gd`), not generated.

## Hand-edited maps (important)
The user edits scenario maps in the map editor. **Never regenerate those** (`tools/make_scenario_map.gd -- <n> --force`), and change them only by small, targeted edits to the file, never by rerunning the tool. Hand-edited so far: `homecoming.json`, `old_fort.json`, `drowned_abbey.json`, `wardline.json`. The edit-handmade-map skill has the checklist of code tied to each. In short:
- `wardline.json` holds `homecoming.json` tile for tile as its inner area: an edit to one needs the same edit in the other.
- Code that depends on specific tiles (tents, roads' map-edge ends, church and quay tiles, spawns, the number and place of ruins, prebuilt offsets from the village centre) must be rechecked when the user edits a map; scenario_bot has layout checks that name what is assumed.

## Map editor
- Maps of every supported size, isometric or top-down; every edit is undoable. Live checks: errors keep a map from being played, some only warn.
- *Play* tries the map; the settings then offer a way back to the editor.
- A map file can be played in single player and co-op. `MapData.for_game` turns villages nobody plays into ownerless ruins.
- In portrait the panels are a bottom sheet, like the game's dock.
