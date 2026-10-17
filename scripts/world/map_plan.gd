class_name MapPlan
extends RefCounted
## The top-down plan of a map: one colour per tile (zone, trees darker, water,
## mountains, lava, roads, bridges and fords, beaches, village pieces), as an
## Image with one pixel per tile. Used by the map editor's 2D view, the map
## previews (map picker, lobby) and tools/map_shot's plans.

const ZONE_COLORS := {
	"meadow": Color("8fbf5a"), "oak": Color("6f9a48"), "pine": Color("4f7a3a"), "heath": Color("8a7a52"),
	"steppe": Color("cdb27a"), "swamp": Color("5d6b3c"), "ash": Color("77736d"),
}
const OBJECT_COLORS := {
	"treasure": Color("f2c230"), "camp": Color("b0381f"), "unlock": Color("b777ff"), "ruin": Color("f4f0e6"),
	"lair": Color("1b1411"), "mine": Color("ff8a1f"),
}
const PIECE_COLORS := {"wall": Color("6b6158"), "gate": Color("c8a46a"), "wall_tower": Color("4a423b"), "hut": Color("a0704a")}
const ROAD := Color("f2e2b0")
const MOUNTAIN := Color("8a837c")
const WATER := Color("2f5f8f")
const SHALLOW := Color("6fa3c8")
const LAVA := Color("ff5a1a")
const BEACH := Color("efe0a8")
const FORD := Color("9ad0e8")
const BRIDGE := Color("8a5a2b")
const CRATER := Color("ff7a1a")
const SPAWN := Color("e0303a")


## The ground colour of tile `t` (no pieces, objects or spawns).
static func ground_color(m: MapData, t: Vector2i) -> Color:
	var c: Color = ZONE_COLORS[m.zone(t)]
	match m.get_terrain(t):
		MapData.Terrain.FOREST: c = c.darkened(0.45)
		MapData.Terrain.DESERT: c = c.lightened(0.12)
		MapData.Terrain.ROAD: c = ROAD
		MapData.Terrain.MOUNTAIN: c = MOUNTAIN
		MapData.Terrain.WATER: c = WATER
		MapData.Terrain.SHALLOW: c = SHALLOW
		MapData.Terrain.LAVA: c = LAVA
	if m.beaches.has(t) and not m.is_road(t) and not m.is_water(t):
		c = BEACH
	if m.crossings.has(t):
		c = FORD if m.crossings[t][0] == "tile_ford" else BRIDGE
	if m.props.get(t, "") == "volcano":
		c = CRATER
	if m.decor.has(t):
		c = c.darkened(0.15)
	return c


## The colour of tile `t` in the plan: its ground, or the village piece on it
## (`pieces`: MapTidy.piece_tiles).
static func tile_color(m: MapData, t: Vector2i, pieces: Dictionary) -> Color:
	if pieces.has(t):
		return PIECE_COLORS.get(pieces[t], Color.MAGENTA)
	return ground_color(m, t)


## The whole plan, one pixel per tile.
static func image(m: MapData) -> Image:
	var img := Image.create(m.size, m.size, false, Image.FORMAT_RGBA8)
	var pieces := MapTidy.piece_tiles(m)
	for a in m.abandoned:
		for p in a["pieces"]:
			pieces[p["tile"]] = p["kind"]
	for y in m.size:
		for x in m.size:
			img.set_pixel(x, y, tile_color(m, Vector2i(x, y), pieces))
	return img


## Tiles nobody has explored, in a preview with fog (a saved game's).
const FOG := Color(0.03, 0.03, 0.03)


## A small preview: the plan with objects, spawns and each village's number
## marked, scaled to `px` pixels per tile. With `explored` (1 per explored
## tile, MapData.index order: a saved game's fog), the rest is black and
## nothing hidden there is marked.
static func preview(m: MapData, px: int, explored: PackedByteArray = PackedByteArray()) -> Image:
	var img := image(m)
	var fog := explored.size() == m.size * m.size
	var seen := func(t: Vector2i) -> bool: return not fog or explored[m.index(t)] == 1
	for o in m.objects:
		for t in Building.footprint(o["tile"], int(o.get("size", 1))):
			if m.in_bounds(t) and seen.call(t):
				img.set_pixelv(t, OBJECT_COLORS.get(o["kind"], Color.MAGENTA))
	for v in m.villages:
		for s: Vector2i in v.get("home_spawns", []):
			if seen.call(s):
				img.set_pixelv(s, SPAWN)
	if fog:
		for i in explored.size():
			if explored[i] == 0:
				img.set_pixel(i % m.size, i / m.size, FOG)
	if px > 1:
		img.resize(m.size * px, m.size * px, Image.INTERPOLATE_NEAREST)
	return img
