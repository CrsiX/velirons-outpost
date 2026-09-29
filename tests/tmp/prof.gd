extends Node
## Normal-speed game with fog: which frames are slow, and what ran in them.
var spans := {}
func _ready() -> void:
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.map_seed = 3109
	add_child(g)
	await get_tree().process_frame
	Engine.time_scale = 1.0
	var last := Time.get_ticks_usec()
	var t := 0.0
	var slow := 0
	var n := 0
	var total := 0
	while t < 120.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000
		last = now
		n += 1
		total += ms
		if ms > 40:
			slow += 1
			if slow <= 12:
				print("slow frame %d ms at t=%.1f" % [ms, t])
	print("frames %d, avg %.1f ms, slow %d" % [n, float(total) / n, slow])
	var ex: Civilian = g.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "explorer")[0]
	var job = ex.get("job")
	var t0 := Time.get_ticks_usec()
	var pathing := g.world.pathing
	var f := pathing.distance_field(ex.current_tile())
	var t1 := Time.get_ticks_usec()
	var ej := ExploreJob.new()
	ej.bind(ex)
	ej.choose_target(ex.current_tile())
	var t2 := Time.get_ticks_usec()
	g.world.village_distance(g.player_village)
	var t3 := Time.get_ticks_usec()
	for layer in [g.world.ground, g.world.ground_top, g.world.water, g.world.lava]:
		for k in 3:
			await get_tree().process_frame
		var a := Time.get_ticks_usec()
		if layer is GroundLayer:
			(layer as GroundLayer).redraw_tile(g.player_village.center + Vector2i(6, 6))
		else:
			layer.queue_redraw()
		await get_tree().process_frame
		print("%s redraw frame %d ms" % [layer.name, (Time.get_ticks_usec() - a) / 1000])
	print("distance_field %d ms, choose_target %d ms, village_distance %d ms" % [(t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000])
	get_tree().quit()
