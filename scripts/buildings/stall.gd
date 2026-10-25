class_name Stall
extends Farm
## The merchant's trade stall (2x2; docs/scenarios-design.md §7.4), only in the
## campaign's scenarios. Its level is its stage (Config.STALL_LEVELS: peddler,
## stall, guild market). While the merchant tends it, its stock of goods
## (`stored`, as a farm's food) refills, and gold buys lots of building
## material or food from it (`buy`, the "trade" command). It is a Farm to the
## rats: they go for it and eat its goods, and nothing refills meanwhile.

## Lots sold so far.
var sold := 0
var _site_spr: Sprite2D


func _build_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	add_child(sprite)
	_site_spr = Art.sprite("site")
	_site_spr.show_behind_parent = true
	_site_spr.scale *= 1.4
	add_child(_site_spr)


func refresh() -> void:
	Art.apply(sprite, "stall" if level < 3 else "stall_3")
	sprite.visible = complete
	_site_spr.visible = not complete
	var c := Color.WHITE if (is_open() or not complete) else Color(0.75, 0.75, 0.75)
	if tearing_down:
		c.a = 0.6
	sprite.modulate = c
	queue_redraw()


func spec_level() -> Dictionary:
	return Config.STALL_LEVELS[clampi(level, 1, Config.STALL_LEVELS.size()) - 1]


func display_name() -> String:
	return str(spec_level()["name"])


func max_level() -> int:
	return Config.STALL_LEVELS.size()


func capacity() -> float:
	return float(spec_level()["stock"])


## Open for trade: finished, standing, and the merchant is there.
func is_open() -> bool:
	return working() and worker != null and worker.has_method("tending") and worker.tending()


## Grows nothing: no food for the village (Population.food_per_second).
func rate() -> float:
	return 0.0


func _process(delta: float) -> void:
	if game.is_client:
		return
	var before := stored
	if is_open() and not has_rats():
		stored = minf(stored + float(spec_level()["refill"]) / 60.0 * delta, capacity())
	since_gain = 0.0 if stored > before else since_gain + delta
	var dimmed := sprite.modulate.r < 0.9
	if complete and dimmed == is_open():
		refresh()  # (the merchant came or went)


## Why a lot of `good` can't be bought now, or "".
func buy_error(good: String) -> String:
	var lots: Dictionary = spec_level()["lots"]
	if not lots.has(good):
		return "The merchant doesn't sell that"
	if not is_open():
		return "The merchant isn't at his stall" if working() else "The stall is closed"
	var lot: Dictionary = lots[good]
	if stored < float(lot["amount"]):
		return "Sold out: wait for new goods"
	if not village.economy.can_afford({"gold": lot["gold"]}):
		return "Not enough gold"
	return ""


## Buys one lot of `good`: gold for the goods. Returns the amount bought (0: none).
func buy(good: String) -> int:
	if buy_error(good) != "":
		return 0
	var lot: Dictionary = spec_level()["lots"][good]
	var amount := int(lot["amount"])
	village.economy.spend({"gold": lot["gold"]}, "trade")
	village.economy.add(good, amount, "trade")
	stored -= amount
	sold += 1
	game.stats.count(village, "trade")
	village.events.debug("buy %d %s at %s for %d gold" % [amount, good, label(), int(lot["gold"])])
	Sfx.play("coin")
	return amount



func _work_info(d: Dictionary) -> void:
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	lines.append("Goods: %d / %d" % [int(stored), int(capacity())])
	if has_rats():
		lines.append("%d rat%s eating the goods!" % [rats.size(), "" if rats.size() == 1 else "s"])
	if worker == null:
		lines.append("Nobody tends it: no merchant.")
	elif not is_open():
		lines.append("%s is away: no trade until he's back." % worker.label().capitalize())
	else:
		lines.append("%s is at his stall." % worker.label().capitalize())
	var lots: Dictionary = spec_level()["lots"]
	for good: String in lots:
		var lot: Dictionary = lots[good]
		var err := buy_error(good)
		actions.append({
			"label": "Buy %s  (%s)" % [Config.cost_icons({good: lot["amount"]}), Config.cost_icons({"gold": lot["gold"]})],
			"disabled": err != "",
			"action": func() -> void: game.command("trade", {"building": nid, "good": good}),
		})


func _draw() -> void:
	_draw_bars()


func _bar_y() -> float:
	return -96.0
