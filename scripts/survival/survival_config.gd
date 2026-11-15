class_name SurvivalConfig
extends RefCounted
## Tuning and catalogs for the survival layer (design/gdd/survival.md), read from data/survival/.

const CONFIG_FILE := "res://data/survival/survival.json"
const ITEMS_FILE := "res://data/survival/items.json"
const LOOT_FILE := "res://data/survival/loot_tables.json"

var values: Dictionary = {}
var items: Dictionary = {}        # id -> {id, name, kind, weight, price, sell, effects}
var item_order: PackedStringArray = []
var shop_stock: Dictionary = {}   # shop kind -> [item ids]
var loot_tables: Dictionary = {}  # table id -> [{item, chance}]


static func load_default() -> SurvivalConfig:
	var c := SurvivalConfig.new()
	var v: Variant = DataFiles.load_json(CONFIG_FILE)
	c.values = v if v is Dictionary else {}
	var it: Variant = DataFiles.load_json(ITEMS_FILE)
	if it is Dictionary:
		for item in it.get("items", []):
			c.items[str(item.id)] = item
			c.item_order.append(str(item.id))
		c.shop_stock = it.get("shop_stock", {})
	var lt: Variant = DataFiles.load_json(LOOT_FILE)
	c.loot_tables = lt.get("tables", {}) if lt is Dictionary else {}
	return c


func num(key: String, fallback := 0.0) -> float:
	return float(values.get(key, fallback))


func item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return str(item(id).get("name", id))


func weight(id: String) -> float:
	return float(item(id).get("weight", 0.0))


func skill(id: String) -> Dictionary:
	return values.get("skills", {}).get(id, {})


func skill_ids() -> Array:
	return values.get("skills", {}).keys()
