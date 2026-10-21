extends Node
## Autoload "Settings": choices made on the title screen that must survive the
## switch into the game (difficulty, map, the tutorial).

enum Difficulty { EASY, NORMAL, HARD }

const NAMES := {Difficulty.EASY: "Easy", Difficulty.NORMAL: "Normal", Difficulty.HARD: "Hard"}
## Enemy strength and loot values (Config.DIFFICULTY_SCALED) are multiplied by this.
const ENEMY_MULTIPLIER := {Difficulty.EASY: 0.67, Difficulty.NORMAL: 1.0, Difficulty.HARD: 1.5}
## Order of the title screen's toggle: normal -> hard -> easy -> normal.
const CYCLE := {Difficulty.NORMAL: Difficulty.HARD, Difficulty.HARD: Difficulty.EASY, Difficulty.EASY: Difficulty.NORMAL}

var difficulty := Difficulty.NORMAL
## Multiplayer: this player's village name and colour (index into
## Config.VILLAGE_COLORS), remembered between sessions in user://player.cfg.
var player_name := ""
var player_color := 0
## The next game is the guided tutorial (set by the title screen, taken by Game).
var tutorial_next := false
## The next game is this scenario of the campaign (Campaign; 0: none; set by
## the title screen's campaign page, taken by Game).
var scenario_next := 0
## The title screen opens on the campaign map (set by a won last scenario's
## Show campaign map, taken by TitleScreen).
var campaign_next := false
## While a scenario runs: enemy values scaled by these instead of the
## difficulty's multiplier ({"hp": 0.5, ...}; Scenario.enemy_scale).
var enemy_scale := {}

const PLAYER_FILE := "user://player.cfg"


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PLAYER_FILE) == OK:
		player_name = str(cf.get_value("player", "name", ""))
		player_color = clampi(int(cf.get_value("player", "color", 0)), 0, Config.VILLAGE_COLORS.size() - 1)


func save_player() -> void:
	var cf := ConfigFile.new()
	cf.set_value("player", "name", player_name)
	cf.set_value("player", "color", player_color)
	cf.save(PLAYER_FILE)


## True once if the title screen asked for the tutorial (then it's cleared).
func take_tutorial() -> bool:
	var t := tutorial_next
	tutorial_next = false
	return t


## The scenario the title screen asked for, once (then it's cleared); 0: none.
func take_scenario() -> int:
	var n := scenario_next
	scenario_next = 0
	return n


## Whether the title screen should open on the campaign map, once (then it's cleared).
func take_campaign() -> bool:
	var c := campaign_next
	campaign_next = false
	return c


## The Difficulty for "easy" / "normal" / "hard".
static func difficulty_of(key: String) -> Difficulty:
	for d in NAMES:
		if NAMES[d].to_lower() == key:
			return d
	return Difficulty.NORMAL


## "" if `n` is a valid village name (2-20 letters, digits, spaces, ' and -), else why not.
static func name_error(n: String) -> String:
	var t := n.strip_edges()
	if t.length() < 2 or t.length() > 20:
		return "The village name needs 2 to 20 characters"
	var re := RegEx.create_from_string("^[\\p{L}\\p{N} '\\-]+$")
	if re.search(t) == null:
		return "Only letters, digits, spaces, ' and - please"
	return ""


## Map type for the next game (Config.MAP_TYPES, or "random") and seed (0: random).
var map_type := "temperate"
var map_seed := 0
## A map from a file for the next single-player games instead of a generated
## one (docs/map-editor-design.md §8), and which of its villages is played.
var custom_map: MapData = null
var custom_village := 0
## The map editor's state while a game runs from its Play (or after leaving
## it): {"map", "path", "dirty", ...}; the editor picks it up again. Empty: none.
var editor_session: Dictionary = {}
## The game was started by the editor's Play: its settings offer Back to editor.
var editor_play := false
## A saved game to load as the next game (SaveGame's body; docs/save-design.md),
## taken by Game.
var pending_save: Dictionary = {}


## The save the next game loads (then it's cleared); empty: a new game.
func take_pending_save() -> Dictionary:
	var d := pending_save
	pending_save = {}
	return d


func cycle_map_type() -> void:
	var order: Array[String] = Config.MAP_TYPE_ORDER.duplicate()
	order.append("random")
	map_type = order[(order.find(map_type) + 1) % order.size()]


func map_type_name(key: String = "") -> String:
	var k := map_type if key == "" else key
	return "Random" if k == "random" else Config.MAP_TYPES.get(k, {"name": k})["name"]


## The actual type for a game: "random" becomes one of the types, by the seed.
static func resolve_map_type(key: String, seed_value: int) -> String:
	if Config.MAP_TYPES.has(key):
		return key
	return Config.MAP_TYPE_ORDER[posmod(seed_value, Config.MAP_TYPE_ORDER.size())]


## A typed-in seed: digits as they are, any other text hashed; "" = random (0).
static func parse_seed(text: String) -> int:
	var t := text.strip_edges()
	if t == "":
		return 0
	if t.is_valid_int():
		return absi(t.to_int())
	return absi(hash(t))


func cycle_difficulty() -> void:
	difficulty = CYCLE[difficulty]


func difficulty_name() -> String:
	return NAMES[difficulty]


## Supported languages (English only so far); the settings button shows the flag.
const LANGUAGES: Array[String] = ["en"]
const LANGUAGE_INFO := {"en": {"name": "English", "flag": "flag_gb"}}
var language := "en"


func cycle_language() -> void:
	language = LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()]


func language_name() -> String:
	return LANGUAGE_INFO[language]["name"]


func language_flag() -> String:
	return LANGUAGE_INFO[language]["flag"]


## "easy" / "normal" / "hard", for string-keyed config tables.
func difficulty_key() -> String:
	return NAMES[difficulty].to_lower()


## What enemy value `key` (Config.DIFFICULTY_SCALED) is multiplied by: the
## difficulty's multiplier, unless a scenario sets its own (enemy_scale).
func enemy_multiplier(key: String = "") -> float:
	return float(enemy_scale[key]) if enemy_scale.has(key) else ENEMY_MULTIPLIER[difficulty]
