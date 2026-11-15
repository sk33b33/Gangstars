class_name Inventory
extends RefCounted
## A weight-limited pile of items (the bag, or the safehouse stash). Pure logic.

signal changed

var config: SurvivalConfig
var capacity := 10.0
var counts: Dictionary = {}   # item id -> count


func _init(p_config: SurvivalConfig, p_capacity: float) -> void:
	config = p_config
	capacity = p_capacity


func count(id: String) -> int:
	return int(counts.get(id, 0))


func weight() -> float:
	var w := 0.0
	for id in counts:
		w += config.weight(str(id)) * int(counts[id])
	return w


func can_add(id: String, n := 1) -> bool:
	return not config.item(id).is_empty() and weight() + config.weight(id) * n <= capacity + 0.0001


func add(id: String, n := 1) -> bool:
	if n <= 0 or not can_add(id, n):
		return false
	counts[id] = count(id) + n
	changed.emit()
	return true


func remove(id: String, n := 1) -> bool:
	if n <= 0 or count(id) < n:
		return false
	counts[id] = count(id) - n
	if int(counts[id]) <= 0:
		counts.erase(id)
	changed.emit()
	return true


## Moves items to another pile; false (and nothing moved) if they don't fit there.
func move_to(other: Inventory, id: String, n := 1) -> bool:
	if count(id) < n or not other.can_add(id, n):
		return false
	remove(id, n)
	other.add(id, n)
	return true


## Item ids in catalog order.
func ids() -> Array:
	var out: Array = []
	for id in config.item_order:
		if counts.has(id):
			out.append(id)
	return out


func to_dict() -> Dictionary:
	return counts.duplicate()


func load_dict(d: Variant) -> void:
	counts.clear()
	if d is Dictionary:
		for id in d:
			if not config.item(str(id)).is_empty() and int(d[id]) > 0:
				counts[str(id)] = int(d[id])
	changed.emit()
