class_name Ruleset
extends RefCounted
## Configurable rules (GAME_RULES.md §12) — GDScript twin of
## server/game-engine/src/ruleset.ts. Same snake_case keys, same defaults,
## same validation. make() returns {} on error and sets last_error.

const CLASSIC_V1 := {
	"id": "classic_v1",
	"enter_on": [6],
	"entry_attempts_when_all_in_yard": 1,
	"bonus_roll_on_six": true,
	"max_consecutive_sixes": 3,
	# exclude_six: after two 6s in a row the next roll is 1..5 (GAME_RULES §6.2).
	# forfeit_turn: alternative ruleset, a third 6 ends the turn.
	"third_six_action": "exclude_six",
	"bonus_roll_on_capture": true,
	"bonus_roll_on_finish": true,
	"safe_cells": "starts_and_stars",
	"capture_on_start_cell": false,
	"stacking": "allowed",
	"blockade": "none",
	"capture_stack": "all",
	"exact_roll_to_finish": true,
	"auto_move_single_option": true,
	"turn_roll_seconds": 10,
	"turn_move_seconds": 12,
	"afk_timeouts_to_autopilot": 3,
	"two_player_claim_win_seconds": 90,
	"four_player_disconnect_leave_seconds": 300,
	"four_player_end": "until_three_finish",
}

const SUPPORTED := {
	"third_six_action": ["exclude_six", "forfeit_turn"],
	"safe_cells": ["starts_and_stars"],
	"stacking": ["allowed"],
	"blockade": ["none"],
	"capture_stack": ["all"],
	"four_player_end": ["until_three_finish", "first_finisher"],
	"entry_attempts_when_all_in_yard": [1],
	"capture_on_start_cell": [false],
	"exact_roll_to_finish": [true],
}

static var last_error := ""


## classic_v1 with overrides (numbers from JSON are normalised to int).
static func make(overrides: Dictionary = {}) -> Dictionary:
	last_error = ""
	var r: Dictionary = CLASSIC_V1.duplicate(true)
	for key: String in overrides:
		if not r.has(key):
			last_error = "unknown ruleset key: %s" % key
			return {}
		r[key] = overrides[key]
	for key: String in r:
		var base: Variant = CLASSIC_V1[key]
		if typeof(base) == TYPE_INT:
			r[key] = int(r[key])
		elif typeof(base) == TYPE_ARRAY:
			var ints: Array = []
			for v: Variant in r[key]:
				ints.append(int(v))
			r[key] = ints
	for key: String in SUPPORTED:
		if not (SUPPORTED[key] as Array).has(r[key]):
			last_error = "ruleset %s=%s is not implemented yet" % [key, str(r[key])]
			return {}
	var enter_on: Array = r["enter_on"]
	if enter_on.is_empty():
		last_error = "enter_on must list dice values 1..6"
		return {}
	for v: int in enter_on:
		if v < 1 or v > 6:
			last_error = "enter_on must list dice values 1..6"
			return {}
	if int(r["max_consecutive_sixes"]) < 2:
		last_error = "max_consecutive_sixes must be >= 2"
		return {}
	if int(r["turn_roll_seconds"]) <= 0 or int(r["turn_move_seconds"]) <= 0:
		last_error = "turn timers must be > 0"
		return {}
	return r
