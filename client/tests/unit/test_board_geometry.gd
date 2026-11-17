extends TestCase
## board_map.json: the client copy equals the single source, and the board
## is the classic 15x15 star board (twin of server test/board.test.ts).

var B := BoardGeometry.default_board()


func test_client_copy_is_byte_identical_to_the_single_source() -> void:
	var source := FileAccess.get_file_as_bytes(repo_path("docs/design/board/board_map.json"))
	var copy := FileAccess.get_file_as_bytes("res://data/board_map.json")
	assert_true(source.size() > 0, "source readable")
	assert_eq(copy, source, "run client/tools/sync_board_map.py")
	assert_eq(B.load_error, "")


func test_sizes_starts_stars_and_safe_cells() -> void:
	assert_eq(B.grid, 15)
	assert_eq(B.track.size(), 52)
	assert_eq(B.goal_step, 56)
	assert_eq(B.last_track_step, 50)
	var starts: Array = []
	for c: String in BoardGeometry.COLORS:
		starts.append(B.start_index(c))
	assert_eq(starts, [0, 13, 26, 39])
	assert_eq(B.star_indices, [8, 21, 34, 47])
	var safe := B.safe_indices.duplicate()
	safe.sort()
	assert_eq(safe, [0, 8, 13, 21, 26, 34, 39, 47])


func test_track_is_closed_with_four_diagonal_corner_steps() -> void:
	var diagonal: Array = []
	var unique := {}
	for i in 52:
		var a := B.track[i]
		var b := B.track[(i + 1) % 52]
		unique[a] = true
		var d := (a - b).abs()
		if d == Vector2i(1, 1):
			diagonal.append(i)
		else:
			assert_eq(d.x + d.y, 1, "step %d" % i)
	assert_eq(unique.size(), 52)
	assert_eq(diagonal, [4, 17, 30, 43])


func test_paths_corridors_and_cells() -> void:
	assert_eq(B.cell_of("red", 0), Vector2i(1, 6))
	assert_eq(B.cell_of("red", 51), Vector2i(1, 7))
	assert_eq(B.cell_of("red", 55), Vector2i(5, 7))
	assert_eq(B.cell_of("red", 56), Vector2i(-1, -1))
	assert_eq(B.track_index("blue", 13), 0)
	assert_eq(B.track_index("red", 51), -1)
	for c: String in BoardGeometry.COLORS:
		var last := B.cell_of(c, 50)
		var k1 := B.cell_of(c, 51)
		var d := (last - k1).abs()
		assert_eq(d.x + d.y, 1, "%s corridor entry" % c)
		var path: Array = B.map["paths"][c]
		for st in 56:
			var cell: Array = path[st]
			assert_eq(B.cell_of(c, st), Vector2i(int(cell[0]), int(cell[1])), "%s step %d" % [c, st])


func test_rotation_maps_each_colour_onto_the_next_and_to_bottom_left() -> void:
	for i in 52:
		assert_eq(B.rotate_cell(B.track[i], 1), B.track[(i + 13) % 52])
	assert_eq(B.quarter_turns_to_bottom_left("blue"), 0)
	assert_eq(B.quarter_turns_to_bottom_left("red"), 3)
	for c: String in BoardGeometry.COLORS:
		var r: Rect2i = B.yard_rects[c]
		var centre := B.rotate_cell(r.position + Vector2i(2, 2), B.quarter_turns_to_bottom_left(c))
		assert_true(centre.x < 6 and centre.y > 8, "%s yard ends bottom-left" % c)
		var slot: Vector2 = B.yard_slots[c][0]
		var p := B.rotate_point(slot + Vector2(0.5, 0.5), B.quarter_turns_to_bottom_left(c))
		assert_true(p.x < 6.0 and p.y > 9.0, "%s slot ends bottom-left" % c)
