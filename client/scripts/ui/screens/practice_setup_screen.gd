class_name PracticeSetupScreen
extends AppScreen
## Offline match setup: 2 or 4 players, the local player's colour, and every
## other seat as "Bot" or "Player" (pass and play on one phone). Bots are
## always labelled. The board turns so that the chosen colour sits bottom-left.
## 2 players: the opponent always takes the opposite colour (K-08):
## red–yellow or green–blue.
## params: players (2 | 4), mode ("bots" | "local"); `config` restores a setup.

signal start_requested(config: Dictionary)

const OPPOSITE := {"red": "yellow", "yellow": "red", "green": "blue", "blue": "green"}

var config := {}          # {players, seats: [{color, role, kind, name}]}
var _players := 2
var _my_color := "red"
var _roles := {}          # color -> "you" | "player" | "bot"
var _other := "bot"       # default role of the other seats
var _rows: VBoxContainer
var _colors_row: HBoxContainer
var _color_note: Label
var _seg_2: Button
var _seg_4: Button
var _play: Button
var _note: Label


func _title() -> String:
	return tr("SETUP_HEADER")


func _build() -> void:
	_players = int(params.get("players", Settings.get_value("last_players")))
	if _players != 2 and _players != 4:
		_players = 2
	_my_color = String(Settings.get_value("last_color"))
	_other = "player" if params.get("mode", "bots") == "local" else "bot"
	if not config.is_empty():
		_players = int(config.get("players", 2))
		for s: Dictionary in config.get("seats", []):
			_roles[s["color"]] = s.get("role", "bot")
			if s.get("role", "") == "you":
				_my_color = s["color"]
	else:
		for c: String in BoardGeometry.COLORS:
			_roles[c] = _other
	if not BoardGeometry.COLORS.has(_my_color):
		_my_color = "red"

	var color_card := card(tr("SETUP_COLOR"))
	_colors_row = UiKit.hbox(UiTokens.S2)
	_colors_row.alignment = BoxContainer.ALIGNMENT_CENTER
	color_card.add_child(_colors_row)
	_color_note = wrapped(UiKit.label(tr("SETUP_COLOR_NOTE_2P"), "InkDimLabel"))
	color_card.add_child(_color_note)

	var seats_card := card(tr("SETUP_SEATS"))
	var seg := UiKit.hbox(UiTokens.S1)
	_seg_2 = UiKit.button(tr("SETUP_TWO_PLAYERS"), "secondary", "s")
	_seg_4 = UiKit.button(tr("SETUP_FOUR_PLAYERS"), "secondary", "s")
	for b: Button in [_seg_2, _seg_4]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		seg.add_child(b)
	_seg_2.pressed.connect(func() -> void: _set_players(2))
	_seg_4.pressed.connect(func() -> void: _set_players(4))
	seats_card.add_child(seg)
	_rows = UiKit.vbox(UiTokens.S1)
	seats_card.add_child(_rows)
	_note = wrapped(UiKit.label("", "InkDimLabel"))
	seats_card.add_child(_note)
	content.add_child(wrapped(UiKit.label(tr("SETUP_RULES"), "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER)))

	_play = UiKit.button(tr("SETUP_PLAY"), "primary", "xl")
	_play.pressed.connect(_start)
	footer.add_child(_play)
	_refresh()


func _colors() -> Array[String]:
	if _players == 4:
		return BoardGeometry.COLORS
	var pair: Array[String] = []
	for c: String in BoardGeometry.COLORS:   # clockwise order, as the engine expects
		if c == _my_color or c == OPPOSITE[_my_color]:
			pair.append(c)
	return pair


func _set_players(n: int) -> void:
	_players = n
	_refresh()


func _set_color(c: String) -> void:
	_my_color = c
	_refresh()


func _refresh() -> void:
	for c: String in BoardGeometry.COLORS:
		if _roles.get(c, "") == "you" or not _roles.has(c):
			_roles[c] = _other
	_roles[_my_color] = "you"
	_seg_2.theme_type_variation = "PrimaryButton" if _players == 2 else "SecondaryButton"
	_seg_4.theme_type_variation = "PrimaryButton" if _players == 4 else "SecondaryButton"
	_color_note.visible = _players == 2
	for child: Node in _colors_row.get_children():
		child.queue_free()
	for c: String in BoardGeometry.COLORS:
		_colors_row.add_child(_color_button(c))
	for child: Node in _rows.get_children():
		child.queue_free()
	for color: String in _colors():
		_rows.add_child(_seat_row(color))
	var humans := 0
	for c: String in _colors():
		if _roles[c] != "bot":
			humans += 1
	_note.text = tr("SETUP_NOTE_HOTSEAT") if humans > 1 else tr("SETUP_NOTE_BOTS")


func _color_button(color: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(120, 120)
	b.tooltip_text = tr("COLOR_" + color.to_upper())
	var mine := color == _my_color
	var opponent: bool = _players == 2 and color == OPPOSITE[_my_color]
	b.draw.connect(func() -> void:
		var c := b.size * 0.5
		if mine:
			b.draw_circle(c, 56, UiPalette.MANGO_500)
			b.draw_circle(c, 49, UiPalette.CREAM_50)
		elif opponent:
			b.draw_arc(c, 52, 0, TAU, 48, UiPalette.player(color, "light"), 4, true)
		b.draw_circle(c + Vector2(0, 4), 42, UiPalette.player(color, "dark"))
		b.draw_circle(c, 42, UiPalette.player(color))
		BoardView.draw_symbol(b, UiPalette.PLAYER[color]["symbol"], c, 15, Color(1, 1, 1, 0.92)))
	b.pressed.connect(func() -> void: _set_color(color))
	return b


func _seat_row(color: String) -> Control:
	var row := UiKit.hbox(UiTokens.S2)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(56, 56)
	dot.draw.connect(func() -> void:
		dot.draw_circle(Vector2(28, 28), 26, UiPalette.player(color))
		BoardView.draw_symbol(dot, UiPalette.PLAYER[color]["symbol"], Vector2(28, 28), 11, Color(1, 1, 1, 0.9)))
	row.add_child(dot)
	var role: String = _roles[color]
	var name := UiKit.label(Settings.display_name() if role == "you" else tr("COLOR_" + color.to_upper()), "InkBodyLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name)
	var b := UiKit.button(tr("ROLE_" + role.to_upper()), "mint" if role == "you" else "secondary", "s")
	if role == "bot":
		b.icon = UiTheme.icon("robot")
		b.add_theme_constant_override("icon_max_width", 40)
		b.add_theme_color_override("icon_normal_color", UiPalette.INK_700)
		b.add_theme_color_override("icon_pressed_color", UiPalette.INK_700)
		b.add_theme_color_override("icon_hover_color", UiPalette.INK_700)
	b.custom_minimum_size = Vector2(230, UiTokens.BUTTON_S)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(func() -> void: _cycle_role(color))
	row.add_child(b)
	return row


func _cycle_role(color: String) -> void:
	if _roles[color] == "you":
		return
	_roles[color] = "player" if _roles[color] == "bot" else "bot"
	_refresh()


func _build_config() -> Dictionary:
	var seats: Array = []
	var player_no := 1
	var bot_no := 1
	for c: String in _colors():
		var role: String = _roles.get(c, "bot")
		var name := ""
		match role:
			"you":
				name = Settings.display_name()
			"player":
				player_no += 1
				name = tr("NAME_PLAYER_N") % player_no
			_:
				name = tr("NAME_BOT_N") % bot_no
				bot_no += 1
		seats.append({"color": c, "role": role, "kind": "bot" if role == "bot" else "human", "name": name})
	return {"players": _players, "seats": seats}


func _start() -> void:
	Settings.set_value("last_players", _players)
	Settings.set_value("last_color", _my_color)
	start_requested.emit(_build_config())
