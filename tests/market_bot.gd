extends "res://tests/bot_base.gd"
## Headless test of the marketplace, the trader and trade caravans
## (docs/market-design.md): placing (a road, one per village), buying from the
## merchants' stock, selling through the trader and a caravan to the map edge
## (gold on arrival, minus the tax), the departure rule, turning back, a thief
## robbing a caravan and its salvage carried back, a destroyed merchants'
## caravan (finder's fee), the merchants' restocking, the save, and the co-op
## order book in a two-village game. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/market_bot.tscn
## Exits 0 when every check passes.

const SEED := 4242

var v: Village
var m: Market


func _run() -> void:
	_test_config()
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = SEED
	game.disable_fog = true
	add_child(game)
	await frames(3)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	_bench_hero(true)
	v = game.player_village
	game.economy.add("gold", 3000)
	game.economy.add("materials", 2000)
	game.economy.add("food", 2000)
	Engine.time_scale = 8.0
	_test_placing()
	if m == null:
		_finish()
		return
	await _test_trader()
	_test_buying()
	await _test_selling()
	await _test_departure_rule()
	await _test_turn_back()
	await _test_robbery()
	await _test_destroyed()
	await _test_restock()
	_test_save()
	game.queue_free()
	await frames(3)
	await _test_order_book()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func _test_config() -> void:
	var mk: Dictionary = Config.MARKET
	var lv: Array = mk["levels"]
	var ok := lv.size() == 3 and (Config.BUILDING_HP["market"] as Array).size() == lv.size()
	for i in lv.size():
		ok = ok and int(lv[i]["stock"]) > 0 and int(lv[i]["caravans"]) > 0 and float(lv[i]["tax"]) >= 0.0
		if i > 0:
			ok = ok and int(lv[i]["stock"]) > int(lv[i - 1]["stock"]) and float(lv[i]["tax"]) < float(lv[i - 1]["tax"]) and lv[i].has("cost") and lv[i].has("work_time")
	check(ok, "market levels: more stock and lower tax each level, an upgrade cost and time, HP for each")
	for good in ["food", "materials"]:
		var buy_each := float(mk["buy"][good]["gold"]) / float(mk["buy"][good]["amount"])
		var sell_each := float(mk["sell"][good]) / float(mk["lot"])
		check(sell_each < buy_each, "%s sells for less than it costs to buy (%.2f < %.2f gold each)" % [good, sell_each, buy_each])
	check(Config.CIVILIANS["trader"]["works_at"] == "market" and int(Config.CIVILIANS["trader"]["max"]) == 1, "the trader works at the market, one per village")
	for art in ["market", "market_2", "market_3", "unit_trader", "unit_trade_cart", "unit_trade_cart_c0", "salvage"]:
		check(ResourceLoader.exists("res://art/%s.svg" % art), "art: %s" % art)


func _test_placing() -> void:
	check(game.allows_building("market") and game.available("trader"), "a free game has the market and the trader")
	var far := Vector2i(-1, -1)
	for y in range(2, game.map.size - 2):
		for x in range(2, game.map.size - 2):
			var t := Vector2i(x, y)
			if v.construction.placement_error("market", t) == "A marketplace must touch a road":
				far = t
				break
		if far != Vector2i(-1, -1):
			break
	check(far != Vector2i(-1, -1), "a market away from the roads is refused")
	var t := find_spot("market", v.center)
	check(t != Vector2i(-1, -1), "a spot by a road for the market (%s)" % str(t))
	if t == Vector2i(-1, -1):
		return
	var r := game.command("place_building", {"kind": "market", "tile": t})
	check(r["ok"], "placed (%s)" % r.get("error", ""))
	m = v.market()
	var t2 := find_spot("farm", v.center)
	check(v.construction.placement_error("market", t2) == "The village has a marketplace already" or t2 == Vector2i(-1, -1), "one per village: a second one is refused (%s)" % v.construction.placement_error("market", t2))
	m.finish()
	v.construction.queue.erase(m)
	check(m.working() and is_equal_approx(m.stock("food"), floorf(m.capacity() * float(Config.MARKET["start_stock"]))), "finished, the merchants' stock starts at %d each" % int(m.stock("food")))


func _test_trader() -> void:
	var r := game.command("recruit_villager", {"role": "trader"})
	check(r["ok"], "a trader is recruited (%s)" % r.get("error", ""))
	check(not game.command("recruit_villager", {"role": "trader"})["ok"], "only one trader per village (%s)" % v.population.recruit_error("trader"))
	check(m.worker is Trader, "the trader goes to work at the market")
	check(await wait_until(func() -> bool: return m.is_open(), 30.0), "he walks there and tends it")


func _test_buying() -> void:
	var gold := v.economy.amount("gold")
	var food := v.economy.amount("food")
	var stock := m.stock("food")
	var lot: Dictionary = Config.MARKET["buy"]["food"]
	var r := game.command("market_buy", {"building": m.nid, "good": "food"})
	check(r["ok"] and is_equal_approx(v.economy.amount("gold"), gold - int(lot["gold"])) and is_equal_approx(v.economy.amount("food"), food + int(lot["amount"])), "buying a lot of food: gold for food, at once")
	check(is_equal_approx(m.stock("food"), stock - int(lot["amount"])), "it comes out of the merchants' stock")
	m.add_stock("materials", -m.stock("materials"))
	check(not game.command("market_buy", {"building": m.nid, "good": "materials"})["ok"], "sold out: refused (%s)" % m.buy_error("materials"))
	m.add_stock("materials", m.capacity() / 2.0)


func _test_selling() -> void:
	var lot := int(Config.MARKET["lot"])
	var food := v.economy.amount("food")
	var r := game.command("market_sell", {"building": m.nid, "good": "food", "amount": lot})
	check(r["ok"] and is_equal_approx(v.economy.amount("food"), food - lot) and int(m.pile["food"]) + m.packed_total() >= lot - 1, "put up for sale: it leaves the village's stock at once")
	game.command("market_sell", {"building": m.nid, "good": "food", "amount": lot})
	var back := game.command("market_take_back", {"building": m.nid, "good": "food", "amount": 5})
	check(back["ok"] and int(back["amount"]) == 5, "some taken back from the pile")
	check(not game.command("market_sell", {"building": m.nid, "good": "food", "amount": int(m.capacity()) + 1})["ok"], "the pile holds at most the level's stock")
	var gold := v.economy.amount("gold")
	check(await wait_until(func() -> bool: return not m.caravans_out().is_empty(), 60.0), "the trader packs it and a trade caravan leaves")
	if m.caravans_out().is_empty():
		return
	var tc := m.caravans_out()[0]
	var cargo := tc.cargo.duplicate()
	var value := Market.edge_value(cargo)
	var expect := floori(value * (1.0 - m.tax()))
	check(tc.trip == TradeCaravan.Trip.OUTGOING and tc.is_in_group("villagers"), "to the map edge; enemies can hit it like a villager")
	check(is_equal_approx(v.economy.amount("gold"), gold), "no gold before the goods arrive")
	check(await wait_until(func() -> bool: return tc.returning, 120.0), "it reaches the edge")
	check(is_equal_approx(v.economy.amount("gold"), gold + expect) and expect > 0, "paid on arrival: %d gold for %s (tax %d%%)" % [expect, Market._goods_text(cargo), roundi(m.tax() * 100.0)])
	check(await wait_until(when_gone(tc, func(x: TradeCaravan) -> bool: return x.dead), 120.0), "and drives home empty")


## Spawns a `kind` on the road by `at` (a tile on the caravan's way).
func _foe(kind: String, at: Vector2) -> Enemy:
	var e := game.waves.spawn_at(kind, Vector2i(at.round()), v, 1)
	e.set_grid_pos(at)
	e.path = PackedVector2Array([at])
	e.path_index = 1
	e.speed = 0.0
	return e


func _test_departure_rule() -> void:
	m.pile["food"] = 0
	m.pile["materials"] = 0
	m.packed["food"] = 30
	var way := game.world.pathing.find_path(m.work_tile(), m.edge_tile())
	var e := _foe("goblin", way[way.size() / 2])
	game.fog.update_surveillance()
	check(not m.route_clear(way), "a visible enemy on the way: the route isn't clear")
	await wait(4.0)
	check(m.caravans_out().is_empty(), "so the load waits at the market")
	kill(e)
	await frames(3)
	check(await wait_until(func() -> bool: return not m.caravans_out().is_empty(), 10.0), "it's gone: the caravan sets off")
	var tc := m.caravans_out()[0]
	await wait_until(when_gone(tc, func(x: TradeCaravan) -> bool: return x.dead), 200.0)


func _test_turn_back() -> void:
	m.packed["food"] = 30
	check(await wait_until(func() -> bool: return not m.caravans_out().is_empty(), 10.0), "another load sets off")
	var tc := m.caravans_out()[0]
	await wait(1.0)
	var ahead := tc.path[mini(tc.path_index + 6, tc.path.size() - 1)]
	var e := _foe("goblin", ahead)
	game.fog.update_surveillance()
	check(await wait_until(func() -> bool: return tc.returning, 5.0), "an enemy on the road ahead: it turns back")
	check(await wait_until(when_gone(tc, func(x: TradeCaravan) -> bool: return x.dead), 60.0) and int(m.packed["food"]) >= 30, "home again, its goods back in the load (%d packed)" % int(m.packed["food"]))
	kill(e)
	await frames(3)
	m.packed["food"] = 0


func _test_robbery() -> void:
	m.packed["materials"] = 40
	check(await wait_until(func() -> bool: return not m.caravans_out().is_empty(), 10.0), "a load of material sets off")
	var tc := m.caravans_out()[0]
	await wait(1.0)
	var at := tc.grid_pos + (tc.path[mini(tc.path_index + 1, tc.path.size() - 1)] - tc.grid_pos).normalized() * 1.5
	var thief := _foe("thief", at)
	thief.speed = thief.base_speed
	var way := tc.path.slice(tc.path_index)  # (its road: towards the cart, so it never "reaches a gate")
	way.reverse()
	way.append(Vector2(m.work_tile()))
	way[0] = at
	thief.follow(way)
	tc.returning = false
	tc._look = 999.0  # (the cart drives on regardless, so the thief gets it)
	check(await wait_until(func() -> bool: return not thief.loot_cargo.is_empty() or thief.dead, 20.0), "a thief in reach robs the caravan")
	check(tc.cargo.is_empty() and tc.returning and not tc.dead, "the empty cart drives home unharmed")
	var goods: Dictionary = thief.loot_cargo.get("goods", {})
	check(int(goods.get("materials", 0)) == 40, "the thief carries the whole cargo")
	kill(thief)
	await frames(3)
	var sack := _salvage()
	check(sack != null, "killed, the thief leaves the cargo as salvage")
	if sack == null:
		return
	check(sack.art() == "salvage" and sack.reward()["salvage"]["merchants"] == false, "salvage of our own goods")
	var pile := int(m.pile["materials"])
	_bench_hero(false)
	game.command("hero_mode", {"mode": Hero.Mode.GATHER})
	var xp := game.hero.xp
	check(await wait_until(func() -> bool: return int(m.pile["materials"]) >= pile + 40, 120.0), "the hero gathering carries it back: onto the for-sale pile")
	check(game.hero.xp >= xp + int(Config.HERO_XP_PER_ACTION["salvage"]), "and earns XP for it")
	game.command("hero_mode", {"mode": Hero.Mode.DEFEND})
	_bench_hero(true)
	m.pile["materials"] = 0
	await wait_until(func() -> bool: return m.caravans_out().is_empty(), 120.0)


func _salvage() -> Treasure:
	for o in game.world.map_objects:
		if o is Treasure and (o as Treasure).reward().has("salvage") and not (o as Treasure).looted:
			return o
	return null


func _test_destroyed() -> void:
	m.restock_timer = 0.0
	m.add_stock("food", -m.stock("food"))
	check(await wait_until(func() -> bool: return m.incoming() != null, 5.0), "the stock has room: the merchants send a caravan")
	var tc := m.incoming()
	if tc == null:
		return
	check(tc.trip == TradeCaravan.Trip.INCOMING and TradeCaravan.art_for(tc.trip, v) == "unit_trade_cart", "a neutral merchants' cart from the edge")
	await wait(1.0)
	var cargo := int(tc.cargo.get("food", 0))
	tc.take_damage(1e6, null, "melee")
	await frames(3)
	var sack := _salvage()
	check(sack != null and bool(sack.reward()["salvage"]["merchants"]), "destroyed, it leaves the merchants' goods as salvage")
	if sack == null:
		return
	var gold := v.economy.amount("gold")
	var stock := m.stock("food")
	var r := game.command("recruit_villager", {"role": "gatherer"})
	check(r["ok"], "a gatherer is recruited")
	check(await wait_until(func() -> bool: return m.stock("food") >= stock + cargo - 0.5, 150.0), "a gatherer carries it to the market: into the merchants' stock")
	var fee := floori(cargo * float(Config.MARKET["buy"]["food"]["gold"]) / float(Config.MARKET["buy"]["food"]["amount"]) * float(Config.MARKET["finder_fee"]))
	check(fee > 0 and v.economy.amount("gold") >= gold + fee - 0.5, "for a finder's fee (%d gold)" % fee)


func _test_restock() -> void:
	m.restock_timer = 0.0
	m.add_stock("materials", -m.stock("materials"))
	var before := m.stock("materials")
	check(await wait_until(func() -> bool: return m.incoming() != null, 5.0), "a merchants' caravan is sent")
	check(await wait_until(func() -> bool: return m.stock("materials") > before, 200.0), "it arrives and refills the stock (%d material)" % int(m.stock("materials")))
	check(m.incoming() == null or m.incoming().dead, "and is gone")


func _test_save() -> void:
	m.pile["food"] = 17
	m.orders.append({"buyer": 0, "good": "food", "amount": 20, "gold": 24, "packed": 3.0})
	m.packed["food"] = 12
	var tc: TradeCaravan = m._send(TradeCaravan.Trip.OUTGOING, {"food": 9}, m.edge_tile())
	var body := SaveGame.capture(game)
	var saved: Array = body["buildings"].filter(func(d: Dictionary) -> bool: return d["n"] == m.nid)
	var mk: Dictionary = saved[0].get("mk", {}) if saved.size() == 1 else {}
	check(int(mk.get("pile", {}).get("food", 0)) == 17 and (mk.get("ord", []) as Array).size() == 1 and int(mk.get("pk", {}).get("food", 0)) == 12, "a save holds the market's pile, load and orders")
	var trade: Array = body["trade"]
	check(trade.any(func(d: Dictionary) -> bool: return int(d["n"]) == tc.nid and int(d["cargo"]["food"]) == 9), "and its trade caravans on the road")
	var civs: Array = body["civilians"]
	check(civs.any(func(d: Dictionary) -> bool: return d["r"] == "trader" and int(d.get("mkt", 0)) == m.nid), "and where the trader works")
	m.orders.clear()


## The co-op order book: a purchase is filled from another player's pile
## first, by trade caravan, with no tax; the seller is paid on arrival.
func _test_order_book() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = 12
	game.test_villages = 2
	game.disable_fog = true
	add_child(game)
	await frames(5)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	_bench_hero(true)
	var a := game.villages[0]
	var b := game.villages[1]
	var ms: Array[Market] = []
	for vv in [a, b]:
		vv.economy.add("gold", 2000)
		vv.economy.add("materials", 2000)
		vv.economy.add("food", 2000)
		var t := _spot_for(vv)
		var mk: Market = vv.construction.place("market", t) as Market if t != Vector2i(-1, -1) else null
		if mk:
			mk.finish()
			vv.construction.queue.erase(mk)
		ms.append(mk)
	check(ms[0] != null and ms[1] != null, "both villages have a market")
	if ms[0] == null or ms[1] == null:
		return
	b.population.recruit("trader")
	await wait_until(func() -> bool: return ms[1].is_open(), 30.0)
	ms[1].put_up("food", 60)  # (and a buys at once, before b's trader packs any of it for the edge)
	var lot: Dictionary = Config.MARKET["buy"]["food"]
	check(ms[0].source("food") == ms[1], "a's purchase is filled from b's pile first")
	var a_gold := a.economy.amount("gold")
	var a_food := a.economy.amount("food")
	var b_gold := b.economy.amount("gold")
	var r := game.commands.submit(a, "market_buy", {"building": ms[0].nid, "good": "food"})
	check(r["ok"] and is_equal_approx(a.economy.amount("gold"), a_gold - int(lot["gold"])) and is_equal_approx(a.economy.amount("food"), a_food), "a pays now; the food comes by caravan")
	check(ms[1].orders.size() == 1, "an order on b's book")
	check(await wait_until(func() -> bool: return a.economy.amount("food") >= a_food + int(lot["amount"]), 300.0), "b's trader packs it, the caravan reaches a")
	check(b.economy.amount("gold") >= b_gold + int(lot["gold"]) - 0.5, "b is paid the full price: no tax between players")
	game.queue_free()
	await frames(3)


func _spot_for(vv: Village) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			var d := Vector2(t).distance_to(Vector2(vv.center))
			if d < best_d and d < 16.0 and vv.construction.placement_error("market", t) == "" and game.world.pathing.can_reach(vv.center, t):
				best_d = d
				best = t
	return best
