class_name Treasure
extends MapObject
## A treasure (docs/world-design.md §9.2): looted by the hero in Explore mode,
## first come first served, once no camp guards it. The reward is paid when
## the looter gets home; a looter downed on the way drops it (a "sack"
## treasure appears where he fell, anyone can pick it up).

var looted := false
## The hero looting it right now (so two don't pick the same one).
var claimed_by: Node = null


func art() -> String:
	if data.get("sack", false):
		return "sack"
	return data["art"] + ("_looted" if looted else "")


func display_name() -> String:
	if data.get("sack", false):
		return "Dropped loot"
	return Config.TREASURES[data["treasure"]]["name"]


func loot_time() -> float:
	if data.get("sack", false):
		return 1.5
	return float(Config.TREASURES[data["treasure"]]["loot_time"])


func reward() -> Dictionary:
	return data.get("reward", {})


## The camp guarding it, while it isn't cleared (else null).
func guard() -> MonsterCamp:
	var g := int(data.get("guard", -1))
	if g < 0:
		return null
	var camp := game.world.map_object(g) as MonsterCamp
	return camp if camp and not camp.cleared else null


## Can the hero go for it now?
func lootable() -> bool:
	return not looted and guard() == null and (claimed_by == null or not is_instance_valid(claimed_by))


func found_message(_v: Village) -> String:
	if looted:
		return ""
	if guard() != null:
		return "Found %s, guarded by a monster camp. Clear the camp first (tap it: Attack with the hero)." % _a_name()
	return "Found %s. The hero loots it in Explore mode." % _a_name()


func _a_name() -> String:
	return "some dropped loot" if data.get("sack", false) else with_article(display_name().to_lower())


## "a buried chest", "an old ...", but "overgrown ruins", "dragon bones" (plurals).
static func with_article(name: String) -> String:
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
				parts.append("units healed")
			"relic":
				var key: String = r[k]
				if not v.relics.has(key):
					v.relics.append(key)
				var spec: Dictionary = Config.RELICS[key]
				v.events.important("Found the %s: %s!" % [spec["name"], spec["desc"]])
				parts.append(spec["name"])
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
	return ", ".join(parts)


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if looted:
		lines.append("Looted.")
	else:
		lines.append("Treasure: %s." % ("something valuable" if reward().is_empty() else "worth looting"))
		if guard() != null:
			lines.append("Guarded by a monster camp nearby.")
		else:
			lines.append("The hero loots it in Explore mode (%.0f s)." % loot_time())
	return d


func net_state() -> Array:
	return [looted]


func apply_net_state(s: Array) -> void:
	if s.size() > 0 and bool(s[0]) != looted:
		looted = bool(s[0])
		refresh()
