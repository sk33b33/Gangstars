class_name Wounds
extends RefCounted
## Bleeding and bandaged wounds. Pure logic (design/gdd/survival.md, Wounds).

signal changed

var config: SurvivalConfig
var bleeding := 0
var bandaged: Array = []   # hours left to heal, one entry per bandaged wound


func _init(p_config: SurvivalConfig) -> void:
	config = p_config


## A hit landed; `roll` is a random number 0..1. True if it left a wound.
func on_hit(roll: float) -> bool:
	if roll >= config.num("wound_chance", 0.0) or bleeding + bandaged.size() >= int(config.num("max_wounds", 3.0)):
		return false
	bleeding += 1
	changed.emit()
	return true


## Bandages up to `n` bleeding wounds; returns how many were treated.
func bandage(n := 1) -> int:
	var done := mini(n, bleeding)
	for i in done:
		bleeding -= 1
		bandaged.append(config.num("heal_hours", 6.0))
	if done > 0:
		changed.emit()
	return done


func bandage_all() -> void:
	bandage(bleeding)


## Health lost to bleeding over `seconds`, limited so it stops at the floor.
func bleed_damage(seconds: float, hp: float) -> float:
	if bleeding <= 0:
		return 0.0
	return clampf(config.num("bleed_per_second", 0.0) * bleeding * seconds, 0.0, maxf(0.0, hp - config.num("bleed_floor", 15.0)))


func tick_hours(hours: float) -> void:
	if bandaged.is_empty():
		return
	var left: Array = []
	for h in bandaged:
		if float(h) - hours > 0.0:
			left.append(float(h) - hours)
	if left.size() != bandaged.size():
		bandaged = left
		changed.emit()
	else:
		bandaged = left


func heal_bandaged() -> void:
	if not bandaged.is_empty():
		bandaged.clear()
		changed.emit()


func speed_factor() -> float:
	return maxf(0.5, 1.0 - config.num("limp_per_wound", 0.0) * bleeding)


func blocks_sprint() -> bool:
	return bleeding >= 2


func to_dict() -> Dictionary:
	return {"bleeding": bleeding, "bandaged": bandaged.duplicate()}


func load_dict(d: Variant) -> void:
	if not d is Dictionary:
		return
	bleeding = clampi(int(d.get("bleeding", 0)), 0, int(config.num("max_wounds", 3.0)))
	bandaged = []
	for h in d.get("bandaged", []):
		bandaged.append(float(h))
