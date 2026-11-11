class_name BalanceMarket
extends BalancePart
## The marketplace of the balancing bot's player: the same for every policy
## (Config.BALANCE_ECONOMY "market" and the keys after it;
## docs/balance-bot-design.md §3). It is built once the economy is steady
## (`steady`). A trader is kept only while he has something to do: goods
## beyond what the village keeps to sell, a sale still on its way, or gold to
## spare for the relic he brings. A full village lets someone go to make room
## for him (BALANCE_ECONOMY "trader_swap") and lets him go again once he has
## been idle a while; the economy then recruits the missing role back. Relics
## on offer are bought with spare gold. Every such choice is a decision
## (BalancePlayer.decide).

var _eco: Dictionary = Config.BALANCE_ECONOMY
## Game clock since when the food has grown (-1: it doesn't now).
var _growing_since := -1.0
## Game clock since when the trader has had nothing to do (-1: he has).
var _idle_since := -1.0
## Goods put up for sale: good -> amount.
var put_up := {}
## [{"t", "wave", "id", "gold"}]: relics bought.
var relics: Array[Dictionary] = []
var trader_hires := 0
var trader_retires := 0
## Good -> the wave its first sale was noted in (decide).
var _sale_noted := {}


func think() -> void:
	_track_food()
	if not bool(_eco.get("market", false)) or not game.allows_building("market"):
		return
	var m := village.market()
	if m == null:
		p.hut_for_trader = false
		if steady() and _wave() >= int(_eco["market_from_wave"]) and not p.repair_wanted:
			var cost: Dictionary = Config.BUILDINGS["market"]["cost"]
			if not _can_afford(cost):
				_claim(cost)
				return
			_place("market")
			if village.market() != null:
				p.decide("market", "placing the marketplace (the economy is steady)")
		return
	if not m.working():
		return
	_trader(m)
	if _trader_of(m) != null:
		_sell(m)
	_relic(m)


# --- the economy is steady ---------------------------------------------------------------

## Every farm and camp the schedule wants by now stands and is worked, nothing
## waits for material, and the food has grown for "market_steady" s.
func steady() -> bool:
	return p.economy.schedule_met() and _growing_since >= 0.0 and game.clock - _growing_since >= float(_eco["market_steady"])


func _track_food() -> void:
	if village.population.food_per_second() >= 0.0:
		if _growing_since < 0.0:
			_growing_since = game.clock
	else:
		_growing_since = -1.0


# --- the trader --------------------------------------------------------------------------

func _trader_of(_m: Market) -> Civilian:
	for c in village.population.civilians:
		if c.role == "trader" and not c.dead:
			return c
	return null


## Why a trader is wanted now ("": he isn't).
func _trader_reason(m: Market) -> String:
	if m.pile_total() > 0 or m.packed_total() > 0 or not m.caravans_out().is_empty():
		return "goods are still for sale"
	for good: String in ["food", "materials"]:
		if _surplus(good) >= int(Config.MARKET["lot"]):
			return "%d %s to sell" % [_surplus(good), good]
	if game.items_enabled() and _spare_gold() >= float(Config.MARKET["relic_gold"]) + float(_eco["relic_spare"]):
		return "gold to spare for the relic he brings"
	return ""


func _trader(m: Market) -> void:
	var t := _trader_of(m)
	var why := _trader_reason(m)
	var pop := village.population
	if t != null:
		p.hut_for_trader = false
		if why != "":
			_idle_since = -1.0
			return
		if _idle_since < 0.0:
			_idle_since = game.clock
		if game.clock - _idle_since >= float(_eco["trader_idle"]) and pop.retire_error(t) == "":
			if _cmd("retire_villager", {"civilian": t.nid})["ok"]:
				trader_retires += 1
				_idle_since = -1.0
				p.decide("market", "the trader is let go (nothing to do for %d s): the hut goes back to the economy" % int(_eco["trader_idle"]))
		return
	if why == "":
		p.hut_for_trader = false
		return
	if pop.free_huts().is_empty():
		var out := _swap_out()
		if out != null and _cmd("retire_villager", {"civilian": out.nid})["ok"]:
			p.hut_for_trader = true  # (the economy leaves the hut for him)
			p.decide("market", "a %s is let go to make room for a trader (%s)" % [out.role, why])
		return
	if pop.recruit_error("trader") == "" and _cmd("recruit_villager", {"role": "trader"})["ok"]:
		trader_hires += 1
		p.hut_for_trader = false
		p.decide("market", "a trader is hired (%s)" % why)


## The villager a full village lets go for a trader: the first of
## "trader_swap" whose role has more than its "trader_keep".
func _swap_out() -> Civilian:
	var pop := village.population
	var keep: Dictionary = _eco["trader_keep"]
	for role: String in _eco["trader_swap"]:
		if pop.count(role) <= int(keep.get(role, 0)):
			continue
		for c in pop.civilians:
			if c.role == role and pop.retire_error(c) == "":
				return c
	return null


# --- selling -----------------------------------------------------------------------------

## What of `good` the village can do without, in whole lots: food beyond
## "keep_food_s" of upkeep (at least BALANCE_BOT "min_food"), material beyond
## "keep_materials" and what waits for it.
func _surplus(good: String) -> int:
	var have := village.economy.amount(good)
	var keep := 0.0
	if good == "food":
		keep = maxf(float(_params["min_food"]), village.population.upkeep() * float(_eco["keep_food_s"]))
		if village.population.food_per_second() < 0.0:
			return 0
	else:
		keep = float(_eco["keep_materials"]) + float(p.want_materials)
		if p.repair_wanted:
			return 0
	var lot := int(Config.MARKET["lot"])
	return maxi(0, floori((have - keep) / float(lot))) * lot


func _sell(m: Market) -> void:
	for good: String in ["food", "materials"]:
		var room := int(m.capacity()) - m.pile_total()
		var n := mini(_surplus(good), room - room % int(Config.MARKET["lot"]))
		if n <= 0:
			continue
		if _cmd("market_sell", {"building": m.nid, "good": good, "amount": n})["ok"]:
			put_up[good] = int(put_up.get(good, 0)) + n
			if int(_sale_noted.get(good, -1)) != _wave():  # (once a wave and good: the totals are in `put_up`)
				_sale_noted[good] = _wave()
				p.decide("market", "selling %s: %d put up (beyond what the village keeps; more may follow this wave)" % [good, n])


# --- relics ------------------------------------------------------------------------------

## Gold beyond BALANCE_BOT "gold_reserve" and what the military holds back.
func _spare_gold() -> float:
	return _gold() - float(_params["gold_reserve"]) - float(p.military.reserved_gold())


func _relic(m: Market) -> void:
	if m.relic_offer.is_empty():
		return
	var id: String = m.relic_offer[0]
	var price := Market.offer_price(id)
	if _spare_gold() < float(price) + float(_eco["relic_spare"]):
		return
	if _cmd("market_buy_item", {"building": m.nid, "item": id})["ok"]:
		relics.append({"t": snappedf(game.clock, 0.1), "wave": _wave(), "id": id, "gold": price})
		p.decide("market", "bought the relic %s for %d gold (spare gold)" % [id, price])
