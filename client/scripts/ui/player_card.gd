class_name PlayerCard
extends HBoxContainer
## Player info next to the board (UI_UX_DESIGN_SYSTEM §5.3, screens §14.1):
## avatar (colour ring, countdown ring), name, finished-pawn dots, status.
## Bots always carry a visible BOT chip. `mirrored` puts the avatar on the
## right (cards in the right-hand corners).

var seat := 0
var color := "red"
var avatar: Avatar
var name_label: Label
var status_label: Label
var _dots: Control
var _finished := 0
var _bot_chip: Control
var _turn_tween: Tween
var _turn_active := false


func setup(p_seat: int, p_color: String, display_name: String, bot: bool, mirrored: bool, big: bool, cosmetics: Dictionary = {}) -> void:
	seat = p_seat
	color = p_color
	add_theme_constant_override("separation", UiTokens.S2)
	alignment = BoxContainer.ALIGNMENT_END if mirrored else BoxContainer.ALIGNMENT_BEGIN
	avatar = Avatar.new()
	var s := UiTokens.AVATAR_M if big else 92
	avatar.custom_minimum_size = Vector2(s, s)
	avatar.setup(display_name, color, bot)
	if not bot:
		avatar.set_cosmetics(String(cosmetics.get("frame", "frame_none")), String(cosmetics.get("effect", "effect_none")))
	var text := UiKit.vbox(2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_row := UiKit.hbox(UiTokens.S1)
	name_row.alignment = BoxContainer.ALIGNMENT_END if mirrored else BoxContainer.ALIGNMENT_BEGIN
	name_label = UiKit.label(display_name, "H3Label")
	if not bot:
		Cosmetics.style_name(name_label, String(cosmetics.get("name", "name_plain")))
	if big:
		name_label.add_theme_font_size_override("font_size", UiTokens.H3 + 2)
	# Long names shorten with an ellipsis instead of widening the card.
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(60, 0)
	name_row.add_child(name_label)
	text.add_child(name_row)
	var meta := UiKit.hbox(UiTokens.S1)
	meta.alignment = name_row.alignment
	_dots = Control.new()
	_dots.custom_minimum_size = Vector2(4 * 22, 22)
	_dots.draw.connect(_draw_dots)
	status_label = UiKit.label("", "CaptionLabel")
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(_dots)
	if bot:
		# Bots are always labelled (Phase 2 decision): the chip sits by the dots.
		_bot_chip = UiKit.chip(tr("MATCH_BOT_TAG"), Color(1, 1, 1, 0.14))
		meta.add_child(_bot_chip)
	meta.add_child(status_label)
	if mirrored:
		for child: Node in meta.get_children():
			meta.move_child(child, 0)
	text.add_child(meta)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mirrored:
		add_child(text)
		add_child(avatar)
		for l: Label in [name_label, status_label]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		add_child(avatar)
		add_child(text)


func set_finished_pawns(count: int) -> void:
	_finished = count
	_dots.queue_redraw()


func _draw_dots() -> void:
	for i in 4:
		var p := Vector2(11 + i * 22, 11)
		if i < _finished:
			_dots.draw_circle(p, 9, UiPalette.player(color))
			_dots.draw_arc(p, 9, 0, TAU, 20, Color.WHITE, 3, true)
		else:
			_dots.draw_circle(p, 9, Color(1, 1, 1, 0.18))


func set_status(text: String, warn: bool = false) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color("#ffb3b5") if warn else UiPalette.ON_NIGHT_DIM)


func set_turn(active: bool, progress: float = -1.0, urgent: bool = false) -> void:
	avatar.progress = progress if active else -1.0
	avatar.urgent = urgent
	if active == _turn_active:
		return
	_turn_active = active
	var target := Vector2(1.04, 1.04) if active else Vector2.ONE
	avatar.pivot_offset = avatar.size * 0.5
	if _turn_tween != null:
		_turn_tween.kill()
	if Settings.get_value("reduced_motion"):
		avatar.scale = target
		return
	if avatar.scale != target:
		_turn_tween = create_tween()
		_turn_tween.tween_property(avatar, "scale", target, UiTokens.duration(UiTokens.T_FAST)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func set_out(rank: int, left: bool) -> void:
	avatar.rank = rank
	avatar.dim = left
	avatar.queue_redraw()
	modulate.a = 0.55 if left else 1.0
