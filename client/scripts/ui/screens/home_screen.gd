class_name HomeScreen
extends AppScreen
## Main menu (UI_SCREEN_SPECIFICATIONS §3, prototype 03_ana_menu).
## Everything shown here works now: practice matches against bots or on one
## phone, the local profile and its real practice stats. Online features are
## labelled "SOON" and open honest info screens (no fake balances, no fake
## daily rewards).

var avatar: Avatar
var card_2p: PlayCard
var card_4p: PlayCard
var _invites: MenuCard


func _nav_tab() -> String:
	return "home"


func _build() -> void:
	content.add_child(_top_row())
	var cards := UiKit.hbox(UiTokens.S3)
	card_2p = _play_card(2, "SETUP_TWO_PLAYERS", Color("#3a7bf7"), Color("#7aa6ff"), Color("#1f4fb8"), 6)
	card_4p = _play_card(4, "SETUP_FOUR_PLAYERS", Color("#e5484d"), Color("#ff8a8d"), Color("#a8262b"), 4)
	cards.add_child(card_2p)
	cards.add_child(card_4p)
	content.add_child(cards)
	var tiles := UiKit.hbox(UiTokens.S3)
	var private_room := _tile("lock", "HOME_PRIVATE", "HOME_PRIVATE_SUB", false)
	private_room.pressed.connect(func() -> void: navigate.emit("room" if Online.room != null else "private", {}))
	var practice := _tile("robot", "HOME_PRACTICE", "HOME_PRACTICE_SUB", false)
	practice.pressed.connect(func() -> void: navigate.emit("setup", {"players": int(Settings.get_value("last_players")), "mode": "bots"}))
	tiles.add_child(private_room)
	tiles.add_child(practice)
	content.add_child(tiles)
	var online := MenuCard.new()
	online.wide = true
	online.icon_name = "globe"
	online.title = tr("HOME_ONLINE_TITLE")
	online.subtitle = tr("HOME_ONLINE_SUB")
	online.tint = UiPalette.MINT_500
	online.badge = tr("BETA")
	online.pressed.connect(func() -> void: navigate.emit("queue", {}))
	content.add_child(online)
	_invites = MenuCard.new()
	_invites.wide = true
	_invites.icon_name = "chat"
	_invites.title = tr("INVITES_TITLE")
	_invites.tint = UiPalette.MANGO_500
	_invites.pressed.connect(func() -> void: navigate.emit("invites", {}))
	content.add_child(_invites)
	_update_invites()
	Online.hub.invites_changed.connect(_update_invites)
	_stats_card()


func _top_row() -> Control:
	var row := UiKit.hbox(UiTokens.S2)
	var who := Button.new()
	who.flat = true
	who.focus_mode = Control.FOCUS_NONE
	who.mouse_filter = Control.MOUSE_FILTER_PASS
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.custom_minimum_size = Vector2(0, UiTokens.AVATAR_M)
	who.pressed.connect(func() -> void: navigate.emit("profile", {}))
	var inner := UiKit.hbox(UiTokens.S2)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar = Avatar.new()
	avatar.custom_minimum_size = Vector2(UiTokens.AVATAR_M, UiTokens.AVATAR_M)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.setup(Settings.display_name(), "yellow", false)
	avatar.ring_color = UiPalette.CREAM_50
	avatar.set_fill(int(Settings.get_value("profile_avatar")))
	inner.add_child(avatar)
	var names := UiKit.vbox(4)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UiKit.label(Settings.display_name(), "H3Label")
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(n)
	var chip := UiKit.chip(tr("HOME_GUEST"))
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(chip)
	inner.add_child(names)
	who.add_child(inner)
	row.add_child(who)
	var gear := UiKit.icon_button("gear", tr("SETTINGS_TITLE"))
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.pressed.connect(func() -> void: navigate.emit("settings", {}))
	row.add_child(gear)
	return row


func _play_card(players: int, title_key: String, base: Color, light: Color, dark: Color, dice: int) -> PlayCard:
	var c := PlayCard.new()
	c.title = tr(title_key)
	c.subtitle = tr("HOME_CARD_SUB")
	c.pill = tr("HOME_PLAY")
	c.base = base
	c.light = light
	c.dark = dark
	c.dice_value = dice
	c.pressed.connect(func() -> void: navigate.emit("modes", {"players": players}))
	return c


func _tile(icon: String, title_key: String, sub_key: String, soon: bool) -> MenuCard:
	var t := MenuCard.new()
	t.icon_name = icon
	t.title = tr(title_key)
	t.subtitle = tr(sub_key)
	t.soon = soon
	return t


func _stats_card() -> void:
	var col := card()
	var head := UiKit.hbox(UiTokens.S2)
	var title := UiKit.label(tr("HOME_STATS_TITLE"), "InkH3Label")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	col.add_child(head)
	var matches := int(Settings.get_value("stats_matches_2p")) + int(Settings.get_value("stats_matches_4p"))
	var wins := int(Settings.get_value("stats_wins_2p")) + int(Settings.get_value("stats_wins_4p"))
	var rate := "–" if matches == 0 else "%d%%" % roundi(100.0 * wins / matches)
	var row := UiKit.hbox(UiTokens.S2)
	for pair: Array in [[str(matches), "STAT_MATCHES"], [str(wins), "STAT_WINS"], [rate, "STAT_RATE"]]:
		var cell := UiKit.vbox(0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UiKit.label(pair[0], "InkH2Label", HORIZONTAL_ALIGNMENT_CENTER)
		v.add_theme_color_override("font_color", UiPalette.MANGO_700)
		cell.add_child(v)
		cell.add_child(UiKit.label(tr(pair[1]), "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(cell)
	col.add_child(row)
	col.add_child(wrapped(UiKit.label(tr("HOME_STATS_NOTE"), "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER)))


func _update_invites() -> void:
	if not is_instance_valid(_invites):
		return
	var n := Online.hub.open_invites().size()
	_invites.subtitle = tr("INVITES_COUNT") % n if n > 0 else tr("INVITES_NONE")
	_invites.badge = str(n) if n > 0 else ""
	_invites.refresh()
