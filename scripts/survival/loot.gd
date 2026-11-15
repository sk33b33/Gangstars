class_name Loot
extends RefCounted
## What search spots hold. A spot's contents depend only on its id and the day it (re)filled, so
## they are the same on every device and after loading. Pure logic.

var config: SurvivalConfig
var searched: Dictionary = {}   # spot id -> game day it was emptied


func _init(p_config: SurvivalConfig) -> void:
	config = p_config


func is_empty(spot_id: String, day: int) -> bool:
	return searched.has(spot_id) and day < int(searched[spot_id]) + int(config.num("refill_days", 2.0))


## The items in a spot (not removed). `extra_chance` is the scavenging bonus for one more roll.
func contents(spot_id: String, table: String, day: int, extra_chance := 0.0) -> Array:
	if is_empty(spot_id, day):
		return []
	var rng := RandomNumberGenerator.new()
	var filled := int(searched[spot_id]) + int(config.num("refill_days", 2.0)) if searched.has(spot_id) else 0
	rng.seed = hash(spot_id) + filled * 7919
	var entries: Array = config.loot_tables.get(table, [])
	var out: Array = []
	for e in entries:
		if rng.randf() < float(e.chance):
			out.append(str(e.item))
	if not entries.is_empty() and rng.randf() < extra_chance:
		out.append(str(entries[rng.randi() % entries.size()].item))
	return out


func mark_searched(spot_id: String, day: int) -> void:
	searched[spot_id] = day


func to_dict() -> Dictionary:
	return searched.duplicate()


func load_dict(d: Variant) -> void:
	searched.clear()
	if d is Dictionary:
		for id in d:
			searched[str(id)] = int(d[id])
