extends Node
## Autoload "Online": the device's account session, the player's server data
## and the current match connection (they outlive screen changes).

var session: OnlineSession
var api: OnlineApi
var profile: OnlineProfile
var hub: OnlineHub
var social: OnlineSocial
var room: OnlineRoom              # the private room the player is in (outlives screen changes)
var match_connection: OnlineMatchConnection


func _ready() -> void:
	session = OnlineSession.new()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--online-session-path="):
			session.path = arg.trim_prefix("--online-session-path=")
	add_child(session)
	api = OnlineApi.new()
	api.session = session
	add_child(api)
	profile = OnlineProfile.new()
	profile.api = api
	profile.session = session
	add_child(profile)
	hub = OnlineHub.new()
	hub.session = session
	add_child(hub)
	social = OnlineSocial.new()
	social.api = api
	social.hub = hub
	add_child(social)
	session.account_changed.connect(func() -> void:
		# another account on this device: social data belongs to the previous one
		hub.stop()
		social.friends = []; social.incoming = []; social.outgoing = []; social.loaded = false
		leave_room())


## Starts the live social connection when this device already has an account
## (it never creates a guest account by itself).
func start_social() -> void:
	if session.has_account() and OnlineConfig.supabase_url() != "":
		hub.start()


## Enters (or re-enters) a private room; the room node lives here, not in a screen.
func enter_room(code: String) -> OnlineRoom:
	if room != null and room.code == code:
		return room
	leave_room()
	room = OnlineRoom.new()
	add_child(room)
	room.enter(session, code)
	return room


func leave_room() -> void:
	if room != null:
		room.leave()
		room.queue_free()
		room = null


## A fresh connection object for a new match (the previous one is closed).
func new_match_connection() -> OnlineMatchConnection:
	if match_connection != null:
		match_connection.close()
		match_connection.queue_free()
	match_connection = OnlineMatchConnection.new()
	add_child(match_connection)
	return match_connection
