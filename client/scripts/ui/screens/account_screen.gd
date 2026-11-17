class_name AccountScreen
extends AppScreen
## Account and security (Phase 4):
##  - guest: protect the account with an e-mail (Supabase sends a confirmation
##    link; the user id — and so profile and match history — stays the same);
##  - after confirmation: set a password (to sign in on another device);
##  - sign in to an existing account on this device (only replaces the current
##    one after a successful sign-in; a guest is warned that it will be left);
##  - Google / Apple: shown as not available in this build (no native plugin,
##    providers not configured) — nothing is faked.

var status: StatusCard
var _msg: Label
var _email: LineEdit
var _password: LineEdit
var _login_email: LineEdit
var _login_password: LineEdit
var _busy := false


func _title() -> String:
	return tr("ACCOUNT_TITLE")


func _build() -> void:
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_check)
	_render()
	_check()


## Re-reads the account from Supabase (e.g. after the e-mail link was clicked).
func _check() -> void:
	if _busy:
		return
	_busy = true
	if not Online.session.has_account():
		status.loading(tr("ACCOUNT_CREATING"))
	var r := await Online.session.fetch_user()
	_busy = false
	if not is_inside_tree():
		return
	if r["ok"]:
		status.clear()
	elif r["error"] == "SESSION_EXPIRED":
		status.error(tr("ACCOUNT_SESSION_EXPIRED"))
	else:
		status.error(tr("PROFILE_OFFLINE"), tr("ONLINE_RETRY"))
	_render()


func _render() -> void:
	for c: Node in content.get_children():
		if c != status:
			c.queue_free()
	var s := Online.session
	# --- current state
	var state := card(tr("ACCOUNT_STATUS"))
	var line := ""
	if not s.is_anonymous and s.email != "":
		line = tr("ACCOUNT_STATE_EMAIL") % s.email
	elif s.new_email != "":
		line = tr("ACCOUNT_PENDING_LONG") % s.new_email
	else:
		line = tr("ACCOUNT_GUEST_LONG")
	state.add_child(wrapped(UiKit.label(line, "InkBodyLabel")))
	_msg = wrapped(UiKit.label("", "InkDimLabel"))
	_msg.hide()
	state.add_child(_msg)
	if s.new_email != "" and s.is_anonymous:
		var check := UiKit.button(tr("ACCOUNT_CHECK"), "primary", "s")
		check.mouse_filter = Control.MOUSE_FILTER_PASS
		check.pressed.connect(_check)
		state.add_child(check)
	if s.last_error == "SESSION_EXPIRED":
		var fresh := UiKit.button(tr("ACCOUNT_NEW_GUEST"), "secondary", "s")
		fresh.mouse_filter = Control.MOUSE_FILTER_PASS
		fresh.pressed.connect(func() -> void:
			await Online.session.start_new_guest()
			_render())
		state.add_child(fresh)
	# --- protect a guest with an e-mail
	if s.is_anonymous:
		var link := card(tr("ACCOUNT_LINK_EMAIL"))
		link.add_child(wrapped(UiKit.label(tr("ACCOUNT_LINK_EMAIL_INFO"), "InkDimLabel")))
		_email = _edit(tr("ACCOUNT_EMAIL_HINT"), false)
		link.add_child(_email)
		var send := UiKit.button(tr("ACCOUNT_SEND_LINK"), "primary", "s")
		send.mouse_filter = Control.MOUSE_FILTER_PASS
		send.pressed.connect(_send_link)
		link.add_child(send)
	# --- password once the e-mail is confirmed
	if not s.is_anonymous and s.email != "":
		var pw := card(tr("ACCOUNT_PASSWORD"))
		pw.add_child(wrapped(UiKit.label(tr("ACCOUNT_PASSWORD_INFO"), "InkDimLabel")))
		_password = _edit(tr("ACCOUNT_PASSWORD_HINT"), true)
		pw.add_child(_password)
		var setb := UiKit.button(tr("ACCOUNT_PASSWORD_SET"), "primary", "s")
		setb.mouse_filter = Control.MOUSE_FILTER_PASS
		setb.pressed.connect(_set_password)
		pw.add_child(setb)
	# --- Google / Apple (prepared, not available in this build)
	var social := card(tr("ACCOUNT_SOCIAL"))
	for provider: String in ["Google", "Apple"]:
		var b := UiKit.button(tr("ACCOUNT_LINK_WITH") % provider, "secondary", "s")
		b.disabled = true
		social.add_child(b)
	social.add_child(wrapped(UiKit.label(tr("ACCOUNT_SOCIAL_SOON"), "InkDimLabel")))
	# --- sign in to another account on this device
	var login := card(tr("ACCOUNT_SIGN_IN"))
	login.add_child(wrapped(UiKit.label(tr("ACCOUNT_SIGN_IN_WARN_GUEST") if s.is_anonymous else tr("ACCOUNT_SIGN_IN_INFO"), "InkDimLabel")))
	_login_email = _edit(tr("ACCOUNT_EMAIL_HINT"), false)
	login.add_child(_login_email)
	_login_password = _edit(tr("ACCOUNT_PASSWORD_HINT"), true)
	login.add_child(_login_password)
	var sign := UiKit.button(tr("ACCOUNT_SIGN_IN_BUTTON"), "secondary", "s")
	sign.mouse_filter = Control.MOUSE_FILTER_PASS
	sign.pressed.connect(_sign_in)
	login.add_child(sign)
	if not s.is_anonymous:
		var out := UiKit.button(tr("ACCOUNT_SIGN_OUT"), "secondary", "s")
		out.add_theme_color_override("font_color", Color("#c03a3f"))
		out.mouse_filter = Control.MOUSE_FILTER_PASS
		out.pressed.connect(func() -> void:
			await Online.session.sign_out()
			Online.profile.loaded_at = 0
			_render())
		content.add_child(out)


func _edit(hint: String, secret: bool) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.secret = secret
	e.custom_minimum_size = Vector2(0, UiTokens.BUTTON_S)
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	ProfileScreen._style_edit(e)
	return e


func _say(text: String, is_error: bool) -> void:
	if _msg == null or not is_instance_valid(_msg):
		return
	_msg.text = text
	_msg.add_theme_color_override("font_color", Color("#c03a3f") if is_error else UiPalette.INK_500)
	_msg.show()


func _send_link() -> void:
	var address := _email.text.strip_edges()
	if not address.contains("@") or address.length() < 5:
		_say(tr("ACCOUNT_ERR_EMAIL_INVALID"), true)
		return
	_say(tr("ACCOUNT_SENDING"), false)
	var r := await Online.session.request_email_link(address)
	if not is_inside_tree():
		return
	if r["ok"]:
		_render()
		_say(tr("ACCOUNT_LINK_SENT") % address, false)
	else:
		_say(_error_text(r["error"]), true)


func _set_password() -> void:
	var pw := _password.text
	if pw.length() < 8:
		_say(tr("ACCOUNT_ERR_WEAK_PASSWORD"), true)
		return
	var r := await Online.session.set_password(pw)
	if not is_inside_tree():
		return
	_password.text = ""
	_say(tr("ACCOUNT_PASSWORD_DONE") if r["ok"] else _error_text(r["error"]), not r["ok"])


func _sign_in() -> void:
	var r := await Online.session.sign_in_email(_login_email.text, _login_password.text)
	if not is_inside_tree():
		return
	_login_password.text = ""
	if r["ok"]:
		Online.profile.loaded_at = 0
		_render()
		_say(tr("ACCOUNT_SIGNED_IN"), false)
	else:
		_say(_error_text(r["error"]), true)


func _error_text(code: String) -> String:
	match code:
		"EMAIL_TAKEN":
			return tr("ACCOUNT_ERR_EMAIL_TAKEN")
		"EMAIL_INVALID":
			return tr("ACCOUNT_ERR_EMAIL_INVALID")
		"EMAIL_NOT_ALLOWED":
			return tr("ACCOUNT_ERR_EMAIL_NOT_ALLOWED")
		"RATE_LIMITED":
			return tr("ACCOUNT_ERR_RATE")
		"WEAK_PASSWORD":
			return tr("ACCOUNT_ERR_WEAK_PASSWORD")
		"BAD_LOGIN":
			return tr("ACCOUNT_ERR_BAD_LOGIN")
		"EMAIL_NOT_CONFIRMED":
			return tr("ACCOUNT_ERR_NOT_CONFIRMED")
		"OFFLINE":
			return tr("PROFILE_OFFLINE")
		"SESSION_EXPIRED":
			return tr("ACCOUNT_SESSION_EXPIRED")
		_:
			return tr("ONLINE_ERR_SERVER")
