class_name OnlineCosmetics
extends Node
## Cosmetics from the server (Phase 7): the published catalog (with server prices) and
## my inventory / loadout. Kept in a small cache so the collection and my own look show
## offline too — the cache is display only: ownership, prices and purchases are always
## decided by the server.

signal changed

var cache_path := "user://cosmetics_cache.json"

var api: OnlineApi
var catalog := {}        # cosmetics_catalog(): {version, store_enabled, featured, items:[...]}
var inventory := {}      # my_inventory(): {owned:[{id, category, source, acquired_at}], loadout:{...}}
var last_error := ""


func _ready() -> void:
	load_cache()


func load_cache() -> void:
	catalog = {}
	inventory = {}
	var f := FileAccess.open(cache_path, FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			catalog = d.get("catalog", {})
			inventory = d.get("inventory", {})


func refresh() -> bool:
	var c := await api.call_rpc("cosmetics_catalog", {})
	var i := await api.call_rpc("my_inventory", {})
	if not (c["ok"] and i["ok"]):
		last_error = c["error"] if not c["ok"] else i["error"]
		return false
	catalog = c["data"]
	inventory = i["data"]
	_save()
	changed.emit()
	return true


func refresh_inventory() -> bool:
	var i := await api.call_rpc("my_inventory", {})
	if not i["ok"]:
		last_error = i["error"]
		return false
	inventory = i["data"]
	_save()
	changed.emit()
	return true


func items(category: String = "") -> Array:
	return (catalog.get("items", []) as Array).filter(func(x: Dictionary) -> bool: return category == "" or x["category"] == category)


func item(id: String) -> Dictionary:
	for x: Dictionary in catalog.get("items", []):
		if x["id"] == id:
			return x
	return {}


func owned(id: String) -> bool:
	return (inventory.get("owned", []) as Array).any(func(x: Dictionary) -> bool: return x["id"] == id)


func source_of(id: String) -> String:
	for x: Dictionary in inventory.get("owned", []):
		if x["id"] == id:
			return String(x.get("source", ""))
	return ""


## My equipped item of a category (default when unknown / offline).
func equipped(category: String) -> String:
	var l: Dictionary = inventory.get("loadout", {})
	var v: Variant = l.get(category)
	return String(v) if v != null and String(v) != "" else String(Cosmetics.DEFAULTS.get(category, ""))


func _save() -> void:
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"catalog": catalog, "inventory": inventory}))
