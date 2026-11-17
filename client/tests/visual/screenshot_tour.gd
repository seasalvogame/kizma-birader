extends Node
## Screenshot tour for visual review (development only, not shipped):
##   godot_console --path client --resolution 540x1170 res://tests/visual/screenshot_tour.tscn \
##       -- --shots=<absolute dir> --settings-path=user://tour/settings.cfg [--safe-insets=94,48] [--locale=en]

var shots := ""
var main: Node
var online := false   # -- --online: really talk to the servers (creates a guest account)


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg == "--online":
			online = true
		elif arg.begins_with("--locale="):
			Settings.set_value("locale", arg.trim_prefix("--locale="))
	if shots == "":
		push_error("--shots=<dir> required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(shots)
	OnlineConfig.force_offline = not online
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
	await _phase4_screens()
	await _phase5_screens()
	await _phase6_screens()
	main.call("go", "modes", {"players": 2})
	await _frames(12)
	await _shot("00i_modes_online")
	main.call("go", "queue", {})
	await _frames(12)
	await _shot("00j_queue")
	await _wait(6.0)
	await _shot("00k_queue_after")
	main.call("go", "home")
	await _frames(6)
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


## Phase 4 screens. Offline states are real; the "with data" shots use SAMPLE
## server rows injected here (screenshots only — the app never shows fake data).
func _phase4_screens() -> void:
	for step: Array in [["profile", {}, "40_profile_offline"], ["history", {}, "41_history_offline"], ["account", {}, "42_account_guest"]]:
		main.call("go", step[0], step[1])
		await _frames(14)
		await _shot(step[2])
	var me := "11111111-1111-4111-8111-111111111111"
	Online.session.user_id = me
	var rows: Array = []
	var opp := [["Mert", 77, "yellow", 1], ["Zeynep", 4120, "green", 2], ["Bot", 0, "blue", 1]]
	for i in 3:
		rows.append({"id": "aaaaaaaa-0000-4000-8000-00000000000%d" % i, "mode": "quick", "players": 2, "status": "finished",
			"started_at": "2026-11-17T1%d:00:00+00:00" % i, "ended_at": "2026-11-17T1%d:14:05+00:00" % i, "end_reason": "left" if i == 1 else "finished",
			"server_version": "60e35975abcd", "action_count": 180 + i * 7,
			"match_players": [
				{"seat": 0, "color": "red", "rank": 2 if opp[i][3] == 1 else 1, "user_id": me, "is_bot": false, "display_name": "Ayşe", "tag": 1234, "left_match": false},
				{"seat": 1, "color": opp[i][2], "rank": opp[i][3], "user_id": "22222222-2222-4222-8222-22222222222%d" % i, "is_bot": false,
					"display_name": opp[i][0], "tag": opp[i][1], "left_match": i == 1}]})
	Online.profile.profile = {"user_id": me, "display_name": "Ayşe", "tag": 1234, "avatar_id": "fill:3", "level": 1}
	Online.profile.stats = {"matches_2p": 12, "wins_2p": 7, "matches_4p": 0, "wins_4p": 0}
	Online.profile.recent = rows
	Online.profile.loaded_at = 1
	Online.profile._mirror_to_settings()
	main.call("go", "profile")
	await _frames(14)
	await _shot("43_profile_sample")
	var sc: ScrollContainer = (main.get("current") as Node).find_children("*", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = 900
	await _frames(6)
	await _shot("44_profile_sample_scrolled")
	main.call("go", "match_detail", {"match": rows[0]})
	await _frames(14)
	await _shot("45_match_detail_sample")
	Online.profile.reset()
	Online.session.user_id = ""
	Settings.set_value("profile_avatar", 0)


## Phase 5 screens. Offline states are real; the "sample" shots use SAMPLE rows
## injected here (screenshots only — the app never shows fake data).
func _phase5_screens() -> void:
	for step: Array in [["friends", {}, "50_friends_offline"], ["private", {}, "51_private_room"], ["invites", {}, "52_invites_offline"]]:
		main.call("go", step[0], step[1])
		await _frames(14)
		await _shot(step[2])
	var me := "11111111-1111-4111-8111-111111111111"
	Online.session.user_id = me
	var f := func(i: int, n: String, tag: int, av: int) -> Dictionary:
		return {"user_id": "2222222%d-2222-4222-8222-222222222222" % i, "display_name": n, "tag": tag, "avatar_id": "fill:%d" % av, "since": "2026-11-10T10:00:00+00:00"}
	Online.social.friends = [f.call(1, "Mert", 77, 1), f.call(2, "Zeynep", 4120, 2), f.call(3, "Can", 905, 4), f.call(4, "Elif", 3311, 5)]
	Online.social.incoming = [{"id": 1, "direction": "in", "user_id": "33333333-3333-4333-8333-333333333331", "display_name": "Deniz", "tag": 18, "avatar_id": "fill:0", "created_at": "2026-11-17T09:12:00+00:00"}]
	Online.social.outgoing = [{"id": 2, "direction": "out", "user_id": "33333333-3333-4333-8333-333333333332", "display_name": "Ali", "tag": 2001, "avatar_id": "fill:3", "created_at": "2026-11-17T08:40:00+00:00"}]
	Online.social.loaded = true
	Online.hub.statuses = {Online.social.friends[0]["user_id"]: "online", Online.social.friends[1]["user_id"]: "match", Online.social.friends[2]["user_id"]: "room"}
	Online.hub.connected = true
	var now := Time.get_unix_time_from_system() * 1000.0
	Online.hub.invites = [{"id": "inv-sample-1", "from": Online.social.friends[0]["user_id"], "fromName": "Mert", "fromTag": 77, "fromAvatar": "fill:1",
		"to": me, "code": "K7MPQ3", "players": 4, "created": now, "expires": now + 95000.0, "status": "pending"}]
	main.call("go", "friends")
	await _frames(14)
	await _shot("53_friends_sample")
	main.call("go", "requests")
	await _frames(4)
	Online.social.loaded = true
	(main.get("current") as Node).call("_render")
	(main.get("current") as Node).get("status").clear()
	await _frames(10)
	await _shot("54_requests_sample")
	main.call("go", "invites")
	await _frames(14)
	await _shot("55_invites_sample")
	var room := OnlineRoom.new()
	room.session = Online.session
	room.code = "K7MPQ3"
	room.connected = true
	room.state = {"code": "K7MPQ3", "players": 4, "host": me, "phase": "lobby", "games": 0, "members": [
		{"userId": me, "name": "Ayşe", "tag": 1234, "avatar": "fill:3", "color": "red", "ready": false, "connected": true, "host": true},
		{"userId": Online.social.friends[0]["user_id"], "name": "Mert", "tag": 77, "avatar": "fill:1", "color": "green", "ready": true, "connected": true, "host": false},
		{"userId": Online.social.friends[2]["user_id"], "name": "Can", "tag": 905, "avatar": "fill:4", "color": "blue", "ready": false, "connected": false, "host": false}]}
	Online.add_child(room)
	Online.room = room
	main.call("go", "room")
	await _frames(14)
	await _shot("56_room_lobby_sample")
	var sc: ScrollContainer = (main.get("current") as Node).find_children("*", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = 1100
	await _frames(6)
	await _shot("57_room_lobby_sample_scrolled")
	Online.room = null
	room.queue_free()
	Online.social.friends = []; Online.social.incoming = []; Online.social.outgoing = []; Online.social.loaded = false
	Online.hub.statuses = {}; Online.hub.invites = []; Online.hub.connected = false
	Online.session.user_id = ""


## Phase 6 screens with SAMPLE server rows (screenshots only).
func _phase6_screens() -> void:
	var me := "11111111-1111-4111-8111-111111111111"
	Online.session.user_id = me
	Online.profile.profile = {"user_id": me, "display_name": "Ayşe", "tag": 1234, "avatar_id": "fill:3", "level": 7}
	Online.profile.stats = {"matches_2p": 21, "wins_2p": 12, "matches_4p": 6, "wins_4p": 2}
	Online.profile.progress = {"level": 7, "xp": 1290, "xp_in_level": 140, "xp_for_next": 250, "max_level": 100, "next_level_gold": 130, "badges": ["level_5"]}
	Online.profile.loaded_at = 1
	main.call("go", "profile")
	await _frames(14)
	await _shot("60_profile_progress_sample")
	Celebration.pop(main.get("current"), tr("LEVEL_UP_TITLE") % 8, tr("LEVEL_UP_SUB"), [["bag", tr("REWARD_GOLD") % 130]])
	await _frames(40)
	await _shot("61_level_up_sample")
	if self.has_method("_phase6_more"):
		await call("_phase6_more")
	Online.profile.reset()
	Online.session.user_id = ""


func _phase6_more() -> void:
	var q := func(per: String, id: String, metric: String, target: int, progress: int, gold: int, xp: int, claimed: bool) -> Dictionary:
		return {"period": per, "period_key": "2026-11-18", "quest_id": id, "metric": metric, "target": target, "progress": progress,
			"gold": gold, "xp": xp, "completed": progress >= target, "claimed": claimed}
	Online.progress.quests = {
		"daily": [q.call("daily", "d_play_3", "matches", 3, 2, 120, 30, false), q.call("daily", "d_win_1", "wins", 1, 1, 120, 30, false),
			q.call("daily", "d_rolls_40", "rolls", 40, 40, 80, 20, true)],
		"weekly": [q.call("weekly", "w_play_10", "matches", 10, 4, 500, 100, false), q.call("weekly", "w_friend_3", "friend_matches", 3, 1, 400, 80, false),
			q.call("weekly", "w_login_3", "login_days", 3, 2, 300, 60, false), q.call("weekly", "w_4p_5", "matches_4p", 5, 0, 500, 100, false)],
		"unclaimed_old": [], "daily_resets_at": "2026-11-18T21:00:00+00:00", "weekly_resets_at": "2026-11-23T21:00:00+00:00"}
	Online.progress._count()
	main.call("go", "quests")
	await _frames(3)
	(main.get("current") as Node).get("status").clear()
	(main.get("current") as Node).call("_render")
	await _frames(12)
	await _shot("62_quests_sample")
	var sc: ScrollContainer = (main.get("current") as Node).find_children("*", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = 1200
	await _frames(6)
	await _shot("63_quests_sample_scrolled")
	Online.progress.quests = {}
	Online.progress._count()
	main.call("go", "home")
	await _frames(10)
	var status := {"can_claim": true, "next_day": 4, "streak": 3, "cycles": 0, "cycle": [{"day": 1, "xp": 30}, {"day": 2, "gold": 100},
		{"day": 3, "xp": 50}, {"day": 4, "gold": 200}, {"day": 5, "xp": 80}, {"day": 6, "gold": 300}, {"day": 7, "gold": 500, "xp": 100, "badge": "login_week"}]}
	var panel := DailyLoginPanel.open(main.get("current"), status)
	await _frames(14)
	await _shot("64_daily_login_sample")
	panel.queue_free()
	var ach := func(id: String, cat: String, target: int, progress: int, gold: int, xp: int, done: bool, claimed: bool, badge: String = "") -> Dictionary:
		var d := {"id": id, "category": cat, "target": target, "progress": progress, "gold": gold, "xp": xp, "completed": done, "claimed": claimed}
		if badge != "":
			d["badge"] = badge
		return d
	Online.progress.achievements = {"achievements": [ach.call("first_match", "match", 1, 1, 50, 20, true, true), ach.call("first_win", "match", 1, 1, 100, 30, true, false),
		ach.call("matches_10", "match", 10, 7, 150, 50, false, false), ach.call("matches_100", "match", 100, 7, 800, 200, false, false, "veteran"),
		ach.call("streak_3", "skill", 3, 2, 300, 80, false, false), ach.call("first_4p_win", "skill", 1, 0, 300, 80, false, false),
		ach.call("friends_10", "social", 10, 3, 300, 80, false, false, "social")]}
	main.call("go", "achievements")
	await _frames(3)
	(main.get("current") as Node).get("status").clear()
	(main.get("current") as Node).call("_render")
	await _frames(12)
	await _shot("65_achievements_sample")
	Online.progress.achievements = {}
	var lb: Node = main.get("current")
	main.call("go", "ranking")
	await _frames(3)
	lb = main.get("current")
	lb.set("_me", {"rank": 12, "points": 86, "wins": 7, "matches": 15, "players": 240, "ends_at": "2026-11-23T21:00:00+00:00", "previous_week": "2026-11-09",
		"last_reward": {"rank": 34, "gold": 500, "points": 61}})
	for c: Node in lb.get("_box").get_children():
		c.queue_free()
	lb.call("_render_me")
	var names := [["Mert", 77, 9, 142], ["Zeynep", 4120, 12, 128], ["Can", 905, 6, 117], ["Elif", 3311, 8, 104], ["Deniz", 18, 5, 99]]
	for i in names.size():
		lb.get("_list").add_child(lb.call("_row", {"rank": i + 1, "display_name": names[i][0], "tag": names[i][1], "avatar_id": "fill:%d" % (i + 1),
			"level": names[i][2], "wins": 10 - i, "points": names[i][3], "me": false, "badge_id": "weekly_top10" if i < 2 else null}))
	lb.get("status").clear()
	await _frames(12)
	await _shot("66_leaderboard_sample")

