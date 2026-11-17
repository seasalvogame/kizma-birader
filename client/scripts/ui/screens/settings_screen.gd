class_name SettingsScreen
extends AppScreen
## Settings (UI_SCREEN_SPECIFICATIONS §23): only options that really work
## today. Language switches immediately; sound is announced as coming.

signal language_changed

const GAME_KEYS := ["auto_single_move", "fast_animations", "color_symbols", "vibration", "reduced_motion"]


func _title() -> String:
	return tr("SETTINGS_TITLE")


func _build() -> void:
	var lang := card(tr("SETTINGS_LANGUAGE"))
	var seg := UiKit.hbox(UiTokens.S1)
	var tr_on := TranslationServer.get_locale().begins_with("tr")
	for pair: Array in [["tr", "Türkçe"], ["en", "English"]]:
		var on: bool = (pair[0] == "tr") == tr_on
		var b := UiKit.button(pair[1], "primary" if on else "secondary", "s")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		var code: String = pair[0]
		b.pressed.connect(func() -> void:
			if not on:
				Settings.set_value("locale", code)
				language_changed.emit())
		seg.add_child(b)
	lang.add_child(seg)
	var game := card(tr("SETTINGS_GAME"))
	for key: String in GAME_KEYS:
		game.add_child(_toggle(key))
	game.add_child(wrapped(UiKit.label(tr("SETTINGS_SOUND_SOON"), "InkDimLabel")))
	var rules := MenuCard.new()
	rules.wide = true
	rules.icon_name = "book"
	rules.title = tr("SETTINGS_RULES")
	rules.subtitle = tr("SETUP_RULES")
	rules.pressed.connect(func() -> void: navigate.emit("rules", {}))
	content.add_child(rules)
	var version := UiKit.label(tr("SETTINGS_VERSION") % ProjectSettings.get_setting("application/config/version", "?"), "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(version)


## One row: name on the left, an On / Off pill on the right.
func _toggle(key: String) -> Control:
	var row := UiKit.hbox(UiTokens.S2)
	var name := wrapped(UiKit.label(tr("SETTING_" + key.to_upper()), "InkBodyLabel"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var b := UiKit.button("", "secondary", "s")
	b.custom_minimum_size = Vector2(176, UiTokens.BUTTON_S)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var refresh := func() -> void:
		var on := bool(Settings.get_value(key))
		b.text = tr("ON") if on else tr("OFF")
		b.theme_type_variation = "MintButton" if on else "SecondaryButton"
	refresh.call()
	b.pressed.connect(func() -> void:
		Settings.set_value(key, not Settings.get_value(key))
		refresh.call())
	row.add_child(b)
	return row
