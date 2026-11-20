extends TestCase
## BoardView geometry (rotation, positions) and the match / setup layouts on
## several screen ratios (portrait only).

const SIZES: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1440), Vector2i(720, 1560), Vector2i(720, 1600), Vector2i(640, 1136), Vector2i(960, 1280)]


func _board(local_color: String, side: float) -> BoardView:
	var v := BoardView.new()
	v.size = Vector2(side, side)
	v.setup(BoardGeometry.default_board(), BoardGeometry.COLORS, local_color)
	return v


func test_local_yard_is_bottom_left_for_every_colour() -> void:
	for color: String in BoardGeometry.COLORS:
		var v := _board(color, 600)
		var p := v.pawn_position(color, -1, 0)
		assert_true(p.x < 300 and p.y > 300, "%s yard bottom-left (%s)" % [color, p])
		# After rotation every colour's start cell is where blue's is on the unrotated board
		# (bottom arm, left column: cell (6, 13)).
		var start := v.pawn_position(color, 0, 0)
		assert_eq(start, Vector2(6.5, 13.5) * 40.0, "%s start cell" % color)
		v.free()


func test_every_position_is_inside_the_square_board() -> void:
	var v := _board("red", 672)
	var r := v.board_rect()
	assert_eq(r.size.x, r.size.y)
	for color: String in BoardGeometry.COLORS:
		for st in range(-1, 57):
			for k in 4:
				var p := v.pawn_position(color, st, k)
				assert_true(r.has_point(p), "%s step %d pawn %d at %s" % [color, st, k, p])
	v.free()


func test_non_square_view_keeps_a_centred_square_board() -> void:
	var v := BoardView.new()
	v.size = Vector2(700, 500)
	v.setup(BoardGeometry.default_board(), BoardGeometry.COLORS, "blue")
	v._layout()
	assert_eq(v.board_rect(), Rect2(Vector2(100, 0), Vector2(500, 500)))
	v.free()


func test_match_layout_on_screen_ratios() -> void:
	for sz: Vector2i in SIZES:
		for players: int in [2, 4]:
			var vp := SubViewport.new()
			vp.size = sz
			tree.root.add_child(vp)
			var holder := Control.new()
			holder.theme = UiTheme.theme()
			holder.size = Vector2(sz)
			vp.add_child(holder)
			var colors: Array[String] = BoardGeometry.default_board().two_player_colors if players == 2 else BoardGeometry.COLORS
			var seats: Array = []
			for i in colors.size():
				seats.append({"color": colors[i], "kind": "human" if i == 0 else "bot", "role": "you" if i == 0 else "bot", "name": "Oyuncu %d" % i})
			var screen := MatchScreen.new()
			screen.config = {"players": players, "seats": seats, "first_seat": 0, "dice": DiceSource.scripted([1, 1, 1, 1])}
			screen.size = Vector2(sz)
			holder.add_child(screen)
			await tree.process_frame
			await tree.process_frame
			screen._layout()
			var where := "%dx%d %dp" % [sz.x, sz.y, players]
			var b := Rect2(screen.board_view.position, screen.board_view.size)
			var screen_rect := Rect2(Vector2.ZERO, Vector2(sz))
			assert_true(is_equal_approx(b.size.x, b.size.y), where + " board square")
			assert_true(screen_rect.encloses(b), where + " board on screen")
			assert_true(b.size.x >= 0.6 * sz.x, where + " board big enough (%d)" % b.size.x)
			var dice_rect := Rect2(screen.dice.position, screen.dice.size)
			assert_true(screen_rect.encloses(dice_rect), where + " dice on screen")
			assert_false(dice_rect.intersects(b), where + " dice below the board")
			assert_true(dice_rect.size.x >= 88, where + " dice touch size")
			for seat: int in screen.cards:
				var card: PlayerCard = screen.cards[seat]
				var cr := Rect2(card.position, card.size)
				assert_false(cr.intersects(b.grow(-2)), where + " card %d off the board" % seat)
				assert_true(screen_rect.encloses(cr), where + " card %d on screen" % seat)
			assert_true(screen._menu_button.size.x >= 88, where + " menu touch size")
			vp.queue_free()
			await tree.process_frame


func test_setup_screen_fits_small_screens() -> void:
	for sz: Vector2i in [Vector2i(640, 1136), Vector2i(720, 1280), Vector2i(720, 1600)]:
		var vp := SubViewport.new()
		vp.size = sz
		tree.root.add_child(vp)
		var holder := Control.new()
		holder.theme = UiTheme.theme()
		holder.size = Vector2(sz)
		vp.add_child(holder)
		var screen := PracticeSetupScreen.new()
		screen.size = Vector2(sz)
		holder.add_child(screen)
		screen._set_players(4)
		for i in 4:
			await tree.process_frame
		var play: Button = screen._play
		var r := Rect2(play.global_position, play.size)
		assert_true(Rect2(Vector2.ZERO, Vector2(sz)).encloses(r), "%s play button visible (%s)" % [sz, r])
		assert_true(play.size.y >= 88, "play touch height")
		vp.queue_free()
		await tree.process_frame


func test_taps_on_the_dice_and_a_pawn_play_the_turn() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1560)
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var holder := Control.new()
	holder.theme = UiTheme.theme()
	holder.size = Vector2(720, 1560)
	vp.add_child(holder)
	var seats := [{"color": "red", "kind": "human", "role": "you", "name": "Sen"}, {"color": "yellow", "kind": "bot", "role": "bot", "name": "Bot 1"}]
	var screen := MatchScreen.new()
	screen.config = {"players": 2, "seats": seats, "first_seat": 0, "dice": DiceSource.scripted([6, 6, 2, 3, 4, 5])}
	screen.size = Vector2(720, 1560)
	holder.add_child(screen)
	screen.controller.auto_single_move = false
	await tree.process_frame
	await tree.process_frame
	_click(vp, screen.dice.global_position + screen.dice.size * 0.5)
	var started := Time.get_ticks_msec()
	while screen.controller.state()["turn"]["phase"] != "move" and Time.get_ticks_msec() - started < 5000:
		await tree.process_frame
	assert_eq(screen.controller.state()["turn"]["phase"], "move", "dice tap rolled")
	while (screen.board_view.selectable as Array).is_empty() and Time.get_ticks_msec() - started < 5000:
		await tree.process_frame
	var sprite: PawnSprite = screen.pawns["red:2"]
	# A tap far from any selectable pawn does nothing.
	_click(vp, screen.board_view.global_position + Vector2(5, 5))
	await tree.process_frame
	assert_eq(screen.controller.state()["turn"]["phase"], "move", "stray tap ignored")
	_click(vp, screen.board_view.global_position + sprite.position)
	while screen.controller.state()["pawns"]["red"][2] != 0 and Time.get_ticks_msec() - started < 5000:
		await tree.process_frame
	assert_eq(screen.controller.state()["pawns"]["red"], [-1, -1, 0, -1], "tapped pawn entered")
	vp.queue_free()


func test_finish_target_keeps_the_selected_pawn_slot() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1560)
	tree.root.add_child(vp)
	var holder := Control.new()
	holder.theme = UiTheme.theme()
	holder.size = Vector2(720, 1560)
	vp.add_child(holder)
	var seats := [{"color": "red", "kind": "human", "role": "you", "name": "Sen"}, {"color": "yellow", "kind": "bot", "role": "bot", "name": "Bot 1"}]
	var screen := MatchScreen.new()
	screen.config = {"players": 2, "seats": seats, "first_seat": 0, "dice": DiceSource.scripted([1, 1, 1, 1])}
	screen.size = Vector2(720, 1560)
	holder.add_child(screen)
	await tree.process_frame
	await tree.process_frame
	var state := screen.controller.state().duplicate(true)
	state["pawns"]["red"] = [56, 56, 55, -1]
	state["turn"] = {"seat": 0, "phase": "move", "dice": 1, "sixes": 0, "turn_id": 12}
	state["legal"] = [{"pawn": 2, "to": 56}]
	screen.controller.session.state = state
	screen._sync(state)
	assert_eq(int(screen.board_view.targets[0]["pawn"]), 2, "finish target retains the selected pawn")
	assert_true(screen.board_view.pawn_position("red", 56, 2) != screen.board_view.pawn_position("red", 56, 0), "finish slots differ by pawn")
	vp.queue_free()


func test_same_cell_pawns_stay_inside_their_cell_and_equipped_cosmetics_refresh() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1560)
	tree.root.add_child(vp)
	var holder := Control.new()
	holder.theme = UiTheme.theme()
	holder.size = Vector2(720, 1560)
	vp.add_child(holder)
	var seats := [
		{"color": "red", "kind": "human", "role": "you", "name": "Sen"},
		{"color": "green", "kind": "bot", "role": "bot", "name": "Bot 1"},
		{"color": "yellow", "kind": "bot", "role": "bot", "name": "Bot 2"},
		{"color": "blue", "kind": "bot", "role": "bot", "name": "Bot 3"},
	]
	var screen := MatchScreen.new()
	screen.config = {"players": 4, "seats": seats, "first_seat": 0, "dice": DiceSource.scripted([1, 1, 1, 1])}
	screen.size = Vector2(720, 1560)
	holder.add_child(screen)
	await tree.process_frame
	await tree.process_frame
	for count: int in [2, 3, 4]:
		var state := screen.controller.state().duplicate(true)
		state["pawns"]["red"] = [-1, -1, -1, -1]
		for i in count:
			state["pawns"]["red"][i] = 10
		screen.controller.session.state = state
		screen._sync(state)
		var centre := screen.board_view.pawn_position("red", 10, 0)
		var cell := screen.board_view.cell_size()
		for i in count:
			var pawn: PawnSprite = screen.pawns["red:%d" % i]
			assert_eq(pawn.get("_stack_count"), count, "%d-pawn stack is scaled" % count)
			assert_true(pawn.position.distance_to(centre) + pawn.visual_half_extent() <= cell * 0.5,
				"%d-pawn stack remains inside its board cell" % count)
	var old_inventory: Dictionary = Online.cosmetics.inventory.duplicate(true)
	Online.cosmetics.inventory = {"owned": [], "loadout": {
		"dice": "dice_night", "pawns": "pawns_gem", "board": "board_mint",
		"frame": "frame_gold", "effect": "effect_sparkle", "name": "name_star"}}
	Online.cosmetics.changed.emit()
	await tree.process_frame
	assert_eq(screen.dice.skin, "dice_night", "equipped dice applies to an active match immediately")
	assert_eq(screen.board_view.theme_id, "board_mint", "equipped board applies to an active match immediately")
	for i in 4:
		assert_eq((screen.pawns["red:%d" % i] as PawnSprite).skin, "pawns_gem", "equipped pawn skin %d applies immediately" % i)
	assert_eq((screen.cards[0] as PlayerCard).avatar.frame_id, "frame_gold", "equipped frame applies to the live player card")
	assert_eq((screen.cards[0] as PlayerCard).avatar.effect_id, "effect_sparkle", "equipped effect applies to the live player card")
	assert_eq((screen.cards[0] as PlayerCard).name_label.text, "★ Sen ★", "equipped name style applies without rebuilding the card")
	Online.cosmetics.inventory = old_inventory
	vp.queue_free()


func _click(vp: SubViewport, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		vp.push_input(e)
