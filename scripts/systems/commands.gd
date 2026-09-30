class_name Commands
extends Node
## Every player action goes through here as a command: a type plus plain
## arguments (numbers, strings, Vector2i; buildings and military units by
## their id, see Game.register). A command is checked first (does the village
## own what it names? is the action allowed right now?) and then applied
## through that village's systems. The result says whether it worked:
## {"ok": true, ...} or {"ok": false, "error": "why"}.
##
## Single player applies commands at once. In co-op a client sends the
## same dictionaries to the host, which applies them for the client's village
## (docs/multiplayer-design.md §8.3), so nothing in `args` may be an object.

## Emitted after every command, applied or refused.
signal applied(village: Village, type: String, args: Dictionary, result: Dictionary)

const HANDLERS := {
	"place_building": "_place_building",
	"cancel_site": "_cancel_site",
	"tear_down": "_tear_down",
	"stop_tear_down": "_stop_tear_down",
	"rebuild_hut": "_rebuild_hut",
	"rebuild_all_huts": "_rebuild_all_huts",
	"upgrade_tower": "_upgrade_tower",
	"recruit_villager": "_recruit_villager",
	"assign_worker": "_assign_worker",
	"unassign_worker": "_unassign_worker",
	"recruit_unit": "_recruit_unit",
	"upgrade_unit": "_upgrade_unit",
	"station_unit": "_station_unit",
	"withdraw_unit": "_withdraw_unit",
	"move_unit": "_move_unit",
	"buy_materials": "_buy_materials",
	"hero_mode": "_hero_mode",
	"hero_level_up": "_hero_level_up",
	"call_wave": "_call_wave",
	"set_speed": "_set_speed",
	"send_caravan": "_send_caravan",
	"send_unit": "_send_unit",
	"hero_support": "_hero_support",
	"promote_archmage": "_promote_archmage",
	"attack_camp": "_attack_camp",
	"restore_ruin": "_restore_ruin",
	"assign_miner": "_assign_miner",
	"unassign_miner": "_unassign_miner",
}

const CARAVAN_SCRIPT := preload("res://scripts/units/caravan.gd")

var game: Game


func setup(p_game: Game) -> void:
	game = p_game


## Checks and applies one command for `village`.
func submit(village: Village, type: String, args: Dictionary = {}) -> Dictionary:
	var result: Dictionary
	if not HANDLERS.has(type):
		result = fail("Unknown command '%s'" % type)
	elif game.game_over and type != "set_speed":
		result = fail("The game is over")
	else:
		result = call(HANDLERS[type], village, args)
	applied.emit(village, type, args, result)
	return result


static func ok(extra: Dictionary = {}) -> Dictionary:
	var r := {"ok": true}
	r.merge(extra)
	return r


static func fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}


# --- argument lookup: entities by id, and they must belong to the village ---------

func _building(village: Village, args: Dictionary, key: String = "building") -> Building:
	var b = game.entity(int(args.get(key, 0)))
	return b if b is Building and b.village == village else null


func _unit(village: Village, args: Dictionary, key: String = "unit") -> MilitaryUnit:
	var u = game.entity(int(args.get(key, 0)))
	return u if u is MilitaryUnit and u.village == village else null


# --- map objects (docs/world-design.md §9) ---------------------------------------------

func _attack_camp(v: Village, a: Dictionary) -> Dictionary:
	var camp = game.entity(int(a.get("camp", 0)))
	if not (camp is MonsterCamp) or camp.cleared:
		return fail("There's no camp to attack")
	if not camp.is_found_by(v):
		return fail("You haven't found that camp")
	if v.hero.dead:
		return fail("The hero is down")
	v.hero.attack_camp(camp)
	return ok()


func _restore_ruin(v: Village, a: Dictionary) -> Dictionary:
	var ruin = game.entity(int(a.get("ruin", 0)))
	if not (ruin is RuinedTower) or ruin.village != v:
		return fail("That isn't your ruin")
	var cost := RuinedTower.restore_cost()
	if not v.economy.can_afford(cost):
		return fail("Not enough building material")
	var site := v.construction.restore_ruin(ruin, cost)
	return ok({"site": site.nid}) if site else fail("Can't restore it now")


func _assign_miner(v: Village, a: Dictionary) -> Dictionary:
	var mine = game.entity(int(a.get("mine", 0)))
	if not (mine is Mine):
		return fail("That isn't a mine")
	if not game.is_unlocked("miner"):
		return fail("Nobody knows how to work a mine yet")
	if not mine.is_free():
		return fail("That mine is taken")
	var idle := v.population.free_workers("miner")
	if idle.is_empty():
		return fail("No idle miner")
	idle[0].assign(mine)
	return ok()


func _unassign_miner(v: Village, a: Dictionary) -> Dictionary:
	var mine = game.entity(int(a.get("mine", 0)))
	if not (mine is Mine) or mine.is_free() or mine.worker.village != v:
		return fail("None of your miners works there")
	mine.worker.unassign()
	return ok()


# --- buildings -----------------------------------------------------------------------

func _place_building(v: Village, a: Dictionary) -> Dictionary:
	var kind := str(a.get("kind", ""))
	if not Config.BUILDINGS.has(kind) or not Construction.KIND_SCRIPTS.has(kind):
		return fail("Can't build that")
	var tile: Vector2i = a.get("tile", Vector2i(-1, -1))
	var err := v.construction.placement_error(kind, tile)
	if err != "":
		return fail(err)
	var b := v.construction.place(kind, tile)
	return ok({"id": b.nid}) if b else fail("Can't build here")


func _cancel_site(v: Village, a: Dictionary) -> Dictionary:
	var b := _building(v, a)
	if b == null or not b.has_work():
		return fail("Nothing to cancel")
	v.construction.cancel(b)
	return ok()


func _tear_down(v: Village, a: Dictionary) -> Dictionary:
	var b := _building(v, a)
	if b == null or not b.can_tear_down():
		return fail("That can't be torn down")
	return ok() if v.construction.order_tear_down(b) else fail("Can't tear that down now")


func _stop_tear_down(v: Village, a: Dictionary) -> Dictionary:
	var b := _building(v, a)
	if b == null or not b.tearing_down:
		return fail("Nothing is being torn down there")
	v.construction.stop_tear_down(b)
	return ok()


func _rebuild_hut(v: Village, a: Dictionary) -> Dictionary:
	var h := _building(v, a) as Hut
	if h == null:
		return fail("That isn't your hut")
	return ok() if v.construction.order_rebuild(h) else fail("Can't rebuild that now")


func _rebuild_all_huts(v: Village, _a: Dictionary) -> Dictionary:
	if v.construction.ruined_huts().is_empty():
		return fail("No destroyed huts")
	var n := v.construction.rebuild_all_huts()
	if n == 0:
		return fail("Not enough building material")
	return ok({"queued": n, "left": v.construction.ruined_huts().size()})


func _upgrade_tower(v: Village, a: Dictionary) -> Dictionary:
	var t := _building(v, a)
	if not (t is Tower or t is Barracks):
		return fail("That isn't your tower")
	return ok() if v.construction.order_upgrade(t) else fail("Can't upgrade that now")


# --- villagers -------------------------------------------------------------------------

func _recruit_villager(v: Village, a: Dictionary) -> Dictionary:
	var role := str(a.get("role", ""))
	if not Config.CIVILIANS.has(role):
		return fail("Unknown villager")
	var err := v.population.recruit_error(role)
	if err != "":
		return fail(err)
	var civ := v.population.recruit(role)
	return ok({"uid": civ.uid}) if civ else fail("Can't recruit now")


func _assign_worker(v: Village, a: Dictionary) -> Dictionary:
	var w := _building(v, a) as Workplace
	if w == null:
		return fail("That isn't your workplace")
	return ok() if v.population.assign_worker(w) else fail("Nobody free to work there")


func _unassign_worker(v: Village, a: Dictionary) -> Dictionary:
	var w := _building(v, a) as Workplace
	if w == null or w.worker == null:
		return fail("Nobody works there")
	v.population.unassign_worker(w)
	return ok()


# --- army ----------------------------------------------------------------------------

func _recruit_unit(v: Village, a: Dictionary) -> Dictionary:
	var kind := str(a.get("kind", ""))
	if not Config.MILITARY.has(kind):
		return fail("Unknown unit")
	if not game.is_unlocked(kind):
		return fail("Not unlocked yet")
	var u := v.army.recruit(kind)
	return ok({"id": u.nid}) if u else fail("Not enough gold")


func _upgrade_unit(v: Village, a: Dictionary) -> Dictionary:
	var u := _unit(v, a)
	if u == null:
		return fail("That isn't your unit")
	if u.state == MilitaryUnit.State.TRAVELLING:
		return fail("It's on its way to another village")
	var to := str(a.get("to", ""))
	if to != "" and not Config.MILITARY.has(to):
		return fail("It can't become that")
	var err := v.army.upgrade_error(u, to)
	if err != "":
		return fail(err)
	v.army.upgrade(u, to)
	return ok()


## A spatial mage of ARCHMAGE_LEVEL leaves the army as the Spatial Archmage (a civilian).
func _promote_archmage(v: Village, a: Dictionary) -> Dictionary:
	var u := _unit(v, a)
	if u == null:
		return fail("That isn't your unit")
	var err := v.army.archmage_error(u)
	if err != "":
		return fail(err)
	var civ := v.army.promote_archmage(u)
	return ok({"uid": civ.uid}) if civ else fail("It didn't work")


func _station_unit(v: Village, a: Dictionary) -> Dictionary:
	var u := _unit(v, a)
	var p := game.entity(int(a.get("post", 0))) as MilitaryPost
	if u == null:
		return fail("That isn't your unit")
	var err := v.army.station_error(u, p)
	if err != "":
		return fail(err)
	v.army.station(u, p)
	return ok()


func _withdraw_unit(v: Village, a: Dictionary) -> Dictionary:
	var u := _unit(v, a)
	if u == null:
		return fail("That isn't your unit")
	if u.state != MilitaryUnit.State.STATIONED and u.state != MilitaryUnit.State.MARCHING:
		return fail("It isn't on duty")
	v.army.unstation(u)
	return ok()


func _move_unit(v: Village, a: Dictionary) -> Dictionary:
	var u := _unit(v, a)
	var p := game.entity(int(a.get("post", 0))) as MilitaryPost
	if u == null:
		return fail("That isn't your unit")
	var err := v.army.transfer_error(u, p)
	if err != "":
		return fail(err)
	v.army.transfer(u, p)
	return ok()


# --- other ---------------------------------------------------------------------------

func _buy_materials(v: Village, a: Dictionary) -> Dictionary:
	var n := int(a.get("bundles", 0))
	if n < 1 or n > 100:
		return fail("Pick how much to buy")
	if not v.economy.buy_materials(n):
		return fail("Not enough gold")
	v.events.debug("buy %d building material for %d gold" % [Config.MATERIALS_TRADE["materials"] * n, Config.MATERIALS_TRADE["gold"] * n])
	return ok()


func _hero_level_up(v: Village, _a: Dictionary) -> Dictionary:
	var h := v.hero
	if h.level >= Config.HERO_MAX_LEVEL - 1:
		return fail("The hero is at his highest level")
	if not h.can_level_up():
		return fail("Not enough XP (%d / %d)" % [h.xp, h.level_up_cost()])
	h.level_up()
	return ok({"level": h.level})


func _hero_mode(v: Village, a: Dictionary) -> Dictionary:
	var m := int(a.get("mode", -1))
	if m < 0 or m >= Hero.MODE_NAMES.size():
		return fail("Unknown hero mode")
	if m == Hero.Mode.SUPPORT:
		if game.villages.size() < 2:
			return fail("There's no other village to support")
		if v.hero.support_target == null or v.hero.support_target == v:
			v.hero.set_support_target(_nearest_other(v))
	v.hero.set_mode(m)
	return ok()


## Co-op: which village the hero supports (in Support mode).
func _hero_support(v: Village, a: Dictionary) -> Dictionary:
	var t := _other_village(v, a)
	if t == null:
		return fail("Pick another village")
	v.hero.set_support_target(t)
	return ok()


# --- co-op help ------------------------------------------------------------------------

func _other_village(v: Village, a: Dictionary, key: String = "target") -> Village:
	var id := int(a.get(key, -1))
	if id < 0 or id >= game.villages.size() or game.villages[id] == v:
		return null
	return game.villages[id]


func _nearest_other(v: Village) -> Village:
	var best: Village = null
	for o in game.villages:
		if o != v and (best == null or (best.fallen and not o.fallen) or (o.fallen == best.fallen and Vector2(o.center).distance_to(Vector2(v.center)) < Vector2(best.center).distance_to(Vector2(v.center)))):
			best = o
	return best


## Resources by caravan: paid now, delivered minus the help tax on arrival.
func _send_caravan(v: Village, a: Dictionary) -> Dictionary:
	var t := _other_village(v, a)
	if t == null:
		return fail("Pick another village")
	var cargo := {}
	for res in Economy.RESOURCES:
		var n := int(a.get(res, 0))
		if n < 0:
			return fail("Amounts can't be negative")
		if n > 0:
			cargo[res] = n
	if cargo.is_empty():
		return fail("Pick something to send")
	if not v.economy.can_afford(cargo):
		return fail("You don't have that much")
	if game.world.pathing.find_path(v.center, t.center).is_empty():
		return fail("No road to that village")
	v.economy.spend(cargo)
	var c: Caravan = CARAVAN_SCRIPT.new()
	c.setup(game, v, t, cargo, Config.help_tax(game.villages.size()))
	c.nid = game.register(c)
	game.world.objects.add_child(c)
	v.events.debug("send %s to %s: %s" % [c.label(), t.village_name, Config.cost_text(cargo)])
	return ok({"caravan": c.uid})


## A reserve unit walks to another village and joins it there.
func _send_unit(v: Village, a: Dictionary) -> Dictionary:
	var u := _unit(v, a)
	var t := _other_village(v, a)
	if u == null:
		return fail("That isn't your unit")
	var err := v.army.send_error(u, t)
	if err != "":
		return fail(err)
	v.army.send(u, t)
	return ok()


func _call_wave(v: Village, _a: Dictionary) -> Dictionary:
	if not game.waves.can_call():
		return fail("A wave is still on")
	game.waves.call_next(v)
	return ok()


## Game speed (0 = paused): only the host may set it (co-op); single player
## is its own host.
func _set_speed(v: Village, a: Dictionary) -> Dictionary:
	if v != game.host_village():
		return fail("The host sets the speed")
	var i := int(a.get("index", -1))
	if i < 0 or i >= Game.SPEEDS.size():
		return fail("Unknown speed")
	game.apply_speed(i)
	return ok()
