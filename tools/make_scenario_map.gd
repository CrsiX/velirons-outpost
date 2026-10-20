extends Node
## Makes a scenario's starting map (docs/scenarios-design.md) and writes it as
## a map file (data/maps/), to be edited by hand in the map editor afterwards
## (open it there, change it, Export over the same file). Run once per
## scenario; it never overwrites a map unless asked to:
##   godot --headless --path . res://tools/make_scenario_map.tscn -- <scenario number> [--force]
##
## What each scenario's map starts from: a generated map (type, seed), with
## the object kinds in "drop" taken out, and at most "ruins" ruined
## watchtowers left (the ones nearest the village); or ("grow") another
## scenario's map file, grown to a bigger size: it sits in the middle, a
## generated map (type, seed) fills the ring around it (its roads, villages
## and objects left out), and the home roads run on straight to the new edge.
## "add_ruins": ruins placed by a road, {"edge": the map edge its road comes
## from ("north", "south", "west", "east"), "at": road tiles from the gate,
## "building": "tower" or "barracks"}. "add_sites": unit-unlock sites placed
## the same way, {"edge", "at", "site": a Config.UNLOCK_SITES key}.
## "add_lairs": monster lairs by a road, {"edge", "at", "art": a lair art},
## their door on the road. "add_camps": a treasure by a road with a camp
## beside it, {"edge", "at", "treasure", "reward", "monsters": [kinds]}.
## "island": a road's stretch turned into an island in a lake ("abbey"),
## {"edge", "at": its middle, road tiles from the gate, "land": its radius,
## "water": the lake's, "treasure", "monsters": the camp beside it}: the road
## crosses the lake on bridges, a water spawn on the far side.
## "city": the capital (scenario 11), {"radius": the city's around the
## village, "houses": the share of a block's tiles with a house, "ruined": the
## share of those in ruins, "steppe": how many steppe spots with trees,
## "throne": {"edge", "from_edge": road tiles from the map edge}}: every open
## tile city (near the village and the throne hall) or ash land, the trees
## gone; houses (mountain tiles with a house) in blocks between lanes, off the
## roads and away from the walls; the throne hall (a 3x3 landmark) by a road.
## Maps the user has edited by hand (CLAUDE.md): never run with --force for
## them. So far: 5 (old_fort.json).
## "citadel": scenario 5's fort in a mountain pass, laid out by citadel_map.gd
## rather than generated ({"seed"}); it prints where Sigmund's tent goes
## (scenario_5.gd's SIGMUND_TENT).

const CitadelMap := preload("res://tools/citadel_map.gd")

const MAPS := {
	1: {"map_type": "highlands", "seed": 1337, "name": "Homecoming",
		"description": "Scenarios 1 and 2: the home village. Three roads lead in; Brenna's tent stands by the north road.",
		"drop": ["unlock", "lair"], "ruins": 1},
	3: {"grow": {"from": 1, "size": 100, "map_type": "highlands", "seed": 4711}, "name": "The Wardline",
		"description": "Scenario 3: the home map grown, the road north to the border lined with the old Wardline's ruins.",
		"add_ruins": [
			{"edge": "north", "at": 13, "building": "tower"},
			{"edge": "north", "at": 25, "building": "tower"},
			{"edge": "north", "at": 37, "building": "tower"},
			{"edge": "north", "at": 46, "building": "barracks"},
		]},
	4: {"map_type": "coast", "seed": 42, "name": "The Guild Town",
		"description": "Scenario 4: the Silver Thread Guild's walled market town on the coast, its harbour on the inlet beside the walls.",
		"drop": ["unlock", "lair"], "ruins": 0},
	5: {"citadel": {"seed": 11}, "name": "The Old Fort",
		"description": "Scenario 5: Brenna's old fort, a citadel filling the only pass through the mountains that split the land. Forest and wilderness to the north, meadow and steppe to the south.",
		"ruins": 0},
	6: {"map_type": "desert", "seed": 606, "name": "The Field of Bones",
		"description": "Scenario 6: a village of survivors on the dry plain where the armies met, its ruined chapel by the road.",
		"drop": ["unlock", "lair"], "ruins": 0,
		"add_sites": [{"edge": "east", "at": 9, "site": "chapel"}]},
	7: {"map_type": "temperate", "seed": 707, "name": "The Refuge",
		"description": "Scenario 7: Fiona's hidden valley in the forest, with the druids' stone circle and the court mages' tower.",
		"drop": ["unlock", "lair"], "ruins": 0,
		"add_sites": [{"edge": "north", "at": 11, "site": "stone_circle"}, {"edge": "west", "at": 8, "site": "mage_tower"}]},
	8: {"map_type": "volcanic", "seed": 808, "name": "The Pale Court",
		"description": "Scenario 8: a camp in the burned capital's outskirts. Three crypts lie under the old court, and the Legion holds its gates.",
		"drop": ["unlock", "lair", "camp"], "ruins": 0,
		"add_lairs": [{"edge": "north", "at": 11, "art": "lair_crypt"}, {"edge": "south", "at": 17, "art": "lair_crypt_big"}, {"edge": "west", "at": 24, "art": "lair_crypt_big"}],
		"add_camps": [{"edge": "west", "at": 12, "treasure": "chest", "reward": {"gold": 140}, "monsters": ["legion_footman", "legion_footman", "legion_archer", "legion_banner"]},
			{"edge": "south", "at": 28, "treasure": "chest", "reward": {"gold": 180, "materials": 60}, "monsters": ["legion_footman", "legion_guard", "legion_archer", "legion_archer", "legion_banner"]}]},
	9: {"map_type": "coast", "seed": 909, "name": "The Drowned Abbey",
		"description": "Scenario 9: a pilgrims' ferry village on a drowned shore. Out in the lake the church's old abbey stands half-sunk on its island.",
		"drop": ["unlock", "lair"], "ruins": 0,
		"island": {"edge": "north", "at": 28, "land": 4.2, "water": 9.5, "treasure": "abbey", "monsters": ["vampire", "vampire", "skeleton"]}},
	11: {"map_type": "temperate", "seed": 1111, "name": "The Capital",
		"description": "Scenario 11: the final camp in the capital's streets, by the throne hall. Cobbles and ash, a few trees, no fields.",
		"drop": ["unlock", "lair", "camp", "mine"], "ruins": 0,
		"city": {"radius": 24.0, "houses": 0.62, "ruined": 0.35, "steppe": 4, "throne": {"edge": "north", "from_edge": 3}}},
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if not args.is_empty() else 0
	if not MAPS.has(n):
		printerr("usage: -- <scenario number: %s> [--force]" % ", ".join(MAPS.keys().map(func(k: int) -> String: return str(k))))
		get_tree().quit(2)
		return
	var path := Campaign.scenario(n).map_path
	if FileAccess.file_exists(path) and not args.has("--force"):
		printerr("%s exists (it may have been edited by hand); add --force to make it again" % path)
		get_tree().quit(1)
		return
	var spec: Dictionary = MAPS[n]
	var m: MapData
	var gen_seed = null
	if spec.has("citadel"):
		var made := CitadelMap.make(int(spec["citadel"]["seed"]))
		m = made["map"]
		gen_seed = int(spec["citadel"]["seed"])
		print("Sigmund's tent: %s" % made["tent"])
	elif spec.has("grow"):
		var g: Dictionary = spec["grow"]
		var r := MapLibrary.load_file(Campaign.scenario(int(g["from"])).map_path)
		if r["map"] == null:
			printerr("the map to grow doesn't read: %s" % "; ".join(r["errors"]))
			get_tree().quit(1)
			return
		m = grow(r["map"], MapGenerator.generate(int(g["seed"]), 1, str(g["map_type"]), int(g["size"])))
	else:
		m = MapGenerator.generate(int(spec["seed"]), 1, str(spec["map_type"]))
		_drop_objects(m, spec["drop"], int(spec["ruins"]))
		gen_seed = int(spec["seed"])
	for ru in spec.get("add_ruins", []):
		var err := _add_ruin(m, ru)
		if err != "":
			printerr("ruin %s: %s" % [str(ru), err])
	for si in spec.get("add_sites", []):
		var err := _add_site(m, si)
		if err != "":
			printerr("site %s: %s" % [str(si), err])
	for la in spec.get("add_lairs", []):
		var err := _add_lair(m, la)
		if err != "":
			printerr("lair %s: %s" % [str(la), err])
	for ca in spec.get("add_camps", []):
		var err := _add_camp(m, ca)
		if err != "":
			printerr("camp %s: %s" % [str(ca), err])
	if spec.has("city"):
		var err := _city(m, spec["city"])
		if err != "":
			printerr("city: %s" % err)
	if spec.has("island"):
		var err := _island(m, spec["island"])
		if err != "":
			printerr("island: %s" % err)
	m.meta = {"name": spec["name"], "author": "", "description": spec["description"],
		"origin": {"generator_seed": gen_seed, "edited": true, "game_version": MapJson.game_version()}}
	var text := MapJson.write(m)
	var back := MapJson.read(text)
	if not (back["errors"] as Array).is_empty():
		printerr("the map doesn't read back: %s" % "; ".join(back["errors"]))
		get_tree().quit(1)
		return
	for pr in MapChecks.run(back["map"]):
		print("  %s: %s" % [pr["level"], pr["text"]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("%s: written (%dx%d, %d objects)" % [path, m.size, m.size, m.objects.size()])
	get_tree().quit()


## Takes out every object of the kinds in `drop`, and all but the `ruins`
## ruined watchtowers nearest the village; camps keep pointing at their treasure.
func _drop_objects(m: MapData, drop: Array, ruins: int) -> void:
	var center: Vector2i = m.villages[0]["center"]
	var ruin_ids: Array = []
	for i in m.objects.size():
		if m.objects[i]["kind"] == "ruin":
			ruin_ids.append(i)
	ruin_ids.sort_custom(func(a: int, b: int) -> bool:
		return Vector2(m.objects[a]["tile"]).distance_to(Vector2(center)) < Vector2(m.objects[b]["tile"]).distance_to(Vector2(center)))
	var keep: Array[Dictionary] = []
	var new_index := {}
	for i in m.objects.size():
		var o: Dictionary = m.objects[i]
		if drop.has(o["kind"]) or (o["kind"] == "ruin" and ruin_ids.find(i) >= ruins):
			continue
		new_index[i] = keep.size()
		keep.append(o)
	for o in keep:
		if o["kind"] == "camp":
			o["guards"] = new_index[int(o["guards"])]
		elif o["kind"] == "treasure" and int(o.get("guard", -1)) >= 0:
			o["guard"] = new_index.get(int(o["guard"]), -1)
	m.objects = keep


# --- growing a map ---------------------------------------------------------------------------

## `home` in the middle of a map of `ring`'s size; `ring` (generated) around
## it without its roads, villages and objects; the home roads that ended at
## the old edge run on straight to the new one (bridges, fords).
func grow(home: MapData, ring: MapData) -> MapData:
	var size := ring.size
	var off := Vector2i((size - home.size) / 2, (size - home.size) / 2)
	var m := MapData.new(size)
	m.map_type = home.map_type
	for y in size:
		for x in size:
			var t := Vector2i(x, y)
			var h := t - off
			var i := m.index(t)
			if home.in_bounds(h):
				var hi := home.index(h)
				m.terrain[i] = home.terrain[hi]
				m.zones[i] = home.zones[hi]
				for pair in [[home.props, m.props], [home.decor, m.decor], [home.crossings, m.crossings], [home.beaches, m.beaches]]:
					if (pair[0] as Dictionary).has(h):
						pair[1][t] = pair[0][h]
				continue
			var v := ring.terrain[i]
			if v == MapData.Terrain.ROAD:
				v = int(ring.crossings[t][1]) if ring.crossings.has(t) else MapData.Terrain.GRASS
			m.terrain[i] = v
			m.zones[i] = ring.zones[i]
			for pair in [[ring.props, m.props], [ring.decor, m.decor], [ring.beaches, m.beaches]]:
				if (pair[0] as Dictionary).has(t):
					pair[1][t] = pair[0][t]
	for vc in home.volcanoes:
		m.volcanoes.append(vc + off)
	for vc in ring.volcanoes:
		if not Rect2i(off - Vector2i(2, 2), Vector2i(home.size + 4, home.size + 4)).has_point(vc):
			m.volcanoes.append(vc)
	for ws in home.water_spawns:
		m.water_spawns.append(ws + off)
	for p in home.village_layout:
		var q: Dictionary = p.duplicate()
		q["tile"] = (p["tile"] as Vector2i) + off
		m.village_layout.append(q)
	var spawns: Array[Vector2i] = []
	for sp in home.edge_spawns:
		spawns.append(_extend_road(m, sp + off, _outward(home, sp)))
	for v in home.villages:
		m.villages.append({"center": (v["center"] as Vector2i) + off, "home_spawns": spawns})
	for o in home.objects:
		var q: Dictionary = o.duplicate(true)
		q["tile"] = (o["tile"] as Vector2i) + off
		if q.has("front"):
			q["front"] = (o["front"] as Vector2i) + off
		m.objects.append(q)
	m.derive()
	return m


## The way out of `home` from its edge tile `t`.
func _outward(home: MapData, t: Vector2i) -> Vector2i:
	if t.y == 0:
		return Vector2i(0, -1)
	if t.y == home.size - 1:
		return Vector2i(0, 1)
	if t.x == 0:
		return Vector2i(-1, 0)
	return Vector2i(1, 0)


## Road from `t` straight along `dir` to the map's edge; returns the edge tile.
func _extend_road(m: MapData, t: Vector2i, dir: Vector2i) -> Vector2i:
	var at := t
	while m.in_bounds(at + dir):
		at += dir
		var v := m.get_terrain(at)
		if v == MapData.Terrain.WATER or v == MapData.Terrain.LAVA:
			var style := "charred" if v == MapData.Terrain.LAVA else str(Config.BRIDGE_STYLES.get(m.zone(at), "timber"))
			m.crossings[at] = ["bridge_%s_%s" % [style, "x" if dir.x != 0 else "y"], v]
		elif v == MapData.Terrain.SHALLOW:
			m.crossings[at] = ["tile_ford", v]
		m.set_terrain(at, MapData.Terrain.ROAD)
		m.props.erase(at)
		m.decor.erase(at)
	return at


## A ruin by the road from map edge `ru.edge`, `ru.at` road tiles from the
## village's gate: on the nearest open land next to that road tile. "" or why not.
func _add_ruin(m: MapData, ru: Dictionary) -> String:
	var size := 2 if str(ru["building"]) == "barracks" else 1
	var res = _add_by_road(m, ru, "ruin", size)
	if res is String:
		return res
	m.objects[res]["building"] = str(ru["building"])
	m.objects[res]["art"] = MapJson.object_art(m.objects[res])
	return ""


## A unit-unlock site by a road, as a ruin (_add_ruin). "" or why not.
func _add_site(m: MapData, si: Dictionary) -> String:
	var res = _add_by_road(m, si, "unlock", 1)
	if res is String:
		return res
	var site := str(si["site"])
	var o: Dictionary = m.objects[res]
	o["site"] = site
	o["unlocks"] = Config.UNLOCK_SITES[site]["unlocks"]
	o["wave"] = int(Config.UNLOCK_SITES[site]["wave"])
	o["art"] = MapJson.object_art(o)
	return ""


## A monster lair by a road, its door on the road. "" or why not.
func _add_lair(m: MapData, la: Dictionary) -> String:
	var art := str(la["art"])
	var res = _add_by_road(m, la, "lair", 2 if art.ends_with("_big") else 1, true)
	if res is String:
		return res
	m.objects[res]["art"] = art
	return ""


## A treasure by a road and a camp guarding it, beside it. "" or why not.
func _add_camp(m: MapData, ca: Dictionary) -> String:
	var res = _add_by_road(m, ca, "treasure", 1)
	if res is String:
		return res
	var tr: Dictionary = m.objects[res]
	tr["treasure"] = str(ca["treasure"])
	tr["tier"] = 3
	tr["reward"] = ca.get("reward", {"gold": 100})
	tr["art"] = MapJson.object_art(tr)
	return _camp_by(m, res, ca["monsters"])


## A camp with `monsters` on open land next to treasure `ti`. "" or why not.
func _camp_by(m: MapData, ti: int, monsters: Array) -> String:
	var t0: Vector2i = m.objects[ti]["tile"]
	var size := int(m.objects[ti].get("size", 1))
	var free := EditorTools.MapCheckFree.new(m)
	for r in [2, 3, 4]:
		for dy in range(-r, r + size):
			for dx in range(-r, r + size):
				var t := t0 + Vector2i(dx, dy)
				if not _open(m, free, [t]) or MapData.neighbors4(t).any(func(n: Vector2i) -> bool: return m.is_road(n)) or not _near_road(m, t, 8):
					continue
				var o := {"kind": "camp", "tile": t, "size": 1, "tier": 3, "guards": ti, "monsters": monsters.duplicate()}
				o["art"] = MapJson.object_art(o)
				m.objects.append(o)
				m.objects[ti]["guard"] = m.objects.size() - 1
				return ""
	return "no open land for the camp"


## A road within `steps` walking steps of `t` (over open land).
func _near_road(m: MapData, t: Vector2i, steps: int) -> bool:
	var seen := {t: 0}
	var q: Array[Vector2i] = [t]
	var i := 0
	while i < q.size():
		var c := q[i]
		i += 1
		if m.is_road(c):
			return true
		if int(seen[c]) >= steps:
			continue
		for n in MapData.neighbors4(c):
			if m.in_bounds(n) and not seen.has(n) and m.is_passable(n) and not m.props.has(n):
				seen[n] = int(seen[c]) + 1
				q.append(n)
	return false


## The road from `isl.edge` through an island in a lake, `isl.at` road tiles
## from the gate: open land within `land` of that road tile, deep water out to
## `water` (bridges where the roads cross it, a shallow rim round the land),
## a treasure on the island guarded by a camp, a water spawn on the lake. "" or why not.
func _island(m: MapData, isl: Dictionary) -> String:
	var road := _road_from(m, str(isl["edge"]))
	if road.is_empty():
		return "no road from that edge"
	var c := road[clampi(road.size() - 1 - int(isl["at"]), 0, road.size() - 1)]
	var land := float(isl["land"])
	var water := float(isl["water"])
	var r := ceili(water)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := c + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(c))
			if not m.in_bounds(t) or d > water or m.in_village(t):
				continue
			m.props.erase(t)
			m.decor.erase(t)
			m.beaches.erase(t)
			if d <= land:
				if not m.is_road(t):
					m.set_terrain(t, MapData.Terrain.GRASS)
					m.set_zone(t, "meadow")
				continue
			var under := MapData.Terrain.SHALLOW if d <= land + 0.9 else MapData.Terrain.WATER
			if m.is_road(t):
				var along_x := m.is_road(t + Vector2i(1, 0)) or m.is_road(t - Vector2i(1, 0))
				m.crossings[t] = ["bridge_stone_%s" % ("x" if along_x else "y"), under] if under == MapData.Terrain.WATER else ["tile_ford", under]
			else:
				m.set_terrain(t, under)
	m.derive()
	# The treasure on the island, off the road; its camp beside it.
	var free := EditorTools.MapCheckFree.new(m)
	var spot := Vector2i(-1, -1)
	var best := INF
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t := c + Vector2i(dx, dy)
			var fp := Building.footprint(t, 2)
			if fp.any(func(q: Vector2i) -> bool: return Vector2(q).distance_to(Vector2(c)) > land - 0.6 or MapData.neighbors4(q).any(func(n: Vector2i) -> bool: return m.is_road(n))):
				continue
			if not _open(m, free, fp):
				continue
			var dd := Vector2(t).distance_to(Vector2(c))
			if dd < best:
				best = dd
				spot = t
	if spot == Vector2i(-1, -1):
		return "no room for the treasure on the island"
	var res = EditorTools.add_object(m, "treasure", spot, 2)
	if res is String:
		return res
	var tr: Dictionary = m.objects[res]
	tr["treasure"] = str(isl["treasure"])
	tr["tier"] = 3
	tr["reward"] = {}
	tr["art"] = MapJson.object_art(tr)
	var err := _camp_by(m, res, isl["monsters"])
	if err != "":
		return err
	# A water spawn on the lake, on the side away from the village.
	var vc := Vector2(m.villages[0]["center"])
	var far := Vector2i(-1, -1)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := c + Vector2i(dx, dy)
			if m.is_deep(t) and (far.x < 0 or Vector2(t).distance_to(vc) > Vector2(far).distance_to(vc)):
				far = t
	if far.x >= 0:
		m.water_spawns.append(far)
	return ""


## The capital (MAPS' "city"). "" or why not.
func _city(m: MapData, ci: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1111
	var vc := Vector2(m.villages[0]["center"])
	var vrect: Rect2i = m.villages[0]["rect"]
	# The throne hall first, by its road near the map edge.
	var th: Dictionary = ci["throne"]
	var road := _road_from(m, str(th["edge"]))
	if road.is_empty():
		return "no road from the throne hall's edge"
	var hall := Vector2i(-1, -1)
	var k := int(th["from_edge"])
	for r in [2, 3, 4, 5]:
		if hall.x >= 0:
			break
		for dy in range(-r - 2, r + 1):
			for dx in range(-r - 2, r + 1):
				var t: Vector2i = road[k] + Vector2i(dx, dy)
				var fp := Building.footprint(t, 3)
				if fp.any(func(q: Vector2i) -> bool: return not m.in_bounds(q) or m.is_road(q) or m.in_village(q) or not (m.get_terrain(q) in [MapData.Terrain.GRASS, MapData.Terrain.FOREST, MapData.Terrain.DESERT])):
					continue
				if not fp.any(func(q: Vector2i) -> bool: return MapData.neighbors4(q).any(func(n: Vector2i) -> bool: return m.is_road(n))):
					continue
				hall = t
				break
			if hall.x >= 0:
				break
	if hall.x < 0:
		return "no room for the throne hall"
	for q in Building.footprint(hall, 3):
		m.set_terrain(q, MapData.Terrain.GRASS)
		m.props.erase(q)
	var res = EditorTools.add_object(m, "treasure", hall, 3)
	if res is String:
		return "throne hall: " + res
	var tr: Dictionary = m.objects[res]
	tr["treasure"] = "throne_hall"
	tr["tier"] = 3
	tr["reward"] = {}
	tr["art"] = MapJson.object_art(tr)
	var hc := Vector2(hall) + Vector2(1, 1)
	# Tiles kept open: the objects and a ring round them.
	var keep := {}
	for o in m.objects:
		var sz := int(o.get("size", 1))
		for dy in range(-2, sz + 2):
			for dx in range(-2, sz + 2):
				keep[(o["tile"] as Vector2i) + Vector2i(dx, dy)] = true
	# Every open tile: city or ash, no trees, no decor.
	var radius := float(ci["radius"])
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.in_village(t) or m.is_road(t) or m.crossings.has(t):
				continue
			var v := m.get_terrain(t)
			var city := Vector2(t).distance_to(vc) <= radius or Vector2(t).distance_to(hc) <= 9.0
			if v == MapData.Terrain.MOUNTAIN and city and not MapTidy.in_volcano(m, t):
				v = MapData.Terrain.GRASS  # (the city's ground is level: its houses stand there)
			if v != MapData.Terrain.GRASS and v != MapData.Terrain.FOREST and v != MapData.Terrain.DESERT:
				continue
			m.set_zone(t, "city" if city else "ash")
			m.set_terrain(t, MapData.Terrain.GRASS)
			m.props.erase(t)
			m.decor.erase(t)
			m.beaches.erase(t)
	# The steppe spots, with trees to cut.
	var spots := 0
	for i in 400:
		if spots >= int(ci["steppe"]):
			break
		var c := Vector2i(rng.randi_range(4, m.size - 5), rng.randi_range(4, m.size - 5))
		var d := Vector2(c).distance_to(vc)
		if d < 11.0 or d > 30.0 or m.get_terrain(c) != MapData.Terrain.GRASS or keep.has(c) or _near_road(m, c, 2):
			continue
		spots += 1
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var t := c + Vector2i(dx, dy)
				if Vector2(dx, dy).length() > 2.7 or not m.in_bounds(t) or m.get_terrain(t) != MapData.Terrain.GRASS or m.in_village(t):
					continue
				m.set_zone(t, "steppe")
				m.set_terrain(t, MapData.Terrain.DESERT)
				keep[t] = true
				if rng.randf() < 0.55 and not MapData.neighbors4(t).any(func(n: Vector2i) -> bool: return m.is_road(n)):
					m.set_terrain(t, MapData.Terrain.FOREST)
					m.props[t] = "tree_oak" if rng.randf() < 0.7 else "tree_pine_0"
	# The houses: blocks of 3x3 between lanes every fourth row and column.
	var walls := vrect.grow(4)
	var peaks: Array = Config.ZONES["city"]["peaks"]
	var standing := peaks.filter(func(a: String) -> bool: return not a.contains("ruin"))
	var ruins := peaks.filter(func(a: String) -> bool: return a.contains("ruin"))
	var blocks := {}
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.zone(t) != "city" or m.get_terrain(t) != MapData.Terrain.GRASS or keep.has(t) or walls.has_point(t):
				continue
			if x % 4 == 0 or y % 4 == 0:
				var art := "city_rubble" if rng.randf() < 0.05 else ""
				if art != "":
					m.decor[t] = art
				continue
			var near_road := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					near_road = near_road or m.is_road(t + Vector2i(dx, dy))
			if near_road:
				continue
			var b := Vector2i(x / 4, y / 4)
			if not blocks.has(b):
				blocks[b] = rng.randf() < float(ci["houses"])
			if not blocks[b] or rng.randf() < 0.12:
				continue
			m.set_terrain(t, MapData.Terrain.MOUNTAIN)
			m.props[t] = ruins[rng.randi() % ruins.size()] if rng.randf() < float(ci["ruined"]) else standing[rng.randi() % standing.size()]
	# Ash land's own bits.
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.zone(t) == "ash" and m.get_terrain(t) == MapData.Terrain.GRASS and not keep.has(t) and rng.randf() < 0.04:
				m.decor[t] = "lava_rock" if rng.randf() < 0.5 else "city_rubble"
	m.derive()
	return ""


## The road tiles from the edge spawn on map edge `e` to the village, in order.
func _road_from(m: MapData, e: String) -> Array[Vector2i]:
	for t in m.edge_spawns:
		if (e == "north" and t.y == 0) or (e == "south" and t.y == m.size - 1) or (e == "west" and t.x == 0) or (e == "east" and t.x == m.size - 1):
			return _road_to_village(m, t)
	return [] as Array[Vector2i]


## An object of `kind` and `size` by the road from map edge `at.edge`,
## `at.at` road tiles from the gate (`touch`: right beside the road, its door
## on it): its index, or why not.
func _add_by_road(m: MapData, at: Dictionary, kind: String, size: int, touch := false) -> Variant:
	var sp := Vector2i(-1, -1)
	var e := str(at["edge"])
	for t in m.edge_spawns:
		if (e == "north" and t.y == 0) or (e == "south" and t.y == m.size - 1) or (e == "west" and t.x == 0) or (e == "east" and t.x == m.size - 1):
			sp = t
	if sp == Vector2i(-1, -1):
		return "no road from that edge"
	var road := _road_to_village(m, sp)
	if road.is_empty():
		return "that road doesn't reach the village"
	var k := clampi(road.size() - 1 - int(at["at"]), 0, road.size() - 1)
	var free := EditorTools.MapCheckFree.new(m)
	for r in [1, 2, 3]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t: Vector2i = road[k] + Vector2i(dx, dy)
				var fp := Building.footprint(t, size)
				if touch and not fp.any(func(q: Vector2i) -> bool: return MapData.neighbors4(q).any(func(n: Vector2i) -> bool: return m.is_road(n))):
					continue
				if _open(m, free, fp):
					var res = EditorTools.add_object(m, kind, t, size)
					if res is int:
						return res
	return "no open land by the road there"


## Grass or desert, no road, prop, village piece or object, not in the village.
func _open(m: MapData, free: EditorTools.MapCheckFree, tiles: Array[Vector2i]) -> bool:
	for t in tiles:
		if free.why_not(t) != "" or m.props.has(t) or m.in_village(t):
			return false
		var v := m.get_terrain(t)
		if v != MapData.Terrain.GRASS and v != MapData.Terrain.DESERT:
			return false
	return true


## The road tiles from edge spawn `sp` to the village, in order (BFS over roads).
func _road_to_village(m: MapData, sp: Vector2i) -> Array[Vector2i]:
	var near: Rect2i = (m.villages[0]["rect"] as Rect2i).grow(1)
	var prev := {sp: sp}
	var q: Array[Vector2i] = [sp]
	var i := 0
	var end := Vector2i(-1, -1)
	while i < q.size():
		var t := q[i]
		i += 1
		if near.has_point(t):
			end = t
			break
		for n in MapData.neighbors4(t):
			if m.in_bounds(n) and m.is_road(n) and not prev.has(n):
				prev[n] = t
				q.append(n)
	if end == Vector2i(-1, -1):
		return [] as Array[Vector2i]
	var out: Array[Vector2i] = [end]
	while out[0] != sp:
		out.push_front(prev[out[0]])
	return out
