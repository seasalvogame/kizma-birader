extends Node
## Player settings (UI_SCREEN_SPECIFICATIONS §23), stored in user://settings.cfg.
## Tests and visual checks use a separate file (--settings-path=...).

signal changed(key: String)

const DEFAULTS := {
	"locale": "",               # "" = device language (tr / en, else en)
	"auto_single_move": true,   # K-20 (proposal)
	"tap_to_move": true,        # false = select, then confirm
	"color_symbols": true,      # K-44 (proposal)
	"fast_animations": false,
	"reduced_motion": false,
	"vibration": true,
	# Local (offline) profile and practice stats; online accounts come later.
	"profile_name": "",
	"profile_avatar": 0,
	"profile_synced": false,   # local name already taken over by the online profile
	"last_players": 2,
	"last_color": "red",
	"stats_matches_2p": 0,
	"stats_wins_2p": 0,
	"stats_matches_4p": 0,
	"stats_wins_4p": 0,
}

var path := "user://settings.cfg"
var _values := {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--settings-path="):
			path = arg.trim_prefix("--settings-path=")
	load_settings()


func load_settings() -> void:
	_values = DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key: String in DEFAULTS:
			_values[key] = file.get_value("settings", key, DEFAULTS[key])
	apply_locale()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	var file := ConfigFile.new()
	file.load(path)
	file.set_value("settings", key, value)
	file.save(path)
	if key == "locale":
		apply_locale()
	changed.emit(key)


func apply_locale() -> void:
	var locale := String(_values.get("locale", ""))
	if locale == "":
		locale = "tr" if OS.get_locale_language() == "tr" else "en"
	TranslationServer.set_locale(locale)


## Name shown for the local player (profile name, or "Oyuncu" / "Player").
func display_name() -> String:
	var n := String(get_value("profile_name")).strip_edges()
	return n if n != "" else tr("DEFAULT_NAME")


## Valid player name: 3..16 characters after trimming.
static func valid_name(n: String) -> bool:
	var t := n.strip_edges()
	return t.length() >= 3 and t.length() <= 16


## Records a finished practice match for the local player (rank 1 = win).
func record_match(players: int, rank: int) -> void:
	var p := "2p" if players == 2 else "4p"
	set_value("stats_matches_" + p, int(get_value("stats_matches_" + p)) + 1)
	if rank == 1:
		set_value("stats_wins_" + p, int(get_value("stats_wins_" + p)) + 1)


## Short haptic feedback when the player enabled vibration (mobile only).
func vibrate(ms: int) -> void:
	if get_value("vibration") and OS.get_name() in ["Android", "iOS"]:
		Input.vibrate_handheld(ms)


## Animation speed factor: "fast animations" shortens every duration by 35 %.
func anim_scale() -> float:
	return 0.65 if get_value("fast_animations") else 1.0
