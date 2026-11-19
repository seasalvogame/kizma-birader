class_name OnlineMatchConnection
extends Node
## Connection to one match (MatchRoom on the game server). Keeps itself
## connected: on a drop it reconnects with backoff (0.5, 1, 2, 4, 8, 15 s),
## sends hello again and receives the full state (match.snapshot).
## Events are delivered in server order; a gap asks for a resync.

signal snapshot_received(p: Dictionary)         # {matchId, yourSeat, seats, state, deadline, serverTime}
signal events_received(p: Dictionary)           # {events, state, deadline, ...}
signal emote_received(seat: int, emote_id: String)
signal connection_changed(connected: bool)
signal fatal(code: String)                      # the match cannot continue on this device
signal action_refused(code: String)
signal recorded(match_id: String)               # the server stored the result (Supabase)
signal progress_received(progress: Dictionary)  # my XP / level from that result {xp, level_before, level_after, gold}

const BACKOFF := [0.5, 1.0, 2.0, 4.0, 8.0, 15.0]

var session: OnlineSession
var match_id := ""
var ws: WsClient
var last_seq := -1
var connected := false
var _want := false
var _attempt := 0
var _hello_id := ""


func open(p_session: OnlineSession, p_match_id: String) -> void:
	session = p_session
	match_id = p_match_id
	_want = true
	_attempt = 0
	if ws == null:
		ws = WsClient.new()
		add_child(ws)
		ws.opened.connect(_on_opened)
		ws.message.connect(_on_message)
		ws.closed.connect(_on_closed)
	_connect()


func close() -> void:
	_want = false
	connected = false
	if ws != null:
		ws.close()


func send_action(t: String, p: Dictionary) -> String:
	return ws.send(t, p) if ws != null else ""


func now_server_ms() -> float:
	return ws.now_server_ms() if ws != null else Time.get_unix_time_from_system() * 1000.0


func _connect() -> void:
	if not _want:
		return
	ws.connect_to(OnlineConfig.ws_url("/v1/match/" + match_id))


func _on_opened() -> void:
	var token := await session.ensure()
	if token == "" or not _want:
		ws.close()
		return
	_hello_id = ws.send("hello", {"token": token})


func _on_message(m: Dictionary) -> void:
	var t := String(m.get("t", ""))
	var p: Dictionary = m.get("p", {})
	match t:
		"welcome":
			_attempt = 0
			connected = true
			connection_changed.emit(true)
		"match.snapshot":
			last_seq = int(m.get("seq", 0))
			snapshot_received.emit(p)
			if (p.get("progress") is Dictionary):   # reconnect after the result was recorded
				progress_received.emit(p["progress"])
		"match.events":
			var seq := int(m.get("seq", 0))
			if seq <= last_seq:
				return
			if seq > last_seq + 1:
				ws.send("resync", {})   # missed something: ask for the full state
				return
			last_seq = seq
			events_received.emit(p)
		"emote":
			emote_received.emit(int(p.get("seat", -1)), String(p.get("emoteId", "")))
		"match.recorded":
			recorded.emit(String(p.get("matchId", "")))
			if p.get("progress") is Dictionary:
				progress_received.emit(p["progress"])
		"error":
			var code := String(p.get("code", "ERROR"))
			if m.get("re", "") == _hello_id or code in ["AUTH_INVALID", "NOT_IN_MATCH", "SESSION_REPLACED", "MATCH_NOT_FOUND"]:
				if code == "AUTH_INVALID":
					session.invalidate()   # retry with a refreshed token
				elif code != "RATE_LIMITED":
					_want = false
					fatal.emit(code)
			else:
				action_refused.emit(code)


func _on_closed(_code: int) -> void:
	if connected:
		connected = false
		connection_changed.emit(false)
	if not _want:
		return
	var wait: float = BACKOFF[mini(_attempt, BACKOFF.size() - 1)]
	_attempt += 1
	await get_tree().create_timer(wait).timeout
	_connect()
