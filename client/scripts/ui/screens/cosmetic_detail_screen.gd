class_name CosmeticDetailScreen
extends AppScreen
## One cosmetic item: big preview, name, description, rarity, where it is used, and
## whether I own it (with how I got it) or how it can be obtained.

var item_id := ""
var _box: VBoxContainer
var _busy := false
var _action_error := ""


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
	_add_action(col, x, owned)
	_box.add_child(panel)
	if _action_error != "":
		_box.add_child(wrapped(UiKit.label(_action_error, "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER)))


func _add_action(col: VBoxContainer, x: Dictionary, owned: bool) -> void:
	var category := String(x.get("category", ""))
	if owned and category != "badge":
		var equipped := Online.cosmetics.equipped(category) == item_id
		var equip := UiKit.button(tr("COS_EQUIPPED") if equipped else tr("COS_EQUIP"), "secondary" if equipped else "primary")
		equip.mouse_filter = Control.MOUSE_FILTER_PASS
		equip.disabled = equipped or _busy
		equip.pressed.connect(func() -> void: await _equip())
		col.add_child(equip)
		return
	if not owned and x.get("purchasable", false) and x.get("price") != null and bool(Online.cosmetics.catalog.get("store_enabled", false)):
		var buy := UiKit.button(tr("COS_BUY_FOR") % [int(x["price"]), tr("CURRENCY_" + String(x.get("currency", "gold")).to_upper())], "primary")
		buy.mouse_filter = Control.MOUSE_FILTER_PASS
		buy.disabled = _busy
		buy.pressed.connect(func() -> void: await _buy())
		col.add_child(buy)


func _buy() -> void:
	if _busy:
		return
	_busy = true
	var r := await Online.cosmetics.purchase(item_id)
	_busy = false
	if not is_inside_tree():
		return
	_action_error = "" if r["ok"] else _error_text(String(r["error"]))
	_render()


func _equip() -> void:
	if _busy:
		return
	_busy = true
	var r := await Online.cosmetics.equip(item_id)
	_busy = false
	if not is_inside_tree():
		return
	_action_error = "" if r["ok"] else _error_text(String(r["error"]))
	_render()


static func _error_text(code: String) -> String:
	match code:
		"INSUFFICIENT_FUNDS":
			return TranslationServer.translate("COS_ERR_FUNDS")
		"ALREADY_OWNED":
			return TranslationServer.translate("COS_ERR_OWNED")
		"DEBT_OPEN":
			return TranslationServer.translate("COS_ERR_DEBT")
		"STORE_CLOSED":
			return TranslationServer.translate("COS_ERR_CLOSED")
		"NOT_OWNED":
			return TranslationServer.translate("COS_ERR_NOT_OWNED")
	return TranslationServer.translate("ONLINE_ERR_SERVER")


## "Mağazada 1.200 Altın", "Seviye 15 ödülü", both, or "yakında".
static func how_to_get(x: Dictionary) -> String:
	var parts: PackedStringArray = []
	if x.get("purchasable", false) and x.get("price") != null:
		parts.append(TranslationServer.translate("COS_HOW_BUY") % [int(x["price"]),
			TranslationServer.translate("CURRENCY_" + String(x.get("currency", "gold")).to_upper())])
	if x.get("earnable", false) and x.has("source"):
		parts.append(Cosmetics.source_text(String(x["source"])))
	return " · ".join(parts) if not parts.is_empty() else TranslationServer.translate("COS_HOW_NONE")
