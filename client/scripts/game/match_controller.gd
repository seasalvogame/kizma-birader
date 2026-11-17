class_name MatchController
extends Node
## Runs one offline match: owns the MatchSession (rules engine), the turn
## timers (roll 10 s / move 12 s from the ruleset), bot and autopilot turns
## and the K-20 auto-move. No UI code: the match screen listens to `applied`,
## animates the events and calls view_done() when it is ready for more.
## Dice: device RNG offline; tests inject scripted dice.

signal applied(events: Array, state: Dictionary)
signal timer_started(seat: int, phase: String, seconds: float)
signal finished(state: Dictionary)

const AUTOPILOT_DELAY := 1.5
const AUTO_MOVE_DELAY := 0.4

var engine := GameEngine.new()
var session: MatchSession
var seats: Array = []           # [{color, kind: "human"|"bot", name}]
var bot_delay := Vector2(0.7, 1.3)
var auto_single_move := true
var _timer: Timer
var _busy := true               # the view is animating
var _req := 0
var _rng := RandomNumberGenerator.new()
var _deadline := 0.0
var _phase_seconds := 0.0
var _paused_left := 0.0


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)


## config: {players: 2|4, seats: [{color, kind, name}], first_seat?: int}
func start(config: Dictionary, dice: DiceSource = null) -> bool:
	seats = config.get("seats", [])
	var spec: Array = []
	for s: Dictionary in seats:
		spec.append({"color": s["color"], "kind": s.get("kind", "human")})
	var options := {"seats": spec, "ruleset": config.get("ruleset", {})}
	if config.has("first_seat"):
		options["first_seat"] = int(config["first_seat"])
	else:
		_rng.randomize()
		options["first_seat"] = _rng.randi_range(0, spec.size() - 1)
	var state := GameState.create(options, engine.board)
	if state.is_empty():
		push_error("match start: " + GameState.last_error)
		return false
	session = MatchSession.new(state, engine, dice if dice != null else DiceSource.local())
	auto_single_move = bool(Settings.get_value("auto_single_move"))
	_busy = false
	_schedule()
	return true


func state() -> Dictionary:
	return session.state if session != null else {}


func is_human_turn(seat: int = -1) -> bool:
	if session == null or state()["turn"]["phase"] == "game_over":
		return false
	var current := int(state()["turn"]["seat"])
	if seat >= 0 and seat != current:
		return false
	return seats[current]["kind"] == "human" and not state()["players"][current]["autopilot"]


func seconds_left() -> float:
	return maxf(0.0, _deadline - Time.get_ticks_msec() / 1000.0)


func phase_seconds() -> float:
	return _phase_seconds


## Local player taps the dice (also takes control back from autopilot).
func human_roll(seat: int) -> Dictionary:
	if _busy or session == null or seats[seat]["kind"] != "human":
		return {"ok": false, "error": "BUSY"}
	return _submit({"type": "roll", "seat": seat, "turn_id": state()["turn"]["turn_id"]})


func human_move(seat: int, pawn: int) -> Dictionary:
	if _busy or session == null or seats[seat]["kind"] != "human":
		return {"ok": false, "error": "BUSY"}
	return _submit({"type": "move", "seat": seat, "turn_id": state()["turn"]["turn_id"], "pawn": pawn})


func leave(seat: int) -> Dictionary:
	if session == null:
		return {"ok": false, "error": "NO_MATCH"}
	return _submit({"type": "leave", "seat": seat})


## The view finished animating the last events.
func view_done() -> void:
	_busy = false
	_schedule()


func stop() -> void:
	_timer.stop()
	session = null


## Offline only: the match menu freezes the clock.
func pause() -> void:
	if _timer.is_stopped():
		return
	_paused_left = _timer.time_left
	_timer.stop()


func resume() -> void:
	if _paused_left > 0.0 and session != null and not _busy:
		_deadline = Time.get_ticks_msec() / 1000.0 + _paused_left
		_timer.start(_paused_left)
	_paused_left = 0.0


func is_paused() -> bool:
	return _paused_left > 0.0


func _submit(action: Dictionary) -> Dictionary:
	_timer.stop()
	_req += 1
	var r := session.submit("c-%d" % _req, action)
	if r["ok"]:
		_busy = true
		applied.emit(r["events"], state())
	return r


func _schedule() -> void:
	if session == null or _busy:
		return
	var s := state()
	if s["turn"]["phase"] == "game_over":
		_timer.stop()
		finished.emit(s)
		return
	var seat := int(s["turn"]["seat"])
	var phase: String = s["turn"]["phase"]
	if seats[seat]["kind"] == "bot":
		_start_timer(_rng.randf_range(bot_delay.x, bot_delay.y) * (0.5 if phase == "move" else 1.0), false)
	elif s["players"][seat]["autopilot"]:
		_start_timer(AUTOPILOT_DELAY, false)
	elif phase == "move" and auto_single_move and MoveValidator.is_single_option(s["legal"]):
		_start_timer(AUTO_MOVE_DELAY, false)
	else:
		var seconds := float(s["ruleset"]["turn_roll_seconds" if phase == "roll" else "turn_move_seconds"])
		_start_timer(seconds, true)
		timer_started.emit(seat, phase, seconds)


func _start_timer(seconds: float, is_turn_timer: bool) -> void:
	_phase_seconds = seconds if is_turn_timer else 0.0
	_deadline = Time.get_ticks_msec() / 1000.0 + seconds
	_timer.start(maxf(seconds, 0.01))


func _on_timer() -> void:
	if session == null or _busy:
		return
	var s := state()
	if s["turn"]["phase"] == "game_over":
		return
	var seat := int(s["turn"]["seat"])
	var turn_id := int(s["turn"]["turn_id"])
	if seats[seat]["kind"] == "bot":
		if s["turn"]["phase"] == "roll":
			_submit({"type": "roll", "seat": seat, "turn_id": turn_id})
		else:
			_submit({"type": "move", "seat": seat, "turn_id": turn_id, "pawn": int(BotPolicy.choose(s, engine.board)["pawn"])})
	elif not s["players"][seat]["autopilot"] and s["turn"]["phase"] == "move" and auto_single_move \
			and MoveValidator.is_single_option(s["legal"]) and _phase_seconds == 0.0:
		# K-20: the only possible move is played for the player (not a timeout).
		_submit({"type": "move", "seat": seat, "turn_id": turn_id, "pawn": int((s["legal"] as Array)[0]["pawn"])})
	else:
		# Turn timer ran out, or autopilot: the engine plays (counts as a timeout).
		_submit({"type": "timeout", "seat": seat, "turn_id": turn_id})
