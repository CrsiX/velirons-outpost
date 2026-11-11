class_name HallBench
extends Barracks
## The town hall's bench (docs/village-design.md §3a): from level
## Config.TOWN_HALL "bench_from" one barracks bench on the hall's front
## (bottom-right) tile, whose unit turns out with the range of a barracks at
## level "bench_range_level". For the army it is a barracks of its own (every
## sortie, revive and aura rule of barracks applies); otherwise it is part of
## the hall: no tiles of its own, no HP, never picked, no panel (the hall's
## shows it), never saved or sent to co-op clients by itself (TownHall carries
## its id and its bench).

## Where the sitter is drawn, from the bench tile's centre (grid): on the bench
## along the side wall in the hall's level-3 art (tools/art/buildings.py, HALL_BENCH,
## which counts from the 2x2's middle: half a tile less each way).
const BENCH_SPOT := Vector2(0.36, -0.2)

var hall: TownHall


func _build_visuals() -> void:
	var s := Sprite2D.new()
	s.show_behind_parent = true
	s.position = Iso.to_world(BENCH_SPOT) + Vector2(0, -4)
	s.visible = false
	add_child(s)
	_bench_sprites.append(s)
	UnitFx.add_hunger_mark(s, game, func() -> MilitaryUnit: return slots[0] if not slots.is_empty() else null)


func refresh() -> void:
	fit_slots()
	var s := _bench_sprites[0]
	var u: MilitaryUnit = slots[0]
	s.visible = working() and u != null and not u.out
	if s.visible:
		UnitFx.show_unit(s, u.kind)
		s.modulate = Color(1, 1, 1, 0.35) if u.is_downed() else Color.WHITE
	queue_redraw()


func display_name() -> String:
	return "Town Hall Bench"


## Its tiles are the hall's: it registers none of its own on the map.
func tiles() -> Array[Vector2i]:
	return [] as Array[Vector2i]


## Its unit steps down onto the bench tile itself (the hall doesn't block it).
func work_tile() -> Vector2i:
	return tile


func capacity() -> int:
	return 1


func max_level() -> int:
	return 1


func activation_range() -> float:
	return Config.BARRACKS_LEVELS[int(Config.TOWN_HALL["bench_range_level"]) - 1]["range"]


## Its unit turns out from the bench tile.
func act_center() -> Vector2:
	return Vector2(tile)


## Only while its hall has the bench and works.
func working() -> bool:
	return is_instance_valid(hall) and hall.has_bench() and hall.working()


## The hall takes the blows, never the bench.
func can_be_hurt() -> bool:
	return false


func sight_radius() -> float:
	return 0.0


## Never picked as a building (its sitter is, through unit_at).
func pick_sprites() -> Array[Sprite2D]:
	return [] as Array[Sprite2D]


func info() -> Dictionary:
	return hall.info() if is_instance_valid(hall) else super.info()
