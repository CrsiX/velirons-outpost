class_name Research
extends Node
## One village's advancements (docs/advancements-design.md): researched at its
## town hall, one at a time, for gold and research time (Config.ADVANCEMENTS),
## lasting for this game only. Tier 1 opens with the hall at level
## ADVANCEMENT_TIERS[1], tier 2 at [2]; a devastated hall pauses the research.
## Researching one half of an exclusive pair locks the other for good. The
## effects are read where they apply (Village.adv_bonus and its helpers); the
## few that change something already in play are applied here (`_apply`).

signal changed

var village: Village
var game: Game
## Researched, in order.
var done: Array[String] = []
## Under research ("": nothing), its seconds of research so far and the gold paid.
var current := ""
var progress := 0.0
var paid := 0
## Exclusive halves locked for good by the choice of the other half.
var locked: Array[String] = []


func setup(p_village: Village) -> void:
	village = p_village
	game = village.game


## Are advancements in this game at all? Not in the title backdrop, and in
## the campaign only where the scenario switches them on.
func enabled() -> bool:
	return game.backdrop == null and (game.scenario == null or game.scenario.spec.advancements)


func has(id: String) -> bool:
	return done.has(id)


## The sum of effect `key` over what was researched (a number per advancement).
func bonus(key: String) -> float:
	var sum := 0.0
	for id in done:
		var v = Config.ADVANCEMENTS[id].get(key)
		if v is float or v is int:
			sum += float(v)
	return sum


## The value of effect `key` of the researched advancement that has it, or `fallback`.
func effect(key: String, fallback: Variant = null) -> Variant:
	for id in done:
		if Config.ADVANCEMENTS[id].has(key):
			return Config.ADVANCEMENTS[id][key]
	return fallback


## Effects that make an advancement the marketplace's (docs/advancements-design.md).
const MARKET_EFFECTS: Array[String] = ["caravans", "tax"]


## Every advancement this game offers (the co-op ones only with several
## villages, the market's only where a marketplace can be built), tier by tier.
func offered() -> Array[String]:
	var out: Array[String] = []
	for tier in [1, 2]:
		for id: String in Config.ADVANCEMENTS:
			if int(Config.ADVANCEMENTS[id]["tier"]) == tier and _available(id):
				out.append(id)
	return out


## Does this game have advancement `id` at all?
func _available(id: String) -> bool:
	var a: Dictionary = Config.ADVANCEMENTS[id]
	if a.get("coop", false) and game.villages.size() < 2:
		return false
	return not is_market(id) or game.allows_building("market")


## Is `id` one of the marketplace's advancements (a MARKET_EFFECTS key)?
static func is_market(id: String) -> bool:
	for k in MARKET_EFFECTS:
		if (Config.ADVANCEMENTS[id] as Dictionary).has(k):
			return true
	return false


## Its unlock conditions: [[text, met]], in the panel's order.
func conditions(id: String) -> Array[Array]:
	var a: Dictionary = Config.ADVANCEMENTS[id]
	var out: Array[Array] = []
	var hall := village.town_hall()
	var need_level := int(Config.ADVANCEMENT_TIERS[int(a["tier"])])
	out.append(["Town hall level %d" % need_level, hall != null and hall.level >= need_level])
	if a.has("wave"):
		out.append(["Wave %d" % int(a["wave"]), game.waves.wave >= int(a["wave"])])
	for n: String in a.get("needs", []):
		out.append([str(Config.ADVANCEMENTS[n]["name"]), has(n)])
	if a.has("earned_gold"):
		var earned := game.stats.value(village.id, "earn.gold")
		out.append(["%d gold earned (%d so far)" % [int(a["earned_gold"]), int(earned)], earned >= float(a["earned_gold"])])
	if a.has("deed"):
		var deed: Dictionary = a["deed"]
		var n := game.stats.value(village.id, str(deed["stat"]))
		out.append(["%d %s (%d so far)" % [int(deed["count"]), str(deed["text"]), int(n)], n >= float(deed["count"])])
	return out


## Why `id` can't be started now ("" when it can).
func error(id: String) -> String:
	if not Config.ADVANCEMENTS.has(id):
		return "No such advancement"
	if not enabled():
		return "There are no advancements here"
	var a: Dictionary = Config.ADVANCEMENTS[id]
	if has(id):
		return "Already researched"
	if locked.has(id):
		return "Locked for good: you chose %s" % Config.ADVANCEMENTS[str(a["excludes"])]["name"]
	if a.get("coop", false) and game.villages.size() < 2:
		return "Only with other villages"
	if not _available(id):
		return "There is no marketplace here"
	if current != "":
		return "Already researching %s" % Config.ADVANCEMENTS[current]["name"]
	var hall := village.town_hall()
	if hall == null or not hall.working():
		return "The town hall is devastated" if hall != null else "No town hall"
	for c in conditions(id):
		if not c[1]:
			return "Needs: %s" % c[0]
	if not village.economy.can_afford({"gold": int(a["gold"])}):
		return "Not enough gold"
	return ""


## Starts researching `id`: its gold is paid now.
func start(id: String) -> bool:
	if error(id) != "":
		return false
	paid = int(Config.ADVANCEMENTS[id]["gold"])
	village.economy.spend({"gold": paid}, "research")
	current = id
	progress = 0.0
	village.events.info("Research of %s begins (%d gold, %d s)" % [Config.ADVANCEMENTS[id]["name"], paid, int(Config.ADVANCEMENTS[id]["time"])])
	village.sound("place")
	changed.emit()
	return true


## Gold that cancelling now gives back: all of it before any research, then
## less as the research goes on (as for a construction site).
func cancel_refund() -> int:
	if current == "":
		return 0
	return floori(paid * (1.0 - clampf(progress / float(Config.ADVANCEMENTS[current]["time"]), 0.0, 1.0)))


func cancel() -> void:
	if current == "":
		return
	var back := cancel_refund()
	if back > 0:
		village.economy.refund({"gold": back}, "research")
	village.events.info("Research of %s called off: %d gold back" % [Config.ADVANCEMENTS[current]["name"], back])
	current = ""
	progress = 0.0
	paid = 0
	changed.emit()


## Seconds of research left on the current one.
func time_left() -> float:
	return maxf(float(Config.ADVANCEMENTS[current]["time"]) - progress, 0.0) if current != "" else 0.0


## The research runs while the town hall works (a devastated one pauses it); host only.
func _process(delta: float) -> void:
	if game == null or game.is_client or current == "" or game.game_over:
		return
	var hall := village.town_hall()
	if hall == null or not hall.working():
		return
	progress += delta
	if progress >= float(Config.ADVANCEMENTS[current]["time"]):
		_finish()


func _finish() -> void:
	var id := current
	var a: Dictionary = Config.ADVANCEMENTS[id]
	done.append(id)
	current = ""
	progress = 0.0
	paid = 0
	if a.has("excludes") and not locked.has(str(a["excludes"])):
		locked.append(str(a["excludes"]))
	game.stats.count(village, "advancements")
	village.events.important("Research done: %s" % a["name"])
	village.toast("Researched: %s" % a["name"], UiTheme.GOLD)
	village.sound("build")
	_apply(id)
	changed.emit()


## What researching `id` changes in what is already in play (the rest is read
## where it applies).
func _apply(id: String) -> void:
	var a: Dictionary = Config.ADVANCEMENTS[id]
	if a.has("walk"):
		for c in village.population.civilians:
			c.speed = c.walk_speed()
	if a.get("shared_vision", false):
		game.fog.shared_vision[village.id] = true


## After a load: what _apply does, for everything researched.
func reapply() -> void:
	for id in done:
		_apply(id)
