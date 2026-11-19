class_name StoreScreen
extends AppScreen
## Server-priced cosmetics store. It deliberately has no local balances or
## client-side price calculations: the item detail calls the database with an
## id only, and the server performs the purchase atomically.

var status: StatusCard
var _tabs: HFlowContainer
var _grid: GridContainer
var _category := ""


func _title() -> String:
	return tr("STORE_TITLE")


func _nav_tab() -> String:
	return "store"


func _build() -> void:
	content.add_child(wrapped(UiKit.label(tr("STORE_SUBTITLE"), "DimLabel")))
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
		status.loading(tr("STORE_LOADING"))
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
	var all := UiKit.button(tr("STORE_ALL"), "primary" if _category == "" else "secondary", "s")
	all.mouse_filter = Control.MOUSE_FILTER_PASS
	all.pressed.connect(func() -> void: _category = ""; _render())
	_tabs.add_child(all)
	for cat: String in Cosmetics.CATEGORIES:
		if Online.cosmetics.items(cat).any(func(x: Dictionary) -> bool: return bool(x.get("purchasable", false))):
			var b := UiKit.button(tr("COS_CAT_" + cat.to_upper()), "primary" if cat == _category else "secondary", "s")
			b.mouse_filter = Control.MOUSE_FILTER_PASS
			b.pressed.connect(func() -> void: _category = cat; _render())
			_tabs.add_child(b)
	for c: Node in _grid.get_children():
		c.queue_free()
	var rows := Online.cosmetics.items(_category).filter(func(x: Dictionary) -> bool:
		return bool(x.get("purchasable", false)) and not Online.cosmetics.owned(String(x["id"])))
	if rows.is_empty() and not Online.cosmetics.catalog.is_empty():
		_grid.add_child(wrapped(UiKit.label(tr("STORE_EMPTY"), "DimLabel")))
		return
	for x: Dictionary in rows:
		var bottom := tr("COS_HOW_BUY") % [int(x.get("price", 0)), tr("CURRENCY_" + String(x.get("currency", "gold")).to_upper())]
		_grid.add_child(CollectionScreen.tile(x, false, func() -> void: navigate.emit("cosmetic", {"id": x["id"]}), bottom))
