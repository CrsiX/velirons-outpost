class_name MonsterLair
extends MonsterCamp
## A monster lair (docs/world-design.md §9.6). Its look depends on where it
## is: a cave in the mountains, a huge hollow tree in the pine forest, a
## sunken ruin in the swamp, a smoking pit in ash land, a crypt in the steppe;
## 1x1 or 2x2. It blocks walking, and a winding road leads from its door
## (data "front") to the network.
## It sleeps until its wave (Config.LAIR_FROM_WAVE, then one more per slice
## every LAIR_EVERY waves). Awake, it's one more spawn point for its slice's
## share of every wave, sending its theme's kinds (Waves._share), and guards
## stand by it like at a camp. The hero can clear it (Attack with the hero):
## it drops a sack of loot and sleeps LAIR_QUIET_WAVES waves, then wakes again.

## Host: the wave it first wakes up at (0: never; set by World).
var wake_wave := 0
var awake := false
## The wave it last woke up at (-1: never).
var woke_at := -1
## Cleared: the wave it wakes up again at.
var quiet_until := -1
var _glow: Polygon2D = null


func art() -> String:
	return data["art"]


func display_name() -> String:
	return "Monster lair"


func is_solid() -> bool:
	return true


func is_solid_when_complete() -> bool:
	return true


## (no guards at the start: they come when it wakes up)
func spawn_monsters() -> void:
	pass


func attackable() -> bool:
	return awake and not cleared


## Its theme (Config.LAIR_THEMES): name, kinds it sends, guards.
func theme() -> Dictionary:
	return Config.LAIR_THEMES[str(data["art"]).trim_suffix("_big")]


## Where its enemies come out: the road at its door.
func door() -> Vector2i:
	return data.get("front", tile)


## The kinds it sends in wave `n` (those whose wave has come; rats come in
## packs, not here), at least goblins.
func kinds_for(n: int) -> Array[String]:
	var out: Array[String] = []
	for k: String in theme()["kinds"]:
		if k == Config.WAVE_FILLER or (Config.WAVE_MIX.has(k) and n >= int(Config.WAVE_MIX[k]["from_wave"])):
			out.append(k)
	if out.is_empty():
		out.append(Config.WAVE_FILLER)
	return out


## Host, at the start of wave `n`: wake up if it's time.
func on_wave(n: int) -> void:
	if awake:
		return
	if cleared:
		if n < quiet_until:
			return
		cleared = false
	elif wake_wave <= 0 or n < wake_wave:
		return
	var again := woke_at >= 0
	awake = true
	woke_at = n
	_spawn_guards(theme()["guards"], pow(Config.WAVE_HP_GROWTH, n - 1))
	for e in monsters:
		e.wave = n
	refresh()
	_announce(n, again)


## Tells its slice's village (log, toast and a sound): where it is if they
## found it, roughly which way otherwise.
func _announce(n: int, again: bool) -> void:
	var v := owner_village()
	if v == null:
		return
	var what: String = theme()["name"]
	var way := _compass(Vector2(game.map.villages[v.id]["center"]), Vector2(tile))
	var sends := _plural_list(kinds_for(n))
	var line: String
	if is_found_by(v):
		line = "The %s to the %s has %s! %s will come out of it with every wave. The hero can clear it: tap it and order Attack with the hero." % [what, way, "woken up again" if again else "woken up", sends]
	else:
		line = "Something stirs %sin a %s somewhere to the %s... %s will come out of it with every wave." % ["again " if again else "", what, way, sends]
	v.events.important(line)
	v.toast("A monster lair has %s!" % ("woken up again" if again else "woken up"), Color("e06a5a"))
	if v.is_local():
		Sfx.play("raid", 0.0)


## The village whose slice it's in.
func owner_village() -> Village:
	var s := int(data.get("slice", 0))
	for v in game.villages:
		if int(game.map.villages[v.id].get("slice", 0)) == s:
			return v
	return game.villages[0] if not game.villages.is_empty() else null


func _on_cleared(v: Village) -> void:
	awake = false
	quiet_until = game.waves.wave + 1 + Config.LAIR_QUIET_WAVES
	var who := v.village_name if v else "Someone"
	game.log_all(EventLog.Level.INFO, "%s cleared a monster lair: it left a sack of loot at its door, and it stays quiet until wave %d." % [who, quiet_until])
	game.world.add_dropped_loot(_loot_tile(), _loot(v))


func _loot(v: Village) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < Config.LAIR_RELIC_CHANCE:
		var keys: Array = Config.RELICS.keys().filter(func(k: String) -> bool: return v == null or not v.relics.has(k))
		if not keys.is_empty():
			return {"relic": keys[rng.randi() % keys.size()]}
	var k := 1.0 + Config.LAIR_LOOT_GROWTH * maxi(game.waves.wave - Config.LAIR_FROM_WAVE, 0)
	var out := {}
	for key in Config.LAIR_LOOT:
		var r: Array = Config.LAIR_LOOT[key]
		out[key] = roundi(rng.randi_range(int(r[0]), int(r[1])) * k)
	return out


## A free tile by its door for the sack.
func _loot_tile() -> Vector2i:
	var d := door()
	for t in [d] + MapData.neighbors4(d):
		if game.map.in_bounds(t) and not game.map.buildings.has(t) and game.world.pathing.is_walkable(t):
			return t
	return d


func found_message(_v: Village) -> String:
	if not awake:
		return ""
	return "Found an awake %s: monsters come out of it with every wave. Tap it and order: Attack with the hero." % theme()["name"]


func info() -> Dictionary:
	var d := {"title": "%s (monster lair)" % str(theme()["name"]).capitalize(), "lines": [] as Array[String], "actions": [] as Array[Dictionary]}
	var lines: Array[String] = d["lines"]
	if awake:
		lines.append("Awake: %s come out of it with every wave." % _plural_list(kinds_for(game.waves.wave)).to_lower())
		lines.append("%d guard%s stand by it. Clear it to make it sleep for %d waves (and take its loot)." % [left, "" if left == 1 else "s", Config.LAIR_QUIET_WAVES])
		_attack_lines(d)
	elif cleared:
		lines.append("Cleared. It stays quiet until wave %d." % quiet_until)
	else:
		lines.append("Something lives in there. It's asleep, for now.")
	return d


func net_state() -> Array:
	return [cleared, left, awake, quiet_until]


func apply_net_state(s: Array) -> void:
	if s.size() >= 4:
		quiet_until = int(s[3])
		if bool(s[2]) != awake:
			awake = bool(s[2])
			refresh()
	super.apply_net_state(s)



## Awake: a red glow on the ground round it (under the art).
func refresh() -> void:
	super.refresh()
	if _glow == null and awake:
		_glow = Polygon2D.new()
		var rx := Iso.HALF_W * (0.8 + 0.5 * (size - 1))
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		pts.append(Vector2.ZERO)
		cols.append(Color(0.95, 0.2, 0.08, 0.45))
		for k in 25:
			var a := TAU * k / 24.0
			pts.append(Vector2(cos(a) * rx, sin(a) * rx * 0.5))
			cols.append(Color(0.95, 0.2, 0.08, 0.0))
		var tris := []
		for k in 24:
			tris.append(PackedInt32Array([0, k + 1, k + 2]))
		_glow.polygon = pts
		_glow.vertex_colors = cols
		_glow.polygons = tris
		_glow.show_behind_parent = true
		add_child(_glow)
		move_child(_glow, 0)
	if _glow:
		_glow.visible = awake

## "Orks and gargoyles".
static func _plural_list(kinds: Array[String]) -> String:
	var names: Array[String] = []
	for k in kinds:
		var n := str(Config.ENEMIES[k]["name"])
		names.append(n + ("es" if n.ends_with("ch") else "s"))
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, -1)) + " and " + names[-1]


## Which way `to` lies from `from` on screen: "north", "south-east", ...
static func _compass(from: Vector2, to: Vector2) -> String:
	var d := Iso.to_world(to) - Iso.to_world(from)
	const WAYS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return WAYS[posmod(roundi(d.angle() / (PI / 4.0)), 8)]
