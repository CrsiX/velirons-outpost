extends Node
## Traces how an explorer (or the hero in Explore mode) moves: a fresh game,
## no waves, one scout exploring for a while; its position every frame and
## every change of target. Prints movement metrics and draws the track over
## the map as a PNG. Run as a scene (it needs the autoloads):
##   godot --headless --fixed-fps 60 --path . res://tools/explore_trace.tscn -- [--who=explorer|hero] [--seed=N] [--secs=180] [--out=DIR]

var game: Game
var who := "explorer"
var map_seed := 1
var secs := 180.0
var out_dir := "user://explore_trace"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--who="):
			who = a.substr(6)
		elif a.begins_with("--seed="):
			map_seed = int(a.substr(7))
		elif a.begins_with("--secs="):
			secs = float(a.substr(7))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = map_seed
	add_child(game)
	for i in 3:
		await get_tree().process_frame
	game.waves.countdown = 1e9
	game.waves.hold = true
	Engine.time_scale = 4.0
	var scout: Civilian
	var explorers := game.population.civilians.filter(func(c: Civilian) -> bool: return c is Explorer)
	if who == "hero":
		for e in explorers:
			e.set_process(false)  # (stays home)
		scout = game.hero
		game.hero.set_mode(Hero.Mode.EXPLORE)
	else:
		game.hero.set_mode(Hero.Mode.REST)
		scout = explorers[0] if not explorers.is_empty() else game.population.recruit("explorer")
	var job: ExploreJob = (scout as Explorer).job if scout is Explorer else game.hero.jobs[Hero.Mode.EXPLORE] as ExploreJob
	var explored0 := game.fog.explored_count()
	# Every frame: game time, position, target.
	var t := 0.0
	var pts: Array[Vector2] = []
	var times: Array[float] = []
	var retargets: Array = []  # [time, position, old target, new target]
	var last_target := Vector2i(-2, -2)
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
		var p := scout.grid_pos
		if job.target != last_target:
			retargets.append([t, p, last_target, job.target])
			last_target = job.target
		pts.append(p)
		times.append(t)
	# --- metrics ---
	# A new target that starts backwards: the way in the 0.3 s after it points
	# against (more than 90 deg) the way in the 0.3 s before.
	var backsteps := 0
	for r: Array in retargets:
		var before := _pos_at(pts, times, float(r[0]) - 0.3)
		var at := _pos_at(pts, times, float(r[0]))
		var after := _pos_at(pts, times, float(r[0]) + 0.3)
		if at.distance_to(before) > 0.05 and after.distance_to(at) > 0.05 and (at - before).dot(after - at) < 0.0:
			backsteps += 1
	var walked := 0.0
	for i in range(1, pts.size()):
		walked += pts[i].distance_to(pts[i - 1])
	# Headings sampled every 0.25 s of game time; sharp turns and reversals.
	var samples: Array[Vector2] = [pts[0]]
	var next := 0.25
	for i in pts.size():
		if times[i] >= next:
			samples.append(pts[i])
			next += 0.25
	var reversals := 0
	var sharp := 0
	var turning := 0.0
	var prev := Vector2.ZERO
	var rev_at: Array[Vector2] = []
	for i in range(1, samples.size()):
		var v := samples[i] - samples[i - 1]
		if v.length() < 0.05:
			continue
		if prev != Vector2.ZERO:
			var ang := absf(prev.angle_to(v))
			turning += ang
			if ang > deg_to_rad(135.0):
				reversals += 1
				rev_at.append(samples[i - 1])
			elif ang > deg_to_rad(60.0):
				sharp += 1
		prev = v
	var revealed := game.fog.explored_count() - explored0
	var far := 0.0
	for p in pts:
		far = maxf(far, p.distance_to(Vector2(game.player_village.center)))
	print("TRACE who=%s seed=%d secs=%.0f" % [who, map_seed, secs])
	print("  walked %.1f tiles, %d re-targets (one every %.1f tiles), %d new paths starting backwards" % [walked, retargets.size(), walked / maxf(1.0, retargets.size()), backsteps])
	print("  reversals (>135 deg per 0.25 s): %d (one every %.1f tiles); sharp turns (60-135 deg): %d; turning %.0f deg per tile" % [reversals, walked / maxf(1.0, reversals), sharp, rad_to_deg(turning) / maxf(0.1, walked)])
	print("  revealed %d tiles: %.1f per tile walked; farthest %.1f tiles from the village" % [revealed, revealed / maxf(0.1, walked), far])
	print("TRACE_DATA %s %d %.1f %d %d %d %d %.1f %d %.1f" % [who, map_seed, walked, retargets.size(), backsteps, reversals, sharp, rad_to_deg(turning) / maxf(0.1, walked), revealed, far])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var base := "%s/%s_%d" % [out_dir, who, map_seed]
	_save_csv(base + ".csv", pts, times, retargets)
	_save_png(base + ".png", pts, rev_at, retargets)
	print("  wrote %s.csv and %s.png" % [base, base])
	Engine.time_scale = 1.0
	get_tree().quit(0)


func _pos_at(pts: Array[Vector2], times: Array[float], t: float) -> Vector2:
	var i := times.bsearch(t)
	return pts[clampi(i, 0, pts.size() - 1)]


func _save_csv(path: String, pts: Array[Vector2], times: Array[float], retargets: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("t,x,y")
	for i in pts.size():
		f.store_line("%.3f,%.3f,%.3f" % [times[i], pts[i].x, pts[i].y])
	f.store_line("# retargets: t,x,y,old,new")
	for r: Array in retargets:
		f.store_line("# %.3f,%.2f,%.2f,%s,%s" % [r[0], r[1].x, r[1].y, r[2], r[3]])


## The map top-down around the track (explored land lighter), the track in
## white, reversals red, re-targets as small yellow ticks, the village blue.
func _save_png(path: String, pts: Array[Vector2], rev_at: Array[Vector2], retargets: Array) -> void:
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var c := Vector2(game.player_village.center)
	lo = lo.min(c) - Vector2(4, 4)
	hi = hi.max(c) + Vector2(4, 4)
	var s := 12.0  # pixels per tile
	var img := Image.create(int((hi.x - lo.x) * s), int((hi.y - lo.y) * s), false, Image.FORMAT_RGB8)
	var vid := game.player_village.id
	for y in img.get_height():
		for x in img.get_width():
			var t := Vector2i((Vector2(x, y) / s + lo).floor())
			var col := Color(0.1, 0.1, 0.1)
			if game.map.in_bounds(t):
				col = Color(0.25, 0.4, 0.25) if game.world.pathing.is_walkable(t) else Color(0.15, 0.2, 0.15)
				if game.map.is_water(t):
					col = Color(0.15, 0.2, 0.4)
				if not game.fog.is_explored_by(vid, t):
					col = col.darkened(0.6)
			img.set_pixel(x, y, col)
	for i in range(1, pts.size()):
		_line(img, (pts[i - 1] + Vector2(0.5, 0.5) - lo) * s, (pts[i] + Vector2(0.5, 0.5) - lo) * s, Color.WHITE)
	for r: Array in retargets:
		_dot(img, ((r[1] as Vector2) + Vector2(0.5, 0.5) - lo) * s, 2, Color.YELLOW)
	for p in rev_at:
		_dot(img, (p + Vector2(0.5, 0.5) - lo) * s, 3, Color.RED)
	_dot(img, (c + Vector2(0.5, 0.5) - lo) * s, 5, Color(0.3, 0.6, 1.0))
	img.save_png(path)


func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(maxf(1.0, a.distance_to(b)))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixelv(Vector2i(p), col)


func _dot(img: Image, p: Vector2, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := Vector2i(p) + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
				img.set_pixelv(q, col)
