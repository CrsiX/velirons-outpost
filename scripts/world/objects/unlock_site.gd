class_name UnlockSite
extends MapObject
## A unit-unlock site (docs/world-design.md §9.4): a stone circle
## (summoner) or a mage's tower (apprentice). Dormant scenery until its wave;
## then every copy awakens and the first hero to spend `visit_time` there
## (Explore mode goes for it first) unlocks the unit for every player. The
## other copies stay as scenery.

var awake := false
## Someone unlocked the unit (here or at another copy): nothing more to get.
var used := false
## The hero on his way to / at it right now.
var claimed_by: Node = null


func spec() -> Dictionary:
	return Config.UNLOCK_SITES[data["site"]]


func art() -> String:
	if data["site"] == "mage_tower":
		return "mage_tower_awake" if awake and not used else "mage_tower_ruin"
	return "stone_circle_awake" if awake and not used else "stone_circle"


func display_name() -> String:
	return spec()["name"]


func unlocks() -> String:
	return data["unlocks"]


## Can a hero unlock it now?
func claimable() -> bool:
	return awake and not used and not game.is_unlocked(unlocks()) and (claimed_by == null or not is_instance_valid(claimed_by))


func awaken() -> void:
	if awake:
		return
	awake = true
	refresh()


func mark_used() -> void:
	used = true
	claimed_by = null
	refresh()


func found_message(_v: Village) -> String:
	if used or game.is_unlocked(unlocks()):
		return ""
	if awake:
		return "Found the awakened %s. The hero can unlock the %s there (Explore mode)." % [display_name().to_lower(), Config.MILITARY[unlocks()]["name"].to_lower()]
	return "Found an old %s. Nothing stirs here yet." % display_name().to_lower()


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	var unit: String = Config.MILITARY[unlocks()]["name"].to_lower()
	if game.is_unlocked(unlocks()):
		lines.append("The %s is unlocked for every village." % unit)
	elif awake:
		lines.append("It has awakened: the hero can unlock the %s here (Explore mode)." % unit)
	else:
		lines.append("Old and silent. Nothing stirs here yet.")
	return d


func net_state() -> Array:
	return [awake, used]


func apply_net_state(s: Array) -> void:
	if s.size() >= 2 and (bool(s[0]) != awake or bool(s[1]) != used):
		awake = bool(s[0])
		used = bool(s[1])
		refresh()
