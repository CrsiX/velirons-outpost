extends Node
## Makes a scenario's starting map (docs/scenarios-design.md) with the map
## generator and writes it as a map file (data/maps/), to be edited by hand in
## the map editor afterwards (open it there, change it, Export over the same
## file). Run once per scenario; it never overwrites a map unless asked to:
##   godot --headless --path . res://tools/make_scenario_map.tscn -- <scenario number> [--force]
##
## What each scenario's map starts from: a generated map (type, seed), with
## the object kinds in "drop" taken out, and at most "ruins" ruined
## watchtowers left (the ones nearest the village).

const MAPS := {
	1: {"map_type": "highlands", "seed": 1337, "name": "Homecoming",
		"description": "Scenario 1: the home village, ruined. Three roads lead in; Brenna's tent stands by the north road.",
		"drop": ["unlock", "lair"], "ruins": 1},
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
	var m := MapGenerator.generate(int(spec["seed"]), 1, str(spec["map_type"]))
	_drop_objects(m, spec["drop"], int(spec["ruins"]))
	m.meta = {"name": spec["name"], "author": "", "description": spec["description"],
		"origin": {"generator_seed": int(spec["seed"]), "edited": true, "game_version": MapJson.game_version()}}
	var text := MapJson.write(m)
	var back := MapJson.read(text)
	if not (back["errors"] as Array).is_empty():
		printerr("the map doesn't read back: %s" % "; ".join(back["errors"]))
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("%s: written (%d objects)" % [path, m.objects.size()])
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
