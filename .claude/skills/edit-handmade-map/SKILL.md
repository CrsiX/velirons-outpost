---
name: edit-handmade-map
description: Checklist for when the user hand-edited a scenario map (homecoming, old_fort, drowned_abbey, wardline) or you must change one. Use before touching data/maps/*.json.
---

# Hand-edited maps

Never regenerate these (`tools/make_scenario_map.gd -- <n> --force`) and never rerun a map tool over them. Make small, targeted edits to the file only. Hand-edited: `data/maps/homecoming.json` (scenarios 1, 2), `old_fort.json` (5), `drowned_abbey.json` (9), `wardline.json` (3, 10).

After the user edits one, check the code tied to it still fits:
- **homecoming (1, 2):** Brenna's start and tent (`hero_start`, `tent_tile`) by the south road; `SOUTH_ROAD` (its end at the map edge: Pell's cart) and `LAKE_ROAD` (2's stranger); exactly one ruined watchtower for 2's claim / restore cards; scenario_bot's map checks (size, name, one ruin). `wardline.json` holds homecoming tile for tile as its inner 50x50 area, at offset (12, 12) in the 75x75 map: an edit to one needs the same edit in the other.
- **wardline (3, 10):** the six ruined watchtowers and the ruined barracks along the border road, the home ruin by the village (both scenarios start it restored; the prebuilt `"ruin"` numbers count nearest the village first and scenario 10's setup names each), scenario 3's journal pages (one per tower) and its talks, `_north_spawn` on the border road (caravans, Halvard), scenario_bot's checks (ruins all on the border road, home ruin restored).
- **old_fort (5):** `SIGMUND_TENT`, the prebuilt offsets from the village centre, the evidence picked by treasure tier, scenario_bot's layout checks.
- **drowned_abbey (9):** `CHURCH_TILE`, the prebuilt offsets, the quay below the south gate, `SECOND_PIER`, `BEACON_OFFSET`, the abbey's camp (its first vampire is the Fallen Abbot), the island's ruins, `_legion_spawn` on the north edge, scenario_bot's checks (one straight bridge onto the island and no other way, two piers, scenery tiles kept free).

Then run `scenario_bot` (`-- --only=N`) and `map_format_bot` via the run-bots skill. Exact constants live in the scenario files; read them there.
