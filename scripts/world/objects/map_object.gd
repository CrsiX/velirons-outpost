class_name MapObject
extends Building
## A special object on the map (docs/world-design.md §9): treasures, monster
## camps, unit-unlock sites, ruined watchtowers, lairs and mines. Spawned by
## World from MapData.objects (on the host and on co-op clients alike; only
## their state is replicated). Neutral (`village` null) unless claimed.
## Hidden in the fog until explored; each village logs (Info) when it finds one.

## Index into MapData.objects, and that entry.
var index := -1
var data: Dictionary = {}
## Village ids that have found (explored) it.
var found_by: Dictionary = {}


func setup_object(p_game: Game, p_index: int, p_data: Dictionary) -> void:
	index = p_index
	data = p_data
	size = int(data.get("size", 1))
	setup(p_game, "obj_" + str(data["kind"]), data["tile"], true)
	remove_from_group("observers")  # (objects don't watch anything)
	visible = false


func _build_visuals() -> void:
	sprite = Art.sprite(art())
	sprite.show_behind_parent = true
	add_child(sprite)


func refresh() -> void:
	if sprite:
		Art.apply(sprite, art())
	queue_redraw()


## Current art (looted / awake / cleared versions override).
func art() -> String:
	return data["art"]


func display_name() -> String:
	return str(data["kind"]).capitalize()


func label() -> String:
	return "%s at %d,%d" % [display_name().to_lower(), tile.x, tile.y]


func is_solid() -> bool:
	return false


## Tile the hero (or a miner) walks to: next to it if the object is solid.
func visit_tile() -> Vector2i:
	if not is_solid() and game.world.pathing.is_walkable(tile):
		return tile
	var best := tile
	var best_d := INF
	for t in tiles():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p := t + Vector2i(dx, dy)
				if tiles().has(p) or not game.world.pathing.is_walkable(p):
					continue
				var d := Vector2(p).distance_to(Vector2(game.map.villages[0]["center"]))
				if d < best_d:
					best_d = d
					best = p
	return best


func is_found_by(v: Village) -> bool:
	return v != null and found_by.has(v.id)


## Village `vid` explored it: remember, and tell that player (Info).
func on_found(vid: int, quiet: bool) -> void:
	if found_by.has(vid):
		return
	found_by[vid] = true
	if not quiet and not game.is_client:
		var line := found_message(game.villages[vid])
		if line != "":
			game.villages[vid].events.info(line)


## "Explorer found a ... ." (empty: say nothing).
func found_message(_v: Village) -> String:
	return ""


## Shown while the local village has explored its tile.
func update_visibility() -> void:
	var seen := false
	for t in tiles():
		seen = seen or game.map.is_explored(t)
	visible = seen


## Co-op: the host's word on its state ([kind-specific values]).
func net_state() -> Array:
	return []


func apply_net_state(_s: Array) -> void:
	pass


func info() -> Dictionary:
	return {"title": display_name(), "lines": [] as Array[String], "actions": [] as Array[Dictionary]}


func pick_rect() -> Rect2:
	return Rect2(-40 * size, -70, 80 * size, 90)


func _draw() -> void:
	pass
