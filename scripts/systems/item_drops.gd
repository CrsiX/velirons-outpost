class_name ItemDrops
## Where items come from (docs/items-design.md §5): carriers (an enemy holding
## an item, marked by a glint, Enemy.carried_item) and the sacks they drop,
## treasures and lairs holding an item, and the random pick behind all of them.
## An item on the ground is a dropped-loot sack with "equipment" in its reward:
## it stays until a gatherer (or the hero gathering or exploring) brings it to
## the town hall's armoury. Numbers: Config.ITEM_SOURCES.


## The items a random source may give: every item that isn't a default or a
## campaign item (a scenario's Scenario.item_pool narrows them).
static func pool(game: Game) -> Array[String]:
	var out: Array[String] = []
	var only: Array[String] = []
	if game != null and game.scenario != null:
		only = game.scenario.spec.item_pool
	for id: String in Config.ITEMS:
		if not Config.ordinary_item(id):
			continue
		if only.is_empty() or only.has(id):
			out.append(id)
	return out


## A random item from the pool ("" if it is empty).
static func random_item(game: Game, rng: RandomNumberGenerator) -> String:
	var p := pool(game)
	return p[rng.randi() % p.size()] if not p.is_empty() else ""


## Do random carriers come in this game (camps, lairs, late waves)?
static func carriers_on(game: Game) -> bool:
	return game.items_enabled() and (game.scenario == null or game.scenario.spec.item_carriers)


## Can an enemy of `kind` carry an item: not water-only, flying, a boss
## ("pin_proof") or a campaign's named one (`given_name`).
static func can_carry(kind: String, given_name: String = "") -> bool:
	var spec: Dictionary = Config.ENEMIES.get(kind, {})
	if spec.is_empty() or given_name != "":
		return false
	return str(spec.get("habitat", "land")) != "water" and not spec.get("flying", false) and not spec.get("pin_proof", false) and str(spec.get("behavior", "")) != "arm"


## `e` carries `id` from now on (shown by its glint).
static func give(e: Enemy, id: String) -> void:
	if not Config.ordinary_item(id):
		return
	e.carried_item = id
	e.fx["glint"] = true


## With `chance`, one of `enemies` that can carry gets a random item.
## Returns that enemy (null: none).
static func maybe_carrier(game: Game, enemies: Array, chance: float, rng: RandomNumberGenerator) -> Enemy:
	if not carriers_on(game) or rng.randf() >= chance:
		return null
	var able: Array[Enemy] = []
	for e: Enemy in enemies:
		if is_instance_valid(e) and not e.dead and e.carried_item == "" and can_carry(e.kind, e.given_name):
			able.append(e)
	if able.is_empty():
		return null
	var e := able[rng.randi() % able.size()]
	give(e, random_item(game, rng))
	if e.carried_item != "":
		e.game.villages[0].events.debug("%s carries an item (%s)" % [e.label(), e.carried_item])
	return e if e.carried_item != "" else null


## A carrier fell (Waves, MonsterCamp): its item drops in a sack near it.
## `v`: the village that killed it (it hears of it), or null.
static func drop_carried(game: Game, e: Enemy, v: Village) -> void:
	if e.carried_item == "":
		return
	var id := e.carried_item
	e.carried_item = ""
	e.fx.erase("glint")
	var sack := drop(game, e.current_tile(), id)
	var hears := v if v != null else e.target_village
	if hears == null:
		return
	if sack == null:
		hears.events.debug("%s's item (%s) is lost: no free tile near %s" % [e.label(), id, str(e.current_tile())])
		return
	hears.events.info("%s dropped something that glints. A gatherer (or the hero gathering) can bring it home." % e.label().capitalize())
	hears.events.debug("%s dropped %s at %s" % [e.label(), id, str(sack.tile)])


## The glint that marks an item (a carrier, a dropped item's sack): a
## four-pointed star flaring and turning slowly, on a soft halo; no art of
## its own. Drawn by `ci` at `c` every frame.
static func draw_glint(ci: CanvasItem, c: Vector2) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var flare := 0.5 + 0.5 * sin(t * 3.3)
	var r := 8.0 + 6.0 * flare
	var a := t * 0.6
	var gold := Color(1.0, 0.92, 0.55, 0.6 + 0.4 * flare)
	ci.draw_circle(c, 7.0 + 3.0 * flare, Color(1.0, 0.85, 0.4, 0.18 + 0.12 * flare))
	for i in 4:
		var d := Vector2.from_angle(a + i * TAU / 4.0)
		ci.draw_line(c - d * r * 0.2, c + d * r, Color(0.08, 0.06, 0.05, 0.5), 4.0)
		ci.draw_line(c - d * r * 0.2, c + d * r, gold, 2.2)
	for i in 4:
		var d := Vector2.from_angle(a + TAU / 8.0 + i * TAU / 4.0)
		ci.draw_line(c, c + d * r * 0.45, gold, 1.5)
	ci.draw_circle(c, 2.0 + flare, Color(1.0, 1.0, 0.9, 0.9))


## Item `id` lies on the ground near `at` from now on (a sack); null when no
## free tile is within ITEM_SOURCES "drop_radius".
static func drop(game: Game, at: Vector2i, id: String) -> Treasure:
	var t := free_tile(game, at)
	if t == Vector2i(-1, -1):
		return null
	return game.world.add_dropped_loot(t, {"equipment": id})


## The nearest free walkable tile to `at` (ring by ring), open ground before
## forest (a sack under the trees is hard to see), or (-1, -1).
static func free_tile(game: Game, at: Vector2i) -> Vector2i:
	var wooded := Vector2i(-1, -1)
	for r in int(Config.ITEM_SOURCES["drop_radius"]) + 1:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := at + Vector2i(dx, dy)
				if game.map.in_bounds(t) and game.map.buildings.get(t) == null and game.world.pathing.is_walkable(t):
					if not game.map.is_forest(t):
						return t
					if wooded.x < 0:
						wooded = t
	return wooded


## Can village `v` take in what `reward` holds (an item needs room in its
## armoury and items in this game, a relic room in its armoury)? Looters
## skip what it can't take.
static func room_for(v: Village, reward: Dictionary) -> bool:
	if reward.has("relic"):
		return not v.armoury.full()
	if not reward.has("equipment"):
		return true
	return v.game.items_enabled() and not v.armoury.full()


## An item brought home (Treasure.pay): into the armoury; a full one leaves it
## in a sack by the town hall for later. Returns the floating text's part.
static func bring_home(v: Village, id: String) -> String:
	var name := str(Config.ITEMS.get(id, {}).get("name", id))
	if v.armoury.add(id):
		v.events.important("%s is in the armoury now. Tap the hero to equip it." % name)
		return "{item:%s} %s" % [id, name]
	var hall := v.town_hall()
	var sack := drop(v.game, hall.tile if hall != null else v.center, id)
	if sack != null:
		v.events.info("The armoury is full: the %s waits by the town hall." % name.to_lower())
	else:
		v.events.info("The armoury is full: the %s is lost." % name.to_lower())
	return ""
