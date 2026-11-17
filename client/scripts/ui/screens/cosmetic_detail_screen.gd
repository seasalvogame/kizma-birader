class_name CosmeticDetailScreen
extends AppScreen
## One cosmetic item: big preview, name, description, rarity, where it is used, and
## whether I own it (with how I got it) or how it can be obtained.

var item_id := ""
var _box: VBoxContainer


func _title() -> String:
	return tr("COS_DETAIL_TITLE")


func _build() -> void:
	item_id = String(params.get("id", ""))
	_box = UiKit.vbox(UiTokens.S2)
	content.add_child(_box)
	Online.cosmetics.changed.connect(_render)
	_render()


func _render() -> void:
	if not is_inside_tree():
		return
	for c: Node in _box.get_children():
		c.queue_free()
	var x := Online.cosmetics.item(item_id)
	if x.is_empty():
		_box.add_child(wrapped(UiKit.label(tr("COS_NOT_FOUND"), "DimLabel")))
		return
	var owned := Online.cosmetics.owned(item_id)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CreamCard"
	var col := UiKit.vbox(UiTokens.S1)
	panel.add_child(col)
	var prev := CosmeticPreview.new()
	prev.item = x
	prev.custom_minimum_size = Vector2(0, 320)
	col.add_child(prev)
	var name := UiKit.label(Cosmetics.item_name(item_id), "InkH2Label", HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(name)
	var chips := UiKit.hbox(UiTokens.S1)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_child(CosmeticPreview.rarity_chip(String(x.get("rarity", "common"))))
	chips.add_child(UiKit.chip(tr("COS_CAT_" + String(x["category"]).to_upper()), Color(0, 0, 0, 0.08), UiPalette.INK_700))
	col.add_child(chips)
	var desc := Cosmetics.item_desc(item_id)
	if desc != "":
		col.add_child(wrapped(UiKit.label(desc, "InkBodyLabel", HORIZONTAL_ALIGNMENT_CENTER)))
	col.add_child(UiKit.label(tr("COS_USAGE_" + String(x.get("usage", "match")).replace("+", "_").to_upper()), "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	if owned:
		col.add_child(UiKit.chip(tr("COS_OWNED") + " · " + Cosmetics.source_text(Online.cosmetics.source_of(item_id)),
			Color(UiPalette.MINT_500, 0.25), UiPalette.INK_900))
	else:
		col.add_child(wrapped(UiKit.label(how_to_get(x), "InkBodyLabel", HORIZONTAL_ALIGNMENT_CENTER)))
	col.add_child(wrapped(UiKit.label(tr("COS_NO_EFFECT"), "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER)))
	_box.add_child(panel)


## "Mağazada 1.200 Altın", "Seviye 15 ödülü", both, or "yakında".
static func how_to_get(x: Dictionary) -> String:
	var parts: PackedStringArray = []
	if x.get("purchasable", false) and x.get("price") != null:
		parts.append(TranslationServer.translate("COS_HOW_BUY") % [int(x["price"]),
			TranslationServer.translate("CURRENCY_" + String(x.get("currency", "gold")).to_upper())])
	if x.get("earnable", false) and x.has("source"):
		parts.append(Cosmetics.source_text(String(x["source"])))
	return " · ".join(parts) if not parts.is_empty() else TranslationServer.translate("COS_HOW_NONE")
