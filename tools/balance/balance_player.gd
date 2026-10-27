class_name BalancePlayer
extends Node
## The player of the balancing bot (docs/balance-bot-design.md): every
## Config.BALANCE_BOT["think_interval"] game seconds it looks at the village
## and does what a reasonably careful player would, through the same commands
## the UI sends (Commands). What it wants comes from a Config.BALANCE_PROFILES
## entry; how it goes about it (where it builds, what comes first) is here.
##
## Order of a round: cheats, hero, repairs, villagers, economy buildings,
## defence buildings, units on posts, upgrades, trading gold for material,
## calling the wave. Earlier steps get the resources first.

var game: Game
var village: Village
var profile_name := ""
var profile: Dictionary = {}
## Commands sent: type -> {"ok": n, "fail": n}; refused ones by reason.
var commands_sent: Dictionary = {}
var refusals: Dictionary = {}
## Gold that went into the army, by what it bought: "recruit <kind>",
## "level <kind>" (a level of the same kind), "branch <kind> -> <branch>"
## -> {"n": times, "gold": gold}.
var army_gold: Dictionary = {}
## Waves called early.
var early_calls := 0

var _timer := 0.0
var _params: Dictionary = Config.BALANCE_BOT
var _cheated := false
## Posts' round-robin counters for choosing a unit kind.
var _turn := {"tower": 0, "wall": 0, "barracks": 0}
## Kind -> game seconds before which it isn't tried to place again (no spot).
var _no_spot: Dictionary = {}
## Material the building held back by lack of it wants (0: nothing), and
## whether that is a hut or a farm / camp (the village's life: the gold kept
## for a unit upgrade goes into it too).
var _want_materials := 0
var _want_critical := false
## The material the critical needs lack (what _trade buys).
var _critical_lack := 0
## Gold put by for the unit upgrade it saves up for (_unit_upgrades; 0: none):
## _trade doesn't spend it on material.
var _saving := 0
## No farm stands (nor is one being built) though there may be room for one:
## the farm comes before every other use of material and before new mouths
## (the village would starve). Not while no spot was found (_no_spot).
var _no_farm := false
## The hero was sent to rest at low HP and stays there until healed
## (BALANCE_BOT "hero_rest_below" / "hero_rest_until").
var _hero_resting := false
## A repair (or hut rebuild) waits for material: nothing else spends any.
var _repair_wanted := false
## (game clock, building material the foresters brought so far), sampled
## for the material rate (BALANCE_BOT "material_window").
var _material_log: Array[Vector2] = []
## Game clock since when only water monsters have been left in the wave.
var _water_only_since := -1.0
var _approach: Array[Vector2i] = []
var _approach_version := -1
## Filled by _covered_roads: road -> how well the other sort of post backs it up.
var _support: Dictionary = {}


func setup(p_game: Game, p_profile: String) -> void:
	game = p_game
	village = game.player_village
	profile_name = p_profile
	profile = Config.BALANCE_PROFILES[p_profile]
	_timer = 0.5  # (the first decisions right away)


func _process(delta: float) -> void:
	if game == null or game.game_over:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = float(_params["think_interval"])
	_think()


func _think() -> void:
	_want_materials = 0
	_want_critical = false
	_critical_lack = 0
	_saving = 0
	_repair_wanted = false
	_log_materials()
	_cheats()
	_no_farm = _farm_wanted()
	_hero()
	_repairs()
	_villagers()
	_economy_buildings()
	_defence_buildings()
	_water_defence()
	_fill_posts()
	_rotate_training()
	_tower_upgrades()
	_unit_upgrades()
	_trade()
	_call_wave()


# --- helpers ----------------------------------------------------------------------------

func _cmd(type: String, args: Dictionary = {}) -> Dictionary:
	var what := ""
	if type == "recruit_unit":
		what = "recruit %s" % args["kind"]
	elif type == "upgrade_unit":
		var u: MilitaryUnit = game.entity(int(args["unit"]))
		what = ("level %s" % u.kind) if args["to"] == u.kind else ("branch %s -> %s" % [u.kind, args["to"]])
	var gold0 := _gold()
	var r := game.command(type, args)
	if what != "" and r["ok"]:
		var row: Dictionary = army_gold.get(what, {"n": 0, "gold": 0})
		row["n"] += 1
		row["gold"] += int(gold0 - _gold())
		army_gold[what] = row
	var sent: Dictionary = commands_sent.get(type, {"ok": 0, "fail": 0})
	sent["ok" if r["ok"] else "fail"] += 1
	commands_sent[type] = sent
	if not r["ok"]:
		var key := "%s: %s" % [type, r["error"]]
		refusals[key] = int(refusals.get(key, 0)) + 1
	return r


func _wave() -> int:
	return game.waves.wave


func _in_wave() -> bool:
	return game.waves.in_progress()


func _gold() -> float:
	return village.economy.amount("gold")


func _materials() -> float:
	return village.economy.amount("materials")


## The first target of a schedule [[from wave, value], ...] that applies now
## (the last entry whose wave has come), or `none`.
func _scheduled(table: Array, none: int = 0) -> int:
	var out := none
	for row: Array in table:
		if _wave() >= int(row[0]):
			out = int(row[1])
	return out


func _buildings_of(kind: String) -> Array[Building]:
	var out: Array[Building] = []
	for b in village.buildings():
		if b.kind == kind and not b.tearing_down:
			out.append(b)
	return out


func _posts() -> Array[MilitaryPost]:
	var out: Array[MilitaryPost] = []
	for b in village.buildings():
		if b is MilitaryPost and b.can_garrison() and not b.tearing_down:
			out.append(b)
	return out


## Finished posts with a free slot (a bench, a tower nobody mans).
func _free_posts() -> int:
	var n := 0
	for p in _posts():
		if not (p is TrainingGrounds) and p.free_slot() >= 0:
			n += 1
	return n


## Sites placed and not finished yet (the builders' queue).
func _open_sites() -> int:
	return village.construction.queue.size()


func _site_room() -> bool:
	return _open_sites() < village.population.count("builder") + int(_params["queue_slack"])


func _can_afford(cost: Dictionary) -> bool:
	return village.economy.can_afford(cost)


## Notes what's missing when only material is: anything essential holds the
## upgrades back (_want_materials); only what is critical (a repair, a hut,
## the farm when there is none) makes _trade buy material with gold
## (_want_critical): the foresters' material comes in by itself, gold is for
## the army.
func _note_missing(cost: Dictionary, essential := true, critical := false) -> void:
	if not essential:
		return
	var lack := int(cost.get("materials", 0)) - int(_materials())
	if lack > 0 and int(cost.get("gold", 0)) <= int(_gold()):
		_want_materials = maxi(_want_materials, lack)
		if critical:
			_want_critical = true
			_critical_lack = maxi(_critical_lack, lack)


# --- cheats (what a test of one unit line needs) -------------------------------------------

func _cheats() -> void:
	if _cheated:
		return
	_cheated = true
	for what: String in profile.get("cheats", []):
		_cmd("debug", {"what": what})


# --- the hero ----------------------------------------------------------------------------

func _hero() -> void:
	var h := village.hero
	if not is_instance_valid(h):
		return
	for i in 3:
		if not h.can_level_up():
			break
		_cmd("hero_level_up")
	var want := Hero.Mode.DEFEND
	var hp: Dictionary = profile["hero"]
	if _hero_low(h):
		want = Hero.Mode.REST  # (downed, she would lose all her XP)
	elif _in_wave():
		# Early waves are small: she goes on exploring (XP) unless the
		# village needs her.
		want = Hero.Mode.EXPLORE if _wave() < int(hp["explore_waves"]) and not _threat() else Hero.Mode.DEFEND
	elif _wave() < int(hp["explore_waves"]) or _unlock_wanted(h):
		want = Hero.Mode.EXPLORE  # (Explore goes for an awake unlock site first)
	elif _training_ready():
		want = Hero.Mode.TRAIN
	elif _wave() < int(hp["explore_waves"]) + 4 and _unexplored_share() > 0.5:
		want = Hero.Mode.EXPLORE
	if int(hp["attack_camps"]) > 0 and not _hero_resting and h.level + 1 >= int(hp["attack_camps"]) and not _in_wave() and not h.dead:
		var camp := _camp_to_attack()
		if camp != null and h.camp_target == null:
			_cmd("attack_camp", {"camp": camp.nid})
	if h.mode != want:
		_cmd("hero_mode", {"mode": want})


## An awake unlock site gives a unit the profile uses and nobody has
## unlocked yet (the hero may be on her way there already).
func _unlock_wanted(h: Hero) -> bool:
	var uses: Array = profile["tower_units"] + profile["wall_units"] + profile["barracks_units"]
	for o in game.world.map_objects:
		if o is UnlockSite and o.awake and not o.used and not game.is_unlocked(o.unlocks()) and uses.has(o.unlocks()) \
				and (o.claimed_by == null or not is_instance_valid(o.claimed_by) or o.claimed_by == h):
			return true
	return false


## Below "hero_rest_below" of her HP she rests until "hero_rest_until".
func _hero_low(h: Hero) -> bool:
	if h.dead:
		_hero_resting = false
		return false
	var share := h.hp / maxf(h.max_hp, 1.0)
	if share < float(_params["hero_rest_below"]):
		_hero_resting = true
	elif share >= float(_params["hero_rest_until"]):
		_hero_resting = false
	return _hero_resting


## An enemy of the wave inside the walls or near them (what draws the hero
## out in Defend).
func _threat() -> bool:
	var rect := village.rect
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.wild():
			continue
		if rect.has_point(e.current_tile()) or Hero.rect_distance(rect, e.grid_pos) <= Config.HERO["alert_radius"]:
			return true
	return false


func _training_ready() -> bool:
	for b in _buildings_of("training"):
		if (b as TrainingGrounds).is_ready_for_training():
			return true
	return false


func _unexplored_share() -> float:
	var explored: PackedByteArray = game.fog.explored_of[village.id]
	return 1.0 - float(explored.count(1)) / float(maxi(explored.size(), 1))


func _camp_to_attack() -> MonsterCamp:
	var best: MonsterCamp = null
	for o in game.world.map_objects:
		if o is MonsterCamp and o.attackable() and o.is_found_by(village):
			if best == null or Vector2(o.tile).distance_to(Vector2(village.center)) < Vector2(best.tile).distance_to(Vector2(village.center)):
				best = o
	return best


# --- repairs -----------------------------------------------------------------------------

## Repairs come before everything: ruined huts, then every building of ours
## that is devastated or below "repair_below" of its HP (the most broken
## first). One that waits for material holds back every other use of it
## (_repair_wanted), and only for these does _trade buy material.
func _repairs() -> void:
	var rebuild := Hut.rebuild_cost()
	if not village.construction.ruined_huts().is_empty():
		if _can_afford(rebuild):
			_cmd("rebuild_all_huts")
		else:
			_note_missing(rebuild, true, true)
			_repair_wanted = true
	var hurt: Array[Building] = []
	for b in village.buildings():
		if b is Hut or b is Warehouse or not b.can_repair():
			continue
		if b.devastated or b.hp < b.max_hp() * float(_params["repair_below"]):
			hurt.append(b)
	hurt.sort_custom(func(a: Building, b: Building) -> bool: return a.hp / a.max_hp() < b.hp / b.max_hp())
	for b in hurt:
		var cost := b.repair_cost()
		if _can_afford(cost):
			_cmd("repair", {"building": b.nid})
		else:
			_note_missing(cost, true, true)
			_repair_wanted = true
			break  # (the most broken one first)
	for o in game.world.map_objects:  # claimed ruins become watchtowers
		if o is RuinedTower and o.village == village and not _repair_wanted and _site_room() and _can_afford(RuinedTower.restore_cost()):
			_cmd("restore_ruin", {"ruin": o.nid})


# --- villagers ---------------------------------------------------------------------------

func _villagers() -> void:
	var pop := village.population
	var want: Dictionary = profile["villagers"]
	var rw := int(profile.get("retire_explorer_wave", 0))
	if rw > 0 and _wave() >= rw and pop.count("explorer") > 0:
		for c in pop.civilians:
			if c.role == "explorer" and pop.retire_error(c) == "":
				_cmd("retire_villager", {"civilian": c.nid})
				break
		want = want.duplicate()
		want["explorer"] = 0
	if _no_farm:
		return
	# A farm without its farmer comes first, as soon as the food pays for one
	# (min_food doesn't hold it back: the farmer is what brings food in).
	if _role_ready("farmer") and pop.count("farmer") < int(want.get("farmer", 0)):
		if pop.free_huts().is_empty():
			_make_room()
		elif pop.recruit_error("farmer") == "":
			_cmd("recruit_villager", {"role": "farmer"})
		return
	var seen := {}
	for role: String in profile["villager_order"]:
		seen[role] = int(seen.get(role, 0)) + 1
		var nth: int = seen[role]
		if nth > int(want.get(role, 0)) or pop.count(role) >= nth:
			continue
		if not _role_ready(role):
			continue
		var err := pop.recruit_error(role)
		if err == "No free hut (%d/%d)" % [pop.count(), pop.cap()]:
			return
		if err != "" or village.economy.amount("food") < float(Config.CIVILIANS[role]["cost"]["food"]) + float(_params["min_food"]):
			return
		_cmd("recruit_villager", {"role": role})


## A full village makes room for a farmer: its explorer retires, else a
## second gatherer.
func _make_room() -> void:
	var pop := village.population
	for role: String in ["explorer", "gatherer"]:
		if pop.count(role) <= (0 if role == "explorer" else 1):
			continue
		for c in pop.civilians:
			if c.role == role and pop.retire_error(c) == "":
				_cmd("retire_villager", {"civilian": c.nid})
				return


## Is there something for a villager of `role` to do (so recruiting one pays)?
func _role_ready(role: String) -> bool:
	match role:
		"farmer":
			return _buildings_of("farm").size() > village.population.count("farmer")
		"forester":
			return _buildings_of("camp").size() > village.population.count("forester")
		"gatherer":
			return _wave() >= 1
		"miner":
			return game.is_unlocked("miner") and _free_mine() != null
	return true


func _free_mine() -> Mine:
	for o in game.world.map_objects:
		if o is Mine and o.is_free() and o.is_found_by(village):
			return o
	return null


# --- economy buildings ---------------------------------------------------------------------

func _economy_buildings() -> void:
	var mine := _free_mine()
	if mine != null and not village.population.free_workers("miner").is_empty():
		_cmd("assign_miner", {"mine": mine.nid})
	# At least the profile's farms, and enough to feed the villagers and the army.
	var farms := maxi(_scheduled(profile["farms"]), ceili(village.population.upkeep() / Config.FARM_RATE))
	if village.economy.amount("food") < 40.0 and village.population.food_per_second() < 0.0:
		farms += 1  # the food is running out
	if _repair_wanted:
		return
	if _buildings_of("farm").size() < farms:
		_place("farm")
	_no_farm = _farm_wanted()
	if _no_farm:
		return
	if _buildings_of("camp").size() < _camps_wanted():
		_place("camp")


## Worker camps: the profile's "camps" (the first wave waits for them, see
## _economy_first), then one more while the foresters bring in less than
## "material_rate" per minute, up to "max_camps".
func _camps_wanted() -> int:
	var want := int(profile["camps"])
	var top := int(profile.get("max_camps", want))
	var have := _buildings_of("camp").size()
	if have >= want and have < top and _wave() >= 1 and _material_rate() >= 0.0 \
			and _material_rate() < float(profile.get("material_rate", 0.0)):
		return have + 1
	return want


## Building material per minute the foresters brought in over the last
## "material_window" s (-1 until that much time has passed).
func _material_rate() -> float:
	if _material_log.is_empty() or game.clock - _material_log[0].x < float(_params["material_window"]):
		return -1.0
	var first := _material_log[0]
	var last := _material_log[_material_log.size() - 1]
	return (last.y - first.y) / maxf(last.x - first.x, 1.0) * 60.0


func _log_materials() -> void:
	_material_log.append(Vector2(game.clock, game.stats.value(village.id, "earn.materials.foresters")))
	while _material_log.size() > 2 and game.clock - _material_log[1].x >= float(_params["material_window"]):
		_material_log.pop_front()


## Before the first wave the economy comes first: the camps the profile
## wants and their foresters before any new post.
func _economy_first() -> bool:
	return _wave() == 0 and _buildings_of("camp").size() < int(profile["camps"])


func _farm_wanted() -> bool:
	return _buildings_of("farm").is_empty() and float(_no_spot.get("farm", -1.0)) <= game.clock


# --- defence buildings -----------------------------------------------------------------------

func _defence_buildings() -> void:
	if _no_farm or _repair_wanted or _economy_first():
		return
	var tw: Array = profile["towers"]
	var want_towers := mini(int(tw[2]), int(tw[0]) + int(floorf(float(tw[1]) * _wave())))
	# (No new post while two stand empty: nobody to man them.)
	if _free_posts() < 2:
		if _buildings_of("tower").size() < want_towers:
			_place("tower")
		if _buildings_of("barracks").size() < _scheduled(profile["barracks"]):
			_place("barracks")
	var tr := int(profile["training"])
	if tr > 0 and _wave() >= tr and _buildings_of("training").is_empty():
		_place("training")


## The wave ends only when its water monsters are dead: once they are all that
## is left (and out of reach), a watchtower goes up on the shore near the nearest.
func _water_defence() -> void:
	var foes: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if not e.dead and not e.wild():
			foes.append(e)
	if not _in_wave() or foes.is_empty() or not foes.all(func(e: Enemy) -> bool: return e.habitat() == "water"):
		_water_only_since = -1.0
		return
	if _water_only_since < 0.0:
		_water_only_since = game.clock
	if game.clock - _water_only_since < 15.0 or float(_no_spot.get("water", -1.0)) > game.clock:
		return
	var cost: Dictionary = Config.BUILDINGS["tower"]["cost"]
	if not _can_afford(cost):
		_note_missing(cost)
		return
	var target := foes[0].current_tile()
	var best := Vector2i(-1, -1)
	var best_d := INF
	var reach: float = Config.TOWER_RANGE["tower"] + float(Config.TOWER_LEVELS[Config.TOWER_LEVELS.size() - 1]["range_bonus"])
	for dy in range(-7, 8):
		for dx in range(-7, 8):
			var t := target + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(target))
			if d <= reach - 0.3 and d < best_d and game.construction.placement_error("tower", t) == "":
				best = t
				best_d = d
	_no_spot["water"] = game.clock + 60.0
	if best != Vector2i(-1, -1):
		_cmd("place_building", {"kind": "tower", "tile": best})


## Places a `kind` where it is worth most; remembers when there was no spot.
func _place(kind: String) -> void:
	if not _site_room():
		return
	var cost: Dictionary = Config.BUILDINGS[kind]["cost"]
	if not _can_afford(cost):
		_note_missing(cost, true, kind == "farm" and _no_farm)  # (gold buys material only for a farm when there is none)
		return
	if float(_no_spot.get(kind, -1.0)) > game.clock:
		return
	var tile := _spot(kind)
	if tile == Vector2i(-1, -1):
		_no_spot[kind] = game.clock + 20.0  # (more land gets explored meanwhile)
		return
	var r := _cmd("place_building", {"kind": kind, "tile": tile})
	if not r["ok"]:
		_no_spot[kind] = game.clock + 10.0
	else:
		_approach_version = -1  # (the covered road changed)


func _spot(kind: String) -> Vector2i:
	var size: int = Config.BUILDINGS[kind]["size"]
	var c := village.center
	var radius := int(_params["scan_radius"])
	var best := Vector2i(-1, -1)
	var best_score := -INF
	var covered := _covered_roads(kind) if kind == "tower" or kind == "barracks" else {}
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var t := c + Vector2i(dx, dy)
			if game.construction.placement_error(kind, t) != "":
				continue
			var score := _score(kind, t, size, covered)
			if score > best_score:
				best_score = score
				best = t
	return best if best_score > -INF else Vector2i(-1, -1)


func _centre(t: Vector2i, size: int) -> Vector2:
	return Vector2(t) + Vector2(0.5, 0.5) * float(size - 1) if size % 2 == 0 else Vector2(t)


func _score(kind: String, t: Vector2i, size: int, covered: Dictionary) -> float:
	var c := _centre(t, size)
	var dist := c.distance_to(Vector2(village.center))
	match kind:
		"tower", "barracks":
			var reach: float = Config.TOWER_RANGE["tower"] if kind == "tower" else float(Config.BARRACKS_LEVELS[0]["range"])
			var gain := 0
			var support := 0.0
			for r in _approach_roads():
				if not covered.has(r) and c.distance_to(Vector2(r)) <= reach - 0.2:
					gain += 1
					support += float(_support.get(r, 0))
			if gain == 0 or _crowded(c):
				return -INF
			if not _params["barracks_support"]:
				return float(gain) - 0.15 * dist
			if kind == "barracks":
				# Where towers (the higher the better) shoot over its fighting
				# ground; anywhere only while there is no tower yet.
				if support <= 0.0 and not _support.is_empty():
					return -INF
				return support + 0.3 * float(gain) - 0.15 * dist
			return float(gain) + 0.5 * support - 0.15 * dist  # (support: a barracks' road)
		"farm":
			var meadow := 0
			var wet := false
			for f in Building.footprint(t, size):
				if game.map.zone(f) == "meadow":
					meadow += 1
				for nb in MapData.neighbors4(f):
					wet = wet or game.map.is_water(nb)
			# (Near a road only where nothing else fits: the rats.)
			var road := float(_params["farm_road_penalty"]) if _road_within(c, float(size) / 2.0 + float(_params["farm_road_gap"])) else 0.0
			return -dist - road + (4.0 if meadow * 2 > size * size else 0.0) + (2.0 if wet else 0.0)
		"camp":
			var trees := _trees_near(t, 7)
			return -INF if trees < 4 else float(trees) * 0.3 - dist * 0.5
		_:
			return -dist  # training grounds, light stones: close to home


func _crowded(c: Vector2) -> bool:
	for p in village.buildings():
		if p is MilitaryPost and not (p is TrainingGrounds) and Vector2(p.tile).distance_to(c) < float(_params["tower_spacing"]):
			return true
	return false


func _road_within(c: Vector2, r: float) -> bool:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var t := Vector2i(roundi(c.x) + dx, roundi(c.y) + dy)
			if Vector2(t).distance_to(c) <= r and game.map.is_road(t):
				return true
	return false


func _trees_near(t: Vector2i, r: int) -> int:
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if game.map.get_terrain(t + Vector2i(dx, dy)) == MapData.Terrain.FOREST:
				n += 1
	return n


## Road tiles within approach_steps of one of the village's gates: where the
## enemies walk the last stretch before the gate.
func _approach_roads() -> Array[Vector2i]:
	if _approach_version == game.world.pathing.version and not _approach.is_empty():
		return _approach
	_approach.clear()
	var radius := int(_params["scan_radius"]) + 4
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var t := village.center + Vector2i(dx, dy)
			if game.map.in_bounds(t) and game.map.is_road(t) and not game.map.in_village(t):
				var d := game.world.pathing.enemy_distance(t, village.id)
				if d <= int(_params["approach_steps"]):
					_approach.append(t)
	_approach_version = game.world.pathing.version
	return _approach


## Approach roads already inside the range of a post: any post's, or with
## BALANCE_BOT.barracks_support a post of `kind`'s own sort (towers and
## barracks then work together). Fills _support meanwhile: for a barracks,
## road -> the highest level of a tower covering it; for a tower, road -> 1
## where a barracks fights.
func _covered_roads(kind: String) -> Dictionary:
	var out := {}
	_support.clear()
	var together: bool = _params["barracks_support"]
	for p in village.buildings():
		if not (p is MilitaryPost) or p is TrainingGrounds or p.tearing_down:
			continue
		var reach: float = (p as Tower).range_tiles() if p is Tower else float(Config.BARRACKS_LEVELS[0]["range"])
		var pc := _centre(p.tile, p.size)
		var own := not together or (p is Tower) == (kind == "tower")
		for r in _approach_roads():
			if pc.distance_to(Vector2(r)) > reach:
				continue
			if own:
				out[r] = true
			elif p is Tower:
				_support[r] = maxi(int(_support.get(r, 0)), p.level)
			else:
				_support[r] = 1
	return out


## Whether a tower shoots over road a barracks fights on.
func _supports_barracks(t: Tower) -> bool:
	var tc := _centre(t.tile, t.size)
	for b in _buildings_of("barracks"):
		var bk := b as Barracks
		for r in _approach_roads():
			if bk.act_center().distance_to(Vector2(r)) <= bk.activation_range() and tc.distance_to(Vector2(r)) <= t.range_tiles():
				return true
	return false


# --- units on posts -------------------------------------------------------------------------

func _fill_posts() -> void:
	for p in _posts():
		if p.free_slot() < 0 or p is TrainingGrounds:
			continue
		var cls := "barracks" if p is Barracks else ("wall" if p.kind == "wall_tower" else "tower")
		var u := _reserve_unit_for(p)
		if u == null:
			var kind := _next_kind(cls)
			if kind == "" or not _can_afford(Config.MILITARY[kind]["cost"]):
				continue
			var r := _cmd("recruit_unit", {"kind": kind})
			if not r["ok"]:
				continue
			_turn[cls] += 1  # (only once bought: the dearer kind waits for its gold)
			u = game.entity(int(r["id"]))
		_cmd("station_unit", {"unit": u.nid, "post": p.nid})
	_fill_training()


## A unit waiting in the reserve that fits `post` (and is any use there).
func _reserve_unit_for(post: MilitaryPost) -> MilitaryUnit:
	for u in village.army.reserve():
		if not u.is_downed() and u.fits(post.post_kind()) and village.army.station_error(u, post) == "":
			return u
	return null


## The kind of the next unit for a post class: the profile's list in turn
## (_fill_posts moves the turn on once one is bought), kinds not unlocked yet
## skipped ("" if none fits).
func _next_kind(cls: String) -> String:
	var key: String = {"tower": "tower_units", "wall": "wall_units", "barracks": "barracks_units"}[cls]
	var kinds: Array = profile[key]
	if kinds.is_empty() and cls == "wall":
		kinds = profile["tower_units"]
	var post := "barracks" if cls == "barracks" else "tower"
	var usable: Array[String] = []
	for k: String in kinds:
		if game.is_unlocked(k) and (Config.MILITARY[k]["posts"] as Array).has(post):
			usable.append(k)
	if usable.is_empty():
		return "" if kinds.is_empty() else (kinds[0] if game.is_unlocked(kinds[0]) else "")
	return usable[int(_turn[cls]) % usable.size()]


## The training grounds hold one unit that the hero levels for free.
func _fill_training() -> void:
	for p in _posts():
		if not (p is TrainingGrounds) or p.free_slot() < 0:
			continue
		var u: MilitaryUnit = null
		for r in village.army.reserve():
			if not r.is_downed() and r.can_train() and village.army.station_error(r, p) == "":
				u = r
				break
		if u == null:
			var kinds: Array = profile["tower_units"] if not profile["tower_units"].is_empty() else profile["barracks_units"]
			var kind: String = kinds[0] if not kinds.is_empty() else ""
			if kind == "" or not game.is_unlocked(kind) or not _can_afford(Config.MILITARY[kind]["cost"]):
				continue
			var res := _cmd("recruit_unit", {"kind": kind})
			if not res["ok"]:
				continue
			u = game.entity(int(res["id"]))
		_cmd("station_unit", {"unit": u.nid, "post": p.nid})


## The unit trained for free at the grounds goes to a post where it fights,
## and the weakest unit of its kind takes its place there.
func _rotate_training() -> void:
	if _in_wave():
		return
	for b in _buildings_of("training"):
		var t := (b as TrainingGrounds).garrison
		if t == null or t.state != MilitaryUnit.State.STATIONED:
			continue
		var weakest: MilitaryUnit = null
		for p in _posts():
			if p is TrainingGrounds:
				continue
			for u in (p as MilitaryPost).units():
				if u.state == MilitaryUnit.State.STATIONED and u.fits(p.post_kind()) and t.fits(p.post_kind()) and (weakest == null or u.level < weakest.level):
					weakest = u
		if weakest != null and t.level >= weakest.level + 2 and village.army.swap_error(t, weakest) == "":
			_cmd("swap_units", {"unit": t.nid, "other": weakest.nid})


# --- upgrades ----------------------------------------------------------------------------------

## (Not while a building waits for material: the material goes to that first,
## or gold would buy material for upgrades through it.)
func _tower_upgrades() -> void:
	if _want_materials > 0:
		return
	var want_tower := _scheduled(profile["tower_levels"], 1)
	var want_barracks := _scheduled(profile["barracks_levels"], 1)
	var order: Array[Building] = []
	for b in village.buildings():
		if b is Tower or b is Barracks:
			order.append(b)
	if _params["barracks_support"]:
		# Towers over a barracks' ground first, then the other towers, the
		# barracks only once every tower has its level.
		var rank := func(b: Building) -> int:
			return 2 if b is Barracks else (0 if _supports_barracks(b as Tower) else 1)
		order.sort_custom(func(a: Building, b: Building) -> bool: return rank.call(a) < rank.call(b))
		var lagging := order.any(func(b: Building) -> bool: return b is Tower and b.level < mini(want_tower, (b as Tower).max_level()))
		if lagging:
			order = order.filter(func(b: Building) -> bool: return b is Tower)
	for b in order:
		if not b.can_upgrade():
			continue
		var want := want_barracks if b is Barracks else want_tower
		if b.level >= want:
			continue
		var cost: Dictionary = b.upgrade_cost()
		if not _can_afford(cost):
			_note_missing(cost, false)
			continue
		if _open_sites() <= village.population.count("builder") + int(_params["queue_slack"]):
			_cmd("upgrade_tower", {"building": b.nid})


## Gold into levels and specialisations, the lowest-level unit first.
func _unit_upgrades() -> void:
	var order: Array[MilitaryUnit] = []
	for u in village.army.units:
		if u.is_available():
			order.append(u)
	order.sort_custom(func(a: MilitaryUnit, b: MilitaryUnit) -> bool: return a.level < b.level)
	var spare := _gold() - float(_params["gold_reserve"]) - float(_next_unit_cost())
	for u in order:
		var to := _upgrade_choice(u)
		if to == "<none>":
			continue
		var opts := u.upgrade_options().filter(func(o: Dictionary) -> bool: return o["to"] == to and not o["archmage"])
		if opts.is_empty():
			continue
		var cost: Dictionary = opts[0]["cost"]
		if float(cost.get("gold", 0)) > spare:
			_saving = int(cost.get("gold", 0))
			break  # (saving up for the lowest one: _trade leaves it alone)
		var r := _cmd("upgrade_unit", {"unit": u.nid, "to": to})
		if r["ok"]:
			spare -= float(cost.get("gold", 0))


## What `u` becomes next: its profile's specialisation as soon as it can, else
## its next level, "<none>" if there is nothing (to do) for it.
func _upgrade_choice(u: MilitaryUnit) -> String:
	var branch := str((profile["branch"] as Dictionary).get(u.kind, ""))
	if branch != "":
		for o in u.upgrade_options():
			if o["to"] == branch and _branch_fits(u, branch):
				return branch
	if u.can_upgrade():
		return u.kind
	return "<none>"


## A specialisation that can't serve where the unit stands would send it back
## to the reserve: only with a barracks to go to.
func _branch_fits(u: MilitaryUnit, branch: String) -> bool:
	var posts: Array = Config.MILITARY[branch]["posts"]
	if u.post != null and posts.has(u.post.post_kind()):
		return true
	return not _buildings_of("barracks").is_empty() and posts.has("barracks")


# --- trading and calling waves -------------------------------------------------------------------

func _trade() -> void:
	if not bool(profile.get("buy_materials", false)) or not _want_critical:
		return
	var per: int = Config.MATERIALS_TRADE["materials"]
	var bundles := ceili(float(_critical_lack) / float(per))
	var gold_per: int = Config.MATERIALS_TRADE["gold"]
	# (Repairs and huts come before everything, an empty post's unit too.)
	var spare := int(_gold() - float(_params["gold_reserve"]))
	bundles = mini(bundles, spare / gold_per)
	if bundles >= 1:
		_cmd("buy_materials", {"bundles": bundles})


## Gold of the unit an empty post waits for (0: none waits): upgrades
## leave it alone, or the dearer kinds would never be bought.
func _next_unit_cost() -> int:
	for p in _posts():
		if p is TrainingGrounds or p.free_slot() < 0 or _reserve_unit_for(p) != null:
			continue
		var kind := _next_kind("barracks" if p is Barracks else ("wall" if p.kind == "wall_tower" else "tower"))
		if kind != "":
			return int(Config.MILITARY[kind]["cost"].get("gold", 0))
	return 0


func _call_wave() -> void:
	if not bool(profile.get("call_early", false)) or not game.waves.can_call() or game.waves.countdown < 10.0:
		return
	if village.hero.dead or _open_sites() > 0:
		return
	for p in _posts():
		if p.free_slot() >= 0:
			return
	if _gold() >= 100.0:
		return  # (something to upgrade still)
	early_calls += 1
	_cmd("call_wave")
