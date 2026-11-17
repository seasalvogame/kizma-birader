extends TestCase
## Online end-to-end test of the REAL client code (needs a game server):
##   godot_console --headless --path client res://tests/test_runner.tscn -- --online --game-url=<url>
## Usually started by server/worker/test/godot_online_test.mjs, which also
## deletes the two guest accounts afterwards (their ids are printed).
##
## Two guest sessions in one process queue for a 2-player match, get paired by
## the server, and play it to the end through OnlineMatchController - the same
## controller the match screen uses. Player A plays through the real
## MatchScreen (taps on the dice and pawns, animations included); player B
## uses the bare controller. The client never draws dice: its dice source is
## empty and would raise an engine error (failing the test) if used.

const TIMEOUT_S := 600.0


class Player:
	extends RefCounted
	var name := ""
	var session: OnlineSession
	var mm: OnlineMatchmaking
	var conn: OnlineMatchConnection
	var ctl: OnlineMatchController
	var screen: MatchScreen
	var found := {}
	var snap := {}
	var finished := {}
	var applied := 0
	var resynced := 0
	var drops := 0
	var reconnects := 0
	var recorded := ""
	var progress := {}


func _player(n: String) -> Player:
	var p := Player.new()
	p.name = n
	p.session = OnlineSession.new()
	# reusable test accounts: the runner passes a folder with their session files
	var seeded := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--test-session-dir="):
			seeded = arg.trim_prefix("--test-session-dir=").path_join("online_%s.cfg" % n)
	if seeded != "":
		p.session.path = seeded
	else:
		p.session.path = "user://test_online_%s.cfg" % n
		if not p.session.path.contains("kb-godot-sessions"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p.session.path))
	tree.root.add_child(p.session)
	return p


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func test_two_clients_queue_match_and_play_to_the_end() -> void:
	var a := _player("a")
	var b := _player("b")
	var started := Time.get_ticks_msec()
	var out_of_time := func() -> bool: return (Time.get_ticks_msec() - started) / 1000.0 > TIMEOUT_S

	# 1. queue: both players join, the server pairs them
	for p: Player in [a, b]:
		p.mm = OnlineMatchmaking.new()
		tree.root.add_child(p.mm)
		p.mm.found.connect(func(info: Dictionary) -> void: p.found = info)
		p.mm.failed.connect(func(code: String) -> void: fail("%s matchmaking failed: %s" % [p.name, code]))
		p.mm.start(p.session, "Test" + p.name.to_upper())
	while (a.found.is_empty() or b.found.is_empty()) and not out_of_time.call() and _failures.is_empty():
		await tree.process_frame
	if not _failures.is_empty():
		return
	print("ONLINE_USERS ", a.session.user_id, ",", b.session.user_id)
	assert_eq(a.found["matchId"], b.found["matchId"], "both players are in the same match")
	assert_true(int(a.found["seat"]) != int(b.found["seat"]), "different seats")
	var pair := [String(a.found["color"]), String(b.found["color"])]
	pair.sort()
	assert_true(pair == ["red", "yellow"] or pair == ["blue", "green"], "server assigned opposite colours %s" % [pair])

	# 2. connect to the match and start the real online controller of each player
	for p: Player in [a, b]:
		p.conn = OnlineMatchConnection.new()
		tree.root.add_child(p.conn)
		p.conn.recorded.connect(func(id: String) -> void: p.recorded = id)
		p.conn.progress_received.connect(func(pr: Dictionary) -> void: p.progress = pr)
		p.conn.snapshot_received.connect(func(s: Dictionary) -> void:
			if p.snap.is_empty():
				p.snap = s, CONNECT_ONE_SHOT)
		p.conn.open(p.session, String(p.found["matchId"]))
	while (a.snap.is_empty() or b.snap.is_empty()) and not out_of_time.call():
		await tree.process_frame
	assert_false(a.snap.is_empty() or b.snap.is_empty(), "both received the match snapshot")
	Engine.time_scale = 6.0   # faster animations; network pacing below ignores the time scale
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1560)
	tree.root.add_child(vp)
	var holder := Control.new()
	holder.theme = UiTheme.theme()
	holder.size = Vector2(720, 1560)
	vp.add_child(holder)
	# the match screen also uses the app-wide Online services (quests, profile): they must use
	# player A's (test) account, never create an account of their own
	Online.session.path = a.session.path
	Online.session._load()
	a.screen = MatchScreen.new()
	a.screen.config = OnlineQueueScreen.match_config(a.snap, a.conn)
	a.screen.size = Vector2(720, 1560)
	holder.add_child(a.screen)
	a.ctl = a.screen.controller as OnlineMatchController
	assert_true(a.ctl != null and a.ctl.session != null, "A: the match screen started the online controller")
	a.screen.match_over.connect(func(state: Dictionary) -> void: a.finished = state)
	a.ctl.applied.connect(func(_e: Array, _s: Dictionary) -> void: a.applied += 1)
	b.ctl = OnlineMatchController.new()
	tree.root.add_child(b.ctl)
	assert_true(b.ctl.start(OnlineQueueScreen.match_config(b.snap, b.conn)), "B controller started")
	b.ctl.applied.connect(func(_events: Array, _state: Dictionary) -> void:
		b.applied += 1
		await tree.process_frame
		b.ctl.view_done())
	b.ctl.finished.connect(func(state: Dictionary) -> void: b.finished = state)
	for p: Player in [a, b]:
		p.ctl.resynced.connect(func(_s: Dictionary) -> void: p.resynced += 1)
		p.ctl.connection_changed.connect(func(c: bool) -> void:
			if c:
				p.reconnects += 1
			else:
				p.drops += 1)
	assert_true(a.ctl.is_human_turn() != b.ctl.is_human_turn(), "exactly one player may act")

	# 3. play: A taps its match screen, B calls its controller
	var actions := 0
	var dropped := false
	while (a.finished.is_empty() or b.finished.is_empty()) and not out_of_time.call():
		if a.ctl.session != null and a.ctl.is_human_turn() and not a.ctl._busy and not a.ctl._waiting:
			var sa := a.ctl.state()
			if sa["turn"]["phase"] == "roll":
				a.screen._on_dice_tapped()
			else:
				var color: String = a.screen.config["seats"][a.ctl.local_seat]["color"]
				a.screen._on_pawn_tapped(color, int((sa["legal"] as Array)[0]["pawn"]))
			actions += 1
		if b.ctl.session != null and b.ctl.is_human_turn():
			var s := b.ctl.state()
			var r: Dictionary
			if s["turn"]["phase"] == "roll":
				r = b.ctl.human_roll(b.ctl.local_seat)
			else:
				r = b.ctl.human_move(b.ctl.local_seat, int((s["legal"] as Array)[0]["pawn"]))
			if r.get("ok", false):
				actions += 1
		# simulate a network drop of player A in the middle of the match
		if not dropped and actions >= 40:
			dropped = true
			a.conn.ws._ws.close()
		await _frames(2)
		await tree.create_timer(0.12, true, false, true).timeout   # human pace in real time (server limit: 10 / s)

	assert_false(a.finished.is_empty() or b.finished.is_empty(), "both clients saw the end of the match (%d actions)" % actions)
	assert_eq(a.finished.get("ranks", []), b.finished.get("ranks", []), "both clients agree on the result")
	assert_eq(a.finished.get("version", -1), b.finished.get("version", -2), "both ended on the same server state version")
	assert_true(a.drops >= 1 and a.reconnects >= 1, "player A dropped and reconnected by itself (drops %d, reconnects %d)" % [a.drops, a.reconnects])
	assert_true(a.resynced >= 1, "after reconnecting A got the full state from the server")
	print("ONLINE_MATCH actions=%d applied_a=%d applied_b=%d" % [actions, a.applied, b.applied])
	if OS.get_cmdline_user_args().has("--expect-db"):
		await _check_records(a, b)
	Engine.time_scale = 1.0
	a.screen._leave(false)
	vp.queue_free()
	b.ctl.stop()
	for n: Node in [b.ctl, a.conn, b.conn, a.mm, b.mm, a.session, b.session]:
		n.queue_free()
	for p: Player in [a, b]:
		if not p.session.path.contains("kb-godot-sessions"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p.session.path))
	await _frames(2)


## Phase 4: the server stored the match (Supabase); stats, history and the
## session after an "app restart" are read back exactly like the app does.
func _check_records(a: Player, b: Player) -> void:
	var until := Time.get_ticks_msec() + 60000
	while (a.recorded == "" or b.recorded == "") and Time.get_ticks_msec() < until:
		await tree.process_frame
	print("ONLINE_RECORDED ", a.recorded)
	assert_true(a.recorded != "" and a.recorded == b.recorded, "both clients were told that the server recorded the match")
	var winner_seat := int((a.finished.get("ranks", [-1]) as Array)[0])
	for p: Player in [a, b]:
		var api := OnlineApi.new()
		api.session = p.session
		tree.root.add_child(api)
		var prof := OnlineProfile.new()
		prof.api = api
		prof.session = p.session
		prof.cache_path = "user://test_run/profile_%s.json" % p.name
		tree.root.add_child(prof)
		var ok := await prof.refresh(5)
		assert_true(ok, "%s: profile, stats and history loaded from Supabase" % p.name)
		var won := int(p.found["seat"]) == winner_seat
		await _until_progress(p)
		assert_eq(int(p.progress.get("xp", -1)), 40 if won else 15, "%s: server tells the XP of this match (2 players: 40 win / 15 loss)" % p.name)
		assert_eq(int(prof.progress.get("xp", -1)), 40 if won else 15, "%s: profile shows the new total XP" % p.name)
		assert_eq(int(prof.progress.get("level", 0)), 1, "%s: still level 1 (100 XP needed)" % p.name)
		var t := prof.totals()
		assert_eq(t["matches"], 1, "%s: exactly one online match counted" % p.name)
		assert_eq(t["wins"], 1 if won else 0, "%s: win counted only for the winner" % p.name)
		assert_eq(prof.recent.size(), 1, "%s: the match is in the history" % p.name)
		if prof.recent.size() == 1:
			var m: Dictionary = prof.recent[0]
			assert_eq(String(m["id"]), a.recorded, "%s: history row is the recorded match" % p.name)
			assert_eq((m["match_players"] as Array).size(), 2, "%s: both players in the record" % p.name)
			assert_eq(int(MatchRow.my_seat(m, p.session.user_id).get("rank", 0)), 1 if won else 2, "%s: own place stored" % p.name)
		var r := await prof.update("Faz4 %s" % p.name.to_upper(), "fill:%d" % (2 if won else 4))
		assert_true(r["ok"], "%s: name and avatar saved on the server" % p.name)
		api.queue_free()
		prof.queue_free()
	# "app restart": a new session object from the stored file is the same account
	var again := OnlineSession.new()
	again.path = a.session.path
	tree.root.add_child(again)
	var token := await again.ensure()
	assert_true(token != "" and again.user_id == a.session.user_id, "after a restart the same account signs in again (refresh token)")
	again.queue_free()


func _until_progress(p: Player) -> void:
	var end := Time.get_ticks_msec() + 20000
	while p.progress.is_empty() and Time.get_ticks_msec() < end:
		await tree.process_frame

