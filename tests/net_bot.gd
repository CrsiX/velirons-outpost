extends Node
## Two-process LAN co-op test (milestone 5 of docs/multiplayer-design.md).
## Start the host and a client, both headless, on the same machine:
##   godot --headless --path . res://tests/net_bot.tscn -- --role=host
##   godot --headless --path . res://tests/net_bot.tscn -- --role=client
## (tests/run_net_test.sh does both.) Each side prints its checks; exit code 0
## when all pass. The client finds the host by LAN discovery (loopback), joins
## the lobby, gets ready; the host starts; then both check the replicated game.

const HOST_NAME := "Hostwatch"
const CLIENT_NAME := "Clientvale"
const TIMEOUT := 60.0
## The lobby's map settings for this test (a coast map with a camp, a ruin, treasures).
const MAP_TYPE := "coast"
const MAP_SEED := 4240

var role := ""
var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
	# Survive the switch into the level: another node becomes the "current scene".
	var stand_in := Node.new()
	stand_in.name = "StandIn"
	get_tree().root.add_child.call_deferred(stand_in)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = stand_in
	if role == "host":
		await _host()
	elif role == "client":
		await _client()
	else:
		print("usage: -- --role=host | --role=client")
	_finish()


func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if cond else "  FAIL ") + "[%s] %s" % [role, msg])
	if not cond:
		failures.append(msg)


func wait_until(cond: Callable, timeout: float = TIMEOUT) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > timeout * 1000.0:
			return false
	return true


func seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _finish() -> void:
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - [%s] %s" % [role, f])
	Net.leave()
	get_tree().quit(1 if failures.size() > 0 else 0)


func _client_id() -> int:
	for id in Net.players:
		if id != 1:
			return id
	return -1


# --- host ---------------------------------------------------------------------------------

func _host() -> void:
	check(Net.host(HOST_NAME, 0) == "" and Net.is_host(), "hosting a lobby")
	Net.disable_fog = false  # (whatever config.gd says: this test is about the fog)
	Net.reveal_map = false
	check(Net.join_decision(Net.PROTOCOL + 1, "Other") != "" and Net.join_decision(Net.PROTOCOL, HOST_NAME) != "", "the host turns away another version and a taken name")
	var joined := await wait_until(func() -> bool: return _client_id() > 0)
	check(joined, "a client joins the lobby")
	if not joined:
		return
	var cid := _client_id()
	check(Net.players[cid]["name"] == CLIENT_NAME and int(Net.players[cid]["color"]) != 0, "it has its name, and another colour than the host's")
	Net.set_map(MAP_TYPE, MAP_SEED)
	var ready := await wait_until(func() -> bool: return Net.players.has(cid) and Net.players[cid]["ready"])
	check(ready and Net.can_start(), "it gets ready: the host can start")
	check(Net.start_game(), "the host starts the game")
	check(Net.join_decision(Net.PROTOCOL, "Latecomer") == "The game has already started", "no late joining once started")
	var loaded := await wait_until(func() -> bool: return Net.game != null and Net.players[cid]["loaded"])
	check(loaded, "the client loaded the level")
	if not loaded:
		return
	var game := Net.game
	var v0 := game.villages[0]
	var v1 := game.villages[1]
	check(game.villages.size() == 2 and v0.village_name == HOST_NAME and v1.village_name == CLIENT_NAME and not game.is_client, "two villages, named after the players")
	# (a tile 3 beyond the client's walls, on the far side from the host's village)
	var dir := Vector2(v1.center - v0.center).normalized()
	var behind := v1.center
	while Rect2i(v1.rect).has_point(behind) and game.map.in_bounds(behind):
		behind = v1.center + Vector2i((dir * (Vector2(behind - v1.center).length() + 1.0)).round())
	behind = v1.center + Vector2i((dir * (Vector2(behind - v1.center).length() + 3.0)).round())
	check(game.fog.is_explored_by(0, v1.center) and not game.fog.is_explored_by(0, behind) and game.fog.is_explored_by(1, behind), "each village has its own fog (the other's walls are known, nothing around them) [%s %s %s, behind %s, centers %s %s]" % [game.fog.is_explored_by(0, v1.center), game.fog.is_explored_by(0, behind), game.fog.is_explored_by(1, behind), behind, v0.center, v1.center])
	# The world (docs/world-design.md): the lobby's map, objects, unlocks.
	check(game.map.map_type == MAP_TYPE and game.map.seed_value == MAP_SEED and not game.world.map_objects.is_empty(), "the lobby's map type and seed are used (%s, %d, %d objects)" % [game.map.map_type, game.map.seed_value, game.world.map_objects.size()])
	var camp: MonsterCamp = null
	var ruin: RuinedTower = null
	var loot: Treasure = null
	for o in game.world.map_objects:
		if o is MonsterCamp and camp == null:
			camp = o
		elif o is RuinedTower and ruin == null:
			ruin = o
		elif o is Treasure and loot == null and o.guard() == null:
			loot = o
	check(camp != null and camp.alive().size() > 0 and ruin != null and loot != null, "the host runs the objects: a camp with its monsters, a ruin, a treasure")
	game.fog.reveal(Vector2(camp.tile), 2.5, v1.id)  # (the client's village finds the camp)
	game.unlock("summoner", v0, v0.hero)
	ruin.claim(v0)
	loot.mark_looted()
	v1.hero.max_hp = 5000.0
	v1.hero.hp = 5000.0
	var ordered := await wait_until(func() -> bool: return v1.hero.camp_target == camp, 60.0)
	check(ordered, "the client's order: its hero sets off to attack the camp")
	var recruited := await wait_until(func() -> bool: return v1.army.units.size() >= 1)
	check(recruited and v1.army.units[0].original_owner == v1 and v0.army.units.is_empty(), "the client's command recruits an archer in its own village")
	var caravan := await wait_until(func() -> bool: return v0.events.entries.any(func(e: Dictionary) -> bool: return str(e["text"]).begins_with("Caravan from %s arrived" % CLIENT_NAME)), 120.0)
	check(caravan, "the client's caravan arrives at the host's village")
	check(game.speed_index == 0, "the client couldn't change the speed")
	# Pause for a moment: the client should notice.
	game.command("set_speed", {"index": 3})
	await get_tree().process_frame
	check(game.hud._pause_gray.visible and game.hud._pause_gray.offset_top >= game.hud._topbar.get_global_rect().end.y - 0.5, "paused: our game turns grey, except the top bar")
	await seconds(3.0)
	game.command("set_speed", {"index": 0})
	var left := await wait_until(func() -> bool: return not Net.players.has(cid) or not Net.players[cid]["online"])
	check(left and v0.events.entries.any(func(e: Dictionary) -> bool: return e["text"] == "%s left the game" % CLIENT_NAME), "when the client leaves, its village stays and everyone is told")


# --- client --------------------------------------------------------------------------------

func _client() -> void:
	var err := Net.discovery.start_listening()
	check(err == "", "listening for games on the network %s" % err)
	var found := await wait_until(func() -> bool: return Net.discovery.games().any(func(g: Dictionary) -> bool: return g["name"] == HOST_NAME), 30.0)
	check(found, "the host's game shows up by LAN discovery")
	if not found:
		return
	var g: Dictionary = Net.discovery.games().filter(func(x: Dictionary) -> bool: return x["name"] == HOST_NAME)[0]
	check(g["players"] == 1 and g["max"] == Config.MAX_PLAYERS and g["proto"] == Net.PROTOCOL, "with its player count and version")
	var messages: Array[String] = []
	Net.lobby_message.connect(func(t: String) -> void: messages.append(t))
	check(Net.join("%s:%d" % [g["address"], g["port"]], CLIENT_NAME, 0) == "", "joining it")
	var in_lobby := await wait_until(func() -> bool: return Net.players.size() == 2)
	check(in_lobby, "in the lobby with the host")
	if not in_lobby:
		return
	var me := Net.my_id()
	check(int(Net.players[me]["color"]) != 0 and messages.any(func(t: String) -> bool: return "colour" in t), "the host's colour was taken: we got another one, and were told")
	Net.set_identity(HOST_NAME, 3)
	var told := await wait_until(func() -> bool: return messages.any(func(t: String) -> bool: return "taken" in t and "name" in t), 10.0)
	check(told and Net.players[me]["name"] == CLIENT_NAME, "the host's village name can't be taken")
	var lobby_map := await wait_until(func() -> bool: return Net.map_type == MAP_TYPE and Net.map_seed == MAP_SEED, 20.0)
	check(lobby_map, "the host's map settings show in our lobby (%s, %d)" % [Net.map_type, Net.map_seed])
	Net.set_ready(true)
	var started := await wait_until(func() -> bool: return Net.game != null and Net.game.is_client)
	check(started, "the host starts: we get the map and the level")
	if not started:
		return
	var game := Net.game
	var mine := game.player_village
	var synced := await wait_until(func() -> bool: return mine.buildings().size() >= 27 and mine.population.count() == Config.START_CIVILIANS.size() and mine.hero.nid > 0)
	check(synced, "our village arrives from the host: %d buildings, %d villagers, the hero" % [mine.buildings().size(), mine.population.count()])
	check(mine.id == 1 and mine.village_name == CLIENT_NAME and game.villages[0].village_name == HOST_NAME, "we play the second village")
	# The world: the host's map exactly, its objects' states, the unlocks.
	var same := MapGenerator.generate(MAP_SEED, 2, MAP_TYPE)
	check(game.map.map_type == MAP_TYPE and game.map.terrain == same.terrain and game.map.zones == same.zones and game.map.objects.size() == same.objects.size() and game.world.map_objects.size() == same.objects.size(), "we get the host's map: %s, seed %d, the same terrain, zones and %d objects" % [game.map.map_type, game.map.seed_value, game.world.map_objects.size()])
	var unl := await wait_until(func() -> bool: return game.is_unlocked("summoner"), 30.0)
	check(unl, "an unlock on the host reaches us (the summoner)")
	var states := await wait_until(func() -> bool:
		return game.world.map_objects.any(func(o: MapObject) -> bool: return o is RuinedTower and o.village == game.villages[0]) and game.world.map_objects.any(func(o: MapObject) -> bool: return o is Treasure and o.looted), 30.0)
	check(states, "object states reach us: the host's claimed ruin, a looted treasure")
	var camp: MonsterCamp = null
	for o in game.world.map_objects:
		if o is MonsterCamp:
			camp = o
			break
	var found_camp := await wait_until(func() -> bool: return camp != null and game.fog.is_explored_by(mine.id, camp.tile), 30.0)
	check(found_camp and camp.info()["actions"].any(func(a: Dictionary) -> bool: return a["label"] == "Attack with the hero"), "a camp we found offers Attack with the hero")
	game.command("attack_camp", {"camp": camp.nid})
	check(is_equal_approx(mine.economy.amount("gold"), Config.START_RESOURCES["gold"]), "with our own starting gold")
	var host_huts := game.villages[0].huts()
	var host_civs := get_tree().get_nodes_in_group("replicated").filter(func(n) -> bool: return n is Civilian and not (n is Hero) and n.village == game.villages[0])
	check(host_huts.size() == 9 and host_civs.is_empty(), "the host's huts are public, its villagers stay unseen")
	check(game.fog.is_explored_by(1, mine.center) and game.fog.is_explored_by(1, game.villages[0].center) and not game.fog.is_explored_by(1, game.villages[0].center + Vector2i(5, 0)), "our fog: our land, and only the walls of the other village")
	game.command("recruit_unit", {"kind": "archer"})
	var got := await wait_until(func() -> bool: return mine.army.units.size() == 1)
	check(got and is_equal_approx(mine.economy.amount("gold"), Config.START_RESOURCES["gold"] - Config.MILITARY["archer"]["cost"]["gold"]), "a command goes to the host; the new archer and the gold come back")
	var refused := []
	Net.command_refused.connect(func(t: String, e: String) -> void: refused.append([t, e]))
	game.command("set_speed", {"index": 1})
	var no := await wait_until(func() -> bool: return refused.any(func(r: Array) -> bool: return r[0] == "set_speed" and r[1] == "The host sets the speed"), 10.0)
	check(no and game.hud._speed_button.disabled, "only the host sets the speed (our speed button is off)")
	game.command("send_caravan", {"target": 0, "gold": 50})
	var paid := await wait_until(func() -> bool: return mine.economy.amount("gold") <= Config.START_RESOURCES["gold"] - Config.MILITARY["archer"]["cost"]["gold"] - 50 + 0.5, 10.0)
	check(paid, "sending a caravan to the host's village")
	game.hud.open_settings()
	check(game.hud._settings.visible and not get_tree().paused and not game.hud._gray.visible and game.hud._settings_title_button.text == "Leave game", "our settings don't pause the game (it keeps running)")
	game.hud.close_settings()
	var saw_pause := await wait_until(func() -> bool: return game.hud._paused_banner != null and game.hud._paused_banner.visible, 150.0)
	check(saw_pause, "when the host pauses, we see it")
	await seconds(1.0)
	var hud: Hud = game.hud
	check(hud._pause_gray.visible and hud._pause_gray.offset_top >= hud._topbar.get_global_rect().end.y - 0.5 and hud._paused_banner.get_index() > hud._pause_gray.get_index(), "while paused the game is grey below the top bar (top bar and banner stay in colour)")
	# The host is gone: one way out, not two.
	hud.show_session_ended("The host left the game")
	await get_tree().process_frame
	var outs := hud._overlay.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.is_visible_in_tree())
	check(outs.size() == 1 and outs[0].text == "Main menu" and not hud._pause_gray.visible, "the session-ended dialog has a single Main menu button (%s)" % str(outs.map(func(b: Button) -> String: return b.text)))
