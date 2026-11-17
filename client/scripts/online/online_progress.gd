class_name OnlineProgress
extends Node
## Player progression from the server (Phase 6): quests (6.2), and later daily login,
## achievements and the weekly leaderboard. Everything is computed and stored by
## Supabase; this node reads it and asks to claim rewards (each reward exactly once,
## decided by the server). `claimable` drives the dot on the "Görevler" tab.

signal changed

var api: OnlineApi
var quests := {}            # my_quests(): {daily, weekly, unclaimed_old, daily_resets_at, weekly_resets_at, server_time}
var claimable := 0
var achievements_claimable := 0
var login := {}             # daily_login_status(): {can_claim, next_day, streak, cycle, resets_at, ...}
var achievements := {}      # my_achievements(): {achievements: [...], counters}
var last_error := ""


func refresh_quests() -> bool:
	var r := await api.call_rpc("my_quests", {})
	if not r["ok"]:
		last_error = r["error"]
		return false
	quests = r["data"]
	_count()
	changed.emit()
	return true


## Claims one quest: {ok, data: {gold, xp, level_before, level_after, level_gold}, error}.
func claim_quest(q: Dictionary) -> Dictionary:
	var r := await api.call_rpc("claim_quest", {"p_period": q["period"], "p_period_key": q["period_key"], "p_quest_id": q["quest_id"]})
	if r["ok"] or r["error"] == "ALREADY_CLAIMED":
		await refresh_quests()
		Online.profile.loaded_at = 0     # gold / XP changed: the profile reloads
	return r


func refresh_login() -> bool:
	var r := await api.call_rpc("daily_login_status", {})
	if not r["ok"]:
		last_error = r["error"]
		return false
	login = r["data"]
	changed.emit()
	return true


## Claims today's login reward: {ok, data: {day, gold, xp, streak, badge, level_before, level_after}, error}.
func claim_login() -> Dictionary:
	var r := await api.call_rpc("claim_daily_login", {})
	await refresh_login()
	if r["ok"]:
		Online.profile.loaded_at = 0
		refresh_quests()       # the weekly "log in on N days" quest moved
	return r


func refresh_achievements() -> bool:
	var r := await api.call_rpc("my_achievements", {})
	if not r["ok"]:
		last_error = r["error"]
		return false
	achievements = r["data"]
	_count()
	changed.emit()
	return true


func claim_achievement(id: String) -> Dictionary:
	var r := await api.call_rpc("claim_achievement", {"p_id": id})
	if r["ok"] or r["error"] == "ALREADY_CLAIMED":
		await refresh_achievements()
		Online.profile.loaded_at = 0
	return r


## Shows an unlocked badge on the profile ("" = none).
func set_badge(badge: String) -> Dictionary:
	var r := await api.call_rpc("set_profile_badge", {"p_badge": badge if badge != "" else null})
	if r["ok"]:
		Online.profile.progress["badge_id"] = r["data"].get("badge_id")
		changed.emit()
	return r


## Weekly leaderboard: top rows of a week ("" = this week), paged.
func leaderboard_top(week: String, limit: int, offset: int) -> Dictionary:
	return await api.call_rpc("leaderboard_top", {"p_week": week if week != "" else null, "p_limit": limit, "p_offset": offset})


## My place, points and last weekly reward.
func leaderboard_me(week: String) -> Dictionary:
	return await api.call_rpc("leaderboard_me", {"p_week": week if week != "" else null})


func _count() -> void:
	var n := 0
	for key: String in ["daily", "weekly", "unclaimed_old"]:
		for q: Dictionary in quests.get(key, []):
			if q.get("completed", false) and not q.get("claimed", false):
				n += 1
	claimable = n
	NavBar.dots["quests"] = n > 0
	var ach := 0
	for a: Dictionary in achievements.get("achievements", []):
		if a.get("completed", false) and not a.get("claimed", false):
			ach += 1
	achievements_claimable = ach


## Quest title from its metric and target (texts live in the client, numbers on the server).
static func quest_title(q: Dictionary) -> String:
	return TranslationServer.translate("QUEST_" + String(q.get("metric", "")).to_upper()) % int(q.get("target", 0))


static func quest_hint(q: Dictionary) -> String:
	return TranslationServer.translate("QUEST_HINT_" + String(q.get("metric", "")).to_upper())
