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


func cycle_difficulty() -> void:
	difficulty = CYCLE[difficulty]


func difficulty_name() -> String:
	return NAMES[difficulty]


## "easy" / "normal" / "hard", for string-keyed config tables.
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


func difficulty_key() -> String:
	return NAMES[difficulty].to_lower()


func enemy_multiplier() -> float:
	return ENEMY_MULTIPLIER[difficulty]
