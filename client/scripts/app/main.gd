extends Node
## App root and screen router (Phase 3.3). Keeps a navigation stack:
## the main tabs (home, friends, store, quests, ranking) replace the stack,
## every other screen is pushed. Android back pops (inside a match it opens
## the match menu instead). The UI lives in a full-screen Control that carries
## the shared theme.

const TABS := ["home", "friends", "store", "quests", "ranking"]

var ui: Control
var current: Control
var stack: Array[Dictionary] = []   # [{route, params}]


func _ready() -> void:
	ui = Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.theme()
	add_child(ui)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--no-ui":
			return
	go("home")
	Online.start_social()   # friends' status and invites (only if this device already has an account)


func route() -> String:
	return stack[-1]["route"] if not stack.is_empty() else ""


## Opens a screen. Tabs reset the stack; other routes are pushed.
func go(route_name: String, params: Dictionary = {}) -> void:
	if route_name in TABS:
		stack.clear()
	stack.append({"route": route_name, "params": params})
	_show(1)


## Back one screen (to home when the stack would be empty).
func back() -> void:
	if stack.size() > 1:
		stack.pop_back()
		_show(-1)
	elif route() != "home":
		stack = [{"route": "home", "params": {}}]
		_show(-1)


## Kept for tools and tests: start a match directly.
func show_match(config: Dictionary) -> void:
	go("match", {"config": config})


func _show(direction: int) -> void:
	var entry: Dictionary = stack[-1]
	var params: Dictionary = entry["params"]
	var screen: Control
	match String(entry["route"]):
		"home":
			screen = HomeScreen.new()
		"quests":
			screen = QuestsScreen.new()
		"achievements":
			screen = AchievementsScreen.new()
		"collection":
			screen = CollectionScreen.new()
		"cosmetic":
			screen = CosmeticDetailScreen.new()
		"ranking":
			screen = LeaderboardScreen.new()
		"store":
			screen = InfoScreen.new()
			params = {"kind": entry["route"]}
		"friends":
			screen = FriendsScreen.new()
		"search":
			screen = PlayerSearchScreen.new()
		"requests":
			screen = FriendRequestsScreen.new()
		"player":
			screen = PlayerProfileScreen.new()
		"invites":
			screen = InvitesScreen.new()
		"private":
			screen = PrivateRoomScreen.new()
		"room":
			screen = RoomLobbyScreen.new()
		"modes":
			screen = ModeSelectScreen.new()
		"queue":
			screen = OnlineQueueScreen.new()
		"setup":
			var setup := PracticeSetupScreen.new()
			if params.has("config"):
				setup.config = params["config"]
			setup.start_requested.connect(func(config: Dictionary) -> void:
				entry["params"] = {"config": config}   # back from the match restores this setup
				go("match", {"config": config}))
			screen = setup
		"match":
			screen = _match_screen(params["config"])
		"info":
			screen = InfoScreen.new()
		"profile":
			screen = ProfileScreen.new()
		"history":
			screen = MatchHistoryScreen.new()
		"match_detail":
			screen = MatchDetailScreen.new()
		"account":
			screen = AccountScreen.new()
		"settings":
			var settings := SettingsScreen.new()
			settings.language_changed.connect(func() -> void: _show(0))
			screen = settings
		"rules":
			screen = RulesScreen.new()
		_:
			screen = HomeScreen.new()
	if screen is AppScreen:
		var app := screen as AppScreen
		app.params = params
		app.navigate.connect(go)
		app.back_requested.connect(back)
	_swap(screen, direction)


func _match_screen(config: Dictionary) -> MatchScreen:
	var screen := MatchScreen.new()
	screen.config = config
	var in_room: bool = config.has("online") and (config["online"] as Dictionary).has("room")
	if not in_room:
		screen.exit_requested.connect(func() -> void:
			stack = [{"route": "home", "params": {}}]
			_show(-1))
	if in_room:
		# private room: "play again" and "exit" both go back to the room lobby
		var back_to_room := func() -> void:
			stack = [{"route": "home", "params": {}}, {"route": "private", "params": {}}]
			if Online.room != null:
				go("room")
			else:
				_show(-1)
		screen.restart_requested.connect(back_to_room)
		screen.exit_requested.connect(back_to_room)
	elif config.has("online"):
		# "Play again" online = back into the queue (a new opponent, a new match).
		screen.restart_requested.connect(func() -> void:
			stack = [{"route": "home", "params": {}}]
			go("queue"))
	else:
		screen.restart_requested.connect(func() -> void: _show(0))
	screen.match_over.connect(func(state: Dictionary) -> void: _record(config, state))
	return screen


## Local practice stats: only matches with a "you" seat.
func _record(config: Dictionary, state: Dictionary) -> void:
	if config.has("online"):
		return   # online results belong to the server (Supabase), not to local practice stats
	var seats: Array = config.get("seats", [])
	for i in seats.size():
		if seats[i].get("role", "") == "you":
			Settings.record_match(seats.size(), MatchScreen.place_of(state.get("ranks", []), i))
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	if current != null and current.has_method("handle_back") and current.call("handle_back"):
		return
	if route() == "home" and stack.size() <= 1:
		get_tree().quit()
		return
	back()


func _swap(screen: Control, direction: int) -> void:
	if current != null:
		current.queue_free()
	current = screen
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(screen)
	if not Settings.get_value("reduced_motion") and direction != 0:
		screen.modulate.a = 0.0
		screen.position.x = 28 * direction
		var t := screen.create_tween().set_parallel()
		t.tween_property(screen, "modulate:a", 1.0, UiTokens.T_BASE / 1000.0)
		t.tween_property(screen, "position:x", 0.0, UiTokens.T_BASE / 1000.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
