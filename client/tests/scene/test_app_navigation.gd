extends TestCase
## Phase 3.3 app shell: router, back navigation, menu screens on several
## screen sizes, 2-player colour choice, local profile and practice stats.
## Uses its own settings file so the real user settings are never touched.

var _old_path := ""


func before_each() -> void:
	_old_path = Settings.path
	Settings.path = "user://test_app_navigation.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.load_settings()
	# no slide-in transition: layout checks measure final positions
	Settings.set_value("reduced_motion", true)


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = _old_path
	Settings.load_settings()


func _viewport(sz: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = sz
	tree.root.add_child(vp)
	return vp


func _main(vp: SubViewport) -> Node:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	vp.add_child(main)
	return main


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func test_every_screen_opens_and_back_returns() -> void:
	var vp := _viewport(Vector2i(720, 1560))
	var main := _main(vp)
	await _frames(3)
	assert_true(main.get("current") is HomeScreen, "starts on the home screen")
	var routes := [
		["modes", {"players": 2}, "ModeSelectScreen"], ["setup", {"players": 4, "mode": "bots"}, "PracticeSetupScreen"],
		["profile", {}, "ProfileScreen"], ["settings", {}, "SettingsScreen"], ["rules", {}, "RulesScreen"],
		["info", {"kind": "online"}, "InfoScreen"], ["info", {"kind": "achievements"}, "InfoScreen"],
	]
	for r: Array in routes:
		main.call("go", r[0], r[1])
		await _frames(2)
		var cur: Node = main.get("current")
		assert_eq(cur.get_script().get_global_name(), r[2], "route %s" % r[0])
	assert_eq((main.get("stack") as Array).size(), 8, "pushed screens stack up")
	main.call("back")
	await _frames(2)
	assert_true(main.get("current") is InfoScreen, "back returns to the previous screen")
	for tab: String in ["friends", "store", "quests", "ranking", "home"]:
		main.call("go", tab)
		await _frames(2)
		assert_eq((main.get("stack") as Array).size(), 1, "tab %s resets the stack" % tab)
		var screen: AppScreen = main.get("current")
		assert_true(screen.nav_bar != null and screen.nav_bar.current == tab, "tab %s shows the bottom bar" % tab)
	# Android back from a pushed screen goes back; from a match it opens the menu.
	main.call("go", "modes", {"players": 4})
	await _frames(2)
	main.call("_on_back")
	await _frames(2)
	assert_true(main.get("current") is HomeScreen, "back from modes returns home")
	var seats := [{"color": "red", "role": "you", "kind": "human", "name": "A"}, {"color": "yellow", "role": "bot", "kind": "bot", "name": "Bot 1"}]
	main.call("show_match", {"players": 2, "seats": seats, "dice": DiceSource.seeded(5)})
	await _frames(3)
	var match_screen: MatchScreen = main.get("current")
	main.call("_on_back")
	await _frames(2)
	assert_true(match_screen._overlay != null, "back inside a match opens the match menu")
	assert_true(main.get("current") == match_screen, "and does not leave the match")
	match_screen.controller.stop()
	vp.queue_free()
	await _frames(1)


func test_home_and_tabs_fit_phone_screens() -> void:
	for sz: Vector2i in [Vector2i(640, 1136), Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(1080, 1440)]:
		var vp := _viewport(sz)
		var main := _main(vp)
		await _frames(4)
		var home: HomeScreen = main.get("current")
		var screen_rect := Rect2(Vector2.ZERO, Vector2(sz))
		for c: Control in [home.card_2p, home.card_4p, home.nav_bar]:
			var r := Rect2(c.global_position, c.size)
			assert_true(screen_rect.encloses(r), "%s: %s visible (%s)" % [sz, c.get_class(), r])
		for b: Button in home.nav_bar.buttons.values():
			assert_true(b.size.y >= UiTokens.TOUCH_MIN, "%s: nav button touch height %s" % [sz, b.size.y])
		assert_true(home.card_2p.size.y >= 300, "%s: play card height" % sz)
		vp.queue_free()
		await _frames(1)


func test_two_player_colours_are_always_opposite() -> void:
	var vp := _viewport(Vector2i(720, 1560))
	var holder := Control.new()
	holder.theme = UiTheme.theme()
	holder.size = Vector2(720, 1560)
	vp.add_child(holder)
	var setup := PracticeSetupScreen.new()
	setup.params = {"players": 2, "mode": "bots"}
	setup.size = Vector2(720, 1560)
	holder.add_child(setup)
	await _frames(2)
	var expected := {"red": ["red", "yellow"], "yellow": ["red", "yellow"], "green": ["green", "blue"], "blue": ["green", "blue"]}
	for mine: String in expected:
		setup._set_color(mine)
		var cfg := setup._build_config()
		var colors: Array = cfg["seats"].map(func(s: Dictionary) -> String: return s["color"])
		assert_eq(colors, expected[mine], "2p colours for %s (clockwise order)" % mine)
		for s: Dictionary in cfg["seats"]:
			assert_eq(s["role"] == "you", s["color"] == mine, "%s: the chosen colour is mine" % mine)
		# the engine accepts the seats
		var state := GameState.create({"seats": cfg["seats"]})
		assert_false(state.is_empty(), "engine accepts %s" % [colors])
	setup._set_players(4)
	assert_eq(setup._build_config()["seats"].size(), 4, "4 players use every colour")
	var local := PracticeSetupScreen.new()
	local.params = {"players": 4, "mode": "local"}
	holder.add_child(local)
	await _frames(2)
	var roles: Array = local._build_config()["seats"].map(func(s: Dictionary) -> String: return s["role"])
	assert_eq(roles.count("you"), 1, "one local 'you' seat")
	assert_eq(roles.count("player"), 3, "pass and play: the other seats are players")
	vp.queue_free()
	await _frames(1)


func test_profile_name_and_practice_stats() -> void:
	assert_true(Settings.valid_name("Ayşe"), "4 letters is valid")
	assert_false(Settings.valid_name("  A "), "too short")
	assert_false(Settings.valid_name("x".repeat(17)), "too long")
	assert_eq(Settings.display_name(), tr("DEFAULT_NAME"), "default name")
	var vp := _viewport(Vector2i(720, 1560))
	var main := _main(vp)
	await _frames(2)
	main.call("go", "profile")
	await _frames(2)
	var profile: ProfileScreen = main.get("current")
	profile.name_edit.text = "Al"
	profile._save_name()
	assert_eq(String(Settings.get_value("profile_name")), "", "an invalid name is not saved")
	profile.name_edit.text = "  Mehmet  "
	profile._save_name()
	assert_eq(Settings.display_name(), "Mehmet", "a valid name is saved trimmed")
	# a finished practice match counts for the local seat only
	var seats := [{"color": "green", "role": "bot"}, {"color": "blue", "role": "you"}]
	main.call("_record", {"seats": seats}, {"ranks": [1, 0]})
	main.call("_record", {"seats": seats}, {"ranks": [0, 1]})
	assert_eq(int(Settings.get_value("stats_matches_2p")), 2, "two 2-player matches")
	assert_eq(int(Settings.get_value("stats_wins_2p")), 1, "one win")
	main.call("go", "home")
	await _frames(2)
	assert_true(main.get("current") is HomeScreen, "home shows after the profile")
	vp.queue_free()
	await _frames(1)
