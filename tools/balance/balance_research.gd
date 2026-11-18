class_name BalanceResearch
extends BalancePart
## Research at the town hall, for the policies with a "research" entry
## (Config.BALANCE_PROFILES; docs/balance-bot-design.md §3). Once the economy
## is steady (BalanceMarket.steady) it upgrades the town hall by the policy's
## "hall_levels". Of the advancements it could take now (every condition met
## but the price) it picks one at random, and waits until the gold covers it
## with "reserve" to spare beyond the army's (BALANCE_BOT "gold_reserve", the
## next unit), its food with BALANCE_BOT "min_food" left to eat, and its
## material (which it claims, as the economy's buildings do). It picks again after each advancement it takes and after each
## town hall level, never in between: a random player who sticks to a plan.
## Every pick and purchase is a decision (BalancePlayer.decide).

var _spec: Dictionary
## The advancement it saves up for ("": none picked yet).
var pick := ""
## [{"t", "wave", "id", "from"}]: every pick, with the ids it was picked from.
var picks: Array[Dictionary] = []
## [{"t", "wave", "id", "gold"}]: every advancement it started.
var started: Array[Dictionary] = []
var _hall_level := -1


func _init(p_player: BalancePlayer) -> void:
	super(p_player)
	_spec = p_player.profile["research"]


func think() -> void:
	var hall := village.town_hall()
	if hall == null:
		return
	if hall.level != _hall_level:
		if _hall_level >= 0:
			p.decide("research", "the town hall is at level %d: picking again" % hall.level)
			pick = ""
		_hall_level = hall.level
	_upgrade_hall(hall)
	var r := village.research
	if not r.enabled() or r.current != "" or not hall.working():
		return
	var can := candidates()
	if pick != "" and not can.has(pick):
		pick = ""  # (locked meanwhile by an exclusive choice: pick again)
	if pick == "":
		if can.is_empty():
			return
		pick = can[randi() % can.size()]
		picks.append({"t": snappedf(game.clock, 0.1), "wave": _wave(), "id": pick, "from": can})
		p.decide("research", "picked %s (%s) out of %s" % [pick, Config.cost_text(_cost_of(pick)), ", ".join(can)])
	var cost := _cost_of(pick)
	var gold := int(cost.get("gold", 0))
	var need := float(gold) + float(_spec.get("reserve", 0.0)) + float(_params["gold_reserve"]) + float(p.military.reserved_gold())
	if _gold() < need:
		p.save_gold = maxi(p.save_gold, gold + int(_spec.get("reserve", 0.0)))  # (unit upgrades wait for it)
		return
	if village.economy.amount("food") < float(cost.get("food", 0)) + float(_params["min_food"]):
		return
	if _materials() < float(cost.get("materials", 0)):
		_claim({"materials": cost["materials"]})
		return
	if _cmd("research", {"id": pick})["ok"]:
		started.append({"t": snappedf(game.clock, 0.1), "wave": _wave(), "id": pick, "gold": gold, "cost": cost})
		p.decide("research", "researching %s for %s" % [pick, Config.cost_text(cost)])
		pick = ""  # (the dice again once it is done: research is one at a time)


## Advancements it could start now but for the gold: offered here, not taken,
## not locked out, every condition met.
func candidates() -> Array[String]:
	var r := village.research
	var out: Array[String] = []
	for id in r.offered():
		if r.has(id) or r.locked.has(id) or id == r.current:
			continue
		if r.conditions(id).all(func(c: Array) -> bool: return c[1]):
			out.append(id)
	return out


func _cost_of(id: String) -> Dictionary:
	return Config.ADVANCEMENTS[id]["cost"]


## The town hall up to the policy's level for this wave, once the economy is
## steady (BalanceMarket.steady).
func _upgrade_hall(hall: TownHall) -> void:
	if hall.upgrading or not hall.can_upgrade() or hall.level >= _scheduled(_spec["hall_levels"], 1):
		return
	if not p.market.steady() or not _site_room():
		return
	var cost: Dictionary = hall.upgrade_cost()
	if not _can_afford(cost):
		_claim(cost)  # (the military waits: the hall is the way to the tiers)
		return
	if _cmd("upgrade_tower", {"building": hall.nid})["ok"]:
		p.decide("research", "upgrading the town hall to level %d (the economy is steady)" % (hall.level + 1))
