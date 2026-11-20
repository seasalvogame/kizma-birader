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
	last_error = ""
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
	last_error = ""
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


## The client sends only an id. The database checks publication, sale state,
## current server price, debt, balance and ownership in one transaction.
func purchase(id: String) -> Dictionary:
	var r := await api.call_rpc("purchase_cosmetic", {"p_item": id})
	if not r["ok"]:
		last_error = r["error"]
		return r
	# purchase_cosmetic returns the authoritative remaining balance.  Keep the
	# visible wallet in sync without recreating the transaction client-side.
	var receipt: Dictionary = r.get("data", {})
	if receipt.has("currency") and receipt.has("balance") and Online.profile != null:
		Online.profile.set_wallet_balance(String(receipt["currency"]), receipt["balance"])
	var refreshed := await refresh_inventory()
	if not refreshed:
		# A confirmed server purchase is safe to reflect locally; this is only a
		# display cache and the next refresh remains authoritative.
		var x := item(id)
		var owned_rows: Array = inventory.get("owned", [])
		if not owned(id) and not x.is_empty():
			owned_rows.append({"id": id, "category": x.get("category", ""), "source": "store"})
			inventory["owned"] = owned_rows
			_save()
			changed.emit()
	return r


## Only an owned item in one of the server-approved loadout categories can be
## equipped. Badges keep using the existing Phase 6 badge selection path.
func equip(id: String) -> Dictionary:
	var r := await api.call_rpc("equip_cosmetic", {"p_item": id})
	if not r["ok"]:
		last_error = r["error"]
		return r
	var refreshed := await refresh_inventory()
	if not refreshed:
		var loadout: Dictionary = inventory.get("loadout", {})
		var response: Dictionary = r.get("data", {})
		loadout[String(response.get("category", ""))] = id
		inventory["loadout"] = loadout
		_save()
		changed.emit()
	return r


func _save() -> void:
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"catalog": catalog, "inventory": inventory}))
