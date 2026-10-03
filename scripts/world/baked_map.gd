class_name BakedMap
extends Resource
## A generated map saved beforehand (MapData.to_bytes), so it needn't be made
## at run time: the title backdrop's maps, baked by tools/bake_title_maps.gd
## into data/title_maps/ (tests/title_bot.gd checks they are up to date).

const DIR := "res://data/title_maps/"

@export var bytes: PackedByteArray

static var _cache: Dictionary = {}


static func path(map_type: String, seed_value: int) -> String:
	return DIR + "%s_%d.res" % [map_type, seed_value]


## A fresh copy of the baked map (the game changes its map: trees fall), or
## null when there is none.
static func load_map(map_type: String, seed_value: int) -> MapData:
	var p := path(map_type, seed_value)
	if not _cache.has(p):
		var res: BakedMap = load(p) if ResourceLoader.exists(p) else null
		_cache[p] = res.bytes if res else PackedByteArray()
	var b: PackedByteArray = _cache[p]
	return MapData.from_bytes(b) if not b.is_empty() else null
