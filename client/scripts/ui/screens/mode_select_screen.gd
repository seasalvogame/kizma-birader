class_name ModeSelectScreen
extends AppScreen
## Game mode for 2 or 4 players: against bots (offline), pass and play on one
## phone, online quick match and private room (both marked SOON until the
## server exists; they open an honest info screen).

var players := 2


func _title() -> String:
	players = int(params.get("players", 2))
	return tr("MODE_TITLE") % tr("SETUP_TWO_PLAYERS" if players == 2 else "SETUP_FOUR_PLAYERS")


func _build() -> void:
	_row("robot", "MODE_BOTS", "MODE_BOTS_SUB", false, UiPalette.ON_NIGHT,
		func() -> void: navigate.emit("setup", {"players": players, "mode": "bots"}))
	_row("phone", "MODE_LOCAL", "MODE_LOCAL_SUB", false, UiPalette.ON_NIGHT,
		func() -> void: navigate.emit("setup", {"players": players, "mode": "local"}))
	_row("globe", "MODE_ONLINE", "MODE_ONLINE_SUB", true, UiPalette.MINT_500,
		func() -> void: navigate.emit("info", {"kind": "online"}))
	_row("lock", "MODE_PRIVATE", "MODE_PRIVATE_SUB", true, Color.WHITE,
		func() -> void: navigate.emit("info", {"kind": "private"}))


func _row(icon: String, title_key: String, sub_key: String, soon: bool, tint: Color, action: Callable) -> void:
	var c := MenuCard.new()
	c.wide = true
	c.icon_name = icon
	c.title = tr(title_key)
	c.subtitle = tr(sub_key)
	c.soon = soon
	c.tint = tint
	c.pressed.connect(action)
	content.add_child(c)
