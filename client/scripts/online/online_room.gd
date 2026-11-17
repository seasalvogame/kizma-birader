class_name OnlineRoom
extends Node
## A private room lobby (game server /v1/room/<code>, Phase 5). The server owns
## members, colours, ready flags, host and start; this node only sends wishes and
## reports the room state. Reconnects by itself while the player is in the room.

signal state_changed(state: Dictionary)   # {code, players, host, phase, games, members:[{userId, name, tag, avatar, color, ready, connected, host}]}
signal started(info: Dictionary)          # {matchId, seat, color, seats}
signal closed(reason: String)
signal failed(code: String)               # entering failed (ROOM_NOT_FOUND, ROOM_FULL, RATE_LIMITED, ...)
signal action_refused(code: String)       # NOT_HOST, NOT_READY, COLOR_TAKEN, ...
signal connection_changed(connected: bool)

const BACKOFF := [0.5, 1.0, 2.0, 4.0, 8.0, 15.0]
const ENTER_ERRORS := ["ROOM_NOT_FOUND", "ROOM_FULL", "ROOM_IN_GAME", "RATE_LIMITED", "ALREADY_IN_ROOM", "IN_MATCH", "AUTH_INVALID", "NOT_IN_ROOM"]

var session: OnlineSession
var code := ""
var state := {}
var connected := false
var _ws: WsClient
var _want := false
var _attempt := 0
var _hello_id := ""


## Creates a room (2 or 4 players) on the server: {ok, code, error}.
static func create(api: OnlineApi, players: int) -> Dictionary:
	var r := await api.game_request(HTTPClient.METHOD_POST, "/v1/rooms", {"players": players})
	if r["ok"]:
		return {"ok": true, "code": String(r["data"]["code"]), "error": ""}
	var d: Variant = r["data"]
	return {"ok": false, "code": String((d as Dictionary).get("code", "")) if d is Dictionary else "", "error": r["error"]}


## The player's current room / match: {ok, room, match}.
static func mine(api: OnlineApi) -> Dictionary:
	var r := await api.game_request(HTTPClient.METHOD_GET, "/v1/rooms/mine")
	if not r["ok"]:
		return {"ok": false, "room": "", "match": "", "error": r["error"]}
	var d: Dictionary = r["data"]
	return {"ok": true, "room": String(d.get("room", "")), "match": String(d.get("match", "")), "error": ""}


static func normalize(raw: String) -> String:
	return raw.strip_edges().to_upper().replace(" ", "").replace("-", "")


static func valid_code(c: String) -> bool:
	return RegEx.create_from_string("^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$").search(c) != null


func enter(p_session: OnlineSession, p_code: String) -> void:
	session = p_session
	code = p_code
	_want = true
	_attempt = 0
	_connect()


func leave() -> void:
	if _ws != null and connected:
		_ws.send("room.leave", {})
	_close()


func set_color(color: String) -> void:
	_send("room.color", {"color": color})


func set_ready(ready: bool) -> void:
	_send("room.ready", {"ready": ready})


func start_match() -> void:
	_send("room.start", {})


func me() -> Dictionary:
	for m: Dictionary in state.get("members", []):
		if m["userId"] == session.user_id:
			return m
	return {}


func is_host() -> bool:
	return state.get("host", "") == session.user_id


func _send(t: String, p: Dictionary) -> void:
	if _ws != null and connected:
		_ws.send(t, p)
	else:
		action_refused.emit("OFFLINE")


func _close() -> void:
	_want = false
	if _ws != null:
		_ws.close()
		_ws.queue_free()
		_ws = null
	_set_connected(false)


func _connect() -> void:
	var token := await session.ensure()
	if not _want:
		return
	if token == "":
		failed.emit(session.last_error if session.last_error != "" else "AUTH")
		_close()
		return
	if _ws == null:
		_ws = WsClient.new()
		add_child(_ws)
		_ws.opened.connect(func() -> void:
			var t := await session.ensure()
			_hello_id = _ws.send("hello", {"token": t}))
		_ws.message.connect(_on_message)
		_ws.closed.connect(func(_c: int) -> void:
			_set_connected(false)
			_retry())
	_ws.connect_to(OnlineConfig.ws_url("/v1/room/" + code))


func _retry() -> void:
	if not _want:
		return
	var wait: float = BACKOFF[mini(_attempt, BACKOFF.size() - 1)]
	_attempt += 1
	await get_tree().create_timer(wait).timeout
	if _want and not connected:
		_connect()


func _set_connected(c: bool) -> void:
	if connected != c:
		connected = c
		connection_changed.emit(c)


func _on_message(m: Dictionary) -> void:
	var p: Dictionary = m.get("p", {})
	match String(m.get("t", "")):
		"welcome":
			_attempt = 0
			_set_connected(true)
		"room.state":
			state = p
			state_changed.emit(p)
		"room.started":
			started.emit(p)
		"room.closed":
			_close()
			closed.emit(String(p.get("reason", "")))
		"room.left":
			_close()
		"error":
			var c := String(p.get("code", "ERROR"))
			if m.get("re", "") == _hello_id and c in ENTER_ERRORS:
				if c == "AUTH_INVALID":
					session.invalidate()
				_close()
				failed.emit(c)
			elif c == "SESSION_REPLACED":
				_close()
				failed.emit(c)
			else:
				action_refused.emit(c)
