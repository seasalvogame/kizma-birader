class_name OnlineApi
extends Node
## Supabase Data API (PostgREST) calls with the player's own JWT and the
## publishable key. Reads are limited by RLS to the player's own data; the only
## write is the update_my_profile RPC (own row, validated in the database).
## Result: {ok, status, data, error} — error is a short code for the UI.

var session: OnlineSession


func get_json(path: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/rest/v1/" + path, null)


func call_rpc(fn: String, args: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + fn, args)


## Game server HTTP API (Cloudflare Worker), e.g. POST /v1/rooms. Errors: the server's code.
func game_request(method: int, path: String, body: Variant = null) -> Dictionary:
	var token := await session.ensure()
	if token == "":
		return {"ok": false, "status": 0, "data": null, "error": session.last_error if session.last_error != "" else "AUTH"}
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json"])
	var err := http.request(OnlineConfig.game_url() + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null, "error": "OFFLINE"}
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": null, "error": "OFFLINE"}
	var code: int = res[1]
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if code >= 200 and code < 300:
		return {"ok": true, "status": code, "data": data, "error": ""}
	if code == 401:
		session.invalidate()
	var e := String((data as Dictionary).get("error", "SERVER")) if data is Dictionary else "SERVER"
	return {"ok": false, "status": code, "data": data, "error": e}


func _request(method: int, path: String, body: Variant) -> Dictionary:
	var token := await session.ensure()
	if token == "":
		return {"ok": false, "status": 0, "data": null, "error": session.last_error if session.last_error != "" else "AUTH"}
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray([
		"apikey: " + OnlineConfig.publishable_key(),
		"Authorization: Bearer " + token,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	var err := http.request(OnlineConfig.supabase_url() + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null, "error": "OFFLINE"}
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": null, "error": "OFFLINE"}
	var code: int = res[1]
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if code >= 200 and code < 300:
		return {"ok": true, "status": code, "data": data, "error": ""}
	if code == 401:
		session.invalidate()
	# Database exceptions raised by our functions come back as {"message": "NAME_INVALID", ...}
	var msg := ""
	if data is Dictionary:
		msg = String((data as Dictionary).get("message", ""))
	return {"ok": false, "status": code, "data": data, "error": msg if msg.length() <= 32 and msg == msg.to_upper() and msg != "" else "SERVER"}
