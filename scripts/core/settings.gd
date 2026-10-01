extends Node
## Autoload "Settings": choices made on the title screen that must survive the
## switch into a level (difficulty, chosen level).

enum Difficulty { EASY, NORMAL, HARD }

const NAMES := {Difficulty.EASY: "Easy", Difficulty.NORMAL: "Normal", Difficulty.HARD: "Hard"}
## Enemy strength and loot values (Config.DIFFICULTY_SCALED) are multiplied by this.
const ENEMY_MULTIPLIER := {Difficulty.EASY: 0.67, Difficulty.NORMAL: 1.0, Difficulty.HARD: 1.5}
## Order of the title screen's toggle: normal -> hard -> easy -> normal.
const CYCLE := {Difficulty.NORMAL: Difficulty.HARD, Difficulty.HARD: Difficulty.EASY, Difficulty.EASY: Difficulty.NORMAL}

var difficulty := Difficulty.NORMAL
var level := 1
## Multiplayer: this player's village name and colour (index into
## Config.VILLAGE_COLORS), remembered between sessions in user://player.cfg.
var player_name := ""
var player_color := 0
## The guided tutorial was finished or skipped once (saved in PLAYER_FILE);
## the singleplayer page then says "Tutorial ✓".
var tutorial_done := false
## The next game is the guided tutorial (set by the title screen, taken by Game).
var tutorial_next := false

const PLAYER_FILE := "user://player.cfg"


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PLAYER_FILE) == OK:
		player_name = str(cf.get_value("player", "name", ""))
		player_color = clampi(int(cf.get_value("player", "color", 0)), 0, Config.VILLAGE_COLORS.size() - 1)
		tutorial_done = bool(cf.get_value("tutorial", "done", false))


func save_player() -> void:
	var cf := ConfigFile.new()
	cf.set_value("player", "name", player_name)
	cf.set_value("player", "color", player_color)
	cf.set_value("tutorial", "done", tutorial_done)
	cf.save(PLAYER_FILE)


## True once if the title screen asked for the tutorial (then it's cleared).
func take_tutorial() -> bool:
	var t := tutorial_next
	tutorial_next = false
	return t


func mark_tutorial_done() -> void:
	if not tutorial_done:
		tutorial_done = true
		save_player()


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


func enemy_multiplier() -> float:
	return ENEMY_MULTIPLIER[difficulty]
