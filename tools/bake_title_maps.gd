extends Node
## Bakes the title backdrop's maps (one per map type and seed its scenes use,
## Config.TITLE_BACKDROP) into data/title_maps/, so the title screen needn't
## generate them. Rerun after changing the map generator or the scenes' maps
## (tests/title_bot.gd fails when they are stale):
##   godot --headless --path . res://tools/bake_title_maps.tscn


func _ready() -> void:
	for key: Array in maps():
		var m := MapGenerator.generate(int(key[1]), 1, str(key[0]))
		var res := BakedMap.new()
		res.bytes = m.to_bytes()
		var p := BakedMap.path(str(key[0]), int(key[1]))
		var err := ResourceSaver.save(res, p)
		print("%s: %s (%d bytes)" % [p, "saved" if err == OK else "error %d" % err, res.bytes.size()])
	get_tree().quit()


## [map type, seed] of every scene's map, each once.
static func maps() -> Array:
	var out: Array = []
	var cfg := Config.TITLE_BACKDROP
	for sc: Dictionary in cfg["scenes"]:
		var key := [str(sc.get("map_type", cfg["map_type"])), int(sc.get("seed", cfg["seed"]))]
		if not key in out:
			out.append(key)
	return out
