class_name Market
extends Farm
## The marketplace (3x3, one per village, touching a road; docs/market-design.md).
## Gold is the only currency. Two piles of goods:
##   - the merchants' buying stock (`stored`: its food, which rats eat as
##     they eat a farm's crops; `stock_materials`), bought for gold at once
##     with or without a trader, refilled by incoming merchants' caravans;
##   - the village's for-sale pile (`pile`), put up by the player and packed
##     by the trader into loads that leave by trade caravan (TradeCaravan):
##     to the map edge (gold on arrival, minus the level's tax), or to another
##     player who bought from it (`orders`; the co-op order book, no tax).
## Its levels (Config.MARKET "levels") raise the stock, the caravans on the
## road at once and lower the tax. It is a Farm to the rats; it grows nothing.
## Equipment (docs/market-design.md §8, where Game.items_enabled): a few
## random items on offer (`item_offer`), rolled anew by each merchants'
## caravan that arrives; bought for gold into the armoury, no trader needed.
## A relic (`relic_offer`, Relics.pool; docs/items-design.md §7) comes only
## from the trader: a new one every MARKET "relic_after" seconds he tends it
## (`stationed`), the old one gone whether bought or not.

const TRADE_CARAVAN_SCRIPT := preload("res://scripts/units/trade_caravan.gd")

## The merchants' building material (their food is `stored`).
var stock_materials := 0.0
## Goods the village put up for sale, not yet packed: {good: amount}.
var pile := {"food": 0, "materials": 0}
## The load the trader is packing for the edge: {good: amount}.
var packed := {"food": 0, "materials": 0}
## Other players' purchases from our pile (the order book), oldest first:
## {"buyer": village id, "good", "amount", "gold": paid by the buyer, "packed": goods packed}.
var orders: Array[Dictionary] = []
## Seconds until the merchants send their next caravan.
var restock_timer := 0.0
## Items on offer (Config.ITEMS keys), MARKET "item_offer" of them at most.
var item_offer: Array[String] = []
## The relic on offer (Relics.pool: a Config.RELICS key), at most one: the
## trader brought it; empty once it is bought.
var relic_offer: Array[String] = []
## Seconds the trader has tended it since he brought the last relic (MARKET
## "relic_after" brings the next): counts while he is at the market
## (is_open), offer or not; pauses while he is away.
var stationed := 0.0
## Lots bought and loads sold so far (scenario and test hooks).
var bought := 0
var sold := 0
var _check := 0.0
## Co-op client: what the host says ([own caravans on the road, merchants'
## caravan coming, {good: source village id or -1}]).
var _net_road := 0
var _net_incoming := false
var _net_src := {}
var _pack_acc := 0.0
var _last_stored := 0.0
## Why the next load waits (debug log: a line only when the reason changes).
var _wait_note := ""


func _build_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	add_child(sprite)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	_site_sprite.scale *= 1.8
	add_child(_site_sprite)


func _exit_tree() -> void:
	pass


func refresh() -> void:
	Art.apply(sprite, "market" if level <= 1 else "market_%d" % level)
	sprite.visible = complete
	_site_sprite.visible = not complete
	var c := Color.WHITE if (worker != null or not complete) else Color(0.82, 0.82, 0.82)
	if tearing_down:
		c.a = 0.6
	sprite.modulate = c
	queue_redraw()


func finish() -> void:
	super.finish()
	if not game.is_client:
		stored = floorf(capacity() * float(Config.MARKET["start_stock"]))
		stock_materials = stored
		restock_timer = float(Config.MARKET["restock_every"])
		roll_items()


func spec_level() -> Dictionary:
	return Config.MARKET["levels"][clampi(level, 1, max_level()) - 1]


func max_level() -> int:
	return (Config.MARKET["levels"] as Array).size()


## Goods of each kind the buying stock and the for-sale pile hold at most.
func capacity() -> float:
	return float(spec_level()["stock"])


## Share of a sale at the map edge the tax takes.
func tax() -> float:
	return float(spec_level()["tax"]) * maxf(0.0, 1.0 - village.relic_bonus("tax"))  # (a Toll charter)


## Trade caravans of ours that may be on the road at once.
func caravan_cap() -> int:
	return int(spec_level()["caravans"])


## Grows nothing: no food for the village (Population.food_per_second).
func rate() -> float:
	return 0.0


## The merchants' stock of `good`.
func stock(good: String) -> float:
	return stored if good == "food" else stock_materials


func add_stock(good: String, amount: float) -> void:
	if good == "food":
		stored = clampf(stored + amount, 0.0, capacity())
	else:
		stock_materials = clampf(stock_materials + amount, 0.0, capacity())


## The trader is at the market (packing goes on only then).
func is_open() -> bool:
	return working() and worker != null and worker.has_method("tending") and worker.tending()


func pile_total() -> int:
	return int(pile["food"]) + int(pile["materials"])


func packed_total() -> int:
	return int(packed["food"]) + int(packed["materials"])


## Goods reserved by other players' orders, not yet on the road.
func ordered(good: String = "") -> int:
	var n := 0
	for o in orders:
		if good == "" or o["good"] == good:
			n += int(o["amount"])
	return n


## For the replicator: what a client's panel needs.
func net_state() -> Dictionary:
	var src := {}
	for good: String in Config.MARKET["buy"]:
		var m := source(good)
		src[good] = m.village.id if m != null else -1
	return {"sm": int(stock_materials), "pile": pile.duplicate(), "pk": packed.duplicate(), "ord": orders.duplicate(true),
		"rt": ceilf(restock_timer), "road": caravans_out().size(), "inc": incoming() != null, "src": src, "io": item_offer.duplicate(), "ro": relic_offer.duplicate(), "st": stationed}


func apply_net_state(st: Dictionary) -> void:
	stock_materials = float(st.get("sm", 0))
	pile = (st.get("pile", pile) as Dictionary).duplicate()
	packed = (st.get("pk", packed) as Dictionary).duplicate()
	orders.assign(st.get("ord", []))
	restock_timer = float(st.get("rt", 0.0))
	_net_road = int(st.get("road", 0))
	_net_incoming = bool(st.get("inc", false))
	_net_src = (st.get("src", {}) as Dictionary).duplicate()
	item_offer.assign(st.get("io", []))
	relic_offer.assign(st.get("ro", []))
	stationed = float(st.get("st", 0.0))


## Our trade caravans on the road (to the edge or a buyer, or coming back).
func caravans_out() -> Array[TradeCaravan]:
	var out: Array[TradeCaravan] = []
	for n in get_tree().get_nodes_in_group("trade_caravans"):
		var tc := n as TradeCaravan
		if tc.market == self and not tc.dead and tc.trip != TradeCaravan.Trip.INCOMING:
			out.append(tc)
	return out


## The merchants' caravan on its way here, or null.
func incoming() -> TradeCaravan:
	for n in get_tree().get_nodes_in_group("trade_caravans"):
		var tc := n as TradeCaravan
		if tc.market == self and not tc.dead and tc.trip == TradeCaravan.Trip.INCOMING:
			return tc
	return null


# --- buying -------------------------------------------------------------------------------

## Where a lot of `good` comes from: another player's market that has it up
## for sale (the order book, docs/market-design.md §7), else this one (the
## merchants' stock), else null (sold out).
func source(good: String) -> Market:
	if game.is_client:
		var vid := int(_net_src.get(good, -1))
		if vid < 0:
			return null
		var other := game.villages[vid].market() if vid != village.id else self
		return other if other != null else self  # (a market we can't see: ours stands in for the name)
	var lot := int(Config.MARKET["buy"][good]["amount"])
	for v in game.villages:
		if v == village or v.fallen:
			continue
		var m := v.market()
		if m != null and m.working() and m.worker != null and int(m.pile[good]) >= lot:
			return m
	return self if stock(good) >= lot else null


## The other village a lot of `good` would come from, or "".
func _source_name(good: String) -> String:
	if game.is_client:
		var vid := int(_net_src.get(good, -1))
		return game.villages[vid].village_name if vid >= 0 and vid != village.id else ""
	var from := source(good)
	return from.village.village_name if from != null and from != self else ""


## Why a lot of `good` can't be bought now, or "".
func buy_error(good: String) -> String:
	if not (Config.MARKET["buy"] as Dictionary).has(good):
		return "The market doesn't sell that"
	if not working():
		return "The market is closed" if complete else "The market isn't built yet"
	if source(good) == null:
		return "Sold out: wait for the merchants' next caravan"
	if not village.economy.can_afford({"gold": Config.MARKET["buy"][good]["gold"]}):
		return "Not enough gold"
	return ""


## Buys a lot of `good`: from another player's pile (it comes by caravan, the
## seller is paid when it arrives) or from the merchants' stock (at once).
## Returns the amount bought (0: none).
func buy(good: String) -> int:
	if buy_error(good) != "":
		return 0
	var lot: Dictionary = Config.MARKET["buy"][good]
	var amount := int(lot["amount"])
	var gold := int(lot["gold"])
	var from := source(good)
	village.economy.spend({"gold": gold}, "trade")
	bought += 1
	game.stats.count(village, "trade.bought")
	village.sound("coin")
	if from != self:
		from.pile[good] = int(from.pile[good]) - amount
		from.orders.append({"buyer": village.id, "good": good, "amount": amount, "gold": gold, "packed": 0.0})
		village.events.info("Bought %d %s from %s for %d gold: it comes by trade caravan" % [amount, _good_name(good), from.village.village_name, gold])
		from.village.events.info("%s bought %d %s from your market: your trader packs it" % [village.village_name, amount, _good_name(good)])
		return amount
	add_stock(good, -amount)
	village.economy.add(good, amount, "trade")
	village.events.debug("buy %d %s at %s for %d gold" % [amount, good, label(), gold])
	return amount


# --- equipment (docs/market-design.md §8) -------------------------------------------------

## A new offer of random items (host; a merchants' caravan brought it).
func roll_items() -> void:
	if game.is_client or not game.items_enabled():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	item_offer.clear()
	for k in int(Config.MARKET["item_offer"]):
		var id := ItemDrops.random_item(game, rng)
		if id != "":
			item_offer.append(id)
	village.events.debug("%s offers %s" % [label(), ", ".join(item_offer)])


## The trader tended it for `delta` more seconds (host): every MARKET
## "relic_after" of them he brings a new relic for sale; one still on offer is
## gone then (a relic can be bought only in its window).
func tend_relic(delta: float) -> void:
	if game.is_client or not game.items_enabled():
		return
	stationed += delta
	if stationed < float(Config.MARKET["relic_after"]):
		return
	stationed = 0.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var old: String = relic_offer[0] if not relic_offer.is_empty() else ""
	var r := Relics.random(game, rng, village)
	relic_offer.assign([r] if r != "" else [])
	var who: String = worker.label().capitalize() if worker != null else "The trader"
	if old != "":
		village.events.info("Nobody bought the %s: it is gone. %s brings the %s instead." % [Relics.name_of(old), who, Relics.name_of(r)])
	elif r != "":
		village.events.info("%s brings a relic for sale at the market: the %s." % [who, Relics.name_of(r)])


## What item or relic `id` costs here (gold).
static func offer_price(id: String) -> int:
	return int(Config.MARKET["relic_gold" if Relics.is_relic(id) else "item_gold"])


## Why item or relic `id` can't be bought now, or "".
func item_buy_error(id: String) -> String:
	if not game.items_enabled():
		return "There is no equipment here"
	if not item_offer.has(id) and not relic_offer.has(id):
		return "That isn't on offer"
	if not working():
		return "The market is closed" if complete else "The market isn't built yet"
	if village.armoury.full():
		return "The armoury is full (%d)" % village.armoury.cap()
	if not village.economy.can_afford({"gold": offer_price(id)}):
		return "Not enough gold"
	return ""


## Buys item or relic `id` off the offer into the armoury. Returns whether it did.
func buy_item(id: String) -> bool:
	if item_buy_error(id) != "":
		return false
	var gold := offer_price(id)
	village.economy.spend({"gold": gold}, "trade")
	village.sound("coin")
	if relic_offer.has(id):
		relic_offer.erase(id)
		Relics.bring_home(village, id)
		village.events.info("Bought the %s for %d gold" % [Relics.name_of(id), gold])
		return true
	item_offer.erase(id)
	village.armoury.add(id)
	village.events.info("Bought the %s for %d gold: it is in the armoury" % [str(Config.ITEMS[id]["name"]).to_lower(), gold])
	return true


# --- selling ------------------------------------------------------------------------------

## Why `amount` of `good` can't be put up for sale, or "".
func sell_error(good: String, amount: int) -> String:
	if not pile.has(good):
		return "The market doesn't take that"
	if not working():
		return "The market is closed" if complete else "The market isn't built yet"
	if amount <= 0:
		return "Nothing to sell"
	if pile_total() + amount > int(capacity()):
		return "The for-sale pile is full (%d)" % int(capacity())
	if village.economy.amount(good) < amount:
		return "Not enough %s" % _good_name(good)
	return ""


## Puts `amount` of `good` up for sale: it leaves the village's stock now.
func put_up(good: String, amount: int) -> bool:
	if sell_error(good, amount) != "":
		return false
	village.economy.spend({good: amount}, "trade")
	pile[good] = int(pile[good]) + amount
	village.events.debug("put %d %s up for sale at %s" % [amount, good, label()])
	village.sound("place")
	return true


## Why `amount` of `good` can't be taken back from the pile, or "".
func take_back_error(good: String, amount: int) -> String:
	if not pile.has(good):
		return "Nothing like that for sale"
	if amount <= 0 or int(pile[good]) <= 0:
		return "None of it is for sale"
	return ""


## Takes up to `amount` of `good` back from the for-sale pile into the village.
func take_back(good: String, amount: int) -> int:
	if take_back_error(good, amount) != "":
		return 0
	var n := mini(amount, int(pile[good]))
	pile[good] = int(pile[good]) - n
	village.economy.refund({good: n}, "trade")
	village.events.debug("took %d %s back from %s" % [n, good, label()])
	return n


## Gold a load of `goods` fetches at the map edge before the tax.
static func edge_value(goods: Dictionary) -> int:
	var lot := float(Config.MARKET["lot"])
	var g := 0.0
	for k in goods:
		g += float(goods[k]) * float(Config.MARKET["sell"].get(k, 0)) / lot
	return floori(g)


# --- the trader, caravans -----------------------------------------------------------------

func _process(delta: float) -> void:
	if game.is_client:
		return
	since_gain = 0.0 if stored > _last_stored else since_gain + delta
	_last_stored = stored
	var dimmed := sprite.modulate.r < 0.9
	if complete and dimmed == (worker != null):
		refresh()
	if not working():
		return
	if not has_rats():
		_restock(delta)
	if is_open():
		_pack(delta)
		tend_relic(delta)
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_dispatch()


## Every "restock_every" seconds while the stock has room, the merchants send
## a caravan from the nearest edge (one at a time).
func _restock(delta: float) -> void:
	if incoming() != null:
		return
	restock_timer -= delta
	if restock_timer > 0.0:
		return
	restock_timer = float(Config.MARKET["restock_every"])
	var cargo := {}
	var each := floorf(capacity() * float(Config.MARKET["restock"]))
	for good in ["food", "materials"]:
		var room := floorf(capacity() - stock(good))
		if room >= 1.0:
			cargo[good] = int(minf(each, room))
	if cargo.is_empty():
		return
	var edge := edge_tile()
	if edge == Vector2i(-1, -1) or not route_clear(game.world.pathing.find_path(edge, work_tile())):
		restock_timer = 10.0  # (try again soon)
		village.events.debug("%s: the merchants' caravan waits at the edge (%s)" % [label(), "no road to the edge" if edge == Vector2i(-1, -1) else "an enemy near the route from %s" % str(edge)])
		return
	_send(TradeCaravan.Trip.INCOMING, cargo, edge)


## The trader packs: orders first (another player's purchase), then the
## for-sale pile into a load for the edge.
func _pack(delta: float) -> void:
	var rate_now := float(Config.MARKET["pack_rate"]) * delta
	if not orders.is_empty():
		var o := orders[0]
		o["packed"] = minf(float(o["packed"]) + rate_now, float(o["amount"]))
		return
	var room := int(Config.MARKET["load"]) - packed_total()
	if room <= 0 or pile_total() <= 0:
		_pack_acc = 0.0
		return
	_pack_acc += rate_now
	var n := floori(_pack_acc)
	if n <= 0:
		return
	_pack_acc -= n
	var good := "food" if int(pile["food"]) >= int(pile["materials"]) else "materials"
	n = mini(mini(n, room), int(pile[good]))
	pile[good] = int(pile[good]) - n
	packed[good] = int(packed[good]) + n


## Loads that are ready leave once their way is clear and a caravan is free.
func _dispatch() -> void:
	var out := caravans_out().size()
	if out >= caravan_cap():
		if not orders.is_empty() or packed_total() > 0:
			_note_wait("all %d trade caravans are on the road (%d packed, %d ordered)" % [caravan_cap(), packed_total(), ordered()])
		return
	if not orders.is_empty():
		var o := orders[0]
		var buyer := game.villages[int(o["buyer"])]
		var bm := buyer.market()
		if bm == null or buyer.fallen:
			_refund_order(o, "%s has no market any more" % buyer.village_name)
			orders.pop_front()
			pile[o["good"]] = int(pile[o["good"]]) + int(o["amount"])
			village.events.debug("%s: order of %d %s for %s dropped (no market there): goods back on the pile" % [label(), int(o["amount"]), o["good"], buyer.village_name])
			return
		if float(o["packed"]) + 0.001 < float(o["amount"]):
			return
		if not route_clear(game.world.pathing.find_path(work_tile(), bm.work_tile())):
			_note_wait("the order for %s waits: an enemy near the route" % buyer.village_name)
			return
		orders.pop_front()
		var tc := _send(TradeCaravan.Trip.ORDER, {o["good"]: int(o["amount"])}, bm.work_tile())
		tc.buyer = buyer
		tc.escrow = int(o["gold"])
		_note_wait("")
		village.events.debug("%s: %s carries the order of %d %s to %s (%d gold in escrow; %d / %d caravans out)" % [label(), tc.label(), int(o["amount"]), o["good"], buyer.village_name, tc.escrow, out + 1, caravan_cap()])
		village.events.info("Trade caravan leaves for %s with %d %s" % [buyer.village_name, int(o["amount"]), _good_name(o["good"])])
		return
	var full := packed_total() >= int(Config.MARKET["load"])
	var whole := {}
	for good in packed:
		if int(packed[good]) > 0:
			whole[good] = int(packed[good])
	if whole.is_empty() or not (full or pile_total() <= 0):
		return
	var edge := edge_tile()
	if edge == Vector2i(-1, -1):
		_note_wait("a load of %s waits: no road to the edge" % _goods_text(whole))
		return
	if not route_clear(game.world.pathing.find_path(work_tile(), edge)):
		_note_wait("a load of %s waits: an enemy near the route to %s" % [_goods_text(whole), str(edge)])
		return
	for good in whole:
		packed[good] = 0
	var tc := _send(TradeCaravan.Trip.OUTGOING, whole, edge)
	_note_wait("")
	village.events.debug("%s: %s takes a load to the edge (%d / %d caravans out, %d left on the pile)" % [label(), tc.label(), out + 1, caravan_cap(), pile_total()])
	village.events.info("Trade caravan leaves for the map edge with %s" % _goods_text(whole))


## A debug line when the reason a load waits changes ("" : it went).
func _note_wait(why: String) -> void:
	if why == _wait_note:
		return
	_wait_note = why
	if why != "":
		village.events.debug("%s: %s" % [label(), why])


func _send(trip: TradeCaravan.Trip, cargo: Dictionary, to: Vector2i) -> TradeCaravan:
	var tc: TradeCaravan = TRADE_CARAVAN_SCRIPT.new()
	tc.setup(game, self, trip, cargo, to)
	game.world.objects.add_child(tc)
	return tc


## A refused or lost order: the buyer gets the gold back.
func _refund_order(o: Dictionary, why: String) -> void:
	var buyer := game.villages[int(o["buyer"])]
	buyer.economy.refund({"gold": int(o["gold"])}, "trade")
	buyer.events.info("Order of %d %s cancelled (%s): %d gold back" % [int(o["amount"]), _good_name(o["good"]), why, int(o["gold"])])


## The edge tile nearest the market by road: the village's own spawns in
## co-op, the map's edge spawns otherwise; (-1, -1) if none can be reached.
func edge_tile() -> Vector2i:
	var points: Array[Vector2i] = village.home_spawns if game.villages.size() > 1 and not village.home_spawns.is_empty() else game.map.edge_spawns
	var dist := game.world.pathing.distance_field(work_tile())
	var best := Vector2i(-1, -1)
	var best_d := float(Pathing.UNREACHABLE)
	for p in points:
		var d := float(dist[game.map.index(p)])
		if d < best_d:
			best_d = d
			best = p
	return best


## No enemy our village can see is within MARKET "blocked_radius" of `path`
## (camp guards stay at their camps and don't count).
func route_clear(path: PackedVector2Array) -> bool:
	return TradeCaravan.first_block(game, village, path, 0, path.size()) < 0


## Salvage brought back (TradeCaravan.drop_salvage): our goods back on the
## pile; the merchants' into their stock, with a finder's fee. Returns the fee.
func take_salvage(goods: Dictionary, merchants: bool) -> int:
	var fee := 0
	for good in goods:
		if merchants:
			add_stock(good, float(goods[good]))
			fee += floori(float(goods[good]) * float(Config.MARKET["buy"][good]["gold"]) / float(Config.MARKET["buy"][good]["amount"]) * float(Config.MARKET["finder_fee"]))
		else:
			pile[good] = int(pile.get(good, 0)) + int(goods[good])
	if fee > 0:
		village.economy.add("gold", fee, "salvage")
	game.stats.count(village, "trade.salvage")
	return fee


func can_upgrade() -> bool:
	return free_for_work() and level < max_level()


func upgrade_cost() -> Dictionary:
	return spec_level_at(level + 1).get("cost", {}) if level < max_level() else {}


func spec_level_at(lv: int) -> Dictionary:
	return Config.MARKET["levels"][clampi(lv, 1, max_level()) - 1]


func start_upgrade() -> void:
	upgrading = true
	upgrade_progress = 0.0
	upgrade_time = float(spec_level_at(level + 1)["work_time"])
	queue_redraw()


func pending_upgrade_cost() -> Dictionary:
	return upgrade_cost() if upgrading else {}


func finish_upgrade() -> void:
	super.finish_upgrade()
	gain_level()
	refresh()


## Its price plus the upgrades paid for (tear-down refund).
func materials_spent() -> int:
	var n := super.materials_spent()
	for i in range(2, level + 1):
		n += int(spec_level_at(i).get("cost", {}).get("materials", 0))
	return n


## Torn down: what was up for sale (and packed, or reserved by an order)
## comes back to the village; other players' orders are refunded
## (Construction calls it).
func clear_out() -> void:
	for good in pile:
		if int(pile[good]) > 0:
			village.economy.refund({good: int(pile[good])}, "trade")
			pile[good] = 0
	for good in packed:
		if int(packed[good]) > 0:
			village.economy.refund({good: int(packed[good])}, "trade")
		packed[good] = 0
	for o in orders:  # (the buyer's gold back to them, the goods back to us)
		_refund_order(o, "the seller's market is gone")
		village.economy.refund({o["good"]: int(o["amount"])}, "trade")
	orders.clear()


static func _good_name(good: String) -> String:
	return "building material" if good == "materials" else good


static func _goods_text(goods: Dictionary) -> String:
	var parts: PackedStringArray = []
	for g in goods:
		parts.append("%d %s" % [int(goods[g]), _good_name(g)])
	return ", ".join(parts)


# --- panel --------------------------------------------------------------------------------

func info() -> Dictionary:
	var d := super.info()
	if working():
		d["title"] = "%s  ·  Level %d/%d" % [display_name(), level, max_level()]
	return d


func _work_info(d: Dictionary) -> void:
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	var cap := int(capacity())
	lines.append("Merchants' stock: %d {food}  %d {materials}  (up to %d each)" % [int(stored), int(stock_materials), cap])
	if has_rats():
		lines.append("%d rat%s eating the merchants' food!" % [rats.size(), "" if rats.size() == 1 else "s"])
	var inc := _net_incoming if game.is_client else incoming() != null
	if inc:
		lines.append("A merchants' caravan is on its way.")
	else:
		lines.append("Next merchants' caravan in %d s." % ceili(maxf(restock_timer, 0.0)))
	for good: String in Config.MARKET["buy"]:
		var lot: Dictionary = Config.MARKET["buy"][good]
		var err := buy_error(good)
		var where := _source_name(good)
		where = "" if where == "" else "  from %s" % where
		actions.append({
			"label": "Buy %s  (%s)%s" % [Config.cost_icons({good: lot["amount"]}), Config.cost_icons({"gold": lot["gold"]}), where],
			"disabled": err != "",
			"action": func() -> void: game.command("market_buy", {"building": nid, "good": good}),
		})
	if game.items_enabled():
		_item_info(lines, actions)
	if worker == null:
		lines.append("No trader: nothing you put up for sale leaves. Recruit one in the Village tab.")
	elif not is_open():
		lines.append("%s is away: packing waits until he's back." % worker.label().capitalize())
	var on_road := _net_road if game.is_client else caravans_out().size()
	lines.append("For sale: %d {food}  %d {materials}  (pile up to %d)  ·  packed: %d" % [int(pile["food"]), int(pile["materials"]), cap, packed_total()])
	if not orders.is_empty():
		lines.append("Orders from other players: %d goods to pack first." % ordered())
	lines.append("Trade caravans on the road: %d / %d  ·  tax at the edge: %d%%" % [on_road, caravan_cap(), roundi(tax() * 100.0)])
	var lot_n := int(Config.MARKET["lot"])
	for good: String in pile:
		var cost := {good: lot_n}
		var gold := floori(float(Config.MARKET["sell"][good]) * (1.0 - tax()))
		var err := sell_error(good, lot_n)
		actions.append({
			"label": "Sell %s  (+%s at the edge)" % [Config.cost_icons(cost), Config.cost_icons({"gold": gold})],
			"disabled": err != "",
			"action": func() -> void: game.command("market_sell", {"building": nid, "good": good, "amount": lot_n}),
		})
	for good: String in pile:
		if int(pile[good]) > 0:
			actions.append({
				"label": "Take back %s" % Config.cost_icons({good: mini(lot_n, int(pile[good]))}),
				"action": func() -> void: game.command("market_take_back", {"building": nid, "good": good, "amount": lot_n}),
			})
	if game.villages.size() > 1:
		for good: String in Config.MARKET["buy"]:
			actions.append({
				"label": "Ask for %s (tell the others)" % Config.cost_icons({good: Config.MARKET["buy"][good]["amount"] * 5}),
				"action": func() -> void: game.command("post_demand", {"good": good, "amount": int(Config.MARKET["buy"][good]["amount"]) * 5}),
			})
	if upgrading:
		lines.append("Upgrading to level %d: %d%% (%s)" % [level + 1, int(100.0 * work_fraction()), _builder_crew_text().to_lower()])
		add_cancel_action(lines, actions, "Cancel upgrade")
	elif level < max_level() and not repairing:
		var nxt := spec_level_at(level + 1)
		lines.append("Next level: stock %d, %d caravans, tax %d%%, {hp} %d." % [int(nxt["stock"]), int(nxt["caravans"]), roundi(float(nxt["tax"]) * 100.0), roundi(hp_at(level + 1))])
		actions.append({
			"label": "Upgrade market (%s)" % Config.cost_icons(upgrade_cost()),
			"disabled": not village.economy.can_afford(upgrade_cost()),
			"action": func() -> void: game.command("upgrade_tower", {"building": nid}),
		})


## The equipment on offer: a buy action each.
func _item_info(lines: Array[String], actions: Array[Dictionary]) -> void:
	_relic_info(lines, actions)
	if item_offer.is_empty():
		lines.append("No equipment on offer: the merchants' next caravan brings some.")
		return
	lines.append("Equipment on offer (new with each merchants' caravan):")
	var gold := int(Config.MARKET["item_gold"])
	for id in item_offer.duplicate():
		var spec: Dictionary = Config.ITEMS[id]
		var err := item_buy_error(id)
		lines.append("{item:%s} %s (%s): %s" % [id, spec["name"], Config.ITEM_SLOT_NAMES[spec["slot"]].to_lower(), spec["desc"]])
		actions.append({
			"label": "Buy {item:%s} %s  (%s)" % [id, spec["name"], Config.cost_icons({"gold": gold})],
			"disabled": err != "",
			"action": func() -> void: game.command("market_buy_item", {"building": nid, "item": id}),
		})


## "4 min", "40 s".
static func _minutes(s: float) -> String:
	return "%d min" % ceili(s / 60.0) if s >= 60.0 else "%d s" % ceili(s)


## The relic on offer (or how long until the trader finds one): a buy action.
func _relic_info(lines: Array[String], actions: Array[Dictionary]) -> void:
	var left := maxf(0.0, float(Config.MARKET["relic_after"]) - stationed)
	var when := "%s more of the trader's time here%s" % [_minutes(left), "" if is_open() else " (he is away: it waits)"]
	if worker == null:
		lines.append("A trader tending the market brings a new relic for sale every %s of his time." % _minutes(float(Config.MARKET["relic_after"])))
	elif relic_offer.is_empty():
		lines.append("The next relic for sale: %s." % when)
	for id in relic_offer.duplicate():
		var err := item_buy_error(id)
		var dup := " You have one: a second does nothing more." if Relics.has_relic(village, id) else ""
		lines.append(("A relic on offer for %s: " % when) + "%s %s: %s.%s" % [Relics.token(id), Relics.name_of(id), Relics.desc_of(id).trim_suffix("."), dup])
		actions.append({
			"label": "Buy %s %s  (%s)" % [Relics.token(id), Relics.name_of(id), Config.cost_icons({"gold": offer_price(id)})],
			"disabled": err != "",
			"action": func() -> void: game.command("market_buy_item", {"building": nid, "item": id}),
		})


func _draw() -> void:
	_draw_bars()


func _bar_y() -> float:
	return -120.0
