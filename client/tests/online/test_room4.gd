extends TestCase
## One of FOUR separate Godot client processes in a 4-player private room on the real
## server (started by server/worker/test/godot_room4_test.mjs; skipped otherwise):
##   -- --online --game-url=<url> --room4-index=<0..3> --room4-dir=<shared dir> --room4-session=<session.cfg>
## Index 0 creates the room (host). The processes coordinate only through small files
## in the shared directory (room code, "done" markers). Each client uses the real
## OnlineSession / OnlineApi / OnlineRoom / OnlineMatchConnection / OnlineMatchController
## code and plays its own seat until the server ends the match.

const COLORS_WANTED := ["red", "blue", "green", "yellow"]   # host red, #1 switches to blue, #2/#3 get the free colours

var index := -1
var dir := ""
var session_path := ""


func _args() -> bool:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--room4-index="):
			index = int(a.trim_prefix("--room4-index="))
		elif a.begins_with("--room4-dir="):
			dir = a.trim_prefix("--room4-dir=")
		elif a.begins_with("--room4-session="):
			session_path = a.trim_prefix("--room4-session=")
	return index >= 0 and dir != "" and session_path != ""


func _mark(name: String, text: String = "1") -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(name: String) -> String:
	return FileAccess.get_file_as_string(dir.path_join(name)) if FileAccess.file_exists(dir.path_join(name)) else ""


func _until(cond: Callable, label: String, ms: int = 60000) -> bool:
	var end := Time.get_ticks_msec() + ms
	while not cond.call() and Time.get_ticks_msec() < end:
		await tree.process_frame
	if not cond.call():
		fail("client %d timeout: %s" % [index, label])
		return false
	return true


func test_four_clients_private_room_full_match() -> void:
	if not _args():
		print("room4: not configured (run by godot_room4_test.mjs), skipped")
		return
	var session := OnlineSession.new()
	session.path = session_path
	tree.root.add_child(session)
	assert_true((await session.ensure()) != "", "client %d: signed in with its test account (refresh token)" % index)
	var api := OnlineApi.new()
	api.session = session
	tree.root.add_child(api)
	var room := OnlineRoom.new()
	tree.root.add_child(room)
	var refused: Array[String] = []
	room.action_refused.connect(func(c: String) -> void: refused.append(c))
	var started := {}
	room.started.connect(func(info: Dictionary) -> void: started.merge(info, true))   # lambdas capture by value: mutate, never reassign
	room.failed.connect(func(c: String) -> void: fail("client %d could not enter: %s" % [index, c]))

	# --- lobby: create / join in a fixed order
	if index == 0:
		var c := await OnlineRoom.create(api, 4)
		assert_true(c["ok"], "host creates a 4-player room")
		_mark("code.txt", c["code"])
	else:
		var wait_for := "code.txt" if index == 1 else "joined_%d" % (index - 1)
		if not await _until(func() -> bool: return _read(wait_for) != "", "waiting for " + wait_for):
			return
	var code := _read("code.txt")
	room.enter(session, code)
	if not await _until(func() -> bool: return not room.me().is_empty(), "entered the room"):
		return
	if index == 1:
		room.set_color("blue")
		await _until(func() -> bool: return String(room.me().get("color", "")) == "blue", "switched to blue")
	_mark("joined_%d" % index)
	if not await _until(func() -> bool: return room.state.get("members", []).size() == 4, "four players in the room"):
		return
	assert_eq(String(room.me()["color"]), COLORS_WANTED[index], "client %d has colour %s" % [index, COLORS_WANTED[index]])
	var colors := (room.state["members"] as Array).map(func(m: Dictionary) -> String: return m["color"])
	colors.sort()
	assert_eq(colors, ["blue", "green", "red", "yellow"], "four different colours")

	# --- rules: taken colour, start only by the host, only when everyone is ready
	if index == 0:
		room.start_match()
		await _until(func() -> bool: return "NOT_READY" in refused, "start refused before everyone is ready")
		assert_true("NOT_READY" in refused, "host cannot start before the others are ready")
		_mark("host_checked")
	else:
		await _until(func() -> bool: return _read("host_checked") != "", "host check")
		if index == 3:
			room.set_color("red")
			await _until(func() -> bool: return "COLOR_TAKEN" in refused, "taken colour refused")
			assert_true("COLOR_TAKEN" in refused, "a colour taken by another player is refused")
		if index == 2:
			room.start_match()
			await _until(func() -> bool: return "NOT_HOST" in refused, "start by a non-host refused")
			assert_true("NOT_HOST" in refused, "a non-host cannot start the match")
		room.set_ready(true)
		await _until(func() -> bool: return bool(room.me().get("ready", false)), "ready")
	if index == 0:
		await _until(func() -> bool: return (room.state["members"] as Array).filter(func(m: Dictionary) -> bool: return m["ready"]).size() == 3, "three players ready")
		room.start_match()
	if not await _until(func() -> bool: return not started.is_empty(), "match started", 60000):
		return
	assert_eq(String(started["color"]), COLORS_WANTED[index], "the match uses the lobby colour")

	# --- the match on the normal MatchRoom, played by this client's own controller
	var conn := OnlineMatchConnection.new()
	tree.root.add_child(conn)
	var snap := {}
	var recorded := {"id": ""}
	conn.snapshot_received.connect(func(p: Dictionary) -> void: if snap.is_empty(): snap.merge(p))
	conn.recorded.connect(func(id: String) -> void: recorded["id"] = id)
	conn.open(session, String(started["matchId"]))
	if not await _until(func() -> bool: return not snap.is_empty(), "match snapshot"):
		return
	var ctl := OnlineMatchController.new()
	tree.root.add_child(ctl)
	assert_true(ctl.start(OnlineQueueScreen.match_config(snap, conn)), "controller started")
	var finished := {}
	ctl.finished.connect(func(st: Dictionary) -> void: finished.merge(st, true))
	ctl.applied.connect(func(_e: Array, _s: Dictionary) -> void:
		await tree.process_frame
		ctl.view_done())
	var actions := 0
	var end := Time.get_ticks_msec() + 20 * 60000
	while finished.is_empty() and Time.get_ticks_msec() < end:
		if ctl.is_human_turn():
			var s := ctl.state()
			var r: Dictionary
			if s["turn"]["phase"] == "roll":
				r = ctl.human_roll(ctl.local_seat)
			elif not (s["legal"] as Array).is_empty():
				r = ctl.human_move(ctl.local_seat, int((s["legal"] as Array)[0]["pawn"]))
			if r.get("ok", false):
				actions += 1
		await tree.create_timer(0.08, true, false, true).timeout
	assert_false(finished.is_empty(), "client %d saw the end of the match" % index)
	await _until(func() -> bool: return recorded["id"] != "", "server recorded the match", 90000)
	var ranks: Array = finished.get("ranks", [])
	var my_rank := MatchScreen.place_of(ranks, ctl.local_seat)   # what the result screen shows
	assert_true(my_rank >= 1 and my_rank <= 4, "client %d: own place found in the final ranking" % index)
	# --- what the player sees afterwards: history from Supabase
	var prof := OnlineProfile.new()
	prof.api = api
	prof.session = session
	prof.cache_path = dir.path_join("profile_%d.json" % index)
	tree.root.add_child(prof)
	assert_true(await prof.refresh(5), "client %d: profile and history load" % index)
	var row: Dictionary = prof.recent[0] if not prof.recent.is_empty() else {}
	assert_eq(String(row.get("id", "")), recorded["id"], "client %d: newest history row is this match" % index)
	assert_eq(int(MatchRow.my_seat(row, session.user_id).get("rank", 0)), my_rank, "client %d: history shows the same place as the match" % index)
	assert_eq((row.get("match_players", []) as Array).size(), 4, "client %d: four players in the record" % index)
	print("ROOM4_RESULT ", JSON.stringify({"index": index, "user": session.user_id, "match": started["matchId"], "recorded": recorded["id"],
		"ranks": ranks, "my_rank": my_rank, "version": finished.get("version", -1), "actions": actions, "color": started["color"]}))
	room.leave()
	conn.close()
	await tree.process_frame
	for n: Node in [prof, ctl, conn, room, api, session]:
		n.queue_free()
