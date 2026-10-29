class_name BalancePlayer
extends Node
## The player of the balancing bot (docs/balance-bot-design.md): every
## Config.BALANCE_BOT["think_interval"] game seconds it looks at the village
## and does what a reasonably careful player would, through the same commands
## the UI sends (Commands). It is three parts, each its own class:
##  - BalanceEconomy: repairs, the farm, villagers, farms and camps, trading
##    gold for material: the same for every policy (Config.BALANCE_ECONOMY);
##  - BalanceHero: what the hero does: the same for every policy
##    (Config.BALANCE_HERO);
##  - BalanceMilitary: defence buildings, units, upgrades, calling waves: what
##    a policy is (a Config.BALANCE_PROFILES entry).
## BalanceLedger watches what gets built and how well it does. The parts talk
## through the public fields below.
##
## Order of a round: cheats, the economy's first part (walls, the farm, huts,
## other repairs), the hero, the economy's second part (villagers, farms and
## camps), the military, trading, calling the wave. Earlier steps get the
## resources first.

var game: Game
var village: Village
var profile_name := ""
var profile: Dictionary = {}
var economy: BalanceEconomy
var hero: BalanceHero
var military: BalanceMilitary
var ledger: BalanceLedger
## Commands sent: type -> {"ok": n, "fail": n}; refusals by reason.
var commands_sent: Dictionary = {}
var refusals: Dictionary = {}
## Gold that went into the army, by what it bought: "recruit <kind>",
## "level <kind>" (a level of the same kind), "branch <kind> -> <branch>"
## -> {"n": times, "gold": gold}.
var army_gold: Dictionary = {}
## Waves called early.
var early_calls := 0

## --- what the parts tell each other (reset every round) ---
## Material the building held back by lack of it wants (0: nothing).
var want_materials := 0
## Something that can't wait (a repair, a hut, the farm) lacks material: the
## economy trades gold for it (critical_lack is how much).
var want_critical := false
var critical_lack := 0
## A repair (or hut rebuild) waits for material: nothing else spends any.
var repair_wanted := false
## No farm stands (nor is one being built or repaired): it comes before every
## other use of material and before new mouths.
var no_farm := false
## A farm stands but nobody works it: its farmer comes before any other recruit.
var farm_unmanned := false
## --- state they share ---
## Kind -> game seconds before which it isn't tried to place again (no spot).
var no_spot: Dictionary = {}
## Tiles where a site stood that nobody ever started (cancelled): not tried again.
var bad_spots: Dictionary = {}
## The pathing version the military's approach roads were made for.
var approach_version := -1

var _timer := 0.0
var _params: Dictionary = Config.BALANCE_BOT
var _cheated := false


func setup(p_game: Game, p_profile: String) -> void:
	game = p_game
	village = game.player_village
	profile_name = p_profile
	profile = Config.BALANCE_PROFILES[p_profile]
	economy = BalanceEconomy.new(self)
	hero = BalanceHero.new(self)
	military = BalanceMilitary.new(self)
	ledger = BalanceLedger.new(game)
	_timer = 0.5  # (the first decisions right away)


func _process(delta: float) -> void:
	if game == null or game.game_over:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = float(_params["think_interval"])
	_think()


func _think() -> void:
	want_materials = 0
	want_critical = false
	critical_lack = 0
	_cheats()
	economy.first()
	hero.think()
	economy.second()
	military.think()
	economy.trade()
	military.call_wave()
	ledger.update()


## Sends a command through the game and keeps count: sent, refused (by reason),
## and the gold a unit purchase cost.
func send(type: String, args: Dictionary = {}) -> Dictionary:
	var what := ""
	if type == "recruit_unit":
		what = "recruit %s" % args["kind"]
	elif type == "upgrade_unit":
		var u: MilitaryUnit = game.entity(int(args["unit"]))
		what = ("level %s" % u.kind) if args["to"] == u.kind else ("branch %s -> %s" % [u.kind, args["to"]])
	var gold0 := village.economy.amount("gold")
	var r := game.command(type, args)
	if what != "" and r["ok"]:
		var row: Dictionary = army_gold.get(what, {"n": 0, "gold": 0})
		row["n"] += 1
		row["gold"] += int(gold0 - village.economy.amount("gold"))
		army_gold[what] = row
	var sent: Dictionary = commands_sent.get(type, {"ok": 0, "fail": 0})
	sent["ok" if r["ok"] else "fail"] += 1
	commands_sent[type] = sent
	if not r["ok"]:
		var key := "%s: %s" % [type, r["error"]]
		refusals[key] = int(refusals.get(key, 0)) + 1
	return r


## Debug commands run at the start (what a test of one unit line needs).
func _cheats() -> void:
	if _cheated:
		return
	_cheated = true
	for what: String in profile.get("cheats", []):
		send("debug", {"what": what})
