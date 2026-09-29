extends Node
## A played game per map type: towers manned, archers bought, the hero explores
## between waves. Reports frame times, waves, finds, loot, unlocks.
func _ready() -> void:
	for t in ["temperate"]:
		await _play(t, 3100 + t.length())
	get_tree().quit()

func _play(type: String, sd: int) -> void:
	Settings.map_type = type
	Settings.map_seed = sd
	var g: Game = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	var v := g.player_village
	var infos: Array[String] = []
	v.events.logged.connect(func(l: int, text: String) -> void:
		if l >= EventLog.Level.INFO:
			infos.append(text)
		if l == EventLog.Level.IMPORTANT or "wave" in text.to_lower():
			print("   t=%.0f  %s  (food %d, pop %d)" % [Engine.get_frames_drawn(), text, v.economy.amount("food"), v.population.count()]))
	Engine.time_scale = 8.0
	var t := 0.0
	var worst := 0
	var frames := 0
	var real0 := Time.get_ticks_msec()
	var last := real0
	var tick := 0.0
	var gold_looted := 0
	while t < 900.0 and not g.game_over:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		frames += 1
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
		tick -= d
		if tick > 0.0:
			continue
		tick = 5.0
		# Man the towers with archers.
		for tw in g.world.towers():
			if tw.village == v and tw.complete and tw.garrison == null and tw.incoming == null:
				var u := v.army.recruit("archer")
				if u:
					v.army.station(u, tw)
		# Hero: defend during waves, explore (claims, loot) between them.
		var want := Hero.Mode.DEFEND if g.waves.in_progress() else Hero.Mode.EXPLORE
		if v.hero.mode != want and not v.hero.dead:
			v.hero.set_mode(want)
		# Keep the food up.
		if v.economy.amount("food") < 40 and v.population.free_huts().size() > 0 and v.economy.amount("food") >= 25:
			pass
	var secs := (Time.get_ticks_msec() - real0) / 1000.0
	var finds := infos.filter(func(s: String) -> bool: return s.begins_with("Found") or "Travellers speak" in s or "awakened" in s)
	var loots := infos.filter(func(s: String) -> bool: return "looted" in s)
	print("%-10s wave %d, %s, %d frames in %.0f s (avg %.1f ms, worst %d ms), %d finds, %d loots, unlocks %s, pop %d, gold %d" % [type, g.waves.wave, "FALLEN" if g.game_over else "standing", frames, secs, secs * 1000.0 / frames, worst, finds.size(), loots.size(), str(g.unlocks.keys()), v.population.count(), v.economy.amount("gold")])
	for s in finds.slice(0, 3) + loots.slice(0, 2):
		print("     ", s)
	g.queue_free()
	await get_tree().process_frame
	Settings.map_type = "temperate"
	Settings.map_seed = 0
