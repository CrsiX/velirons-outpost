class_name BalanceHero
extends BalancePart
## The hero part of the balancing bot's player: the same for every policy
## (Config.BALANCE_HERO). She spends her XP on levels, explores in the first
## waves (between them, and during them while no enemy is near the walls),
## then trains the unit at the grounds, defends during waves, rests when she
## is nearly downed (she would lose all her XP) and may be sent against known
## monster camps. What she does is recorded by the ledger (BalanceLedger:
## seconds per mode, XP by source, kills, how often she fell).

var _plan: Dictionary = Config.BALANCE_HERO
## The hero was sent to rest at low HP and stays there until healed
## ("rest_below" / "rest_until").
var _resting := false
## The level the unit at the grounds is trained up to in this run (-1: she is
## not in a training run).
var _train_to := -1
## The unit whose run is over: she doesn't train it again while it is there.
var finished_unit := -1


## She is passing her XP on to the unit at the grounds right now.
func in_training_run() -> bool:
	return _train_to >= 0


func think() -> void:
	var h := village.hero
	if not is_instance_valid(h):
		return
	for i in 3:
		if not h.can_level_up() or _banking(h):
			break
		_cmd("hero_level_up")
	var want := Hero.Mode.DEFEND
	var explore_waves := int(_plan["explore_waves"])
	if _low(h):
		_train_to = -1
		want = Hero.Mode.REST  # (downed, she would lose all her XP)
	elif _training(h):
		want = Hero.Mode.TRAIN
	elif _in_wave():
		# Early waves are small: she goes on exploring (XP) unless the
		# village needs her.
		want = Hero.Mode.EXPLORE if _wave() < explore_waves and not _threat() else Hero.Mode.DEFEND
	elif _wave() < explore_waves or _unlock_wanted(h):
		want = Hero.Mode.EXPLORE  # (Explore goes for an awake unlock site first)
	elif _wave() < explore_waves + 4 and _unexplored_share() > 0.5:
		want = Hero.Mode.EXPLORE
	if int(_plan["attack_camps"]) > 0 and not _resting and h.level + 1 >= int(_plan["attack_camps"]) and not _in_wave() and not h.dead:
		var camp := _camp_to_attack()
		if camp != null and h.camp_target == null:
			_cmd("attack_camp", {"camp": camp.nid})
	if h.mode != want:
		_cmd("hero_mode", {"mode": want})


## An awake unlock site gives a unit the profile uses and nobody has
## unlocked yet (the hero may be on her way there already).
func _unlock_wanted(h: Hero) -> bool:
	var uses: Array = p.profile["tower_units"] + p.profile["wall_units"] + p.profile["barracks_units"]
	for o in game.world.map_objects:
		if o is UnlockSite and o.awake and not o.used and not game.is_unlocked(o.unlocks()) and uses.has(o.unlocks()) \
				and (o.claimed_by == null or not is_instance_valid(o.claimed_by) or o.claimed_by == h):
			return true
	return false


## From "bank_xp_from_level" on her XP is kept for training units as long as
## there are training grounds and a unit that can still level up.
func _banking(h: Hero) -> bool:
	var from := int(_plan["bank_xp_from_level"])
	if from <= 0 or h.level + 1 < from or _grounds() == null:
		return false
	for u in village.army.units:
		if u.can_train() and not u.bound:
			return true
	return false


func _grounds() -> TrainingGrounds:
	for b in _buildings_of("training"):
		if b.working():
			return b as TrainingGrounds
	return null


## Whether she trains now. Only between waves, and only with a unit at the
## grounds that her XP can level up completely: a run starts when she has
## the XP for its next level, and goes on until the unit has gained
## "train_levels" levels or her XP no longer covers the next one; then she is
## back to what she did before (the choice below this one). The military
## sends only a unit her XP can take through all "train_levels" there.
func _training(h: Hero) -> bool:
	var g := _grounds()
	var u: MilitaryUnit = null if g == null else g.trainable_unit()
	if u == null or h.dead or _in_wave():
		_train_to = -1
		if u == null:
			finished_unit = -1
		return false
	if u.nid == finished_unit:
		return false
	if _train_to < 0:
		if _train_levels(u) < 1 or h.xp < _train_need(u, 1):
			return false
		_train_to = u.level + _train_levels(u)
	if u.level >= _train_to or h.xp < _train_need(u, 1):
		_train_to = -1
		finished_unit = u.nid
		return false
	return true


## Below "rest_below" of her HP (with "careful_xp" XP: "careful_rest_below")
## she rests until "rest_until": downed, she would lose all her XP.
func _low(h: Hero) -> bool:
	if h.dead:
		_resting = false
		return false
	var share := h.hp / maxf(h.max_hp, 1.0)
	var below := float(_plan["rest_below"])
	if h.xp >= int(_plan["careful_xp"]):
		below = maxf(below, float(_plan["careful_rest_below"]))
	if share < below:
		_resting = true
	elif share >= float(_plan["rest_until"]):
		_resting = false
	return _resting


## An enemy of the wave inside the walls or near them (what draws the hero
## out in Defend).
func _threat() -> bool:
	var rect := village.rect
	for node in p.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.wild():
			continue
		if rect.has_point(e.current_tile()) or Hero.rect_distance(rect, e.grid_pos) <= Config.HERO["alert_radius"]:
			return true
	return false


func _unexplored_share() -> float:
	var explored: PackedByteArray = game.fog.explored_of[village.id]
	return 1.0 - float(explored.count(1)) / float(maxi(explored.size(), 1))


func _camp_to_attack() -> MonsterCamp:
	var best: MonsterCamp = null
	for o in game.world.map_objects:
		if o is MonsterCamp and o.attackable() and o.is_found_by(village):
			if best == null or Vector2(o.tile).distance_to(Vector2(village.center)) < Vector2(best.tile).distance_to(Vector2(village.center)):
				best = o
	return best
