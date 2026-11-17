class_name OnlineSocial
extends Node
## Friends (Phase 5): search, requests, friend list, profiles, block — Supabase
## RPCs that take the player from the JWT (the client never names "who I am").
## After a change the other player is told through the social hub (a content-free
## hint; they reload from Supabase). Results: {ok, status, data, error}.

signal changed   # friends / requests changed (here or on another device / by another player)

var api: OnlineApi
var hub: OnlineHub
var friends: Array = []        # [{user_id, display_name, tag, avatar_id, since}]
var incoming: Array = []       # pending requests to me  [{id, direction, user_id, display_name, tag, avatar_id, created_at}]
var outgoing: Array = []
var blocked: Array = []
var loaded := false
var last_error := ""


func _ready() -> void:
	# another player changed something that concerns me (request, acceptance, removal): reload
	if hub != null:
		hub.social_changed.connect(func(_kind: String) -> void: refresh())


func refresh() -> bool:
	last_error = ""
	var f := await api.call_rpc("my_friends", {})
	var r := await api.call_rpc("my_friend_requests", {})
	if not (f["ok"] and r["ok"]):
		last_error = f["error"] if not f["ok"] else r["error"]
		return false
	friends = f["data"]
	incoming = (r["data"] as Array).filter(func(x: Dictionary) -> bool: return x["direction"] == "in")
	outgoing = (r["data"] as Array).filter(func(x: Dictionary) -> bool: return x["direction"] == "out")
	loaded = true
	changed.emit()
	return true


func refresh_blocks() -> bool:
	var b := await api.call_rpc("my_blocks", {})
	if b["ok"]:
		blocked = b["data"]
	return b["ok"]


func search(query: String) -> Dictionary:
	return await api.call_rpc("search_players", {"p_query": query.strip_edges()})


func profile(user_id: String) -> Dictionary:
	return await api.call_rpc("get_player_profile", {"p_user": user_id})


func send_request(user_id: String) -> Dictionary:
	var r := await api.call_rpc("send_friend_request", {"p_to": user_id})
	if r["ok"]:
		var accepted: bool = (r["data"] as Dictionary).get("status", "") == "accepted"
		_tell(user_id, "friend_accepted" if accepted else "friend_request", accepted)
		await refresh()
	return r


func respond(request_id: int, user_id: String, accept: bool) -> Dictionary:
	var r := await api.call_rpc("respond_friend_request", {"p_request_id": request_id, "p_accept": accept})
	if r["ok"]:
		_tell(user_id, "friend_accepted" if accept else "friend_request", accept)
		await refresh()
	return r


func cancel(request_id: int, user_id: String) -> Dictionary:
	var r := await api.call_rpc("cancel_friend_request", {"p_request_id": request_id})
	if r["ok"]:
		_tell(user_id, "friend_request", false)
		await refresh()
	return r


func remove(user_id: String) -> Dictionary:
	var r := await api.call_rpc("remove_friend", {"p_other": user_id})
	if r["ok"]:
		_tell(user_id, "friends_changed", true)
		await refresh()
	return r


func block(user_id: String) -> Dictionary:
	var r := await api.call_rpc("block_player", {"p_other": user_id})
	if r["ok"]:
		_tell(user_id, "friends_changed", true)
		await refresh()
		await refresh_blocks()
	return r


func unblock(user_id: String) -> Dictionary:
	var r := await api.call_rpc("unblock_player", {"p_other": user_id})
	if r["ok"]:
		await refresh_blocks()
	return r


func is_friend(user_id: String) -> bool:
	return friends.any(func(f: Dictionary) -> bool: return f["user_id"] == user_id)


## friendship changed -> the hub reloads both friend lists (presence); otherwise a hint only.
func _tell(user_id: String, kind: String, friendship_changed: bool) -> void:
	if hub == null:
		return
	if friendship_changed:
		hub.send("friends.changed", {"other": user_id})
	if kind != "friends_changed":
		hub.send("poke", {"to": user_id, "kind": kind})


static func display(row: Dictionary) -> String:
	return "%s#%d" % [String(row.get("display_name", "?")), int(row.get("tag", 0))]
