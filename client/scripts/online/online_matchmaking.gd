class_name OnlineMatchmaking
extends Node
## 2-player quick match queue: hello -> queue.join -> match.found.
## The server pairs two players, picks an opposite colour pair and creates the
## match; this node only reports the result.

signal found(info: Dictionary)      # {matchId, seat, color, seats}
signal failed(code: String)
signal searching

var session: OnlineSession
var player_name := ""
var _ws: WsClient
var _done := false


func start(p_session: OnlineSession, p_name: String) -> void:
	session = p_session
	player_name = p_name
	_done = false
	var token := await session.ensure()
	if _done:
		return
	if token == "":
		_fail(session.last_error)
		return
	_ws = WsClient.new()
	add_child(_ws)
	_ws.opened.connect(func() -> void: _ws.send("hello", {"token": token}))
	_ws.message.connect(_on_message)
	_ws.closed.connect(func(_code: int) -> void:
		if not _done:
			_fail("NETWORK"))
	_ws.connect_to(OnlineConfig.ws_url("/v1/queue"))


func cancel() -> void:
	if _done:
		return
	_done = true
	if _ws != null:
		_ws.send("queue.leave", {})
		_ws.close()


func _on_message(m: Dictionary) -> void:
	match String(m.get("t", "")):
		"welcome":
			_ws.send("queue.join", {"mode": "2p", "name": player_name})
		"queue.status":
			searching.emit()
		"match.found":
			_done = true
			_ws.close()
			found.emit(m["p"])
		"error":
			var code := String((m.get("p", {}) as Dictionary).get("code", "ERROR"))
			if code == "AUTH_INVALID":
				session.invalidate()
			_fail(code)


func _fail(code: String) -> void:
	if _done:
		return
	_done = true
	if _ws != null:
		_ws.close()
	failed.emit(code)
