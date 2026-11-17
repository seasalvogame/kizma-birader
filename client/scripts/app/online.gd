extends Node
## Autoload "Online": the device's account session, the player's server data
## and the current match connection (they outlive screen changes).

var session: OnlineSession
var api: OnlineApi
var profile: OnlineProfile
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


## A fresh connection object for a new match (the previous one is closed).
func new_match_connection() -> OnlineMatchConnection:
	if match_connection != null:
		match_connection.close()
		match_connection.queue_free()
	match_connection = OnlineMatchConnection.new()
	add_child(match_connection)
	return match_connection
