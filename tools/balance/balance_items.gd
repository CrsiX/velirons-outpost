class_name BalanceItems
extends BalancePart
## The hero's equipment, for the policies with an "equipment" entry
## (Config.BALANCE_PROFILES; docs/balance-bot-design.md §3). For each slot
## still on its default (Config.ITEM_DEFAULTS), the first item the armoury has
## for it goes on; after that she keeps what she wears: judging one item
## against another would be a balance opinion of its own. Equipment the
## marketplace offers for such a slot is bought with gold beyond the policy's
## "reserve" (over BALANCE_BOT "gold_reserve" and the next unit). Where items
## come from otherwise (camps, lairs, late waves) the policy's hero settings
## decide ("hero": she goes after monster camps). Every item put on or bought
## is a decision (BalancePlayer.decide).

var _spec: Dictionary
## [{"t", "wave", "slot", "id"}]: every item she put on.
var worn: Array[Dictionary] = []
## [{"t", "wave", "id", "gold"}]: every item bought at the marketplace.
var bought: Array[Dictionary] = []


func _init(p_player: BalancePlayer) -> void:
	super(p_player)
	_spec = p_player.profile["equipment"]


func think() -> void:
	var h := village.hero
	if not is_instance_valid(h) or not game.items_enabled():
		return
	_buy()
	if h.swap_error() != "":
		return
	for slot: String in Config.ITEM_SLOTS:
		if h.equipped.has(slot):
			continue  # (she keeps what she wears)
		var have := village.armoury.for_slot(slot)
		if have.is_empty():
			continue
		if _cmd("equip", {"item": have[0]})["ok"]:
			worn.append({"t": snappedf(game.clock, 0.1), "wave": _wave(), "slot": slot, "id": have[0]})
			p.decide("items", "the hero puts on the %s (%s; she had the default)" % [have[0], slot])


## The first item on offer for a slot that is still on its default and that
## the armoury doesn't hold one for yet.
func _buy() -> void:
	var m := village.market()
	if m == null or not m.working():
		return
	var h := village.hero
	for id: String in m.item_offer:
		var slot := str(Config.ITEMS[id]["slot"])
		if h.equipped.has(slot) or not village.armoury.for_slot(slot).is_empty():
			continue
		var price := Market.offer_price(id)
		if _gold() < float(price) + float(_spec.get("reserve", 0.0)) + float(_params["gold_reserve"]) + float(p.military.reserved_gold()):
			p.save_gold = maxi(p.save_gold, price + int(_spec.get("reserve", 0.0)))  # (unit upgrades wait for it)
			return
		if _cmd("market_buy_item", {"building": m.nid, "item": id})["ok"]:
			bought.append({"t": snappedf(game.clock, 0.1), "wave": _wave(), "id": id, "gold": price})
			p.decide("items", "bought the %s at the marketplace for %d gold (her %s is the default)" % [id, price, slot])
		return
