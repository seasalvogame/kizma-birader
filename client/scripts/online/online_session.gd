class_name OnlineSession
extends Node
## The player's Supabase account on this device: a guest (anonymous) account
## first, which can later be made permanent with e-mail (+ password), Google or
## Apple — the user id never changes, so profile and match history stay.
## ensure() returns a valid access token: the stored one or a refreshed one.
## A NEW guest account is created only when this device has no account at all;
## a failed refresh never replaces the account (network error -> "OFFLINE",
## rejected token -> "SESSION_EXPIRED", the UI then asks the player).
## Only the publishable key is used. The refresh token is kept in the app's
## private storage (not yet the Android Keystore: TECHNICAL_ARCHITECTURE §4).

signal account_changed

var path := "user://online_session.cfg"
var access_token := ""
var refresh_token := ""
var expires_at := 0          # unix seconds
var user_id := ""
var email := ""              # confirmed e-mail of a permanent account
var new_email := ""          # e-mail waiting for confirmation
var is_anonymous := true
var last_error := ""
var _busy := false


func _ready() -> void:
	_load()


func has_account() -> bool:
	return refresh_token != ""


func has_valid_token() -> bool:
	return access_token != "" and expires_at - 60 > int(Time.get_unix_time_from_system())


## A valid access token, or "" (last_error: OFFLINE, SESSION_EXPIRED, NO_CONFIG, AUTH_<code>).
func ensure() -> String:
	while _busy:
		await get_tree().process_frame
	if has_valid_token():
		return access_token
	_busy = true
	last_error = ""
	var ok := false
	if refresh_token != "":
		ok = await _token_request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token})
		if not ok and last_error != "OFFLINE" and last_error != "NO_CONFIG":
			last_error = "SESSION_EXPIRED"     # keep the stored account; never replace it silently
	else:
		ok = await _token_request("/auth/v1/signup", {"data": {}})
	_busy = false
	return access_token if ok else ""


## Forget the access token (the server rejected it); the next ensure() refreshes.
func invalidate() -> void:
	expires_at = 0


## Re-reads the account (e-mail, guest or not) from Supabase Auth.
func fetch_user() -> Dictionary:
	var token := await ensure()
	if token == "":
		return {"ok": false, "error": last_error}
	var r := await _call(HTTPClient.METHOD_GET, "/auth/v1/user", null, token)
	if r["ok"]:
		_apply_user(r["data"])
		account_changed.emit()
	return r


## Step 1 of making a guest permanent: Supabase sends a confirmation link to
## the address (the user id stays). Errors: EMAIL_TAKEN, EMAIL_INVALID,
## EMAIL_NOT_ALLOWED, RATE_LIMITED, OFFLINE.
func request_email_link(address: String) -> Dictionary:
	var token := await ensure()
	if token == "":
		return {"ok": false, "error": last_error}
	var redirect := OnlineConfig.game_url() + "/auth/confirmed"
	var r := await _call(HTTPClient.METHOD_PUT, "/auth/v1/user?redirect_to=" + redirect.uri_encode(), {"email": address.strip_edges()}, token)
	if r["ok"]:
		_apply_user(r["data"])
		account_changed.emit()
	return r


## Step 2 (after the e-mail is confirmed): a password for signing in on other devices.
func set_password(password: String) -> Dictionary:
	var token := await ensure()
	if token == "":
		return {"ok": false, "error": last_error}
	return await _call(HTTPClient.METHOD_PUT, "/auth/v1/user", {"password": password}, token)


## Sign in to an existing permanent account on this device. The current account
## is replaced only after a successful sign-in (a failed attempt changes nothing).
func sign_in_email(address: String, password: String) -> Dictionary:
	var backup := [access_token, refresh_token, expires_at, user_id, email, new_email, is_anonymous]
	var ok := await _token_request("/auth/v1/token?grant_type=password", {"email": address.strip_edges(), "password": password})
	if not ok:
		access_token = backup[0]; refresh_token = backup[1]; expires_at = backup[2]; user_id = backup[3]
		email = backup[4]; new_email = backup[5]; is_anonymous = backup[6]
		return {"ok": false, "error": last_error}
	account_changed.emit()
	return {"ok": true}


## Native Google / Apple sign-in (needs a native plugin that returns an ID token;
## not part of this build). Links the identity to the CURRENT user, like
## supabase-flutter's linkIdentityWithIdToken (signInWithIdToken + link_identity).
## UNVERIFIED: providers are not configured yet (docs/setup/SUPABASE_SETUP.md §6).
func link_id_token(provider: String, id_token: String, nonce: String = "") -> Dictionary:
	var token := await ensure()
	if token == "":
		return {"ok": false, "error": last_error}
	var body := {"provider": provider, "id_token": id_token, "link_identity": true}
	if nonce != "":
		body["nonce"] = nonce
	var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=id_token", body, token)
	if r["ok"] and r["data"] is Dictionary and (r["data"] as Dictionary).has("access_token"):
		_apply_tokens(r["data"])
		account_changed.emit()
	return r


## Signs out a PERMANENT account on this device (it can sign in again).
## Guests are not signed out: their account would be lost.
func sign_out() -> void:
	if is_anonymous:
		return
	var token := access_token
	if token != "":
		await _call(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, token)
	_clear()
	account_changed.emit()


## After SESSION_EXPIRED: the player explicitly starts over with a new guest account.
func start_new_guest() -> bool:
	_clear()
	var ok := (await ensure()) != ""
	account_changed.emit()
	return ok


func _clear() -> void:
	access_token = ""
	refresh_token = ""
	expires_at = 0
	user_id = ""
	email = ""
	new_email = ""
	is_anonymous = true
	_save()


func _token_request(endpoint: String, body: Dictionary) -> bool:
	var r := await _call(HTTPClient.METHOD_POST, endpoint, body, "")
	if not r["ok"] or not (r["data"] is Dictionary) or not (r["data"] as Dictionary).has("access_token"):
		last_error = r.get("error", "AUTH")
		return false
	_apply_tokens(r["data"])
	return true


func _apply_tokens(d: Dictionary) -> void:
	access_token = d["access_token"]
	refresh_token = d.get("refresh_token", refresh_token)
	expires_at = int(d.get("expires_at", int(Time.get_unix_time_from_system()) + int(d.get("expires_in", 3600))))
	if d.get("user") is Dictionary:
		_apply_user(d["user"])
	_save()


func _apply_user(u: Variant) -> void:
	if not (u is Dictionary):
		return
	var d: Dictionary = u
	user_id = String(d.get("id", user_id))
	is_anonymous = bool(d.get("is_anonymous", false))
	# confirmed address only; a pending change shows up as new_email
	var e: Variant = d.get("email")
	email = String(e) if e != null and String(e) != "" and d.get("email_confirmed_at") != null else ""
	var ne: Variant = d.get("new_email")
	new_email = String(ne) if ne != null else ""
	_save()


## HTTP to Supabase Auth. Returns {ok, status, data, error}.
func _call(method: int, endpoint: String, body: Variant, token: String) -> Dictionary:
	if OnlineConfig.supabase_url() == "" or OnlineConfig.publishable_key() == "":
		return {"ok": false, "status": 0, "data": null, "error": "NO_CONFIG"}
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray(["apikey: " + OnlineConfig.publishable_key(), "Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := http.request(OnlineConfig.supabase_url() + endpoint, headers, method, "" if body == null else JSON.stringify(body))
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
	return {"ok": false, "status": code, "data": data, "error": auth_error(code, data)}


## Maps Supabase Auth errors to short codes for the UI.
static func auth_error(code: int, data: Variant) -> String:
	var ec := ""
	var msg := ""
	if data is Dictionary:
		ec = String((data as Dictionary).get("error_code", (data as Dictionary).get("code", "")))
		msg = String((data as Dictionary).get("msg", (data as Dictionary).get("message", (data as Dictionary).get("error_description", "")))).to_lower()
	if ec in ["email_exists", "user_already_exists", "identity_already_exists"] or msg.contains("already been registered") or msg.contains("already exists"):
		return "EMAIL_TAKEN"
	if ec in ["email_address_invalid", "validation_failed"] or msg.contains("invalid format") or msg.contains("invalid email"):
		return "EMAIL_INVALID"
	if ec == "email_address_not_authorized" or msg.contains("not authorized"):
		return "EMAIL_NOT_ALLOWED"
	if ec in ["over_email_send_rate_limit", "over_request_rate_limit"] or code == 429:
		return "RATE_LIMITED"
	if ec == "weak_password" or msg.contains("password should"):
		return "WEAK_PASSWORD"
	if ec == "invalid_credentials" or msg.contains("invalid login"):
		return "BAD_LOGIN"
	if ec == "email_not_confirmed":
		return "EMAIL_NOT_CONFIRMED"
	return "AUTH_%d" % code


func _load() -> void:
	var f := ConfigFile.new()
	if f.load(path) == OK:
		refresh_token = f.get_value("session", "refresh_token", "")
		user_id = f.get_value("session", "user_id", "")
		email = f.get_value("session", "email", "")
		new_email = f.get_value("session", "new_email", "")
		is_anonymous = f.get_value("session", "is_anonymous", true)


func _save() -> void:
	# The short-lived access token stays in memory; the refresh token and the
	# account summary are stored so the account survives an app restart.
	var f := ConfigFile.new()
	f.set_value("session", "refresh_token", refresh_token)
	f.set_value("session", "user_id", user_id)
	f.set_value("session", "email", email)
	f.set_value("session", "new_email", new_email)
	f.set_value("session", "is_anonymous", is_anonymous)
	f.save(path)
