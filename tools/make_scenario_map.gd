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
## "building": "tower" or "barracks"}.

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
		"description": "Scenario 4: the neutral guild's walled market town on the coast, its harbour on the inlet beside the walls.",
		"drop": ["unlock", "lair"], "ruins": 0},
	5: {"map_type": "highlands", "seed": 11, "name": "The Old Fort",
		"description": "Scenario 5: Brenna's old fort, where the road comes down out of the northern pass. The evidence lies in the hills around it.",
		"drop": ["unlock", "lair"], "ruins": 0},
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
	if spec.has("grow"):
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
	var sp := Vector2i(-1, -1)
	var e := str(ru["edge"])
	for t in m.edge_spawns:
		if (e == "north" and t.y == 0) or (e == "south" and t.y == m.size - 1) or (e == "west" and t.x == 0) or (e == "east" and t.x == m.size - 1):
			sp = t
	if sp == Vector2i(-1, -1):
		return "no road from that edge"
	var road := _road_to_village(m, sp)
	if road.is_empty():
		return "that road doesn't reach the village"
	var k := clampi(road.size() - 1 - int(ru["at"]), 0, road.size() - 1)
	var size := 2 if str(ru["building"]) == "barracks" else 1
	var free := EditorTools.MapCheckFree.new(m)
	for r in [1, 2, 3]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t: Vector2i = road[k] + Vector2i(dx, dy)
				if _open(m, free, Building.footprint(t, size)):
					var res = EditorTools.add_object(m, "ruin", t, size)
					if res is int:
						m.objects[res]["building"] = str(ru["building"])
						m.objects[res]["art"] = MapJson.object_art(m.objects[res])
						return ""
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
