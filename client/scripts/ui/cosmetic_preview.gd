class_name CosmeticPreview
extends Control
## Picture of one cosmetic item (store, collection, details): dice face, a pawn in all
## four colours, a mini board, an avatar with its frame / effect, a styled name, an
## emote bubble or a badge. Drawn from the same code the match and profile use.

var item := {}            # catalog entry {id, category, rarity, ...}
var locked := false
var _phase := 0.0
var _name_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 180)


func _ready() -> void:
	if String(item.get("category", "")) == "name":
		_name_label = Label.new()
		_name_label.text = Settings.display_name()
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_name_label.add_theme_font_override("font", UiTheme.display_font())
		_name_label.add_theme_font_size_override("font_size", 40)
		_name_label.add_theme_color_override("font_color", UiPalette.INK_900)
		Cosmetics.style_name(_name_label, String(item.get("id", "")))
		add_child(_name_label)
	modulate = Color(1, 1, 1, 0.55) if locked else Color.WHITE


func _process(delta: float) -> void:
	var cat := String(item.get("category", ""))
	if (cat == "effect" or cat == "frame") and not Settings.get_value("reduced_motion") and is_visible_in_tree():
		_phase += delta
		queue_redraw()


func _draw() -> void:
	var id := String(item.get("id", ""))
	var c := size * 0.5
	var s := minf(size.x, size.y)
	match String(item.get("category", "")):
		"dice":
			var t := Cosmetics.dice_face(id, 6)
			draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.36, Vector2(s, s) * 0.72), false)
		"pawns":
			var colors := ["red", "green", "yellow", "blue"]
			for i in 4:
				var t := Cosmetics.pawn_texture(id, colors[i])
				var w := s * 0.42
				var x := size.x * 0.5 + (i - 1.5) * w * 0.82
				draw_texture_rect(t, Rect2(Vector2(x - w * 0.5, c.y - w * 0.55), Vector2(w, w)), false)
		"board":
			var p := Cosmetics.board_palette(id)
			var r := Rect2(c - Vector2(s, s) * 0.4, Vector2(s, s) * 0.8)
			var sb := StyleBoxFlat.new()
			sb.bg_color = p["board"]
			sb.set_corner_radius_all(int(s * 0.08))
			draw_style_box(sb, r)
			var cell := r.size.x / 5.0
			for y in 5:
				for x in 5:
					if (x + y) % 2 == 0 and not (x == 2 and y == 2):
						var cr := Rect2(r.position + Vector2(x, y) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6))
						var cb := StyleBoxFlat.new()
						cb.bg_color = p["cell"]
						cb.border_color = p["edge"]
						cb.set_border_width_all(2)
						cb.set_corner_radius_all(int(cell * 0.2))
						draw_style_box(cb, cr)
			Cosmetics._star(self, r.get_center(), cell * 0.45, p["star"])
			var corners := [["red", Vector2(0, 0)], ["green", Vector2(4, 0)], ["yellow", Vector2(4, 4)], ["blue", Vector2(0, 4)]]
			for k: Array in corners:
				draw_circle(r.position + (k[1] as Vector2) * cell + Vector2(cell, cell) * 0.5, cell * 0.32, UiPalette.player(k[0]))
		"frame", "effect":
			var rr := s * 0.3
			if item["category"] == "effect":
				Cosmetics.draw_effect(self, id, c, rr, _phase)
			draw_circle(c, rr, UiPalette.MANGO_500)
			draw_circle(c + Vector2(0, -rr * 0.15), rr * 0.82, UiPalette.MANGO_300)
			if item["category"] == "frame":
				Cosmetics.draw_frame(self, id, c, rr, _phase)
		"emotes":
			var phrase := tr("EMOTE_" + String(Cosmetics.phrases(id)[1]).to_upper())
			var f := UiTheme.display_font()
			var w := f.get_string_size(phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 48
			var br := Rect2(c - Vector2(w * 0.5, 40), Vector2(w, 80))
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = _emote_color(id)
			sb2.set_corner_radius_all(36)
			draw_style_box(sb2, br)
			draw_colored_polygon(PackedVector2Array([br.position + Vector2(36, 76), br.position + Vector2(64, 76), br.position + Vector2(30, 104)]), _emote_color(id))
			draw_string(f, br.position + Vector2(24, 52), phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiPalette.INK_900)
		"badge":
			var col: Color = Cosmetics.RARITY_COLORS.get(String(item.get("rarity", "common")), UiPalette.MANGO_500)
			draw_circle(c, s * 0.3, col.darkened(0.25))
			draw_circle(c, s * 0.26, col)
			Cosmetics._star(self, c, s * 0.17, Color("#fff8e6"))


static func _emote_color(id: String) -> Color:
	match id:
		"emotes_cheer":
			return Color("#ffe1a8")
		"emotes_star":
			return Color("#e9d5ff")
	return UiPalette.CREAM_50


## Small rarity chip (visual class only).
static func rarity_chip(rarity: String) -> PanelContainer:
	var col: Color = Cosmetics.RARITY_COLORS.get(rarity, UiPalette.INK_500)
	return UiKit.chip(TranslationServer.translate("RARITY_" + rarity.to_upper()), Color(col, 0.22), col.darkened(0.25))
