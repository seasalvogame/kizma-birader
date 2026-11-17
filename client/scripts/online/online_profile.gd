class_name OnlineProfile
extends Node
## The player's server data: profile, online stats and match history (read
## through RLS), and profile changes (update_my_profile RPC, validated by the
## database). The last good answer is cached so the profile still shows
## offline, clearly marked as "last known".

signal changed

const HISTORY_SELECT := "id,mode,players,status,started_at,ended_at,end_reason,server_version,action_count,match_players(seat,color,rank,user_id,is_bot,display_name,tag,left_match)"

var api: OnlineApi
var session: OnlineSession
var profile := {}          # {user_id, display_name, tag, avatar_id, level}
var stats := {}            # player_stats row
var recent: Array = []     # last matches (see HISTORY_SELECT)
var loaded_at := 0         # unix seconds of the last successful load (0 = never)
var last_error := ""
var cache_path := "user://online_profile_cache.json"


func _ready() -> void:
	_load_cache()


## Forget everything (another account signed in, or tests).
func reset() -> void:
	profile = {}
	stats = {}
	recent = []
	loaded_at = 0


## Loads profile + stats + recent matches. Returns true when the server answered.
func refresh(recent_limit: int = 5) -> bool:
	last_error = ""
	var uid := session.user_id
	var token := await session.ensure()
	if token == "":
		last_error = session.last_error
		return false
	uid = session.user_id
	var p := await api.get_json("profiles?select=user_id,display_name,tag,avatar_id,level&user_id=eq." + uid)
	var s := await api.get_json("player_stats?select=*&user_id=eq." + uid)
	var h := await history(recent_limit)
	if not (p["ok"] and s["ok"] and h["ok"]) or (p["data"] as Array).is_empty():
		last_error = p["error"] if not p["ok"] else ("SERVER" if p["ok"] and (p["data"] as Array).is_empty() else s["error"])
		return false
	profile = (p["data"] as Array)[0]
	stats = (s["data"] as Array)[0] if not (s["data"] as Array).is_empty() else {}
	recent = h["data"]
	loaded_at = int(Time.get_unix_time_from_system())
	await _adopt_local_name()
	_mirror_to_settings()
	_save_cache()
	changed.emit()
	return true


## Finished online matches of the player, newest first; `before` = ended_at of the last row shown.
func history(limit: int = 20, before: String = "") -> Dictionary:
	var q := "matches?select=%s&status=eq.finished&mode=neq.test&order=ended_at.desc&limit=%d" % [HISTORY_SELECT, limit]
	if before != "":
		q += "&ended_at=lt." + before.uri_encode()
	return await api.get_json(q)


## Changes the own name and/or avatar (server validates). Errors: NAME_INVALID, NAME_TAKEN, AVATAR_INVALID, OFFLINE, ...
func update(display_name: Variant = null, avatar_id: Variant = null) -> Dictionary:
	var args := {"p_display_name": display_name, "p_avatar_id": avatar_id}
	var r := await api.call_rpc("update_my_profile", args)
	if r["ok"] and r["data"] is Dictionary:
		for k: String in (r["data"] as Dictionary):
			profile[k] = r["data"][k]
		_mirror_to_settings()
		_save_cache()
		changed.emit()
	return r


func display_name() -> String:
	return String(profile.get("display_name", Settings.display_name()))


func tag() -> int:
	return int(profile.get("tag", 0))


static func avatar_index(avatar_id: String) -> int:
	return int(avatar_id.trim_prefix("fill:")) if avatar_id.begins_with("fill:") else 0


## Online totals: matches, wins, losses (matches - wins), win rate (0..100 or -1).
func totals() -> Dictionary:
	var m := int(stats.get("matches_2p", 0)) + int(stats.get("matches_4p", 0))
	var w := int(stats.get("wins_2p", 0)) + int(stats.get("wins_4p", 0))
	return {"matches": m, "wins": w, "losses": m - w, "rate": -1 if m == 0 else roundi(100.0 * w / m)}


## Same rule as the database (update_my_profile): 3–16 characters; letters of any
## language, digits, space, _ . - ; starts and ends with a letter or digit; no double spaces.
static func valid_name(n: String) -> bool:
	var t := n.strip_edges()
	if t.length() < 3 or t.length() > 16 or t.contains("  "):
		return false
	var re := RegEx.create_from_string("^[\\p{L}\\p{N}]([\\p{L}\\p{N} _.\\-]*[\\p{L}\\p{N}])?$")
	return re.search(t) != null


## A name chosen offline before this account existed is taken over once.
func _adopt_local_name() -> void:
	var local := String(Settings.get_value("profile_name")).strip_edges()
	if local == "" or bool(Settings.get_value("profile_synced")):
		return
	if String(profile.get("display_name", "")) == "Oyuncu" and valid_name(local):
		var r := await update(local, "fill:%d" % int(Settings.get_value("profile_avatar")))
		if not r["ok"]:
			return
	Settings.set_value("profile_synced", true)


## Offline matches show the same name and avatar as the online profile.
func _mirror_to_settings() -> void:
	if profile.has("display_name"):
		Settings.set_value("profile_name", String(profile["display_name"]))
	if profile.has("avatar_id"):
		Settings.set_value("profile_avatar", avatar_index(String(profile["avatar_id"])))


func _save_cache() -> void:
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"user_id": session.user_id, "profile": profile, "stats": stats, "recent": recent, "loaded_at": loaded_at}))


func _load_cache() -> void:
	var f := FileAccess.open(cache_path, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary and String((d as Dictionary).get("user_id", "")) == session.user_id and session.user_id != "":
		profile = d.get("profile", {})
		stats = d.get("stats", {})
		recent = d.get("recent", [])
		loaded_at = int(d.get("loaded_at", 0))
		_mirror_to_settings()
