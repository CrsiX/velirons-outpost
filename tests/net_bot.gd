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
	check(game.fog.is_explored_by(0, v1.center) and not game.fog.is_explored_by(0, v1.center + Vector2i(5, 0)) and game.fog.is_explored_by(1, v1.center + Vector2i(5, 0)), "each village has its own fog (the other's walls are known, nothing around them)")
	var recruited := await wait_until(func() -> bool: return v1.army.units.size() >= 1)
	check(recruited and v1.army.units[0].original_owner == v1 and v0.army.units.is_empty(), "the client's command recruits an archer in its own village")
	var caravan := await wait_until(func() -> bool: return v0.events.entries.any(func(e: Dictionary) -> bool: return str(e["text"]).begins_with("Caravan from %s arrived" % CLIENT_NAME)), 120.0)
	check(caravan, "the client's caravan arrives at the host's village")
	check(game.speed_index == 0, "the client couldn't change the speed")
	# Pause for a moment: the client should notice.
	game.command("set_speed", {"index": 3})
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
