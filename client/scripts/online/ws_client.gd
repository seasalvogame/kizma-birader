class_name WsClient
extends Node
## Thin WebSocket wrapper for the game server protocol (NETWORK_PROTOCOL §2):
## JSON envelopes {v, t, id, p}, request ids, server clock offset, polling.
## Emits every server message; reconnect policy belongs to the owner.

signal message(m: Dictionary)
signal opened
signal closed(code: int)

var server_offset_ms := 0.0      # server clock - local clock
var _ws: WebSocketPeer
var _was_open := false
var _req := 0


func connect_to(url: String) -> void:
	close()
	_ws = WebSocketPeer.new()
	if "heartbeat_interval" in _ws:
		_ws.set("heartbeat_interval", 10.0)   # protocol pings: answered by the server runtime, not billed
	_was_open = false
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		closed.emit(-1)


func is_open() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


## Sends a request and returns its id ("" when not connected).
func send(t: String, p: Dictionary = {}) -> String:
	if not is_open():
		return ""
	_req += 1
	var id := "c%d-%d" % [Time.get_ticks_msec(), _req]
	_ws.send_text(JSON.stringify({"v": 1, "t": t, "id": id, "p": p}))
	return id


func close() -> void:
	if _ws != null:
		_ws.close()
		_ws = null


func now_server_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0 + server_offset_ms


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			opened.emit()
		while _ws != null and _ws.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
			if parsed is Dictionary:
				var m: Dictionary = parsed
				if m.has("st"):
					server_offset_ms = float(m["st"]) - Time.get_unix_time_from_system() * 1000.0
				message.emit(m)
	elif state == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		_ws = null
		closed.emit(code)
