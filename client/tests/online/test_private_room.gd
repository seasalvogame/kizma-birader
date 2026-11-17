extends TestCase
## Phase 5 online end-to-end test of the REAL client code (needs a game server):
## two guest players in one process. With a database (-- --expect-db) they become
## friends through Supabase (OnlineSocial), see each other online through the
## social hub (OnlineHub), A invites B to a private room and B accepts; without a
## database B joins with the room code. Then: colour choice (opposite pair), ready,
## the host starts, both get the same match on the normal MatchRoom, B leaves the
## match, A wins, the result is recorded (with a database) and the room is a lobby
## again. Started by server/worker/test/godot_online_test.mjs (deletes the users).

const TIMEOUT_MS := 120000


class P:
	extends RefCounted
	var name := ""
	var session: OnlineSession
	var api: OnlineApi
	var hub: OnlineHub
	var social: OnlineSocial
	var room: OnlineRoom
	var started := {}
	var conn: OnlineMatchConnection
	var over := false
	var recorded := ""
	var progress := {}


func _make(n: String) -> P:
	var p := P.new()
	p.name = n
	p.session = OnlineSession.new()
	# reusable test accounts: the runner passes a folder with their session files
	var seeded := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--test-session-dir="):
			seeded = arg.trim_prefix("--test-session-dir=").path_join("room_%s.cfg" % n)
	if seeded != "":
		p.session.path = seeded
	else:
		p.session.path = "user://test_room_%s.cfg" % n
		if not p.session.path.contains("kb-godot-sessions"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p.session.path))
	tree.root.add_child(p.session)
	p.api = OnlineApi.new()
	p.api.session = p.session
	tree.root.add_child(p.api)
	p.hub = OnlineHub.new()
	p.hub.session = p.session
	tree.root.add_child(p.hub)
	p.social = OnlineSocial.new()
	p.social.api = p.api
	p.social.hub = p.hub
	tree.root.add_child(p.social)
	p.room = OnlineRoom.new()
	tree.root.add_child(p.room)
	return p


func _until(cond: Callable, label: String, ms: int = 20000) -> bool:
	var end := Time.get_ticks_msec() + ms
	while not cond.call() and Time.get_ticks_msec() < end:
		await tree.process_frame
	if not cond.call():
		fail("timeout: " + label)
		return false
	return true


func test_friends_invite_private_room_match() -> void:
	var db := OS.get_cmdline_user_args().has("--expect-db")
	var a := _make("a")
	var b := _make("b")
	for p: P in [a, b]:
		assert_true((await p.session.ensure()) != "", "%s: guest account" % p.name)
	print("ONLINE_USERS ", a.session.user_id, ",", b.session.user_id)
	for p: P in [a, b]:
		p.hub.start()
	if not await _until(func() -> bool: return a.hub.connected and b.hub.connected, "hub connections"):
		return

	var code := ""
	var created := await OnlineRoom.create(a.api, 2)
	assert_true(created["ok"], "A creates a 2-player private room")
	code = created["code"]
	a.room.enter(a.session, code)
	if not await _until(func() -> bool: return a.room.state.get("members", []).size() == 1, "A in the lobby"):
		return

	if db:
		# friends through Supabase, live hints and presence through the hub
		var req := await a.social.send_request(b.session.user_id)
		assert_true(req["ok"], "A sends a friend request")
		await _until(func() -> bool: return b.social.incoming.size() == 1, "B is told about the request and reloads")
		var acc := await b.social.respond(int(b.social.incoming[0]["id"]), a.session.user_id, true)
		assert_true(acc["ok"] and b.social.is_friend(a.session.user_id), "B accepts: friends")
		await _until(func() -> bool: return a.hub.status_of(b.session.user_id) != "offline", "A sees B online")
		assert_eq(a.hub.status_of(b.session.user_id), "online", "A sees friend B online")
		assert_eq(b.hub.status_of(a.session.user_id), "room", "B sees that A is in a room")
		var inv := await a.hub.send_invite(b.session.user_id, code)
		assert_true(inv["ok"], "A invites B")
		await _until(func() -> bool: return b.hub.open_invites().size() == 1, "B receives the invite live")
		var ans := await b.hub.answer_invite(String(b.hub.invites[0]["id"]) if b.hub.invites.size() > 0 else "", true)
		assert_true(ans["ok"] and String(ans["data"]["code"]) == code, "B accepts and gets the room code")
		b.room.enter(b.session, String(ans["data"]["code"]))
	else:
		b.room.enter(b.session, code)
	if not await _until(func() -> bool: return a.room.state.get("members", []).size() == 2, "B in the room"):
		return
	b.room.set_color("green")
	await _until(func() -> bool: return String(a.room.me().get("color", "")) == "blue" and String(b.room.me().get("color", "")) == "green", "A moved to the opposite colour")
	assert_eq(String(b.room.me().get("color", "")), "green", "B picked green")
	a.room.start_match()
	var refused := {"code": ""}
	a.room.action_refused.connect(func(c: String) -> void: refused["code"] = c, CONNECT_ONE_SHOT)
	await _until(func() -> bool: return refused["code"] != "", "start refused while B is not ready")
	assert_eq(refused["code"], "NOT_READY", "host cannot start before B is ready")
	b.room.set_ready(true)
	await _until(func() -> bool: return bool(b.room.me().get("ready", false)), "B ready")
	for p: P in [a, b]:
		p.room.started.connect(func(info: Dictionary) -> void: p.started = info)
	a.room.start_match()
	if not await _until(func() -> bool: return not a.started.is_empty() and not b.started.is_empty(), "both told that the match started"):
		return
	assert_eq(a.started["matchId"], b.started["matchId"], "same match for both")
	for p: P in [a, b]:
		p.conn = OnlineMatchConnection.new()
		tree.root.add_child(p.conn)
		p.conn.recorded.connect(func(id: String) -> void: p.recorded = id)
		p.conn.progress_received.connect(func(pr: Dictionary) -> void: p.progress = pr)
		p.conn.events_received.connect(func(ev: Dictionary) -> void:
			if (ev.get("state", {}) as Dictionary).get("turn", {}).get("phase", "") == "game_over":
				p.over = true)
		p.conn.open(p.session, String(p.started["matchId"]))
	await _until(func() -> bool: return a.conn.connected and b.conn.connected, "both connected to the match")
	b.conn.ws.send("action.leave", {})
	if not await _until(func() -> bool: return a.over, "match over after B left"):
		return
	await _until(func() -> bool: return int(a.room.state.get("games", 0)) == 1 and a.room.state.get("phase", "") == "lobby", "room is a lobby again")
	assert_eq(a.room.state.get("phase", ""), "lobby", "after the match the room is a lobby again")
	if db:
		await _until(func() -> bool: return a.recorded != "", "match recorded", 60000)
		print("ONLINE_RECORDED ", a.recorded)
		var prof := OnlineProfile.new()
		prof.api = a.api
		prof.session = a.session
		prof.cache_path = "user://test_run/profile_room_a.json"
		tree.root.add_child(prof)
		assert_true(await prof.refresh(5), "A's profile loads")
		assert_true(prof.recent.size() >= 1 and String(prof.recent[0]["mode"]) == "private", "the private match is in A's history")
		assert_eq(int(prof.stats.get("wins_2p", 0)), 1, "A's win counted")
		await _until(func() -> bool: return not a.progress.is_empty() and not b.progress.is_empty(), "XP results", 20000)
		# B left right after the start: a match cut that short gives nobody XP (anti-farming guard);
		# the private-room XP rate itself (half) is checked in supabase/tests/phase6_test.sql §2.6
		assert_eq(int(a.progress.get("xp", -1)), 0, "a match cut short by a leave gives no XP")
		assert_false(bool(a.progress.get("counted", true)), "the server reports that the match did not count for rewards")
		assert_eq(int(b.progress.get("xp", -1)), 0, "B left the match: no XP")
		prof.queue_free()
	for p: P in [a, b]:
		p.room.leave()
		p.hub.stop()
		p.conn.close()
	await _frames(2)
	for p: P in [a, b]:
		for n: Node in [p.conn, p.room, p.social, p.hub, p.api, p.session]:
			n.queue_free()
		if not p.session.path.contains("kb-godot-sessions"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p.session.path))
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame
