extends Node
## Screenshot tour for visual review (development only, not shipped):
##   godot_console --path client --resolution 540x1170 res://tests/visual/screenshot_tour.tscn \
##       -- --shots=<absolute dir> --settings-path=user://tour/settings.cfg [--safe-insets=94,48] [--locale=en]

var shots := ""
var main: Node


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--locale="):
			Settings.set_value("locale", arg.trim_prefix("--locale="))
	if shots == "":
		push_error("--shots=<dir> required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(shots)
	Settings.set_value("reduced_motion", true)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Settings.set_value("profile_name", "Ayşe")
	main.call("go", "home")
	await _frames(20)
	await _shot("00a_home")
	for step: Array in [["modes", {"players": 2}, "00b_modes"], ["setup", {"players": 2, "mode": "bots"}, "01_setup_2p"]]:
		main.call("go", step[0], step[1])
		await _frames(12)
		await _shot(step[2])
	var setup: PracticeSetupScreen = main.get("current")
	setup._set_color("green")
	setup._set_players(4)
	await _frames(5)
	await _shot("02_setup_4p")
	for step: Array in [["profile", {}, "00c_profile"], ["settings", {}, "00d_settings"], ["rules", {}, "00e_rules"],
			["friends", {}, "00f_friends"], ["store", {}, "00g_store"], ["info", {"kind": "online"}, "00h_online"]]:
		main.call("go", step[0], step[1])
		await _frames(12)
		await _shot(step[2])
	# 4-player match, scripted dice, local red starts.
	var config := _config(4)
	config["first_seat"] = 0
	config["dice"] = DiceSource.scripted([6, 6, 3, 4, 2, 5, 1, 6, 6, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6])
	main.call("show_match", config)
	await _frames(20)
	await _shot("03_match_4p_start")
	var screen: MatchScreen = main.get("current")
	# Mid-game position, local player to move with a 4.
	var s := screen.controller.state()
	s["pawns"] = {"red": [4, 27, -1, -1], "green": [11, 33, 52, -1], "yellow": [56, 56, 16, -1], "blue": [22, 56, -1, -1]}
	s["turn"] = {"seat": 0, "phase": "roll", "dice": 0, "sixes": 0, "turn_id": 40}
	s["version"] = 80
	screen.controller.session.state = s
	screen.controller.view_done()
	screen._sync(s)
	await _frames(5)
	await _shot("04_match_4p_roll")
	screen.controller.human_roll(0)
	await _wait(1.5)
	await _shot("05_match_4p_select")
	screen._open_menu()
	await _wait(0.6)
	await _shot("06_menu")
	screen._close_overlay()
	await _frames(5)
	var over := s.duplicate(true)
	over["turn"]["phase"] = "game_over"
	over["ranks"] = [2, 0, 3, 1]
	for i in 4:
		over["players"][i]["rank"] = over["ranks"].find(i) + 1
	over["players"][2]["status"] = "finished"
	screen._show_result(over)
	await _wait(0.6)
	await _shot("07_result")
	# 2-player match.
	var config2 := _config(2)
	config2["first_seat"] = 1
	config2["dice"] = DiceSource.scripted([6, 6, 4, 6, 2, 3, 5, 1, 2, 3, 4, 5, 6, 6])
	main.call("show_match", config2)
	await _frames(20)
	var screen2: MatchScreen = main.get("current")
	var s2 := screen2.controller.state()
	s2["pawns"] = {"red": [21, 56, -1, -1], "yellow": [56, 56, 44, 33]}
	s2["turn"] = {"seat": 1, "phase": "roll", "dice": 0, "sixes": 0, "turn_id": 30}
	screen2.controller.session.state = s2
	screen2._sync(s2)
	await _wait(2.5)
	await _shot("08_match_2p")
	get_tree().quit(0)


func _config(players: int) -> Dictionary:
	var colors: Array[String] = BoardGeometry.default_board().two_player_colors if players == 2 else BoardGeometry.COLORS
	var seats: Array = []
	for i in colors.size():
		if i == 0:
			seats.append({"color": colors[i], "role": "you", "kind": "human", "name": tr("NAME_YOU")})
		else:
			seats.append({"color": colors[i], "role": "bot", "kind": "bot", "name": tr("NAME_BOT_N") % i})
	return {"players": players, "seats": seats}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))
	print("shot ", name)
