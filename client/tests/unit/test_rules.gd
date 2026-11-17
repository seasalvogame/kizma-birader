extends TestCase
## GDScript engine rules — the Phase 2 scenarios (same numbering as the
## server tests). Full parity is checked separately (test_vectors.gd).

var E := GameEngine.new()


func _game(options: Dictionary = {}, pawns: Dictionary = {}) -> Dictionary:
	var s := GameState.create(options)
	for c: String in pawns:
		s["pawns"][c] = pawns[c].duplicate()
	return s


func _roll(s: Dictionary, v: int) -> Dictionary:
	var r := E.apply(s, {"type": "roll", "seat": s["turn"]["seat"], "turn_id": s["turn"]["turn_id"]}, v)
	if not r["ok"]:
		fail("roll %d: %s" % [v, r["error"]])
	return r


func _move(s: Dictionary, pawn: int) -> Dictionary:
	var r := E.apply(s, {"type": "move", "seat": s["turn"]["seat"], "turn_id": s["turn"]["turn_id"], "pawn": pawn})
	if not r["ok"]:
		fail("move %d: %s" % [pawn, r["error"]])
	return r


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return e["type"])


func test_01_02_enter_only_with_six() -> void:
	var r := _roll(_game(), 6)
	assert_eq((r["state"]["legal"] as Array).size(), 4)
	var m := _move(r["state"], 1)
	assert_eq(m["state"]["pawns"]["red"], [-1, 0, -1, -1])
	assert_eq(_types(m["events"]), ["pawn_moved", "bonus_roll"])
	for v in [1, 2, 3, 4, 5]:
		var n := _roll(_game(), v)
		assert_eq(_types(n["events"]), ["dice_rolled", "no_moves", "turn_changed"])


func test_03_04_05_exact_count_turn_change_and_six_bonus() -> void:
	var m := _move(_roll(_game({}, {"red": [5, -1, -1, -1]}), 4)["state"], 0)
	assert_eq(m["state"]["pawns"]["red"][0], 9)
	assert_eq(m["events"][0]["path"], [6, 7, 8, 9])
	assert_eq(m["state"]["turn"]["seat"], 1)
	var six := _move(_roll(_game({}, {"red": [5, -1, -1, -1]}), 6)["state"], 0)
	assert_eq(six["events"][-1]["type"], "bonus_roll")
	assert_eq(six["state"]["turn"]["seat"], 0)


func test_06_third_roll_after_two_sixes_is_one_to_five() -> void:
	var s := _game({}, {"red": [5, -1, -1, -1]})
	s = _move(_roll(s, 6)["state"], 0)["state"]
	assert_eq(GameEngine.max_dice_value(s), 6)
	s = _move(_roll(s, 6)["state"], 0)["state"]
	assert_eq(s["pawns"]["red"][0], 17)
	assert_eq(GameEngine.max_dice_value(s), 5)
	var six := E.apply(s, {"type": "roll", "seat": 0, "turn_id": s["turn"]["turn_id"]}, 6)
	assert_eq(six["error"], "INVALID_DICE")
	assert_true(six["state"] == s, "state unchanged")
	assert_eq(E.apply(s, {"type": "timeout", "seat": 0, "turn_id": s["turn"]["turn_id"]}, 6)["error"], "INVALID_DICE")
	for v in [1, 2, 3, 4, 5]:
		var r := _move(_roll(s, v)["state"], 0)
		assert_eq(r["state"]["pawns"]["red"][0], 17 + v)
		assert_eq(r["state"]["turn"]["seat"], 1)
		assert_eq(r["state"]["turn"]["sixes"], 0)
		assert_false(_types(r["events"]).has("turn_forfeited"))


func test_06b_alternative_ruleset_third_six_forfeits() -> void:
	var s := _game({"ruleset": {"third_six_action": "forfeit_turn"}}, {"red": [5, -1, -1, -1]})
	s = _move(_roll(s, 6)["state"], 0)["state"]
	s = _move(_roll(s, 6)["state"], 0)["state"]
	assert_eq(GameEngine.max_dice_value(s), 6)
	var r := _roll(s, 6)
	assert_eq(_types(r["events"]), ["dice_rolled", "turn_forfeited", "turn_changed"])
	assert_eq(r["state"]["pawns"]["red"][0], 17)


func test_06c_session_and_local_dice_respect_the_bound() -> void:
	assert_eq(Ruleset.make()["third_six_action"], "exclude_six")
	# the offline device RNG never gives a 6 when the bound is 5
	var local := DiceSource.local()
	var seen := {}
	for i in 5000:
		var v := local.next(5)
		assert_true(v >= 1 and v <= 5, "local dice %d out of 1..5" % v)
		seen[v] = true
	assert_eq(seen.size(), 5)
	# the session asks for 1..5 right after two sixes
	var s := _game({"players": 2}, {"red": [5, -1, -1, -1]})
	var m := MatchSession.new(s, E, DiceSource.scripted([6, 6, 5]))
	for step in [["a", "roll"], ["b", "move"], ["c", "roll"], ["d", "move"], ["e", "roll"]]:
		var action := {"type": step[1], "seat": 0, "turn_id": m.state["turn"]["turn_id"], "pawn": 0}
		assert_true(m.submit(step[0], action)["ok"], "step %s" % step[0])
	assert_eq(m.state["pawns"]["red"][0], 17)
	assert_eq(m.state["turn"]["dice"], 5)


func test_07_08_09_safe_cells_capture_and_stacks() -> void:
	var safe := _move(_roll(_game({}, {"red": [17, -1, -1, -1], "green": [8, -1, -1, -1]}), 4)["state"], 0)
	assert_eq(safe["state"]["pawns"]["green"][0], 8)
	var cap := _move(_roll(_game({}, {"red": [16, -1, -1, -1], "green": [7, -1, -1, -1]}), 4)["state"], 0)
	assert_eq(cap["state"]["pawns"]["green"][0], -1)
	assert_eq(_types(cap["events"]), ["pawn_moved", "pawn_captured", "bonus_roll"])
	var stack := _move(_roll(_game({}, {"red": [7, 10, -1, -1]}), 3)["state"], 0)
	assert_eq(stack["state"]["pawns"]["red"], [10, 10, -1, -1])


func test_10_11_corridor_and_exact_finish() -> void:
	var c := _move(_roll(_game({}, {"red": [48, -1, -1, -1]}), 5)["state"], 0)
	assert_eq(c["state"]["pawns"]["red"][0], 53)
	var over := _roll(_game({}, {"red": [53, -1, -1, -1]}), 4)
	assert_true(_types(over["events"]).has("no_moves"))
	var done := _move(_roll(_game({}, {"red": [53, -1, -1, -1]}), 3)["state"], 0)
	assert_eq(done["state"]["pawns"]["red"][0], 56)


func test_12_13_winning_two_and_four_players() -> void:
	var two := _move(_roll(_game({"players": 2}, {"red": [56, 56, 56, 53]}), 3)["state"], 3)
	assert_eq(two["state"]["ranks"], [0, 1])
	assert_eq(two["state"]["turn"]["phase"], "game_over")
	var s := _game({}, {"red": [56, 56, 56, 55], "green": [56, 56, 56, 55], "yellow": [56, 56, 56, 55]})
	for i in 3:
		s = _move(_roll(s, 1)["state"], 3)["state"]
	assert_eq(s["ranks"], [0, 1, 2, 3])


func test_14_15_17_18_no_moves_and_invalid_actions() -> void:
	var s := _game({}, {"red": [5, -1, -1, -1]})
	assert_eq(E.apply(s, {"type": "move", "seat": 0, "turn_id": 1, "pawn": 0})["error"], "WRONG_PHASE")
	assert_eq(E.apply(s, {"type": "roll", "seat": 2, "turn_id": 1}, 3)["error"], "NOT_YOUR_TURN")
	assert_eq(E.apply(s, {"type": "roll", "seat": 0, "turn_id": 9}, 3)["error"], "STALE_TURN")
	assert_eq(E.apply(s, {"type": "roll", "seat": 0, "turn_id": 1}, 7)["error"], "INVALID_DICE")
	var rolled: Dictionary = _roll(s, 3)["state"]
	var bad := E.apply(rolled, {"type": "move", "seat": 0, "turn_id": rolled["turn"]["turn_id"], "pawn": 2})
	assert_eq(bad["error"], "ILLEGAL_MOVE")
	assert_true(bad["state"] == rolled, "state untouched")


func test_16_repeated_request_is_applied_once() -> void:
	var dice := DiceSource.scripted([6, 2])
	var m := MatchSession.new(GameState.create({"players": 2}), E, dice)
	var first := m.submit("a", {"type": "roll", "seat": 0, "turn_id": 1})
	var again := m.submit("a", {"type": "roll", "seat": 0, "turn_id": 1})
	assert_true(first["ok"])
	assert_true(again["duplicate"])
	assert_eq(dice.remaining(), 1)
	m.submit("b", {"type": "move", "seat": 0, "turn_id": 1, "pawn": 0})
	assert_eq(m.submit("c", {"type": "move", "seat": 0, "turn_id": 1, "pawn": 0})["error"], "STALE_TURN")
	assert_eq(m.state["pawns"]["red"], [0, -1, -1, -1])


func test_ruleset_validation_and_bad_games() -> void:
	assert_true(Ruleset.make({"blockade": "pair_blocks"}).is_empty())
	assert_true(Ruleset.last_error.contains("not implemented"))
	assert_true(Ruleset.make({"nonsense": 1}).is_empty())
	assert_true(GameState.create({"seats": [{"color": "red"}, {"color": "green"}]}).is_empty())
	assert_false(GameState.create({"seats": [{"color": "green"}, {"color": "blue"}]}).is_empty())


func test_bot_only_games_always_finish() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in range(1, 41):
		rng.seed = seed
		var s := GameState.create({"players": 2 if seed % 2 == 1 else 4})
		var guard := 0
		while s["turn"]["phase"] != "game_over" and guard < 5000:
			var r := E.apply(s, {"type": "timeout", "seat": s["turn"]["seat"], "turn_id": s["turn"]["turn_id"]}, rng.randi_range(1, 6))
			s = r["state"]
			guard += 1
		assert_eq(s["turn"]["phase"], "game_over", "seed %d" % seed)
