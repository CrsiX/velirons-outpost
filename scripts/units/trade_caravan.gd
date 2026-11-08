class_name TradeCaravan
extends Unit
## A trade caravan (docs/market-design.md §5): an open cart with crates and
## sacks. Not the co-op help caravan (Caravan), which nothing can stop. Trips:
##   OUTGOING: our goods from the market to the map edge; the edge pays gold
##     minus the market's tax on arrival, then it drives home empty;
##   ORDER: our goods to another player who bought them (the order book); the
##     buyer gets the goods and we get the gold they paid, no tax; home empty;
##   INCOMING: the merchants' goods from the edge into the market's buying
##     stock (a neutral cart, nobody's: it watches nothing).
## On the road it is a villager to enemies (group "villagers", is_exposed):
## hit when in reach, never hunted, never poisoned. It never flees, but turns
## back when an enemy its village sees blocks the road ahead. A thief robs it
## (`rob`): the cargo goes with the thief, the empty cart home. Destroyed, it
## leaves its cargo as salvage (`drop_salvage`).

enum Trip { OUTGOING, ORDER, INCOMING }

var market: Market = null
## Whose cart it is (the market's village); an incoming one belongs to the merchants.
var village: Village = null
var trip := Trip.OUTGOING
## Goods on board: {good: amount}.
var cargo: Dictionary = {}
## ORDER: who bought it, and the gold they paid (the seller's on arrival).
var buyer: Village = null
var escrow := 0
## Where it is going (the edge or the buyer's market) and where it came from.
var dest := Vector2i.ZERO
var origin := Vector2i.ZERO
## On its way back (home empty, or turned back with its cargo).
var returning := false
var hp := 1.0
var max_hp := 1.0
var dead := false
var uid := 0
var _look := 0.0


func setup(p_game: Game, p_market: Market, p_trip: Trip, p_cargo: Dictionary, to: Vector2i) -> void:
	init_cart(p_game, p_market, p_trip, p_cargo)
	uid = game.next_id("trade caravan")
	nid = game.register(self)
	if trip == Trip.INCOMING:
		origin = to
		dest = market.work_tile()
	else:
		origin = market.work_tile()
		dest = to
	set_grid_pos(Vector2(origin))
	follow(game.world.pathing.find_path(origin, dest))


## What every cart has: a new one, a loaded one (SaveGame) and a co-op
## client's look-alike (Replicator, `p_market` null) alike.
func init_cart(p_game: Game, p_market: Market, p_trip: Trip, p_cargo: Dictionary, p_village: Village = null) -> void:
	game = p_game
	market = p_market
	village = market.village if market else p_village
	trip = p_trip
	cargo = p_cargo.duplicate()
	max_hp = float(Config.MARKET["hp"])
	hp = max_hp
	speed = float(Config.MARKET["speed"])
	_init_sprite(art_for(trip, village))
	add_to_group("trade_caravans")
	add_to_group("villagers")  # (enemies in reach hit it: is_exposed, take_damage)
	if trip != Trip.INCOMING:
		add_to_group("observers")


## Where it was going and where it is (a loaded game): on from here.
func resume_trip(pos: Vector2) -> void:
	set_grid_pos(pos)
	var to := dest
	if returning:
		to = market.work_tile() if trip != Trip.INCOMING and is_instance_valid(market) else origin
	var p := game.world.pathing.find_path(current_tile(), to)
	if not p.is_empty():
		p[0] = grid_pos
	follow(p)


## Its art: the owner's colour, or a neutral merchants' cart.
static func art_for(p_trip: Trip, v: Village) -> String:
	return "unit_trade_cart" if p_trip == Trip.INCOMING or v == null else "unit_trade_cart_c%d" % (v.id % Config.VILLAGE_COLORS.size())


func label() -> String:
	return "trade caravan %d" % uid


func display_name() -> String:
	return "Merchants' caravan" if trip == Trip.INCOMING else "Trade caravan"


# --- for enemies: a villager out on the road ------------------------------------------------

func is_exposed() -> bool:
	return not dead and is_inside_tree()


func inside_walls() -> bool:
	return false


func take_damage(amount: float, source = null, category: String = "pure") -> void:
	if dead or category == "poison" or game.is_client:
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.5, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		_destroyed(source)


func _destroyed(source) -> void:
	hp = 0.0
	dead = true
	remove_from_group("villagers")
	remove_from_group("trade_caravans")
	var what := _cargo_text()
	_log_owner(EventLog.Level.IMPORTANT, "%s destroyed by %s%s" % [label().capitalize(), game.who(source), (": %s left as salvage" % what) if what != "" else ""])
	if trip == Trip.ORDER and buyer != null and escrow > 0 and not cargo.is_empty():
		buyer.economy.refund({"gold": escrow}, "trade")
		buyer.events.info("Your order from %s was lost on the road: %d gold back" % [village.village_name, escrow])
	drop_salvage(game, current_tile(), market, cargo, trip == Trip.INCOMING)
	cargo = {}
	float_text("Caravan lost", Color("ff7a6a"))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


## A thief takes the whole cargo (and the buyer of an order gets their gold
## back); the empty cart drives home unharmed. Returns the salvage the thief
## carries: {"goods", "market": its id, "merchants": incoming goods}.
func rob(thief: Enemy) -> Dictionary:
	if dead or cargo.is_empty():
		return {}
	var taken := {"goods": cargo.duplicate(), "market": market.nid if is_instance_valid(market) else 0, "merchants": trip == Trip.INCOMING}
	_log_owner(EventLog.Level.IMPORTANT, "%s robbed %s of %s" % [thief.label().capitalize(), label(), _cargo_text()])
	if trip == Trip.ORDER and buyer != null and escrow > 0:
		buyer.economy.refund({"gold": escrow}, "trade")
		buyer.events.info("Your order from %s was stolen on the road: %d gold back" % [village.village_name, escrow])
		escrow = 0
	cargo = {}
	float_text("Robbed!", Color("ff7a6a"))
	_head_back()
	return taken


## The cargo where `at` is (or the nearest free tile): a sack anyone of the
## market's village can carry back to it (GatherJob). Nothing for an empty cargo.
static func drop_salvage(p_game: Game, at: Vector2i, p_market: Market, goods: Dictionary, merchants: bool) -> void:
	if goods.is_empty() or not is_instance_valid(p_market):
		return
	var t := _free_tile(p_game, at)
	if t == Vector2i(-1, -1):
		return
	p_game.world.add_dropped_loot(t, {"salvage": {"goods": goods.duplicate(), "market": p_market.nid, "merchants": merchants, "wave": p_game.waves.wave}})


static func _free_tile(p_game: Game, at: Vector2i) -> Vector2i:
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := at + Vector2i(dx, dy)
				if p_game.map.in_bounds(t) and p_game.map.buildings.get(t) == null and p_game.world.pathing.is_walkable(t):
					return t
	return Vector2i(-1, -1)


# --- the road --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if game.is_client:
		net_follow(delta)
		return
	if dead:
		return
	_look -= delta
	if _look <= 0.0:
		_look = 0.5
		if not returning and not cargo.is_empty() and village != null:
			var to := mini(path_index + int(Config.MARKET["look_ahead"]), path.size())
			if first_block(game, village, path, path_index, to) >= 0:
				_log_owner(EventLog.Level.INFO, "%s turns back: enemies on the road" % label().capitalize())
				float_text("Enemies ahead!", Color("ff9a6a"))
				_head_back()
	if step_path(delta):
		_arrive()


## Index of the first waypoint of `p` (from `from` up to `to`) that an enemy
## `v` can see is within MARKET "blocked_radius" of, or -1. Camp guards and
## faded ghosts don't count.
static func first_block(p_game: Game, v: Village, p: PackedVector2Array, from: int, to: int) -> int:
	var r := float(Config.MARKET["blocked_radius"])
	var foes: Array[Vector2] = []
	for node in p_game.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or not e.scary() or e.behavior is CampBehavior:
			continue
		if v != null and not p_game.fog.is_watched_by(v.id, e.current_tile()):
			continue
		foes.append(e.grid_pos)
	if foes.is_empty():
		return -1
	for i in range(from, mini(to, p.size())):
		for f in foes:
			if f.distance_to(p[i]) <= r:
				return i
	return -1


func _head_back() -> void:
	returning = true
	var home := origin
	if trip != Trip.INCOMING and is_instance_valid(market):
		home = market.work_tile()
	var p := game.world.pathing.find_path(current_tile(), home)
	if not p.is_empty():
		p[0] = grid_pos
	follow(p)


func _arrive() -> void:
	if returning:
		_home()
		return
	match trip:
		Trip.OUTGOING:
			var value := Market.edge_value(cargo)
			var rate := market.tax() if is_instance_valid(market) else float(Config.MARKET["levels"][0]["tax"])
			var gold := floori(value * (1.0 - rate))
			village.economy.add("gold", gold, "trade")
			game.stats.count(village, "trade.sold")
			game.stats.count(village, "trade.tax", value - gold)
			if is_instance_valid(market):
				market.sold += 1
			village.events.info("Trade caravan sold %s at the map edge: +%d gold (tax %d)" % [_cargo_text(), gold, value - gold])
			float_text("+%d {gold}" % gold, UiTheme.GOLD)
			village.sound("coin")
		Trip.ORDER:
			for good in cargo:
				buyer.economy.add(good, int(cargo[good]), "trade")
			village.economy.add("gold", escrow, "trade")
			game.stats.count(village, "trade.sold")
			if is_instance_valid(market):
				market.sold += 1
			buyer.events.info("Trade caravan from %s arrived: +%s" % [village.village_name, _cargo_text()])
			village.events.info("Your trade caravan reached %s: +%d gold" % [buyer.village_name, escrow])
			float_text("+%d {gold}" % escrow, UiTheme.GOLD)
			escrow = 0
			buyer.sound("coin")
		Trip.INCOMING:
			if is_instance_valid(market) and market.working():
				for good in cargo:
					market.add_stock(good, float(cargo[good]))
				village.events.debug("merchants' caravan brings %s to %s" % [_cargo_text(), market.label()])
			_vanish()
			return
	cargo = {}
	_head_back()


## Back where it set off: a cart turned back unloads into the market again
## (an order goes back on the book), then it is gone.
func _home() -> void:
	if trip != Trip.INCOMING and not cargo.is_empty() and is_instance_valid(market):
		if trip == Trip.ORDER and buyer != null:
			for good in cargo:
				market.orders.push_front({"buyer": buyer.id, "good": good, "amount": int(cargo[good]), "gold": escrow, "packed": float(cargo[good])})
		else:
			for good in cargo:
				market.packed[good] = int(market.packed.get(good, 0)) + int(cargo[good])
	cargo = {}
	_vanish()


func _vanish() -> void:
	dead = true
	set_process(false)
	remove_from_group("villagers")
	remove_from_group("trade_caravans")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _log_owner(level: EventLog.Level, text: String) -> void:
	if village != null:
		village.events.add(level, text)
	if trip == Trip.ORDER and buyer != null:
		buyer.events.add(level, text)


func _cargo_text() -> String:
	return Market._goods_text(cargo)


func sight_radius() -> float:
	return 0.0 if dead or trip == Trip.INCOMING else Config.UNIT_SIGHT


func sight_center() -> Vector2:
	return grid_pos


func _draw() -> void:
	if dead or hp >= max_hp:
		return
	_draw_hp_bar(30.0, -44.0, 4.0, hp / max_hp, Color("3a2a10"), Color("8fd05a"))
