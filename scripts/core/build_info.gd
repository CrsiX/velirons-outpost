class_name BuildInfo
extends RefCounted
## Which build this is: the git commit and the most recent git tag. Both come
## from scripts/core/build_stamp.gd, which tools/stamp_version.sh writes
## (never committed) while a build is exported (tools/export.sh, CI) and which
## is gone again afterwards. The game never runs git itself. Anywhere without
## a stamp, and always in the editor binary (so the bots and development runs
## can't pick up a stale stamp), both are "unknown": never a guess.

const STAMP := "res://scripts/core/build_stamp.gd"
const UNKNOWN := "unknown"

## Tests: a stamp's constants (COMMIT, TAG) to use instead of the file (an
## empty one: a build without a stamp). Null: the real thing.
static var test_stamp: Variant = null


## The most recent git tag, e.g. "v5.2.1" ("unknown": no stamp, or no tag yet).
static func game_version() -> String:
	return _value("TAG")


## The short git commit sha, with "-dirty" when tracked files had changes
## ("unknown": no stamp).
static func game_commit() -> String:
	return _value("COMMIT")


## What the title screen shows: "v5.2.1 (ab12cd3)"; just the one that is known
## when the other isn't ("" when neither is).
static func display_text() -> String:
	var tag := game_version()
	var commit := game_commit()
	if tag == UNKNOWN:
		return "" if commit == UNKNOWN else commit
	return tag if commit == UNKNOWN else "%s (%s)" % [tag, commit]


static func _value(key: String) -> String:
	var v := str(_stamp().get(key, "")).strip_edges()
	return v if v != "" else UNKNOWN


static func _stamp() -> Dictionary:
	if test_stamp is Dictionary:
		return test_stamp
	if OS.has_feature("editor") or not ResourceLoader.exists(STAMP):
		return {}
	var script := load(STAMP) as Script
	return script.get_script_constant_map() if script else {}
