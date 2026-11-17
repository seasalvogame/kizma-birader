class_name OnlineConfig
extends RefCounted
## Public online configuration (data/online_config.json): Supabase URL,
## publishable key and game server URL. Only values that are safe to ship in
## the app; never a secret key. Tests and tools can override the game server
## with -- --game-url=http://127.0.0.1:8787

const PATH := "res://data/online_config.json"

static var _data := {}
## Unit/scene tests run without network: no Supabase, no game server
## (set by the test runner unless -- --online is given).
static var force_offline := false


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--game-url="):
				_data["game_url"] = arg.trim_prefix("--game-url=")
	return _data


static func supabase_url() -> String:
	return "" if force_offline else String(data().get("supabase_url", ""))


static func publishable_key() -> String:
	return String(data().get("publishable_key", ""))


static func game_url() -> String:
	return String(data().get("game_url", "")).trim_suffix("/")


## WebSocket URL of a game server path ("/v1/queue", "/v1/match/<id>").
static func ws_url(path: String) -> String:
	var base := game_url()
	if base.begins_with("https://"):
		base = "wss://" + base.trim_prefix("https://")
	elif base.begins_with("http://"):
		base = "ws://" + base.trim_prefix("http://")
	return base + path
