class_name MatchSession
extends RefCounted
## One match: current state + idempotency (NETWORK_PROTOCOL §7) — twin of
## server/game-engine/src/session.ts. A request id already processed for a
## seat returns the first result again and changes nothing. Dice are drawn
## only for actions the engine will accept, within the rule's bound (1..5
## after two sixes, GAME_RULES §6.2).

var state: Dictionary
var engine: GameEngine
var dice: DiceSource
var _seen := {}
var _order: Array[String] = []
var _memory := 1000


func _init(p_state: Dictionary, p_engine: GameEngine, p_dice: DiceSource) -> void:
	state = p_state
	engine = p_engine
	dice = p_dice


func submit(request_id: String, action: Dictionary) -> Dictionary:
	var key := "%d:%s" % [int(action.get("seat", -1)), request_id]
	if _seen.has(key):
		var previous: Dictionary = (_seen[key] as Dictionary).duplicate()
		previous["duplicate"] = true
		return previous
	var type := String(action.get("type", ""))
	var needs_dice: bool = type == "roll" or (type == "timeout" and state["turn"]["phase"] == "roll")
	var value := GameEngine.NO_DICE
	if _preflight(action) and needs_dice:
		value = dice.next(GameEngine.max_dice_value(state))
	var result := engine.apply(state, action, value)
	var out: Dictionary
	if result["ok"]:
		state = result["state"]
		out = {"ok": true, "events": result["events"], "duplicate": false, "version": int(state["version"])}
	else:
		out = {"ok": false, "error": result["error"], "events": [], "duplicate": false, "version": int(state["version"])}
	_seen[key] = out
	_order.append(key)
	if _order.size() > _memory:
		_seen.erase(_order.pop_front())
	return out


func _preflight(action: Dictionary) -> bool:
	var t: Dictionary = state["turn"]
	var seat := int(action.get("seat", -1))
	var players: Array = state["players"]
	return t["phase"] != "game_over" and action.get("type", "") != "leave" and seat == int(t["seat"]) \
		and int(action.get("turn_id", -1)) == int(t["turn_id"]) and seat >= 0 and seat < players.size() \
		and players[seat]["status"] == "active" and (action.get("type", "") != "roll" or t["phase"] == "roll")
