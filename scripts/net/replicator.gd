class_name Replicator
extends Node
## Keeps clients' worlds in step with the host's (docs/multiplayer-design.md §8.4).
##
## Host: SEND_INTERVAL times a second (real time) builds one snapshot per
## client with only what that player may know:
##   - entities: their own always; others' units, enemies and corpses only
##     where their village has surveillance; others' buildings once explored,
##     with live state only while watched (or public: the huts of the inner
##     3x3, which everybody sees),
##   - their village: economy, army, and everyone's standing / fallen,
##   - the wave, the game speed, game over,
##   - their log lines, toasts, floating texts and arrows they can see,
##     newly explored tiles and warning lights.
## Only changes since the last snapshot are sent.
## Client: creates, updates and removes the matching entities, which don't
## simulate (Game.is_client); units glide to their new positions.

const SEND_INTERVAL := 0.1
const ENEMY_SCRIPT := preload("res://scripts/units/enemy.gd")
const SOLDIER_SCRIPT := preload("res://scripts/units/soldier.gd")
const ELEMENTAL_SCRIPT := preload("res://scripts/units/earth_elemental.gd")
const CORPSE_SCRIPT := preload("res://scripts/units/corpse.gd")
const CARAVAN_SCRIPT := preload("res://scripts/units/caravan.gd")

var game: Game
var hosting := false
var _timer := 0.0
## Host, per peer id: {"known": {nid: state}, "ev": [], "to": [], "ft": [], "fx": [],
## "ex": PackedInt32Array, "full": bool, "vd": last village data}
var _peers: Dictionary = {}
## Client: dummy units standing on others' towers, per building nid.
var _foreign_units: Dictionary = {}


func setup(p_game: Game, p_hosting: bool) -> void:
	game = p_game
	hosting = p_hosting
	process_mode = Node.PROCESS_MODE_ALWAYS
	if hosting:
		for v in game.villages:
			v.events.logged.connect(_on_logged.bind(v.id))
		game.fog.explored_changed.connect(_on_explored)


# --- host ------------------------------------------------------------------------------

## A client just (re)loaded the level: send it everything next time.
func reset_peer(id: int) -> void:
	_peers[id] = {"known": {}, "ev": [], "to": [], "ft": [], "fx": [], "ex": PackedInt32Array(), "full": true, "vd": {}}


func _peers_of(vid: int) -> Array[int]:
	var out: Array[int] = []
	for id in _peers:
		var v := Net.village_of_peer(id)
		if v and v.id == vid:
			out.append(id)
	return out


func _on_logged(level: int, text: String, vid: int) -> void:
	for id in _peers_of(vid):
		_peers[id]["ev"].append([level, text])


func _on_explored(vid: int, tiles: Array[Vector2i]) -> void:
	for id in _peers_of(vid):
		var ex: PackedInt32Array = _peers[id]["ex"]
		for t in tiles:
			ex.append(game.map.index(t))
		_peers[id]["ex"] = ex


## A toast for village `vid`'s player (Village.toast on the host).
func toast(vid: int, text: String, col: Color) -> void:
	for id in _peers_of(vid):
		_peers[id]["to"].append([text, col])


## A floating text at world position `pos`, for every player who watches it.
func float_text(text: String, pos: Vector2, col: Color) -> void:
	var t := Iso.to_tile(pos)
	for id in _peers:
		var v := Net.village_of_peer(id)
		if v and game.fog.is_watched_by(v.id, t):
			_peers[id]["ft"].append([text, pos, col])


## An arrow flying from `from` to `to` (world positions), for those who watch it.
func arrow(from: Vector2, to: Vector2) -> void:
	var t := Iso.to_tile(to)
	for id in _peers:
		var v := Net.village_of_peer(id)
		if v and game.fog.is_watched_by(v.id, t):
			_peers[id]["fx"].append(["arrow", from, to])


func _process(delta: float) -> void:
	if not hosting:
		return
	_timer -= delta / maxf(Engine.time_scale, 0.001)
	if _timer > 0.0:
		return
	_timer = SEND_INTERVAL
	var peers := Net.client_peers()
	if peers.is_empty():
		return
	# Every entity's state once, then each client's share of it.
	var all: Array = []  # [nid, type, spawn, state, tile, owner vid, public]
	for b in game.world.buildings:
		if b.nid > 0 and is_instance_valid(b):
			all.append([b.nid, "b", _building_spawn(b), _building_state(b), b.tile, b.village.id if b.village else -1, b is Hut])
	for n in get_tree().get_nodes_in_group("replicated"):
		if n is Building or not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var d := _describe(n)
		if not d.is_empty():
			all.append(d)
	for id in peers:
		if not _peers.has(id):
			reset_peer(id)
		Net.send_snapshot(id, _snapshot_for(id, all))


func _snapshot_for(id: int, all: Array) -> Dictionary:
	var p: Dictionary = _peers[id]
	var v := Net.village_of_peer(id)
	var vid := v.id
	var known: Dictionary = p["known"]
	var seen := {}
	var sp := []
	var up := {}
	for e in all:
		var nid: int = e[0]
		var type: String = e[1]
		var own: bool = e[5] == vid
		var tile: Vector2i = e[4]
		var state: Dictionary = e[3]
		if type == "b":
			if not own and not game.fog.is_explored_by(vid, tile):
				continue
			if not own and not e[6] and not game.fog.is_watched_by(vid, tile):
				state = {"c": state["c"]}  # others' buildings: only what they looked like
		elif not own and not game.fog.is_watched_by(vid, tile):
			continue
		seen[nid] = true
		if not known.has(nid):
			sp.append([nid, type, e[2], state])
			known[nid] = state
		elif known[nid] != state:
			up[nid] = state
			known[nid] = state
	var de := []
	for nid in known.keys():
		if not seen.has(nid):
			var o = game.entity(nid)
			# Buildings stay as last seen while out of sight; gone ones are removed.
			if o is Building and is_instance_valid(o) and not o.is_queued_for_deletion():
				continue
			de.append(nid)
			known.erase(nid)
	var out := {"sp": sp, "up": up, "de": de}
	var vd := _village_data(v)
	if vd != p["vd"]:
		out["vd"] = vd
		p["vd"] = vd
	for k in ["ev", "to", "ft", "fx"]:
		if not p[k].is_empty():
			out[k] = p[k]
			p[k] = []
	if p["full"]:
		out["exa"] = game.fog.explored_of[vid]
		p["full"] = false
		p["ex"] = PackedInt32Array()
	elif not p["ex"].is_empty():
		out["ex"] = p["ex"]
		p["ex"] = PackedInt32Array()
	out["wl"] = game.world.warnings.compute_spots(vid) if game.world.warnings.enabled() else []
	return out


func _village_data(v: Village) -> Dictionary:
	var army := []
	for u in v.army.units:
		army.append([u.nid, u.kind, u.level, u.state, game.id_of(u.post), u.train_xp, u.uid, u.travel_to.id if u.travel_to else -1])
	var w := game.waves
	return {
		"eco": [v.economy.amount("gold"), v.economy.amount("food"), v.economy.amount("materials")],
		"starve": v.population.starving,
		"army": army,
		"fallen": game.villages.map(func(o: Village) -> bool: return o.fallen),
		"wave": [w.wave, snappedf(w.countdown, 0.1), w.in_progress(), w.enemies_left(), w.can_call()],
		"speed": game.speed_index,
		"paused": get_tree().paused,
		"over": game.game_over,
	}


func _building_spawn(b: Building) -> Dictionary:
	return {"k": b.kind, "t": b.tile, "v": b.village.id if b.village else 0, "f": b.get("flip") == true, "u": b.uid}


func _building_state(b: Building) -> Dictionary:
	var st := {"c": b.complete, "p": snappedf(b.progress, 0.1), "g": 0}
	if b.upgrading:
		st["u"] = snappedf(b.upgrade_progress, 0.1)
	if b is Tower:
		st["l"] = b.level
		st["en"] = b.enchanted > 0.0
	if b is MilitaryPost:
		var g: MilitaryUnit = b.garrison
		st["g"] = g.nid if g else 0
		st["gk"] = g.kind if g else ""
		st["gl"] = g.level if g else 0
		st["gx"] = snappedf(g.train_xp, 1.0) if g else 0.0
		st["i"] = b.incoming.nid if b.incoming else 0
	if b is Hut:
		st["r"] = b.ruined
		st["res"] = game.id_of(b.resident)
	if b is Workplace:
		st["w"] = game.id_of(b.worker)
	if b is Farm:
		st["fs"] = int(b.stored)
	if b is TrainingGrounds:
		st["th"] = game.id_of(b.trainee_hero)
	return st


## [nid, type, spawn, state, tile, owner village id, public]
func _describe(n: Node) -> Array:
	var vid := -1
	var v = n.get("village")
	if v is Village:
		vid = v.id
	if n is Hero:
		var h := n as Hero
		return [h.nid, "h", {"v": vid}, _unit_state(h).merged({"m": h.mode, "xp": h.xp, "hp": snappedf(h.hp, 0.5), "mhp": h.max_hp, "d": h.dead, "st": h.support_target.id if h.support_target else -1, "s": h.status_text()}), h.current_tile(), vid, false]
	if n is Civilian:
		var c := n as Civilian
		if c.dead:
			return []
		return [c.nid, "c", {"r": c.role, "v": vid, "u": c.uid}, _unit_state(c).merged({"h": c.at_home, "s": c.status_text(), "hut": game.id_of(c.hut)}), c.current_tile(), vid, false]
	if n is Enemy:
		var e := n as Enemy
		if e.dead:
			return []
		return [e.nid, "e", {"k": e.kind, "u": e.uid, "v": e.target_village.id if e.target_village else 0}, _unit_state(e).merged({"hp": snappedf(e.hp, 0.5), "mhp": e.max_hp}), e.current_tile(), -1, false]
	if n is Soldier:
		var s := n as Soldier
		vid = s.unit.village.id if s.unit.village else -1
		return [s.nid, "s", {"k": s.unit.kind, "n": s.unit.nid, "v": vid}, _unit_state(s), s.current_tile(), vid, false]
	if n is EarthElemental:
		var el := n as EarthElemental
		if el.dead:
			return []
		return [el.nid, "el", {"v": vid, "u": el.uid}, _unit_state(el).merged({"hp": snappedf(el.hp, 0.5), "mhp": el.max_hp}), el.current_tile(), vid, false]
	if n is Caravan:
		var ca := n as Caravan
		return [ca.nid, "ca", {"from": ca.from.id, "to": ca.to.id, "u": ca.uid}, _unit_state(ca), ca.current_tile(), vid, false]
	if n is Corpse:
		var co := n as Corpse
		return [co.nid, "co", {"k": co.kind, "u": co.uid, "p": co.grid_pos}, {"a": snappedf(co.modulate.a, 0.1)}, co.tile(), -1, false]
	return []


func _unit_state(u: Unit) -> Dictionary:
	return {"p": u.grid_pos.snapped(Vector2(0.01, 0.01)), "fx": u.sprite.flip_h, "vis": u.visible, "rot": snappedf(u.sprite.rotation, 0.05)}


# --- client -------------------------------------------------------------------------------

func apply(d: Dictionary) -> void:
	if d.has("vd"):
		_apply_village(d["vd"])
	if d.has("exa"):
		var e: PackedByteArray = d["exa"]
		var tiles: Array[Vector2i] = []
		for i in e.size():
			if e[i] == 1:
				tiles.append(Vector2i(i % game.map.size, i / game.map.size))
		game.fog.explore_tiles(tiles, game.player_village.id)
	if d.has("ex"):
		var tiles: Array[Vector2i] = []
		for i in (d["ex"] as PackedInt32Array):
			tiles.append(Vector2i(i % game.map.size, i / game.map.size))
		game.fog.explore_tiles(tiles, game.player_village.id)
	# Buildings first: units refer to them (huts, posts).
	var sp: Array = d.get("sp", [])
	for s in sp:
		if s[1] == "b":
			_spawn(s[0], s[1], s[2], s[3])
	for s in sp:
		if s[1] != "b":
			_spawn(s[0], s[1], s[2], s[3])
	var up: Dictionary = d.get("up", {})
	for nid in up:
		var o = game.entity(nid)
		if o != null:
			_apply_state(o, up[nid])
	for nid in d.get("de", []):
		_despawn(nid)
	for e in d.get("ev", []):
		game.player_village.events.add(e[0], e[1])
	for t in d.get("to", []):
		game.hud.toast(t[0], t[1])
	for f in d.get("ft", []):
		game.world.float_text(f[0], f[1], f[2])
	for f in d.get("fx", []):
		if f[0] == "arrow":
			var a := Arrow.new()
			a.visual_only = true
			game.world.effects.add_child(a)
			a.fly(f[1], f[2])
	game.world.warnings.show_net(d.get("wl", []))


func _apply_village(vd: Dictionary) -> void:
	var v := game.player_village
	var eco: Array = vd["eco"]
	v.economy.set_amounts({"gold": eco[0], "food": eco[1], "materials": eco[2]})
	v.population.starving = vd["starve"]
	# Army: keep our MilitaryUnit objects, keyed by id.
	var keep := {}
	for a in vd["army"]:
		var u = game.entity(a[0])
		if not (u is MilitaryUnit):
			u = MilitaryUnit.new(a[1])
			u.nid = a[0]
			u.village = v
			game.register_as(u, a[0])
		u.level = a[2]
		u.state = a[3]
		u.post = game.entity(a[4]) as MilitaryPost
		u.train_xp = a[5]
		u.uid = a[6]
		u.travel_to = game.villages[a[7]] if a[7] >= 0 else null
		keep[u] = true
	var units: Array[MilitaryUnit] = []
	for u in keep:
		units.append(u)
	v.army.units = units
	v.army.changed.emit()
	var fallen: Array = vd["fallen"]
	var fell := false
	for i in mini(fallen.size(), game.villages.size()):
		if game.villages[i].fallen != fallen[i]:
			game.villages[i].fallen = fallen[i]
			fell = true
	if fell:
		game.world.refresh_village_labels()
	var w: Array = vd["wave"]
	game.waves.set_net_state(w[0], w[1], w[2], w[3], w[4])
	if vd["speed"] != game.speed_index:
		game.speed_index = vd["speed"]
		Engine.time_scale = maxf(Game.SPEEDS[vd["speed"]], 1.0)
		game.speed_changed.emit(vd["speed"])
	game.hud.set_host_paused(vd["paused"] or Game.SPEEDS[vd["speed"]] == 0.0)
	if vd["over"] and not game.game_over:
		game.game_over = true
		game.hud.show_game_over("The outposts have fallen", "Every village has fallen.\nYou held out for %d waves." % maxi(game.waves.wave - 1, 0))


func _spawn(nid: int, type: String, s: Dictionary, st: Dictionary) -> void:
	if game.entity(nid) != null:
		_apply_state(game.entity(nid), st)
		return
	var o: Node = null
	match type:
		"b":
			var kind: String = s["k"]
			var script: GDScript = Construction.KIND_SCRIPTS.get(kind, World.PIECE_SCRIPTS.get(kind))
			var b: Building = script.new()
			if b is StaticPiece:
				b.flip = s["f"]
			b.village = game.villages[s["v"]]
			b.nid = nid
			b.uid = s["u"]
			game.register_as(b, nid)
			b.setup(game, kind, s["t"], st["c"])
			game.world.add_building(b)
			o = b
		"h":
			var hv := game.villages[s["v"]]
			o = hv.hero
			o.nid = nid
			game.register_as(o, nid)
		"c":
			var cv := game.villages[s["v"]]
			var c: Civilian = Population.ROLE_SCRIPTS[s["r"]].new()
			c.village = cv
			c.uid = s["u"]
			c.setup(game, s["r"])
			c.nid = nid
			game.register_as(c, nid)
			game.world.objects.add_child(c)
			if cv == game.player_village:
				cv.population.civilians.append(c)
				cv.population.changed.emit()
			o = c
		"e":
			var e: Enemy = ENEMY_SCRIPT.new()
			e.setup(game, [Vector2i(Vector2(st["p"]).round())] as Array[Vector2i], 1.0, s["k"])
			e.uid = s["u"]
			e.target_village = game.villages[s["v"]]
			e.nid = nid
			game.register_as(e, nid)
			game.world.objects.add_child(e)
			o = e
		"s":
			var u = game.entity(s["n"])
			if not (u is MilitaryUnit):
				u = MilitaryUnit.new(s["k"])
				u.village = game.villages[s["v"]] if s["v"] >= 0 else null
			var so: Soldier = SOLDIER_SCRIPT.new()
			so.setup(game, u, Vector2i(Vector2(st["p"]).round()))
			so.nid = nid
			game.register_as(so, nid)
			game.world.objects.add_child(so)
			o = so
		"el":
			var el: EarthElemental = ELEMENTAL_SCRIPT.new()
			el.village = game.villages[s["v"]] if s["v"] >= 0 else null
			var t := Vector2i(Vector2(st["p"]).round())
			el.setup(game, t, t, st["mhp"], 0.0)
			el.uid = s["u"]
			el.nid = nid
			game.register_as(el, nid)
			game.world.objects.add_child(el)
			o = el
		"ca":
			var ca: Caravan = CARAVAN_SCRIPT.new()
			ca.setup(game, game.villages[s["from"]], game.villages[s["to"]], {}, 0.0)
			ca.uid = s["u"]
			ca.nid = nid
			game.register_as(ca, nid)
			game.world.objects.add_child(ca)
			o = ca
		"co":
			var co: Corpse = CORPSE_SCRIPT.new()
			co.setup(game, s["k"], 0, s["p"])
			co.uid = s["u"]
			co.nid = nid
			game.register_as(co, nid)
			game.world.decals.add_child(co)
			game.corpses.corpses.append(co)
			game.corpses.changed.emit()
			o = co
	if o:
		_apply_state(o, st, true)


func _apply_state(o, st: Dictionary, first: bool = false) -> void:
	if o is Building:
		_apply_building(o, st)
		return
	if o is Corpse:
		o.modulate.a = st.get("a", 1.0)
		return
	if o is Unit:
		var u := o as Unit
		u.net_move(st["p"], first)
		u.sprite.flip_h = st["fx"]
		u.sprite.rotation = st.get("rot", 0.0)
		u.visible = st["vis"]
	if o is Civilian:
		var c := o as Civilian
		c.at_home = st.get("h", c.at_home)
		c.net_status = st.get("s", "")
		var hut = game.entity(st.get("hut", 0))
		if hut is Hut:
			c.hut = hut
	if o is Hero:
		var h := o as Hero
		h.mode = st["m"]
		h.xp = st["xp"]
		h.hp = st["hp"]
		h.max_hp = st["mhp"]
		h.dead = st["d"]
		h.support_target = game.villages[st["st"]] if st["st"] >= 0 else null
		h.queue_redraw()
		h.changed.emit()
	if o is Enemy or o is EarthElemental:
		o.hp = st["hp"]
		o.max_hp = st["mhp"]
		o.queue_redraw()


func _apply_building(b: Building, st: Dictionary) -> void:
	var was_complete := b.complete
	b.complete = st["c"]
	b.progress = st.get("p", b.progress)
	b.upgrading = st.has("u")
	b.upgrade_progress = st.get("u", 0.0)
	if b is Tower and st.has("l") and b.level != st["l"]:
		b.level = st["l"]
	if b is Tower:
		b.enchanted = 1.0 if st.get("en", false) else 0.0
	if b is MilitaryPost:
		b.garrison = _garrison_for(b, st)
		b.incoming = game.entity(st.get("i", 0)) as MilitaryUnit
	if b is Hut:
		b.ruined = st.get("r", false)
		b.resident = game.entity(st.get("res", 0)) as Civilian
	if b is Workplace:
		b.worker = game.entity(st.get("w", 0))
	if b is Farm:
		b.stored = st.get("fs", 0)
	if b is TrainingGrounds:
		b.trainee_hero = game.entity(st.get("th", 0))
	b.refresh()
	b.queue_redraw()
	if was_complete != b.complete:
		game.world.refresh_building(b)


## The unit on a post: ours from our army, or a stand-in for someone else's.
func _garrison_for(b: MilitaryPost, st: Dictionary) -> MilitaryUnit:
	var nid: int = st.get("g", 0)
	if nid == 0:
		_foreign_units.erase(b.nid)
		return null
	var u = game.entity(nid)
	if u is MilitaryUnit:
		return u
	var f: MilitaryUnit = _foreign_units.get(b.nid)
	if f == null or f.kind != st["gk"]:
		f = MilitaryUnit.new(st["gk"])
		f.village = b.village
		_foreign_units[b.nid] = f
	f.level = st.get("gl", 0)
	f.train_xp = st.get("gx", 0.0)
	f.state = MilitaryUnit.State.STATIONED
	f.post = b
	return f


func _despawn(nid: int) -> void:
	var o = game.entity(nid)
	game.unregister(nid)
	if o == null:
		return
	if o is Building:
		game.world.remove_building(o)
		return
	if o is Hero:
		o.visible = false
		return
	if o is Civilian:
		game.player_village.population.civilians.erase(o)
		game.player_village.population.changed.emit()
	if o is Corpse:
		game.corpses.corpses.erase(o)
		game.corpses.changed.emit()
	if o is Node:
		(o as Node).queue_free()
