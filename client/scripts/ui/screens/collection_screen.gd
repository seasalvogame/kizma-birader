class_name CollectionScreen
extends AppScreen
## My collection (Phase 7): items I own, by category, with how I got them. Tapping an
## item opens its details. (7.3 adds equipping; 7.4 shows locked items and progress.)

var status: StatusCard
var _tabs: HFlowContainer
var _grid: GridContainer
var _category := "dice"
const WalletBarView := preload("res://scripts/ui/wallet_bar.gd")


func _title() -> String:
	return tr("COLLECTION_TITLE")


func _header_extra() -> Control:
	return WalletBarView.new()


func _build() -> void:
	_category = String(params.get("category", "dice"))
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 10)
	_tabs.add_theme_constant_override("v_separation", 10)
	content.add_child(_tabs)
	status = StatusCard.new()
	content.add_child(status)
	status.action_pressed.connect(_reload)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", UiTokens.S2)
	_grid.add_theme_constant_override("v_separation", UiTokens.S2)
	content.add_child(_grid)
	Online.cosmetics.changed.connect(_render)
	_render()
	_reload()


func _reload() -> void:
	if Online.cosmetics.catalog.is_empty():
		status.loading(tr("COLLECTION_LOADING"))
	var ok := await Online.cosmetics.refresh()
	if not is_inside_tree():
		return
	if ok:
		status.clear()
	elif Online.cosmetics.catalog.is_empty():
		status.error(tr("PROFILE_OFFLINE") if Online.cosmetics.last_error in ["OFFLINE", "NO_CONFIG"] else tr("ONLINE_ERR_SERVER"), tr("ONLINE_RETRY"))
	else:
		status.error(tr("PROFILE_OFFLINE_CACHED"), tr("ONLINE_RETRY"))
	_render()


func _render() -> void:
	if not is_inside_tree():
		return
	for c: Node in _tabs.get_children():
		c.queue_free()
	for cat: String in Cosmetics.CATEGORIES:
		var b := UiKit.button(tr("COS_CAT_" + cat.to_upper()), "primary" if cat == _category else "secondary", "s")
		b.custom_minimum_size = Vector2(0, 72)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void:
			_category = cat
			_render())
		_tabs.add_child(b)
	for c: Node in _grid.get_children():
		c.queue_free()
	var rows := Online.cosmetics.items(_category).filter(func(x: Dictionary) -> bool: return Online.cosmetics.owned(x["id"]))
	if rows.is_empty() and not Online.cosmetics.catalog.is_empty():
		var empty := wrapped(UiKit.label(tr("COLLECTION_EMPTY"), "DimLabel"))
		_grid.add_child(empty)
		return
	for x: Dictionary in rows:
		_grid.add_child(tile(x, true, func() -> void: navigate.emit("cosmetic", {"id": x["id"]})))


## A cosmetic tile (collection and store): preview, name, rarity, and a bottom line.
static func tile(x: Dictionary, owned: bool, on_press: Callable, bottom: String = "") -> Button:
	var b: Button = preload("res://scripts/ui/tactile_button.gd").new()
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 350)
	var face := StyleBoxFlat.new()
	face.bg_color = UiPalette.CREAM_100
	face.set_corner_radius_all(UiTokens.R_M)
	face.border_width_bottom = 6
	face.border_color = Cosmetics.RARITY_COLORS.get(String(x.get("rarity", "common")), UiPalette.CREAM_300)
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, face)
	var col := UiKit.vbox(4)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_right = -14
	col.offset_top = 10
	col.offset_bottom = -14
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var prev := CosmeticPreview.new()
	prev.item = x
	prev.custom_minimum_size = Vector2(0, 170)
	col.add_child(prev)
	var n := UiKit.label(Cosmetics.item_name(String(x["id"])), "InkH3Label", HORIZONTAL_ALIGNMENT_CENTER)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(0, 44)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(n)
	var chip := CosmeticPreview.rarity_chip(String(x.get("rarity", "common")))
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chip)
	if owned:
		var state := UiKit.chip(TranslationServer.translate("COS_EQUIPPED") if Online.cosmetics.equipped(String(x.get("category", ""))) == String(x.get("id", "")) else TranslationServer.translate("COS_OWNED"),
			Color(UiPalette.MINT_500, 0.23), UiPalette.INK_900)
		state.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(state)
	if bottom != "":
		var l := UiKit.label(bottom, "InkDimLabel", HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(0, 38)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	b.pressed.connect(on_press)
	return b
