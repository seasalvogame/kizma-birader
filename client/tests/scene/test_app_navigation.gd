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
			assert_eq(b.focus_mode, Control.FOCUS_ALL, "%s: nav button accepts keyboard/gamepad focus" % sz)
		var nav_buttons: Array[Button] = []
		for tab: Array in NavBar.TABS:
			nav_buttons.append(home.nav_bar.buttons[tab[0]] as Button)
		for index: int in nav_buttons.size():
			var button: Button = nav_buttons[index]
			var left: Button = nav_buttons[(index - 1 + nav_buttons.size()) % nav_buttons.size()]
			var right: Button = nav_buttons[(index + 1) % nav_buttons.size()]
			assert_eq(button.focus_neighbor_left, button.get_path_to(left), "%s: nav left focus wraps" % sz)
			assert_eq(button.focus_neighbor_right, button.get_path_to(right), "%s: nav right focus wraps" % sz)
		assert_eq(vp.gui_get_focus_owner(), home.nav_bar.buttons["home"], "%s: current tab receives initial focus" % sz)
		var right_key := InputEventKey.new()
		right_key.keycode = KEY_RIGHT
		right_key.pressed = true
		vp.push_input(right_key)
		await _frames(1)
		assert_eq(vp.gui_get_focus_owner(), home.nav_bar.buttons["friends"], "%s: right input reaches the next tab" % sz)
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
	# same rule as the database function update_my_profile (tested in supabase/tests/phase4_test.sql)
	for ok: String in ["Ayşe", "Ali Can", "çağrı_42", "Jo.ke-1"]:
		assert_true(OnlineProfile.valid_name(ok), "valid name: " + ok)
	for bad: String in ["Al", "x".repeat(17), "a  b", "-abc", "abc.", "a<b"]:
		assert_false(OnlineProfile.valid_name(bad), "invalid name: " + bad)
	assert_eq(Settings.display_name(), tr("DEFAULT_NAME"), "default name")
	var vp := _viewport(Vector2i(720, 1560))
	var main := _main(vp)
	await _frames(2)
	# offline (tests never reach the servers): clear state, no editing, no fake data
	main.call("go", "profile")
	await _frames(4)
	var profile: ProfileScreen = main.get("current")
	assert_true(profile.status.visible, "offline state is shown")
	assert_false(profile.name_edit.editable, "the name can only be changed online")
	# a finished practice match counts for the local seat only, never for online stats
	var seats := [{"color": "green", "role": "bot"}, {"color": "blue", "role": "you"}]
	main.call("_record", {"seats": seats}, {"ranks": [1, 0]})
	main.call("_record", {"seats": seats}, {"ranks": [0, 1]})
	main.call("_record", {"seats": seats, "online": true}, {"ranks": [1, 0]})
	assert_eq(int(Settings.get_value("stats_matches_2p")), 2, "two 2-player practice matches")
	assert_eq(int(Settings.get_value("stats_wins_2p")), 1, "one win")
	main.call("go", "home")
	await _frames(2)
	assert_true(main.get("current") is HomeScreen, "home shows after the profile")
	vp.queue_free()
	await _frames(1)


## Server data (as returned by Supabase) is shown in the profile, history row and detail screen.
func test_online_profile_history_and_detail_render() -> void:
	var me := "11111111-1111-4111-8111-111111111111"
	var saved_uid := Online.session.user_id
	var saved := [Online.profile.profile, Online.profile.stats, Online.profile.recent, Online.profile.loaded_at]
	Online.session.user_id = me
	var m := {"id": "aaaaaaaa-0000-4000-8000-000000000001", "mode": "quick", "players": 2, "status": "finished",
		"started_at": "2026-11-17T10:00:00+00:00", "ended_at": "2026-11-17T10:12:30+00:00", "end_reason": "finished",
		"server_version": "abcdef1234", "action_count": 140,
		"match_players": [
			{"seat": 0, "color": "red", "rank": 2, "user_id": me, "is_bot": false, "display_name": "Ayşe", "tag": 1234, "left_match": false},
			{"seat": 1, "color": "yellow", "rank": 1, "user_id": "22222222-2222-4222-8222-222222222222", "is_bot": false, "display_name": "Mert", "tag": 77, "left_match": false}]}
	Online.profile.profile = {"user_id": me, "display_name": "Ayşe", "tag": 1234, "avatar_id": "fill:3", "level": 1}
	Online.profile.stats = {"matches_2p": 3, "wins_2p": 2, "matches_4p": 1, "wins_4p": 0}
	Online.profile.recent = [m]
	Online.profile.loaded_at = 1
	Online.profile._mirror_to_settings()   # what a successful refresh does
	var t := Online.profile.totals()
	assert_eq(t["matches"], 4, "total matches")
	assert_eq(t["losses"], 2, "losses = matches - wins")
	assert_eq(t["rate"], 50, "win rate")
	assert_eq(MatchRow.result_text(m, 2), tr("HISTORY_PLACE") % 2, "second place text")
	assert_eq(MatchRow.opponents(m, me), "Mert#77", "opponent with tag")
	assert_eq(MatchRow.duration(m), tr("HISTORY_DURATION") % [12, 30], "duration")
	var vp := _viewport(Vector2i(720, 1560))
	var main := _main(vp)
	await _frames(2)
	main.call("go", "profile")
	await _frames(4)
	var profile: ProfileScreen = main.get("current")
	assert_true(profile.name_edit.text == "Ayşe", "server name in the editor")
	assert_eq(int(Settings.get_value("profile_avatar")), 3, "server avatar mirrored for offline play")
	assert_true(profile.status.visible, "offline: the last known data is marked")
	var rows := profile.find_children("*", "MatchRow", true, false)
	assert_eq(rows.size(), 1, "one recent match row")
	main.call("go", "match_detail", {"match": m})
	await _frames(3)
	assert_true(main.get("current") is MatchDetailScreen, "match details open")
	main.call("go", "history")
	await _frames(4)
	var history: MatchHistoryScreen = main.get("current")
	assert_true(history.status.visible, "offline history shows an error state, not fake rows")
	main.call("go", "account")
	await _frames(4)
	assert_true(main.get("current") is AccountScreen, "account screen opens")
	vp.queue_free()
	await _frames(1)
	Online.profile.profile = saved[0]; Online.profile.stats = saved[1]; Online.profile.recent = saved[2]; Online.profile.loaded_at = saved[3]
	Online.session.user_id = saved_uid


## The account survives an app restart: a new session object reads the same account back.
func test_session_survives_restart_and_auth_errors_map() -> void:
	var path := "user://test_session_%d.cfg" % Time.get_ticks_usec()
	var a := OnlineSession.new()
	a.path = path
	a.refresh_token = "rt-test"
	a.user_id = "33333333-3333-4333-8333-333333333333"
	a._apply_user({"id": a.user_id, "is_anonymous": false, "email": "x@example.com", "email_confirmed_at": "2026-11-17T10:00:00Z", "new_email": null})
	var b := OnlineSession.new()
	b.path = path
	b._load()
	assert_eq(b.user_id, a.user_id, "same user after restart")
	assert_eq(b.refresh_token, "rt-test", "refresh token kept")
	assert_false(b.is_anonymous, "permanent account kept")
	assert_eq(b.email, "x@example.com", "confirmed e-mail kept")
	assert_true(b.has_account(), "has an account")
	assert_false(b.has_valid_token(), "the access token is never stored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	a.free()
	b.free()
	assert_eq(OnlineSession.auth_error(422, {"error_code": "email_exists"}), "EMAIL_TAKEN", "email taken")
	assert_eq(OnlineSession.auth_error(400, {"error_code": "invalid_credentials"}), "BAD_LOGIN", "bad login")
	assert_eq(OnlineSession.auth_error(429, {}), "RATE_LIMITED", "rate limit")
	assert_eq(OnlineSession.auth_error(422, {"error_code": "weak_password"}), "WEAK_PASSWORD", "weak password")
	assert_eq(OnlineSession.auth_error(400, {"error_code": "email_address_not_authorized"}), "EMAIL_NOT_ALLOWED", "smtp restriction")


## Phase 5 screens open offline without the network, show honest states and no fake data.
func test_social_and_room_screens_open_offline() -> void:
	assert_true(OnlineRoom.valid_code("AB2C3D"), "valid room code")
	for bad: String in ["AB2C3", "ABOC3D", "AB1C3D", "ab2c3d"]:
		assert_false(OnlineRoom.valid_code(bad), "invalid room code: " + bad)
	assert_eq(OnlineRoom.normalize(" ab2-c3d "), "AB2C3D", "codes are normalised (case, spaces, dashes)")
	var vp := _viewport(Vector2i(720, 1560))
	var main := _main(vp)
	await _frames(2)
	var routes := [
		["friends", {}, "FriendsScreen"], ["search", {}, "PlayerSearchScreen"], ["requests", {}, "FriendRequestsScreen"],
		["player", {"user_id": "11111111-1111-4111-8111-111111111111"}, "PlayerProfileScreen"],
		["invites", {}, "InvitesScreen"], ["private", {}, "PrivateRoomScreen"], ["room", {}, "RoomLobbyScreen"],
	]
	for r: Array in routes:
		main.call("go", r[0], r[1])
		await _frames(4)
		var cur: Node = main.get("current")
		assert_eq(cur.get_script().get_global_name(), r[2], "route %s" % r[0])
		var st: StatusCard = cur.get("status")
		if r[0] != "search" and r[0] != "private":   # these show a state only after an action
			assert_true(st != null and st.visible, "%s shows a loading / offline / empty state" % r[0])
	var friends_rows := (main.get("current") as Node).find_children("*", "PersonRow", true, false)
	assert_eq(friends_rows.size(), 0, "no rows without server data")
	main.call("go", "home")
	await _frames(3)
	var home: HomeScreen = main.get("current")
	assert_true(home._invites != null, "home has the invites card")
	vp.queue_free()
	await _frames(1)


## The result screen finds the player's place also when the ranking came from the
## server as JSON (floats): online matches showed "0." before this was fixed.
func test_result_place_with_server_json_ranks() -> void:
	var from_server: Array = JSON.parse_string("[2, 0, 3, 1]")
	assert_eq(MatchScreen.place_of(from_server, 2), 1, "seat 2 first")
	assert_eq(MatchScreen.place_of(from_server, 1), 4, "seat 1 last")
	assert_eq(MatchScreen.place_of([0, 1], 1), 2, "int ranks still work")
	assert_eq(MatchScreen.place_of([], 0), 0, "not ranked")



## Phase 7 screens open offline (no catalog yet: honest loading / offline state, no fake items).
func test_cosmetics_screens_open_offline() -> void:
	assert_eq(Cosmetics.board_palette("board_unknown"), Cosmetics.BOARDS["board_classic"], "unknown board -> classic palette")
	assert_true(Cosmetics.dice_face("dice_star", 6) != null and Cosmetics.dice_face("dice_nope", 3) != null, "dice faces load (fallback to classic)")
	assert_true(Cosmetics.pawn_texture("pawns_gem", "blue") != null, "pawn skin loads")
	var vp := _viewport(Vector2i(720, 1560))
	var main := _main(vp)
	await _frames(2)
	main.call("go", "collection", {})
	await _frames(4)
	var col: Node = main.get("current")
	assert_eq(col.get_script().get_global_name(), "CollectionScreen", "collection opens")
	assert_true((col.get("status") as StatusCard).visible, "collection shows a loading / offline state")
	main.call("go", "cosmetic", {"id": "dice_star"})
	await _frames(3)
	assert_eq((main.get("current") as Node).get_script().get_global_name(), "CosmeticDetailScreen", "item details open")
	assert_eq(CosmeticDetailScreen._error_text("INSUFFICIENT_FUNDS"), tr("COS_ERR_FUNDS"), "store insufficient-funds error is actionable")
	assert_eq(CosmeticDetailScreen._error_text("NOT_OWNED"), tr("COS_ERR_NOT_OWNED"), "equip ownership error is actionable")
	main.call("go", "store")
	await _frames(3)
	assert_eq((main.get("current") as Node).get_script().get_global_name(), "StoreScreen", "store opens")
	assert_true((main.get("current").get("status") as StatusCard).visible, "store shows a loading / offline state")
	# Own cached data is only a fallback. An online snapshot supplies every
	# player's server-verified visual loadout and never changes rules or colours.
	var old_inventory := Online.cosmetics.inventory
	Online.cosmetics.inventory = {"loadout": {"dice": "dice_star", "pawns": "pawns_gem", "board": "board_mint", "frame": "frame_gold", "effect": "effect_sparkle", "name": "name_gold"}}
	var seats := [{"color": "red", "role": "you", "kind": "human", "name": "A"}, {"color": "yellow", "role": "remote", "kind": "human", "name": "B", "cosmetics": {"dice": "dice_aurora", "pawns": "pawns_crown", "board": "board_sunset", "frame": "frame_royal", "effect": "effect_aurora", "name": "name_gold", "emotes": "emotes_star"}}]
	main.call("show_match", {"players": 2, "seats": seats, "dice": DiceSource.seeded(5)})
	await _frames(3)
	var match_screen: MatchScreen = main.get("current")
	assert_eq(match_screen.dice.skin, "dice_star", "own dice skin is applied")
	assert_eq(match_screen.board_view.theme_id, "board_mint", "own board theme is applied")
	assert_eq((match_screen.pawns["red:0"] as PawnSprite).skin, "pawns_gem", "own pawn skin is applied")
	assert_eq((match_screen.pawns["yellow:0"] as PawnSprite).skin, "pawns_crown", "remote pawn skin comes from the server snapshot")
	assert_eq((match_screen.card_dice[1] as DiceView).skin, "dice_aurora", "remote dice skin comes from the server snapshot")
	match_screen.controller.stop()
	Online.cosmetics.inventory = old_inventory
	vp.queue_free()
	await _frames(1)
