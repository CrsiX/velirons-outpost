class_name BalanceMilitary
extends BalancePart
## The military part of the balancing bot's player: what differs between the
## policies (the profile, Config.BALANCE_PROFILES). Defence buildings (towers,
## barracks, training grounds) and where they go, which units man them, tower
## and barracks levels, gold into unit levels and specialisations, and calling
## the next wave early. It holds back while the economy needs the material
## (BalancePlayer.no_farm / repair_wanted / want_materials).

var _profile: Dictionary
## Posts' round-robin counters for choosing a unit kind.
var _turn := {"tower": 0, "wall": 0, "barracks": 0}
## Gold put by for the unit upgrade it saves up for (0: none).
var _saving := 0
var _approach: Array[Vector2i] = []
## Filled by _covered_roads: road -> how well the other sort of post backs it up.
var _support: Dictionary = {}
## Game clock since when only water monsters have been left in the wave.
var _water_only_since := -1.0
## Post nid -> [unit nid, game clock]: the post a unit left for the training
## grounds; nobody else is sent there meanwhile.
var _held: Dictionary = {}


func _init(p_player: BalancePlayer) -> void:
	super(p_player)
	_profile = p_player.profile


## One round: buildings, then units on posts, then upgrades.
func think() -> void:
	_saving = 0
	_defence_buildings()
	_water_defence()
	_training()
	_fill_posts()
	_tower_upgrades()
	_unit_upgrades()


# --- helpers ----------------------------------------------------------------------------

func _posts() -> Array[MilitaryPost]:
	var out: Array[MilitaryPost] = []
	for b in village.buildings():
		if b is MilitaryPost and b.can_garrison() and not b.tearing_down:
			out.append(b)
	return out


## Finished posts with a free slot (a bench, a tower nobody mans).
func _free_posts() -> int:
	var n := 0
	for post in _posts():
		if not (post is TrainingGrounds) and post.free_slot() >= 0 and not _held.has(post.nid):
			n += 1
	return n


# --- defence buildings -----------------------------------------------------------------------

func _defence_buildings() -> void:
	if p.no_farm or p.repair_wanted or p.economy.economy_first() or p.economy.site_open():
		return
	if _training_due():
		_place("training")  # (before the towers: they would keep taking the material)
		return
	var tw: Array = _profile["towers"]
	var want_towers := mini(int(tw[2]), int(tw[0]) + int(floorf(float(tw[1]) * _wave())))
	# (No new post while two stand empty: nobody to man them.)
	if _free_posts() < 2:
		if _buildings_of("tower").size() < want_towers:
			_place("tower")
		if _buildings_of("barracks").size() < _scheduled(_profile["barracks"]):
			_place("barracks")


## The wave ends only when its water monsters are dead: once they are all that
## is left (and out of reach), a watchtower goes up on the shore near the nearest.
func _water_defence() -> void:
	var foes: Array[Enemy] = []
	for n in p.get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if not e.dead and not e.wild():
			foes.append(e)
	if not _in_wave() or foes.is_empty() or not foes.all(func(e: Enemy) -> bool: return e.habitat() == "water"):
		_water_only_since = -1.0
		return
	if _water_only_since < 0.0:
		_water_only_since = game.clock
	if game.clock - _water_only_since < 15.0 or float(p.no_spot.get("water", -1.0)) > game.clock:
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
	p.no_spot["water"] = game.clock + 60.0
	if best != Vector2i(-1, -1):
		_cmd("place_building", {"kind": "tower", "tile": best})


func _spot_context(kind: String) -> Dictionary:
	return _covered_roads(kind) if kind == "tower" or kind == "barracks" else {}


func _score(kind: String, t: Vector2i, size: int, ctx: Dictionary) -> float:
	if kind != "tower" and kind != "barracks":
		return super._score(kind, t, size, ctx)  # training grounds, light stones: close to home
	var c := _centre(t, size)
	var dist := c.distance_to(Vector2(village.center))
	var reach: float = Config.TOWER_RANGE["tower"] if kind == "tower" else float(Config.BARRACKS_LEVELS[0]["range"])
	var gain := 0
	var support := 0.0
	for r in _approach_roads():
		if not ctx.has(r) and c.distance_to(Vector2(r)) <= reach - 0.2:
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


func _crowded(c: Vector2) -> bool:
	for post in village.buildings():
		if post is MilitaryPost and not (post is TrainingGrounds) and Vector2(post.tile).distance_to(c) < float(_params["tower_spacing"]):
			return true
	return false


## Road tiles within approach_steps of one of the village's gates: where the
## enemies walk the last stretch before the gate.
func _approach_roads() -> Array[Vector2i]:
	if p.approach_version == game.world.pathing.version and not _approach.is_empty():
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
	p.approach_version = game.world.pathing.version
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
	for post in village.buildings():
		if not (post is MilitaryPost) or post is TrainingGrounds or post.tearing_down:
			continue
		var reach: float = (post as Tower).range_tiles() if post is Tower else float(Config.BARRACKS_LEVELS[0]["range"])
		var pc := _centre(post.tile, post.size)
		var own := not together or (post is Tower) == (kind == "tower")
		for r in _approach_roads():
			if pc.distance_to(Vector2(r)) > reach:
				continue
			if own:
				out[r] = true
			elif post is Tower:
				_support[r] = maxi(int(_support.get(r, 0)), post.level)
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
	for post in _posts():
		if post.free_slot() < 0 or post is TrainingGrounds or _held.has(post.nid):
			continue
		var cls := _post_class(post)
		var u := _reserve_unit_for(post)
		if u == null:
			var kind := _next_kind(cls)
			if kind == "" or not _can_afford(Config.MILITARY[kind]["cost"]):
				continue
			var r := _cmd("recruit_unit", {"kind": kind})
			if not r["ok"]:
				continue
			_turn[cls] += 1  # (only once bought: the dearer kind waits for its gold)
			u = game.entity(int(r["id"]))
		_cmd("station_unit", {"unit": u.nid, "post": post.nid})


func _post_class(post: MilitaryPost) -> String:
	return "barracks" if post is Barracks else ("wall" if post.kind == "wall_tower" else "tower")


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
	var kinds: Array = _profile[key]
	if kinds.is_empty() and cls == "wall":
		kinds = _profile["tower_units"]
	var post := "barracks" if cls == "barracks" else "tower"
	var usable: Array[String] = []
	for k: String in kinds:
		if game.is_unlocked(k) and (Config.MILITARY[k]["posts"] as Array).has(post):
			usable.append(k)
	if usable.is_empty():
		return "" if kinds.is_empty() else (kinds[0] if game.is_unlocked(kinds[0]) else "")
	return usable[int(_turn[cls]) % usable.size()]


# --- the training grounds ---------------------------------------------------------------

## The hero's XP levels a unit up for free, and her XP is worth most when it
## takes a unit through whole levels: a unit goes to the grounds only when her
## XP covers "train_levels" levels of it (the weakest unit, the cheapest per
## level; one from a post leaves it free for that time), and goes back to its
## post once the hero is done (or at once when a wave starts, or her XP no
## longer covers a level: a unit that can't be levelled completely doesn't
## stay there).
func _training() -> void:
	_prune_held()
	for b in _buildings_of("training"):
		var g := b as TrainingGrounds
		if not g.working():
			continue
		var t := g.garrison
		if t != null and t.state == MilitaryUnit.State.STATIONED:
			if not _keep_at_grounds(t):
				_send_back(t)
		elif t == null and g.free_slot() >= 0 and not _in_wave():
			_send_to_grounds(g)


func _hero_xp() -> int:
	var h := village.hero
	return h.xp if is_instance_valid(h) and not h.dead else 0


func _keep_at_grounds(t: MilitaryUnit) -> bool:
	if _in_wave():
		return false
	if p.hero.in_training_run():
		return true
	return t.nid != p.hero.finished_unit and _train_levels(t) >= 1 and float(_hero_xp()) >= _train_need(t, 1)


## The weakest unit her XP can take through "train_levels" levels goes to the grounds.
func _send_to_grounds(g: TrainingGrounds) -> void:
	var best: MilitaryUnit = null
	for u in village.army.units:
		if not u.can_train() or u.bound or u.nid == p.hero.finished_unit:
			continue
		var onpost := u.state == MilitaryUnit.State.STATIONED and u.post != null and not (u.post is TrainingGrounds)
		if (u.state != MilitaryUnit.State.RESERVE and not onpost) or _train_levels(u) < int(Config.BALANCE_HERO["train_levels"]):
			continue
		if float(_hero_xp()) >= _train_need(u, _train_levels(u)) and (best == null or u.level < best.level):
			best = u
	if best == null:
		return
	if best.state == MilitaryUnit.State.RESERVE:
		_cmd("station_unit", {"unit": best.nid, "post": g.nid})
		return
	var home := best.post
	if _cmd("move_unit", {"unit": best.nid, "post": g.nid})["ok"]:
		_held[home.nid] = [best.nid, game.clock]


## Back to its post: the one it left, else a free one, else the place of a
## weaker unit (which goes to the reserve), else to the reserve itself.
func _send_back(t: MilitaryUnit) -> void:
	var home: MilitaryPost = null
	for nid: int in _held:
		if int(_held[nid][0]) == t.nid:
			home = game.entity(nid) as MilitaryPost
	if home == null or home.free_slot() < 0 or village.army.transfer_error(t, home) != "":
		home = _free_post_for(t)
	if home == null:
		var weakest: MilitaryUnit = null
		for u in village.army.units:
			if u.state == MilitaryUnit.State.STATIONED and u.post != null and not (u.post is TrainingGrounds) \
					and t.fits(u.post.post_kind()) and u.level < t.level and (weakest == null or u.level < weakest.level):
				weakest = u
		if weakest == null:
			_cmd("withdraw_unit", {"unit": t.nid})  # (nothing better to do for it: the reserve)
			return
		_held[weakest.post.nid] = [t.nid, game.clock]
		_cmd("withdraw_unit", {"unit": weakest.nid})
		return  # (the post is free next round)
	if _cmd("move_unit", {"unit": t.nid, "post": home.nid})["ok"]:
		_held.erase(home.nid)


func _free_post_for(t: MilitaryUnit) -> MilitaryPost:
	for post in _posts():
		if not (post is TrainingGrounds) and post.free_slot() >= 0 and not _held.has(post.nid) \
				and t.fits(post.post_kind()) and village.army.transfer_error(t, post) == "":
			return post
	return null


## Holds that nobody came back to (the unit was downed, say) lapse.
func _prune_held() -> void:
	for nid: int in _held.keys():
		if game.clock - float(_held[nid][1]) > 180.0:
			_held.erase(nid)


# --- upgrades ----------------------------------------------------------------------------------

## (Not while a building waits for material: the material goes to that first,
## or gold would buy material for upgrades through it.)
func _tower_upgrades() -> void:
	if p.want_materials > 0 or p.economy.site_open() or _training_due():
		return
	var want_tower := _scheduled(_profile["tower_levels"], 1)
	var want_barracks := _scheduled(_profile["barracks_levels"], 1)
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
	var spare := _gold() - float(_params["gold_reserve"]) - float(_next_unit_cost()) - float(_training_reserve())
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
			break  # (saving up for the lowest one: the units wait)
		var r := _cmd("upgrade_unit", {"unit": u.nid, "to": to})
		if r["ok"]:
			spare -= float(cost.get("gold", 0))


## What `u` becomes next: its profile's specialisation as soon as it can, else
## its next level, "<none>" if there is nothing (to do) for it.
func _upgrade_choice(u: MilitaryUnit) -> String:
	var branch := str((_profile["branch"] as Dictionary).get(u.kind, ""))
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


## The training grounds are due (from the profile's wave) and not there yet:
## they come before other new posts and tower upgrades, and unit upgrades leave
## their gold alone, or the price would never be saved.
func _training_due() -> bool:
	var tr := int(_profile["training"])
	return tr > 0 and _wave() >= tr and _buildings_of("training").is_empty()


func _training_reserve() -> int:
	return int(Config.BUILDINGS["training"]["cost"].get("gold", 0)) if _training_due() else 0


## Gold of the unit an empty post waits for (0: none waits): upgrades
## leave it alone, or the dearer kinds would never be bought.
func _next_unit_cost() -> int:
	for post in _posts():
		if post is TrainingGrounds or post.free_slot() < 0 or _reserve_unit_for(post) != null:
			continue
		var kind := _next_kind(_post_class(post))
		if kind != "":
			return int(Config.MILITARY[kind]["cost"].get("gold", 0))
	return 0


# --- calling waves -------------------------------------------------------------------------------

func call_wave() -> void:
	if not bool(_profile.get("call_early", false)) or not game.waves.can_call() or game.waves.countdown < 10.0:
		return
	if village.hero.dead or _open_sites() > 0:
		return
	for post in _posts():
		if post.free_slot() >= 0:
			return
	if _gold() >= 100.0:
		return  # (something to upgrade still)
	p.early_calls += 1
	_cmd("call_wave")
