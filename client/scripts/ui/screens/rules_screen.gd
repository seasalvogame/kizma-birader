class_name RulesScreen
extends AppScreen
## "How to play": the rules of classic_v1 in plain words. By decision K-56 the
## 1..5 limit after two sixes in a row is deliberately not described.

const KEYS := ["RULES_GOAL", "RULES_ENTER", "RULES_SIX", "RULES_CAPTURE", "RULES_SAFE", "RULES_FINISH", "RULES_TIME", "RULES_END"]


func _title() -> String:
	return tr("RULES_TITLE")


func _build() -> void:
	var col := card()
	col.add_theme_constant_override("separation", UiTokens.S3)
	for i in KEYS.size():
		var row := UiKit.hbox(UiTokens.S2)
		var n := UiKit.label(str(i + 1), "InkH3Label", HORIZONTAL_ALIGNMENT_CENTER)
		n.custom_minimum_size = Vector2(52, 52)
		n.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		n.add_theme_color_override("font_color", UiPalette.MANGO_700)
		row.add_child(n)
		var t := wrapped(UiKit.label(tr(KEYS[i]), "InkBodyLabel"))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		col.add_child(row)
