class_name OnlineMatchController
extends MatchController
## Online match for the SAME match screen: same signals and methods as the
## offline MatchController, but the authority is the game server.
##  - never draws dice, never applies rules, never runs turn timers itself;
##  - human_roll / human_move only send requests; the result arrives as server
##    events with the full server state, which replaces the local copy;
##  - event batches are queued and released when the view finished animating;
##  - after a reconnect the server snapshot replaces everything (`resynced`).
## config.online: {connection: OnlineMatchConnection, seat: int, snapshot: Dictionary}

signal resynced(state: Dictionary)
signal connection_changed(connected: bool)
signal action_refused(code: String)
## The match cannot continue on this device (e.g. opened on another device).
signal fatal(code: String)
## The server stored the finished match in the database (match history, stats).
signal recorded(match_id: String)

var conn: OnlineMatchConnection
var local_seat := 0
var _pending: Array[Dictionary] = []
var _waiting := false           # a request is on its way; no second tap
var _finished_sent := false


func start(config: Dictionary, _dice: DiceSource = null) -> bool:
	var online: Dictionary = config.get("online", {})
	conn = online.get("connection", null)
	if conn == null:
		return false
	seats = config.get("seats", [])
	local_seat = int(online.get("seat", 0))
	var snap: Dictionary = online.get("snapshot", {})
	if not snap.has("state"):
		return false
	# MatchSession is only a holder of the server state here; it never draws dice.
	session = MatchSession.new(snap["state"], engine, DiceSource.scripted([]))
	_apply_deadline(float(snap.get("deadline", 0)))
	conn.events_received.connect(_on_events)
	conn.snapshot_received.connect(_on_snapshot)
	conn.connection_changed.connect(func(c: bool) -> void: connection_changed.emit(c))
	conn.action_refused.connect(_on_refused)
	conn.fatal.connect(func(code: String) -> void: fatal.emit(code))
	conn.recorded.connect(func(id: String) -> void: recorded.emit(id))
	_busy = false
	_schedule()
	return true


func is_remote(seat: int) -> bool:
	return seat != local_seat


## Only the local seat can act; on autopilot a tap takes control back (server side).
func is_human_turn(seat: int = -1) -> bool:
	if session == null or state()["turn"]["phase"] == "game_over":
		return false
	var current := int(state()["turn"]["seat"])
	if seat >= 0 and seat != current:
		return false
	return current == local_seat


func human_roll(seat: int) -> Dictionary:
	if _busy or _waiting or session == null or seat != local_seat:
		return {"ok": false, "error": "BUSY"}
	var id := conn.send_action("action.roll", {"turnId": int(state()["turn"]["turn_id"])})
	_waiting = id != ""
	return {"ok": id != "", "pending": true}


func human_move(seat: int, pawn: int) -> Dictionary:
	if _busy or _waiting or session == null or seat != local_seat:
		return {"ok": false, "error": "BUSY"}
	var id := conn.send_action("action.move", {"turnId": int(state()["turn"]["turn_id"]), "pawn": pawn})
	_waiting = id != ""
	return {"ok": id != "", "pending": true}


func leave(_seat: int) -> Dictionary:
	if conn != null:
		conn.send_action("action.leave", {})
	return {"ok": true}


func view_done() -> void:
	_busy = false
	_flush()


func stop() -> void:
	if conn != null:
		conn.close()
	session = null


## Online matches cannot be paused: the opponent keeps playing.
func pause() -> void:
	pass


func resume() -> void:
	pass


func is_paused() -> bool:
	return false


func _on_events(p: Dictionary) -> void:
	_waiting = false
	_pending.append(p)
	_flush()


func _flush() -> void:
	if session == null or _busy:
		return
	if _pending.is_empty():
		_schedule()
		return
	var p: Dictionary = _pending.pop_front()
	session.state = p["state"]
	_apply_deadline(float(p.get("deadline", 0)))
	_busy = true
	applied.emit(p.get("events", []), state())


func _on_snapshot(p: Dictionary) -> void:
	if session == null:
		return
	_pending.clear()
	_waiting = false
	session.state = p["state"]
	_apply_deadline(float(p.get("deadline", 0)))
	_busy = false
	resynced.emit(state())
	_schedule()


func _on_refused(code: String) -> void:
	_waiting = false
	action_refused.emit(code)
	if code in ["STALE_TURN", "NOT_YOUR_TURN", "WRONG_PHASE", "ILLEGAL_MOVE"]:
		conn.send_action("resync", {})


## No local timers: only the display of the server's deadline.
func _schedule() -> void:
	if session == null or _busy:
		return
	var s := state()
	if s["turn"]["phase"] == "game_over":
		if not _finished_sent:
			_finished_sent = true
			finished.emit(s)
		return
	var seat := int(s["turn"]["seat"])
	var automatic: bool = seats[seat].get("kind", "human") == "bot" or s["players"][seat]["autopilot"]
	_phase_seconds = 0.0 if automatic else float(s["ruleset"]["turn_roll_seconds" if s["turn"]["phase"] == "roll" else "turn_move_seconds"])


func _apply_deadline(deadline_ms: float) -> void:
	if deadline_ms <= 0.0 or conn == null:
		return
	_deadline = Time.get_ticks_msec() / 1000.0 + (deadline_ms - conn.now_server_ms()) / 1000.0
