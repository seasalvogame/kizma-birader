class_name WalletBar
extends HBoxContainer
## A display-only view of the authenticated player's existing wallet row.
## It hides while there is no trusted value instead of substituting sample data.

const GAP := 8


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	if Online.profile != null:
		Online.profile.changed.connect(_refresh)
	call_deferred("_refresh")


func _refresh() -> void:
	if not is_inside_tree():
		return
	for child: Node in get_children():
		child.queue_free()
	var wallet: Dictionary = Online.profile.wallet if Online.profile != null else {}
	visible = not wallet.is_empty()
	if not visible:
		return
	add_child(CurrencyPill.new("gold", int(wallet.get("coins", 0))))
	add_child(CurrencyPill.new("gems", int(wallet.get("gems", 0))))


class CurrencyPill:
	extends Control
	var currency := "gold"
	var amount := 0

	func _init(kind: String, value: int) -> void:
		currency = kind
		amount = value
		custom_minimum_size = Vector2(124, 52)
		tooltip_text = str(maxi(0, amount))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var bg := Color("#fff0bf") if currency == "gold" else Color("#e7dcff")
		var edge := UiPalette.GOLD_700 if currency == "gold" else Color("#6845bd")
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.border_color = Color(edge, 0.45)
		box.set_border_width_all(2)
		box.set_corner_radius_all(26)
		box.shadow_color = Color(UiPalette.CREAM_SHADOW, 0.18)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 3)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var c := Vector2(25, size.y * 0.5)
		if currency == "gold":
			draw_circle(c, 14, UiPalette.GOLD_500)
			draw_arc(c, 14, 0, TAU, 24, UiPalette.GOLD_700, 3, true)
			draw_circle(c - Vector2(4, 4), 3, Color(1, 1, 1, 0.72))
		else:
			var r := 15.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.74, 0), c + Vector2(0, r), c + Vector2(-r * 0.74, 0)]), Color("#8a62e8"))
			draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.74, 0), c + Vector2(0, r), c + Vector2(-r * 0.74, 0), c + Vector2(0, -r)]), Color("#53308f"), 2, true)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(1, 1, 1, 0.5), 2, true)
		var f := UiTheme.body_font(900)
		draw_string(f, Vector2(47, 34), _compact(amount), HORIZONTAL_ALIGNMENT_LEFT, size.x - 53, 22, UiPalette.INK_900)

	func _compact(value: int) -> String:
		var safe := maxi(0, value)
		# A compact suffix is deliberate rather than clipping a real server
		# balance. The full authoritative value remains available as a tooltip.
		if safe >= 1000000:
			return "%.1fM" % (safe / 1000000.0)
		if safe >= 1000:
			return "%.1fK" % (safe / 1000.0)
		return str(safe)
