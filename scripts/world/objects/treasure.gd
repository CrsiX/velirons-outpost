class_name Treasure
extends MapObject
## A treasure (docs/world-design.md §9.2): looted by the hero in Explore mode,
## first come first served, once no camp guards it. The reward is paid when
## the looter gets home; a looter downed on the way drops it (a "sack"
## treasure appears where she fell, anyone can pick it up).

var looted := false
## The hero looting it right now (so two don't pick the same one).
var claimed_by: Node = null
## Can't be looted yet (a scenario opens it: the drowned abbey's crypt).
var sealed := false
## A seal enemies can break (scenario 9: the Legion at the crypt): its HP and
## its max (0: no such seal); a bar shows it while it holds.
var seal_hp := 0.0
var seal_max := 0.0
## Why it can't be looted now although open ("": it can): the drowned
## abbey's leviathan coiled round the island.
var blocked := ""


func art() -> String:
	if data.get("sack", false):
		if reward().has("salvage"):
			return "salvage"
		return "relic_sword" if reward().has("item") else "sack"
	return data["art"] + ("_looted" if looted else "")


func display_name() -> String:
	if data.get("sack", false):
		if reward().has("salvage"):
			return "Salvage"
		if reward().has("item"):
			return Treasure.item_name(str(reward()["item"]))
		if reward().has("equipment"):
			return "Dropped item"
		if reward().has("relic"):
			return "Dropped relic"
		return "Dropped loot"
	return Config.TREASURES[data["treasure"]]["name"]


func loot_time() -> float:
	if data.get("sack", false):
		return 1.5
	return float(Config.TREASURES[data["treasure"]]["loot_time"])


func reward() -> Dictionary:
	return data.get("reward", {})


## Where there are no items (Game.items_enabled), a treasure holding one pays
## gold instead (ITEM_SOURCES "treasure_gold"); a relic this game can't use (a
## co-op one alone) is another one (Relics.usable).
func setup_object(p_game: Game, p_index: int, p_data: Dictionary) -> void:
	if p_data.get("reward", {}).has("equipment") and not p_game.items_enabled() and not p_game.is_client:
		p_data["reward"] = {"gold": int(Config.ITEM_SOURCES["treasure_gold"])}
	if p_data.get("reward", {}).has("relic") and not p_game.is_client:
		p_data["reward"]["relic"] = Relics.usable(p_game, str(p_data["reward"]["relic"]), p_index)
	super.setup_object(p_game, p_index, p_data)


## The camp guarding it, while it isn't cleared (else null).
func guard() -> MonsterCamp:
	var g := int(data.get("guard", -1))
	if g < 0:
		return null
	var camp := game.world.map_object(g) as MonsterCamp
	return camp if camp and not camp.cleared else null


## What it is if it is no treasure but a place to see (the throne hall), or "".
func landmark() -> String:
	return "" if data.get("sack", false) else str(Config.TREASURES[data["treasure"]].get("landmark", ""))


## Can the hero go for it now?
func lootable() -> bool:
	return not looted and not sealed and blocked == "" and landmark() == "" and guard() == null and (claimed_by == null or not is_instance_valid(claimed_by))


func found_message(_v: Village) -> String:
	if looted:
		return ""
	if landmark() != "":
		return "Found the %s." % display_name().to_lower()
	if guard() != null:
		return "Found %s, guarded by a %s. Clear the camp first (tap it: Attack with the hero)." % [_a_name(), guard().display_name().to_lower()]
	if sealed:
		return "Found %s. It is sealed for now." % _a_name()
	return "Found %s. The hero loots it in Explore mode." % _a_name()


func _a_name() -> String:
	if reward().has("salvage"):
		return "salvage from a trade caravan"
	if data.get("sack", false) and reward().has("equipment"):
		return "a dropped item"
	if data.get("sack", false) and reward().has("relic"):
		return "a dropped relic"
	return "some dropped loot" if data.get("sack", false) else with_article(display_name().to_lower())


## "a buried chest", "an old ...", but "overgrown ruins", "dragon bones" (plurals).
static func with_article(name: String) -> String:
	for id: String in Config.ITEMS:
		if Config.campaign_item(id) and str(Config.ITEMS[id]["name"]) == name:
			return "the " + name  # (one of a kind: the First King's Hand)
	if name.ends_with("s"):
		return name
	return ("an " if name.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a ") + name


func mark_looted() -> void:
	looted = true
	claimed_by = null
	if data.get("sack", false):
		visible = false
		game.world.remove_map_object(self)
		return
	refresh()


## Pays `r` to village `v` (gold, food, material; hero XP to its hero;
## healing its units; a relic). Returns what it was, for a floating text
## (with icon tokens, see World.float_text).
static func pay(v: Village, r: Dictionary) -> String:
	var parts: Array[String] = []
	for k in r:
		match k:
			"gold", "food", "materials":
				v.economy.add(k, int(r[k]), "treasure")
				parts.append("+%d {%s}" % [int(r[k]), k])
			"hero_xp":
				if v.hero:
					v.hero.xp += int(r[k])
					v.hero.changed.emit()
				parts.append("+%d {xp}" % int(r[k]))
			"heal_units":
				for u in v.army.units:
					u.heal(u.max_hp())
				if v.hero and not v.hero.dead:
					v.hero.hp = v.hero.max_hp
					v.hero.changed.emit()
				parts.append("units healed")
			"item":  # (a campaign item: the First King's Hand)
				if not v.items.has(str(r[k])):
					v.items.append(str(r[k]))
				v.events.important("%s is home with the %s." % [v.hero.label() if v.hero else "The hero", Treasure.item_name(str(r[k]))])
				parts.append(Treasure.item_name(str(r[k])))
			"equipment":
				var got := ItemDrops.bring_home(v, str(r[k]))
				if got != "":
					parts.append(got)
			"relic":
				var got_relic := Relics.bring_home(v, str(r[k]))
				if got_relic != "":
					parts.append(got_relic)
	return ", ".join(parts)


## What the reward is, for the panel.
static func reward_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	for k in r:
		match k:
			"gold", "food", "materials":
				parts.append("%d %s" % [int(r[k]), k])
			"hero_xp":
				parts.append("%d hero XP" % int(r[k]))
			"heal_units":
				parts.append("every unit healed")
			"relic":
				parts.append("a relic")
			"equipment":
				parts.append("an item")
			"item":
				parts.append(Treasure.item_name(str(r[k])))
	return ", ".join(parts)


## A campaign item's name (a treasure's "item", a Config.ITEMS key).
static func item_name(id: String) -> String:
	return str(Config.ITEMS.get(id, {}).get("name", id))


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if landmark() != "":
		lines.append(landmark())
	elif looted:
		lines.append("Looted.")
	elif reward().has("salvage"):
		var sv: Dictionary = reward()["salvage"]
		lines.append("The cargo of a lost trade caravan: %s." % TradeCaravan.salvage_text(sv))
		lines.append("A gatherer (or the hero gathering) carries it back to its marketplace. It lies here until the next wave is over.")
	elif data.get("sack", false) and reward().has("relic"):
		lines.append("Something that glints: a relic.")
		lines.append("A gatherer (or the hero gathering or exploring) brings it to the armoury once it has room. It lies here until then.")
	elif data.get("sack", false) and reward().has("equipment"):
		lines.append("Something that glints: an item.")
		lines.append("A gatherer (or the hero gathering or exploring) brings it to the armoury once it has room. It lies here until then.")
	else:
		lines.append("Treasure: %s." % ("something valuable" if reward().is_empty() else "worth looting"))
		if guard() != null:
			lines.append("Guarded by a %s nearby." % guard().display_name().to_lower())
		elif sealed:
			lines.append("Sealed: it can't be looted yet.")
			if seal_max > 0.0:
				lines.append("The seal: %d / %d HP." % [ceili(seal_hp), int(seal_max)])
		elif blocked != "":
			lines.append(blocked)
		else:
			lines.append("The hero loots it in Explore mode (%.0f s)." % loot_time())
	return d


func net_state() -> Array:
	return [looted]


func apply_net_state(s: Array) -> void:
	if s.size() > 0 and bool(s[0]) != looted:
		looted = bool(s[0])
		refresh()


## A dropped item's or relic's sack glints (ItemDrops.draw_glint), redrawn every frame.
func _process(_delta: float) -> void:
	if data.get("sack", false) and (reward().has("equipment") or reward().has("relic")) and visible:
		queue_redraw()


func _draw() -> void:
	if data.get("sack", false) and (reward().has("equipment") or reward().has("relic")) and not looted:
		ItemDrops.draw_glint(self, Vector2(7.0, -24.0))
	if not sealed or seal_max <= 0.0 or looted:
		return
	var w := 70.0
	var r := Rect2(-w / 2.0, -96.0, w, 6.0)
	draw_rect(r.grow(2.0), Color("15110d"))
	draw_rect(r, Color("3a2e22"))
	draw_rect(Rect2(r.position, Vector2(w * clampf(seal_hp / seal_max, 0.0, 1.0), r.size.y)), Color("c9a24a"))
