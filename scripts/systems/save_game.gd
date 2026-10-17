class_name SaveGame
extends RefCounted
## Saving and loading a running game (docs/save-design.md). Only between
## waves: what is saved is everything durable (the map as it is now, fog,
## objects, villages, buildings, villagers, army, hero, corpses, camp guards,
## the waves' counter, statistics); what anything is doing right now (paths,
## targets, cooldowns) starts afresh after a load.
##
## A save file in Config.SAVE["dir"]: "VOSV", FORMAT (u32), the header's
## length (u32), the header (var_to_bytes, for the save list), the body's raw
## length (u32) and the body (var_to_bytes, zstd). Plain values only: entities
## refer to each other by nid, villages by index, map objects by index.

const FORMAT := 1
const MAGIC := "VOSV"
const EXT := "vsave"
const AUTO_PREFIX := "auto-"
const ELEMENTAL_SCRIPT := preload("res://scripts/units/earth_elemental.gd")
const ENEMY_SCRIPT := preload("res://scripts/units/enemy.gd")
const CORPSE_SCRIPT := preload("res://scripts/units/corpse.gd")
const CARAVAN_SCRIPT := preload("res://scripts/units/caravan.gd")


## Tests: their own folder instead of Config.SAVE["dir"] (never the player's saves).
static var dir_override := ""


static func dir() -> String:
	return dir_override if dir_override != "" else str(Config.SAVE["dir"])


# --- files -----------------------------------------------------------------------------

## Writes a save; returns "" or why it failed. Into a temporary file first,
## then renamed over the old one, so a crash mid-write keeps the old save.
static func write(path: String, header: Dictionary, body: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var head := var_to_bytes(header)
	var raw := var_to_bytes(body)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return error_string(FileAccess.get_open_error())
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_32(FORMAT)
	f.store_32(head.size())
	f.store_buffer(head)
	f.store_32(raw.size())
	f.store_buffer(packed)
	var err := f.get_error()
	f.close()
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return error_string(err)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	err = DirAccess.rename_absolute(tmp, path)
	return "" if err == OK else error_string(err)


## {"path", "header", "body" (only with `body`), "error"}: "" when it can be loaded.
static func read(path: String, body: bool = true) -> Dictionary:
	var out := {"path": path, "header": {}, "body": {}, "error": ""}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out["error"] = "Can't open the file"
		return out
	if f.get_length() < 16 or f.get_buffer(4).get_string_from_ascii() != MAGIC:
		out["error"] = "Not a save file"
		return out
	if f.get_32() != FORMAT:
		out["error"] = "Made with another version of the game"
		return out
	var hl := f.get_32()
	var h = bytes_to_var(f.get_buffer(hl))
	if not (h is Dictionary):
		out["error"] = "Broken file"
		return out
	out["header"] = h
	if not body:
		return out
	var raw_size := f.get_32()
	var packed := f.get_buffer(f.get_length() - f.get_position())
	var raw := packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	var b = bytes_to_var(raw) if raw.size() == raw_size else null
	if not (b is Dictionary):
		out["error"] = "Broken file"
		return out
	out["body"] = b
	out["error"] = check(b)
	return out


## Starts the single-player game saved at `path` (Continue, Load...); "" or why not.
static func start(path: String, tree: SceneTree) -> String:
	var r := read(path)
	if r["error"] != "":
		return str(r["error"])
	Settings.pending_save = r["body"]
	Settings.custom_map = null
	Settings.editor_play = false
	Engine.time_scale = 1.0
	tree.paused = false
	tree.change_scene_to_file(Net.GAME_SCENE)
	return ""


## "" if every kind the body names exists in Config, else why it can't be loaded.
static func check(b: Dictionary) -> String:
	var bad := "Made with another version of the game"
	if not b.has("map") or not b.has("villages") or not b.has("buildings"):
		return "Broken file"
	for d: Dictionary in b["buildings"]:
		if not Construction.KIND_SCRIPTS.has(d["k"]) and not World.PIECE_SCRIPTS.has(d["k"]):
			return bad
	for d: Dictionary in b["civilians"]:
		if not Population.ROLE_SCRIPTS.has(d["r"]):
			return bad
	for d: Dictionary in b["units"]:
		if not Config.MILITARY.has(d["k"]):
			return bad
	for list in [b["guards"], b["corpses"]]:
		for d: Dictionary in list:
			if not Config.ENEMIES.has(d["k"]):
				return bad
	for d: Dictionary in b["elementals"]:
		if not Config.SUMMONS.has(d["sm"]):
			return bad
	return ""


## Every save, newest first: [{"path", "header", "error"}] (headers only).
## `coop`: only co-op saves (2+ villages); else only single-player ones.
static func list(coop: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir()):
		return out
	for f in DirAccess.get_files_at(dir()):
		if f.get_extension() != EXT:
			continue
		var e := read(dir().path_join(f), false)
		var h: Dictionary = e["header"]
		if e["error"] == "" and bool(h.get("coop", false)) != coop:
			continue
		e.erase("body")
		out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["header"].get("saved_at", 0)) > int(b["header"].get("saved_at", 0)))
	return out


## The newest loadable single-player save ("" if none): what Continue loads.
static func newest_single() -> String:
	for e in list(false):
		if e["error"] == "":
			return str(e["path"])
	return ""


## The newest save of game `game_id` ("" if none): the defeat screen's Load last save.
static func newest_of(game_id: String) -> String:
	for coop in [false, true]:
		for e in list(coop):
			if e["error"] == "" and str(e["header"].get("game_id", "")) == game_id:
				return str(e["path"])
	return ""


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## The file a manual save named `save_name` goes to.
static func path_for(save_name: String) -> String:
	var slug := ""
	for ch in save_name.strip_edges().to_lower():
		slug += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	while "--" in slug:
		slug = slug.replace("--", "-")
	slug = slug.trim_prefix("-").trim_suffix("-")
	if slug == "" or slug.begins_with(AUTO_PREFIX.trim_suffix("-")):
		slug = "save-" + slug
	return dir().path_join("%s.%s" % [slug, EXT])


## A manual save named `save_name` already exists (it would be overwritten).
static func exists(save_name: String) -> bool:
	return FileAccess.file_exists(path_for(save_name))


static func auto_path(game_id: String) -> String:
	return dir().path_join("%s%s.%s" % [AUTO_PREFIX, game_id, EXT])


## Saves `game` under `save_name` (manual); returns "" or why not.
static func save_named(game: Game, save_name: String) -> String:
	var n := save_name.strip_edges().left(int(Config.SAVE["name_max"]))
	if n == "":
		return "Give the save a name"
	return write(path_for(n), header(game, n, false), capture(game))


## The game's autosave (one per game); older games' autosaves beyond
## Config.SAVE["keep_autosaves"] are deleted. Returns "" or why it failed.
static func autosave(game: Game) -> String:
	var err := write(auto_path(game.game_id), header(game, "Autosave", true), capture(game))
	if err == "":
		_prune_autosaves()
	return err


static func _prune_autosaves() -> void:
	var autos: Array[Dictionary] = []
	for coop in [false, true]:
		for e in list(coop):
			if str(e["path"]).get_file().begins_with(AUTO_PREFIX):
				autos.append(e)
	autos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["header"].get("saved_at", 0)) > int(b["header"].get("saved_at", 0)))
	for i in range(int(Config.SAVE["keep_autosaves"]), autos.size()):
		delete(str(autos[i]["path"]))


## What the save list shows.
static func header(game: Game, save_name: String, auto: bool) -> Dictionary:
	var vs: Array = []
	for v in game.villages:
		vs.append({"name": v.village_name, "color": v.color.to_html(false)})
	var h := {
		"name": save_name, "auto": auto, "game_id": game.game_id, "saved_at": int(Time.get_unix_time_from_system()),
		"play_time": game.stats.time, "wave": game.waves.wave, "difficulty": int(Settings.difficulty),
		"map_type": game.map.map_type, "seed": game.map.seed_value, "size": game.map.size,
		"villages": vs, "coop": game.villages.size() > 1,
	}
	if not game.map.meta.is_empty():
		h["map_name"] = MapJson.map_name(game.map)
	return h


## "Wave 7 · Highlands · Normal" (the Continue button, the list).
static func summary(h: Dictionary) -> String:
	var map_text: String = str(h["map_name"]) if h.has("map_name") else Settings.map_type_name(str(h.get("map_type", "")))
	return "%s · %s · %s" % [wave_text(int(h.get("wave", 0))), map_text, Settings.NAMES.get(int(h.get("difficulty", 1)), "Normal")]


## "Wave 7", or "Before wave 1" for a game saved before its first wave.
static func wave_text(wave: int) -> String:
	return "Wave %d" % wave if wave > 0 else "Before wave 1"


# --- capture ---------------------------------------------------------------------------

static func capture(game: Game) -> Dictionary:
	var world := game.world
	var b := {}
	b["game"] = {"game_id": game.game_id, "difficulty": int(Settings.difficulty), "clock": game.clock,
		"next_nid": game._next_nid, "ids": game._ids.duplicate(), "unlocks": game.unlocks.keys()}
	b["map"] = game.map.to_bytes()
	var live := PackedInt32Array()
	var objs: Array = []
	var guards: Array = []
	for o in world.map_objects:
		live.append(o.index)
		var d := {"i": o.index, "found": o.found_by.keys()}
		if not (o is Mine):
			d["net"] = o.net_state()
		if o is MonsterLair:
			d["woke_at"] = (o as MonsterLair).woke_at
		objs.append(d)
		if o is MonsterCamp:
			for e in (o as MonsterCamp).alive():
				guards.append({"camp": o.index, "k": e.kind, "hp": e.hp, "hs": e.hp_scale, "w": e.wave, "pos": e.grid_pos,
					"home": (e.behavior as CampBehavior).home if e.behavior is CampBehavior else e.grid_pos, "u": e.uid, "n": e.nid, "c": e.color})
	b["live"] = live
	b["objects"] = objs
	b["guards"] = guards
	b["trees"] = world._chopped.duplicate()
	var fog: Array = []
	for e in game.fog.explored_of:
		fog.append(e.duplicate())
	b["fog"] = fog
	var vs: Array = []
	for v in game.villages:
		var queue := PackedInt32Array()
		for site in v.construction.queue:
			queue.append(site.nid)
		vs.append({"name": v.village_name, "color": v.color.to_html(false), "fallen": v.fallen, "relics": Array(v.relics),
			"cd": v.corpses_delivered, "log": int(v.events.shown_level), "queue": queue,
			"eco": {"gold": v.economy.amount("gold"), "food": v.economy.amount("food"), "materials": v.economy.amount("materials")},
			"hero": _hero_state(v.hero)})
	b["villages"] = vs
	var buildings: Array = []
	for bd in world.buildings:
		buildings.append(_building_state(bd))
	b["buildings"] = buildings
	var civs: Array = []
	var units: Array = []
	for v in game.villages:
		for c in v.population.civilians:
			civs.append(_civilian_state(c))
		for u in v.army.units:
			units.append(_unit_state(u))
	b["civilians"] = civs
	b["units"] = units
	b["elementals"] = _elementals(game)
	var caravans: Array = []
	for n in world.objects.get_children():
		var ca := n as Caravan
		if ca and ca.is_processing():
			caravans.append({"n": ca.nid, "u": ca.uid, "from": ca.from.id, "to": ca.to.id, "cargo": ca.cargo.duplicate(), "tax": ca.tax, "pos": ca.grid_pos})
	b["caravans"] = caravans
	var corpses: Array = []
	for c in game.corpses.corpses:
		if is_instance_valid(c):
			corpses.append({"k": c.kind, "w": c.wave, "pos": c.grid_pos, "tl": c.time_left, "u": c.uid, "n": c.nid, "eg": c.extra_gold, "hs": c.hp_scale})
	b["corpses"] = corpses
	b["waves"] = {"wave": game.waves.wave, "countdown": game.waves.countdown}
	b["stats"] = game.stats.save_state()
	return b


static func _building_state(bd: Building) -> Dictionary:
	var d := {"k": bd.kind, "t": bd.tile, "v": bd.village.id if bd.village else -1, "u": bd.uid, "n": bd.nid,
		"c": bd.complete, "p": bd.progress, "ps": bd.paid_share, "up": bd.upgrading, "upp": bd.upgrade_progress,
		"upt": bd.upgrade_time, "td": bd.tearing_down, "tdp": bd.teardown_progress}
	if bd is Hut:
		d["ru"] = (bd as Hut).ruined
	if bd is Tower:
		d["lvl"] = (bd as Tower).level
	if bd is Barracks:
		d["lvl"] = (bd as Barracks).level
	if bd is Farm:
		d["st"] = (bd as Farm).stored
	return d


static func _civilian_state(c: Civilian) -> Dictionary:
	var d := {"r": c.role, "v": c.village.id, "u": c.uid, "n": c.nid, "hut": c.hut.nid if is_instance_valid(c.hut) else 0,
		"hp": c.hp, "home": c.at_home, "pos": c.grid_pos}
	if c is Farmer:
		var fa := c as Farmer
		d["farm"] = fa.farm.nid if is_instance_valid(fa.farm) else 0
		d["carry"] = fa.carrying
	elif c is Forester:
		var fo := c as Forester
		d["camp"] = fo.camp.nid if is_instance_valid(fo.camp) else 0
		d["tree"] = fo.tree
		d["carry"] = fo.carrying
	elif c is Gatherer:
		d["job"] = _gather_state((c as Gatherer).job)
	elif c is Miner:
		var m := c as Miner
		d["mine"] = m.mine.index if is_instance_valid(m.mine) else -1
		d["ms"] = int(m.state)
	return d


static func _gather_state(job: GatherJob) -> Dictionary:
	return {"carried": Array(job.carried), "gold": job.carried_gold, "loot": job.loot.duplicate()}


static func _hero_state(h: Hero) -> Dictionary:
	var ex := h.jobs[Hero.Mode.EXPLORE] as HeroExploreJob
	var carry: Dictionary = ex.carrying.duplicate() if ex.task == HeroExploreJob.Task.CARRYING else {}
	return {"n": h.nid, "mode": int(h.mode), "xp": h.xp, "lvl": h.level, "hp": h.hp, "dead": h.dead, "pos": h.grid_pos,
		"home": h.at_home, "sup": h.support_target.id if h.support_target else -1,
		"camp": h.camp_target.index if is_instance_valid(h.camp_target) else -1,
		"cry": [h.cry_bonus, h.cry_until], "gather": _gather_state(h.jobs[Hero.Mode.GATHER] as GatherJob),
		"carry": carry, "from": ex.carrying_from if not carry.is_empty() else ""}


static func _unit_state(u: MilitaryUnit) -> Dictionary:
	var d := {"k": u.kind, "lvl": u.level, "st": int(u.state), "post": u.post.nid if is_instance_valid(u.post) else 0, "slot": u.slot,
		"hp": u.hp, "rl": u.revive_left, "rap": u.revive_at_post, "txp": u.train_xp, "u": u.uid, "v": u.village.id, "n": u.nid,
		"oo": u.original_owner.id if u.original_owner else -1, "tt": u.travel_to.id if u.travel_to else -1,
		"cry": [u.cry_bonus, u.cry_until]}
	if is_instance_valid(u.walker) and not u.out:
		d["pos"] = (u.walker as Soldier).grid_pos
	return d


## Elementals of summoners on duty (not out on a sortie: those come back to their bench on a load).
static func _elementals(game: Game) -> Array:
	var out: Array = []
	for v in game.villages:
		for u in v.army.units:
			if u.state != MilitaryUnit.State.STATIONED or u.out or not (u.behavior is SummonerBehavior):
				continue
			for e in (u.behavior as SummonerBehavior).summons:
				if is_instance_valid(e) and not e.dead:
					out.append({"by": u.nid, "n": e.nid, "u": e.uid, "sm": e.summon, "hp": e.hp, "mhp": e.max_hp, "dmg": e.damage,
						"home": e.home, "pos": e.grid_pos, "cry": [e.cry_bonus, e.cry_until]})
	return out


# --- restore ---------------------------------------------------------------------------

## What the save list's and the lobby's preview may show of the map: the
## explored land, of all villages together (single player: its fog; co-op:
## every player's, so they can tell the villages apart).
static func seen(b: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	for e: PackedByteArray in b.get("fog", []):
		if out.is_empty():
			out = e.duplicate()
		elif e.size() == out.size():
			for i in e.size():
				if e[i] == 1:
					out[i] = 1
	return out


## The map the game is built on (Game.preset_map).
static func saved_map(b: Dictionary) -> MapData:
	return MapData.from_bytes(b["map"])


## After World.setup built the saved map: the map objects as they were
## (the gone ones removed), tree chopping, and every village's fog.
static func restore_world(game: Game, b: Dictionary) -> void:
	var world := game.world
	var live := {}
	for i in (b["live"] as PackedInt32Array):
		live[i] = true
	for o in world.map_objects.duplicate():
		if not live.has(o.index):
			world.remove_map_object(o)
	for d: Dictionary in b["objects"]:
		var o := world.map_object(int(d["i"]))
		if o == null:
			continue
		for vid in d["found"]:
			o.found_by[int(vid)] = true
		if d.has("net"):
			o.apply_net_state(d["net"])
		if o is MonsterLair:
			(o as MonsterLair).woke_at = int(d.get("woke_at", -1))
			o.refresh()
	world.restore_chopped(b["trees"])
	var fog: Array = b["fog"]
	for vid in mini(fog.size(), game.fog.explored_of.size()):
		var e: PackedByteArray = fog[vid]
		if e.size() == game.fog.explored_of[vid].size():
			game.fog.explored_of[vid] = e


## Instead of Village.setup (the villages set up empty, Village.setup_restored):
## everything the save holds, without spending, logging, counting or assigning.
static func restore_entities(game: Game, b: Dictionary) -> void:
	var g: Dictionary = b["game"]
	game._next_nid = maxi(game._next_nid, int(g["next_nid"]))
	game.clock = float(g["clock"])
	for key in g["unlocks"]:
		game.unlocks[key] = true
		game.world.on_unlocked(key)
	_restore_buildings(game, b["buildings"])
	for i in mini(game.villages.size(), (b["villages"] as Array).size()):
		var v := game.villages[i]
		var d: Dictionary = b["villages"][i]
		v.fallen = bool(d["fallen"])
		v.relics.assign(d["relics"])
		v.corpses_delivered = int(d["cd"])
		v.economy.set_amounts(d["eco"])
		v.events.shown_level = int(d["log"]) as EventLog.Level
		for nid in (d["queue"] as PackedInt32Array):
			var site := game.entity(nid) as Building
			if site and site.has_work() and not v.construction.queue.has(site):
				v.construction.queue.append(site)
	var field: Array[Civilian] = []  # (out in the field: they ask what to do once everything is back)
	for d: Dictionary in b["civilians"]:
		_restore_civilian(game, d, field)
	for i in mini(game.villages.size(), (b["villages"] as Array).size()):
		_restore_hero(game, game.villages[i].hero, b["villages"][i]["hero"], field)
	for d: Dictionary in b["units"]:
		_restore_unit(game, d)
	for d: Dictionary in b["elementals"]:
		_restore_elemental(game, d)
	for d: Dictionary in b["caravans"]:
		_restore_caravan(game, d)
	for d: Dictionary in b["corpses"]:
		_restore_corpse(game, d)
	for d: Dictionary in b["guards"]:
		var camp := game.world.map_object(int(d["camp"])) as MonsterCamp
		if camp:
			camp.restore_guard(d)
	var w: Dictionary = b["waves"]
	game.waves.wave = int(w["wave"])
	game.waves.countdown = float(w["countdown"])
	# Everything is back (sites, corpses, sacks, guards): whoever stands out in
	# the field asks once what to do from there.
	for c in field:
		c.resume_work()
	game._ids = (g["ids"] as Dictionary).duplicate()  # (last: restoring some of the above counted)
	for v in game.villages:
		v.population.changed.emit()
		v.army.changed.emit()
		v.construction.changed.emit()
	game.world.refresh_village_labels()


static func _restore_buildings(game: Game, list: Array) -> void:
	var world := game.world
	# The village pieces stand already (World built them from the map): they
	# take their saved ids; everything else is built anew.
	var pieces := {}
	for bd in world.buildings:
		if World.PIECE_SCRIPTS.has(bd.kind):
			pieces["%s@%s" % [bd.kind, bd.tile]] = bd
			game.unregister(bd.nid)
	var matched := {}
	for d: Dictionary in list:
		var kind: String = d["k"]
		var bd: Building
		if World.PIECE_SCRIPTS.has(kind):
			bd = pieces.get("%s@%s" % [kind, d["t"]])
			if bd == null:
				continue
			matched[bd] = true
			bd.nid = int(d["n"])
			bd.uid = int(d["u"])
			game.register_as(bd, bd.nid)
		else:
			var vid := int(d["v"])
			if vid < 0 or vid >= game.villages.size():
				continue
			bd = Construction.KIND_SCRIPTS[kind].new()
			bd.village = game.villages[vid]
			bd.uid = int(d["u"])
			bd.nid = int(d["n"])
			game.register_as(bd, bd.nid)
			bd.setup(game, kind, d["t"], bool(d["c"]))
			world.add_building(bd)
		_apply_building(bd, d)
	for bd in pieces.values():
		if not matched.has(bd):
			bd.nid = game.register(bd)


static func _apply_building(bd: Building, d: Dictionary) -> void:
	bd.complete = bool(d["c"])
	bd.progress = float(d["p"])
	bd.paid_share = float(d["ps"])
	bd.upgrading = bool(d["up"])
	bd.upgrade_progress = float(d["upp"])
	bd.upgrade_time = float(d["upt"])
	if bd is Hut:
		(bd as Hut).ruined = bool(d.get("ru", false))
	if bd is Tower:
		(bd as Tower).level = int(d.get("lvl", 1))
	if bd is Barracks:
		(bd as Barracks).level = int(d.get("lvl", 1))
	if bd is Farm:
		(bd as Farm).stored = float(d.get("st", 0.0))
	if bool(d["td"]):
		bd.set_tearing_down(true)
		bd.teardown_progress = float(d["tdp"])
	bd.refresh()
	bd.game.world.refresh_building(bd)


static func _restore_civilian(game: Game, d: Dictionary, field: Array[Civilian]) -> void:
	var v := game.villages[int(d["v"])]
	var role: String = d["r"]
	var civ: Civilian = Population.ROLE_SCRIPTS[role].new()
	civ.village = v
	civ.setup(game, role)
	civ.uid = int(d["u"])
	civ.nid = int(d["n"])
	game.register_as(civ, civ.nid)
	var hut := game.entity(int(d["hut"])) as Hut
	if hut and hut.resident == null:
		hut.resident = civ
		civ.hut = hut
	game.world.objects.add_child(civ)
	v.population.civilians.append(civ)
	civ.hp = clampf(float(d["hp"]), 1.0, civ.max_hp)
	var pos: Vector2 = d["pos"]
	var home := bool(d["home"])
	if civ is Farmer:
		var farm := game.entity(int(d["farm"])) as Farm
		if farm and farm.worker == null:
			farm.worker = civ
			(civ as Farmer).assign(farm)
			farm.refresh()
		(civ as Farmer).carrying = int(d["carry"])
	elif civ is Forester:
		var f := civ as Forester
		var camp := game.entity(int(d["camp"])) as WorkerCamp
		if camp and camp.worker == null:
			camp.worker = civ
			f.assign(camp)
			camp.refresh()
		var tree: Vector2i = d["tree"]
		if f.camp and game.world.is_tree(tree):
			f.tree = tree
			game.world.claim_tree(tree, f)
		f.carrying = int(d["carry"])
	elif civ is Gatherer:
		_apply_gather((civ as Gatherer).job, d["job"])
	elif civ is Miner:
		var m := civ as Miner
		var mine := game.world.map_object(int(d["mine"])) as Mine
		if mine and int(d["ms"]) == Miner.State.WORKING and mine.is_free():
			m.mine = mine
			mine.worker = m
			m.state = Miner.State.WORKING
			civ.set_grid_pos(pos)
			civ.at_home = false
			civ.visible = false
			return
		if mine:
			m.mine = mine
			m.state = Miner.State.TO_MINE
			if home:
				m.assign(mine)
				return
	if not home:
		civ.set_grid_pos(pos)
		civ._set_home(false)
		field.append(civ)


static func _apply_gather(job: GatherJob, d: Dictionary) -> void:
	job.carried.assign(d["carried"])
	job.carried_gold = int(d["gold"])
	job.loot = (d["loot"] as Dictionary).duplicate()


static func _restore_hero(game: Game, h: Hero, d: Dictionary, field: Array[Civilian]) -> void:
	h.nid = int(d["n"])
	game.register_as(h, h.nid)
	h.level = int(d["lvl"])
	h.max_hp = Config.hero_stat("hp", h.level)
	h.xp = int(d["xp"])
	h.mode = int(d["mode"]) as Hero.Mode
	var sup := int(d["sup"])
	h.support_target = game.villages[sup] if sup >= 0 and sup < game.villages.size() else null
	var camp := game.world.map_object(int(d["camp"])) as MonsterCamp
	h.camp_target = camp if camp and not camp.cleared else null
	h.cry_bonus = float(d["cry"][0])
	h.cry_until = float(d["cry"][1])
	if bool(d["dead"]):
		h.dead = true
		h.hp = 0.0
		h.remove_from_group("melee_defenders")
		h.visible = false
		return
	h.hp = clampf(float(d["hp"]), 1.0, h.max_hp)
	h.set_grid_pos(d["pos"])
	h._set_home(bool(d["home"]))
	_apply_gather(h.jobs[Hero.Mode.GATHER] as GatherJob, d["gather"])
	var carry: Dictionary = d["carry"]
	if not carry.is_empty():
		var ex := h.jobs[Hero.Mode.EXPLORE] as HeroExploreJob
		ex.carrying = carry.duplicate()
		ex.carrying_from = str(d["from"])
		ex.task = HeroExploreJob.Task.CARRYING
	if not h.at_home:
		field.append(h)
	h.changed.emit()


static func _restore_unit(game: Game, d: Dictionary) -> void:
	var v := game.villages[int(d["v"])]
	var u := MilitaryUnit.new(str(d["k"]))
	u.village = v
	var oo := int(d["oo"])
	u.original_owner = game.villages[oo] if oo >= 0 and oo < game.villages.size() else v
	u.uid = int(d["u"])
	u.nid = int(d["n"])
	game.register_as(u, u.nid)
	u.level = clampi(int(d["lvl"]), 0, Config.MAX_UNIT_LEVEL - 1)
	u.hp = minf(float(d["hp"]), u.max_hp())
	u.train_xp = float(d["txp"])
	u.revive_left = float(d["rl"])
	u.cry_bonus = float(d["cry"][0])
	u.cry_until = float(d["cry"][1])
	var tt := int(d["tt"])
	u.travel_to = game.villages[tt] if tt >= 0 and tt < game.villages.size() else null
	u.state = int(d["st"]) as MilitaryUnit.State
	u.slot = int(d["slot"])
	var post := game.entity(int(d["post"])) as MilitaryPost
	v.army.units.append(u)
	var pos: Vector2 = d.get("pos", Vector2(v.center))
	match u.state:
		MilitaryUnit.State.STATIONED:
			if post and post.can_garrison() and _slot_free(post, u.slot) and u.fits(post.post_kind()):
				u.post = post
				post.set_slot(u.slot, u)
			else:
				u.state = MilitaryUnit.State.RESERVE
		MilitaryUnit.State.DOWNED:
			if bool(d["rap"]) and post and _slot_free(post, u.slot):
				u.post = post
				u.revive_at_post = true
				post.set_slot(u.slot, u)
		MilitaryUnit.State.MARCHING:
			if post and post.can_garrison() and _slot_free(post, u.slot):
				u.post = post
				post.incoming_slots[u.slot] = u
				post.refresh()
				v.army.resume_walk(u, pos, post.work_tile())
			else:
				u.state = MilitaryUnit.State.RETURNING
				v.army.resume_walk(u, pos, v.center)
		MilitaryUnit.State.RETURNING:
			v.army.resume_walk(u, pos, v.center)
		MilitaryUnit.State.TRAVELLING:
			if u.travel_to:
				v.army.resume_walk(u, pos, u.travel_to.center)
			else:
				u.state = MilitaryUnit.State.RETURNING
				v.army.resume_walk(u, pos, v.center)


static func _slot_free(post: MilitaryPost, slot: int) -> bool:
	post.fit_slots()
	return slot >= 0 and slot < post.capacity() and post.slots[slot] == null and post.incoming_slots[slot] == null


static func _restore_elemental(game: Game, d: Dictionary) -> void:
	var u := game.entity(int(d["by"])) as MilitaryUnit
	if u == null or u.state != MilitaryUnit.State.STATIONED or not (u.behavior is SummonerBehavior):
		return
	var e: EarthElemental = ELEMENTAL_SCRIPT.new()
	e.village = u.village
	var pos: Vector2 = d["pos"]
	e.setup(game, d["home"], Vector2i(pos.round()), float(d["mhp"]), float(d["dmg"]), str(d["sm"]))
	e.set_grid_pos(pos)
	e.hp = clampf(float(d["hp"]), 1.0, e.max_hp)
	e.cry_bonus = float(d["cry"][0])
	e.cry_until = float(d["cry"][1])
	e.uid = int(d["u"])
	e.nid = int(d["n"])
	game.register_as(e, e.nid)
	game.world.objects.add_child(e)
	(u.behavior as SummonerBehavior).summons.append(e)


static func _restore_caravan(game: Game, d: Dictionary) -> void:
	var from := int(d["from"])
	var to := int(d["to"])
	if from < 0 or from >= game.villages.size() or to < 0 or to >= game.villages.size():
		return
	var ca: Caravan = CARAVAN_SCRIPT.new()
	ca.setup(game, game.villages[from], game.villages[to], (d["cargo"] as Dictionary).duplicate(), float(d["tax"]))
	ca.uid = int(d["u"])
	ca.nid = int(d["n"])
	game.register_as(ca, ca.nid)
	ca.set_grid_pos(d["pos"])
	ca.follow(game.world.pathing.find_path(ca.current_tile(), ca.to.center))
	game.world.objects.add_child(ca)


static func _restore_corpse(game: Game, d: Dictionary) -> void:
	var c: Corpse = CORPSE_SCRIPT.new()
	c.setup(game, str(d["k"]), int(d["w"]), d["pos"])
	c.time_left = float(d["tl"])
	c.extra_gold = int(d["eg"])
	c.hp_scale = float(d["hs"])
	c.uid = int(d["u"])
	c.nid = int(d["n"])
	game.register_as(c, c.nid)
	game.world.decals.add_child(c)
	game.corpses.corpses.append(c)
