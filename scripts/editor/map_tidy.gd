class_name MapTidy
extends RefCounted
## The map editor's automatic tidy-up after an edit (docs/map-editor-design.md
## §5.3), so a hand-painted map stays what the game expects: crossings follow
## the roads, trees and peaks follow the terrain, decor stays off roads,
## pieces, objects and blocked tiles, beaches stay by the water, and tiles
## under village pieces are ground (gates: road). Choices it makes (which
## tree) depend only on the tile, so redoing an edit gives the same map.

const PEAK_ARTS: Array[String] = ["mountain_0", "mountain_1", "mountain_2"]


## The ground a zone's open tiles have (steppe: desert, else grass).
static func ground(m: MapData, t: Vector2i) -> int:
	return MapData.Terrain.DESERT if m.zone(t) == "steppe" else MapData.Terrain.GRASS


## Tidies `tiles` and the ring around them.
static func tidy(m: MapData, tiles: Array) -> void:
	var seen := {}
	var pieces := piece_tiles(m)
	var objects := object_tiles(m)
	for t: Vector2i in tiles:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p := t + Vector2i(dx, dy)
				if m.in_bounds(p) and not seen.has(p):
					seen[p] = true
					_tidy_tile(m, p, pieces, objects)


## Tidies every tile (after loading or a big change).
static func tidy_all(m: MapData) -> void:
	var pieces := piece_tiles(m)
	var objects := object_tiles(m)
	for y in m.size:
		for x in m.size:
			_tidy_tile(m, Vector2i(x, y), pieces, objects)


static func _tidy_tile(m: MapData, t: Vector2i, pieces: Dictionary, objects: Dictionary) -> void:
	var v := m.get_terrain(t)
	# Under a village piece: ground, a gate on road; nothing grows there.
	if pieces.has(t):
		if pieces[t] == "gate":
			m.set_terrain(t, MapData.Terrain.ROAD)
		elif v != MapData.Terrain.GRASS and v != MapData.Terrain.DESERT:
			m.set_terrain(t, ground(m, t))
		m.crossings.erase(t)
		m.props.erase(t)
		m.decor.erase(t)
		m.beaches.erase(t)
		return
	# Crossings only on road; road over water / lava keeps a crossing.
	if m.crossings.has(t) and v != MapData.Terrain.ROAD:
		m.crossings.erase(t)
	# Trees on forest, peaks on mountains (a volcano's tiles have only its crater).
	var prop: String = m.props.get(t, "")
	if v == MapData.Terrain.FOREST:
		if prop == "" or not _is_tree(prop):
			m.props[t] = tree_for(m, t)
	elif v == MapData.Terrain.MOUNTAIN:
		if in_volcano(m, t):
			if prop != "volcano":
				m.props.erase(t)
		elif prop == "" or not PEAK_ARTS.has(prop):
			m.props[t] = PEAK_ARTS[_hash(t) % PEAK_ARTS.size()]
	elif prop != "":
		m.props.erase(t)
	# Decor only on open, walkable land, off roads and objects.
	if m.decor.has(t) and (v == MapData.Terrain.ROAD or not m.is_passable(t) or v == MapData.Terrain.SHALLOW or objects.has(t)):
		m.decor.erase(t)
	# Beaches: land by water.
	if m.beaches.has(t) and (m.is_water(t) or v == MapData.Terrain.ROAD or v == MapData.Terrain.LAVA or not _by_water(m, t)):
		m.beaches.erase(t)


## A crossing for road tile `t` if it lies on water or lava `under` (bridge
## style by zone, a ford on shallow water), as the generator makes them.
static func set_crossing(m: MapData, t: Vector2i, under: int) -> void:
	if under == MapData.Terrain.SHALLOW:
		m.crossings[t] = ["tile_ford", under]
		return
	var style: String = Config.BRIDGE_STYLES.get(m.zone(t), "timber")
	if under == MapData.Terrain.LAVA:
		style = "charred"
	var along_x := m.is_road(t + Vector2i.LEFT) or m.is_road(t + Vector2i.RIGHT)
	var along_y := m.is_road(t + Vector2i.UP) or m.is_road(t + Vector2i.DOWN)
	m.crossings[t] = ["bridge_%s_%s" % [style, "y" if along_y and not along_x else "x"], under]


static func tree_for(m: MapData, t: Vector2i) -> String:
	var mix: Dictionary = Config.ZONES[m.zone(t)]["mix"]
	if mix.is_empty():
		return "tree_oak"
	var total := 0.0
	for k in mix:
		total += float(mix[k])
	var r := float(_hash(t) % 10000) / 10000.0 * total
	for k in mix:
		r -= float(mix[k])
		if r < 0.0:
			return k
	return mix.keys()[0]


static func decor_for(m: MapData, t: Vector2i) -> String:
	var mix: Dictionary = Config.ZONES[m.zone(t)].get("decor_mix", {})
	if mix.is_empty():
		return "boulder"
	var keys: Array = mix.keys()
	return keys[_hash(t) % keys.size()]


static func in_volcano(m: MapData, t: Vector2i) -> bool:
	for c in m.volcanoes:
		if absi(t.x - c.x) <= 1 and absi(t.y - c.y) <= 1:
			return true
	return false


## Village piece kinds by tile (every village).
static func piece_tiles(m: MapData) -> Dictionary:
	var out := {}
	for p in m.village_layout:
		out[p["tile"]] = p["kind"]
	return out


## Tiles covered by map objects.
static func object_tiles(m: MapData) -> Dictionary:
	var out := {}
	for i in m.objects.size():
		for t in Building.footprint(m.objects[i]["tile"], int(m.objects[i].get("size", 1))):
			out[t] = i
	return out


static func _is_tree(art: String) -> bool:
	for z in Config.ZONES:
		if (Config.ZONES[z]["mix"] as Dictionary).has(art):
			return true
	return art.begins_with("tree_") or art.begins_with("stump")


static func _by_water(m: MapData, t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if m.is_water(t + Vector2i(dx, dy)):
				return true
	return false


static func _hash(t: Vector2i) -> int:
	return absi(hash(Vector2i(t.x * 7919 + 13, t.y * 104729 + 7)))
