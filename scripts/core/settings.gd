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
func difficulty_key() -> String:
	return NAMES[difficulty].to_lower()


func enemy_multiplier() -> float:
	return ENEMY_MULTIPLIER[difficulty]
