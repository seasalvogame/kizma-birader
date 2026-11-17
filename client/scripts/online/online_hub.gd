class_name OnlineHub
extends Node
## Live social connection (game server /v1/hub, Phase 5): friends' online status
## (pushed, never polled), match invites and "something changed" hints.
## Connected while the player uses the online / social parts of the app;
## reconnects by itself (0.5 … 15 s).

signal presence_changed            # statuses changed
signal invites_changed             # incoming invites changed
signal social_changed(kind: String)
signal invite_update(update: Dictionary)   # {inviteId, status, from, to}
signal connection_changed(connected: bool)

const BACKOFF := [0.5, 1.0, 2.0, 4.0, 8.0, 15.0]

var session: OnlineSession
var statuses := {}        # friend user id -> "online" | "room" | "match" (missing = offline)
var invites: Array = []   # pending invites to me
var connected := false
var _ws: WsClient
var _want := false
var _attempt := 0
var _waiting := {}        # request id -> reply (or null while waiting)


func start() -> void:
	if _want:
		return
	_want = true
	_attempt = 0
	_connect()


func stop() -> void:
	_want = false
	if _ws != null:
		_ws.close()
		_ws.queue_free()
		_ws = null
	_set_connected(false)


func status_of(user_id: String) -> String:
	return String(statuses.get(user_id, "offline"))


## Sends without waiting ("" when offline).
func send(t: String, p: Dictionary) -> String:
	return _ws.send(t, p) if _ws != null and connected else ""


## Sends and waits for the answer: {ok, data, error}.
func request(t: String, p: Dictionary, timeout: float = 10.0) -> Dictionary:
	if _ws == null or not connected:
		return {"ok": false, "data": {}, "error": "OFFLINE"}
	var id := _ws.send(t, p)
	if id == "":
		return {"ok": false, "data": {}, "error": "OFFLINE"}
	_waiting[id] = null
	var until := Time.get_ticks_msec() + int(timeout * 1000)
	while _waiting.has(id) and _waiting[id] == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	var m: Variant = _waiting.get(id)
	_waiting.erase(id)
	if not (m is Dictionary):
		return {"ok": false, "data": {}, "error": "TIMEOUT"}
	var msg: Dictionary = m
	var p2: Dictionary = msg.get("p", {})
	if msg.get("t") == "error":
		return {"ok": false, "data": p2, "error": String(p2.get("code", "ERROR"))}
	return {"ok": true, "data": p2, "error": ""}


func send_invite(to: String, code: String) -> Dictionary:
	return await request("invite.send", {"to": to, "code": code})


func answer_invite(invite_id: String, accept: bool) -> Dictionary:
	var r := await request("invite.accept" if accept else "invite.decline", {"inviteId": invite_id})
	invites = invites.filter(func(i: Dictionary) -> bool: return i["id"] != invite_id)
	invites_changed.emit()
	return r


## Invites still open (the server also expires them; this hides the ones whose time ran out).
func open_invites() -> Array:
	var now := Time.get_unix_time_from_system() * 1000.0 + (_ws.server_offset_ms if _ws != null else 0.0)
	return invites.filter(func(i: Dictionary) -> bool: return float(i["expires"]) > now)


func server_now_ms() -> float:
	return _ws.now_server_ms() if _ws != null else Time.get_unix_time_from_system() * 1000.0


func _connect() -> void:
	var token := await session.ensure()
	if not _want:
		return
	if token == "":
		_retry()
		return
	if _ws == null:
		_ws = WsClient.new()
		add_child(_ws)
		_ws.opened.connect(func() -> void: _hello())
		_ws.message.connect(_on_message)
		_ws.closed.connect(func(_c: int) -> void:
			_set_connected(false)
			_retry())
	_ws.connect_to(OnlineConfig.ws_url("/v1/hub"))


func _hello() -> void:
	var token := await session.ensure()
	_ws.send("hello", {"token": token})


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
	var re := String(m.get("re", ""))
	if re != "" and _waiting.has(re):
		_waiting[re] = m
	var p: Dictionary = m.get("p", {})
	match String(m.get("t", "")):
		"welcome":
			_attempt = 0
			_set_connected(true)
		"presence.list":
			statuses.clear()
			for f: Dictionary in p.get("friends", []):
				statuses[f["userId"]] = f["status"]
			presence_changed.emit()
		"presence":
			if p.get("status") == "offline":
				statuses.erase(p["userId"])
			else:
				statuses[p["userId"]] = p["status"]
			presence_changed.emit()
		"invite.list":
			invites = p.get("invites", [])
			invites_changed.emit()
		"invite.new":
			var inv: Dictionary = p["invite"]
			invites = invites.filter(func(i: Dictionary) -> bool: return i["id"] != inv["id"])
			invites.append(inv)
			invites_changed.emit()
			Settings.vibrate(40)
		"invite.update":
			if p.get("to") == session.user_id:
				invites = invites.filter(func(i: Dictionary) -> bool: return i["id"] != p["inviteId"])
				invites_changed.emit()
			invite_update.emit(p)
		"social.changed":
			social_changed.emit(String(p.get("kind", "")))
		"error":
			if String(p.get("code", "")) == "AUTH_INVALID":
				session.invalidate()
