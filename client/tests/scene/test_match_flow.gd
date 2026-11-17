extends TestCase
## MatchController (offline flow) and MatchScreen end to end, headless.


func _seats(kinds: Array, two: bool) -> Array:
	var colors: Array[String] = BoardGeometry.default_board().two_player_colors if two else BoardGeometry.COLORS
	var out: Array = []
	for i in colors.size():
		out.append({"color": colors[i], "kind": kinds[i], "role": "you" if i == 0 else ("bot" if kinds[i] == "bot" else "player"), "name": "P%d" % i})
	return out


## Seeded dice that respect the 1..5 bound after two sixes (GAME_RULES §6.2).
func _random_dice(seed: int) -> DiceSource:
	return DiceSource.seeded(seed)


func _run_controller(c: MatchController, limit_frames: int) -> Dictionary:
	var done := {"over": false, "applied": 0}
	c.applied.connect(func(_e: Array, _s: Dictionary) -> void:
		done["applied"] += 1
		c.view_done.call_deferred())
	c.finished.connect(func(_s: Dictionary) -> void: done["over"] = true)
	for i in limit_frames:
		if done["over"]:
			break
		await tree.process_frame
	return done


func test_bot_matches_play_to_the_end_two_and_four_players() -> void:
	for two: bool in [true, false]:
		var c := MatchController.new()
		tree.root.add_child(c)
		c.bot_delay = Vector2(0.0, 0.0)
		var n := 2 if two else 4
		assert_true(c.start({"seats": _seats(["bot", "bot", "bot", "bot"].slice(0, n), two), "first_seat": 0}, _random_dice(7 + n)))
		var done := await _run_controller(c, 20000)
		assert_true(done["over"], "%d-player bot match finished (%d actions)" % [n, done["applied"]])
		var s := c.state()
		assert_eq(s["turn"]["phase"], "game_over")
		assert_eq((s["ranks"] as Array).size(), n)
		c.queue_free()


func test_human_timeout_and_autopilot() -> void:
	var c := MatchController.new()
	tree.root.add_child(c)
	c.bot_delay = Vector2(0.0, 0.0)
	var cfg := {"seats": _seats(["human", "bot"], true), "first_seat": 0, "ruleset": {"turn_roll_seconds": 1, "turn_move_seconds": 1}}
	assert_true(c.start(cfg, _random_dice(3)))
	var seen := {"timeouts": 0, "autopilot": false}
	c.applied.connect(func(events: Array, _s: Dictionary) -> void:
		for e: Dictionary in events:
			if e["type"] == "dice_rolled" and e["seat"] == 0 and e["auto"]:
				seen["timeouts"] += 1
			if e["type"] == "autopilot_changed" and e["on"]:
				seen["autopilot"] = true
		c.view_done.call_deferred())
	var started := Time.get_ticks_msec()
	while not seen["autopilot"] and Time.get_ticks_msec() - started < 15000:
		await tree.process_frame
	assert_true(seen["timeouts"] >= 3, "human turns timed out (%d)" % seen["timeouts"])
	assert_true(seen["autopilot"], "autopilot after 3 timeouts")
	# Taking control back: the human rolls.
	while not (int(c.state()["turn"]["seat"]) == 0 and c.state()["turn"]["phase"] == "roll") and Time.get_ticks_msec() - started < 20000:
		await tree.process_frame
	var r := c.human_roll(0)
	if r["ok"]:
		assert_false(c.state()["players"][0]["autopilot"], "acting turns autopilot off")
	c.queue_free()


func test_single_option_is_auto_played_but_choices_wait_for_the_player() -> void:
	var c := MatchController.new()
	tree.root.add_child(c)
	c.bot_delay = Vector2(0.0, 0.0)
	assert_true(c.start({"seats": _seats(["human", "bot"], true), "first_seat": 0}, DiceSource.scripted([6, 3, 6, 1, 1, 1])))
	c.auto_single_move = true
	c.applied.connect(func(_e: Array, _s: Dictionary) -> void: c.view_done.call_deferred())
	c.human_roll(0)  # 6: four yard pawns, all the same move -> auto
	for i in 120:
		await tree.process_frame
	assert_eq(c.state()["pawns"]["red"], [0, -1, -1, -1], "single option played automatically")
	assert_eq(c.state()["turn"]["phase"], "roll", "bonus roll waits for the player")
	c.human_roll(0)  # 3: one pawn on the board -> also a single option (yard pawns cannot enter)
	for i in 120:
		await tree.process_frame
	assert_eq(c.state()["pawns"]["red"][0], 3)
	c.queue_free()


func test_match_screen_plays_a_whole_bot_game_with_animations() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1560)
	tree.root.add_child(vp)
	var holder := Control.new()
	holder.theme = UiTheme.theme()
	holder.size = Vector2(720, 1560)
	vp.add_child(holder)
	var screen := MatchScreen.new()
	screen.config = {"players": 4, "seats": _seats(["bot", "bot", "bot", "bot"], false), "first_seat": 0, "dice": _random_dice(11)}
	screen.size = Vector2(720, 1560)
	holder.add_child(screen)
	screen.controller.bot_delay = Vector2(0.0, 0.0)
	var over := {"done": false}
	screen.controller.finished.connect(func(_s: Dictionary) -> void: over["done"] = true)
	Engine.time_scale = 40.0
	var started := Time.get_ticks_msec()
	while not over["done"] and Time.get_ticks_msec() - started < 120000:
		await tree.process_frame
	Engine.time_scale = 1.0
	assert_true(over["done"], "4-player bot game reached the result through the real screen")
	for i in 30:
		await tree.process_frame
	# Pawns end where the state says.
	var s := screen.controller.state()
	for p: Dictionary in s["players"]:
		for k in 4:
			var sprite: PawnSprite = screen.pawns["%s:%d" % [p["color"], k]]
			assert_eq(sprite.step, int(s["pawns"][p["color"]][k]), "%s:%d step" % [p["color"], k])
	vp.queue_free()
