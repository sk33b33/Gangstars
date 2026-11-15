class_name Skills
extends RefCounted
## Skills that grow with use. Pure logic (design/gdd/survival.md, Skills).

signal levelled(skill: String, level: int)

var config: SurvivalConfig
var xp: Dictionary = {}   # skill id -> total xp


func _init(p_config: SurvivalConfig) -> void:
	config = p_config


## Total XP needed to reach `level` (1-based).
func threshold(level: int) -> float:
	return config.num("xp_base", 100.0) * pow(float(level), config.num("xp_power", 1.5))


func level(skill: String) -> int:
	var have := float(xp.get(skill, 0.0))
	var lvl := 0
	while lvl < int(config.num("max_level", 5.0)) and have >= threshold(lvl + 1):
		lvl += 1
	return lvl


## Gains XP for an event named in the skill's "xp" table (e.g. add("hustle", "sale")).
func add(skill: String, event: String, times := 1.0) -> void:
	var amount := float(config.skill(skill).get("xp", {}).get(event, 0.0)) * times
	if amount <= 0.0:
		return
	var before := level(skill)
	xp[skill] = float(xp.get(skill, 0.0)) + amount
	var after := level(skill)
	if after > before:
		levelled.emit(skill, after)


## The skill's bonus at its current level (e.g. 0.16 at level 2 with 0.08 per level).
func bonus(skill: String, key := "bonus") -> float:
	return float(config.skill(skill).get(key, 0.0)) * level(skill)


## 0..1 progress towards the next level (1 at the top level).
func progress(skill: String) -> float:
	var lvl := level(skill)
	if lvl >= int(config.num("max_level", 5.0)):
		return 1.0
	var lo := threshold(lvl) if lvl > 0 else 0.0
	return clampf((float(xp.get(skill, 0.0)) - lo) / (threshold(lvl + 1) - lo), 0.0, 1.0)


func to_dict() -> Dictionary:
	return xp.duplicate()


func load_dict(d: Variant) -> void:
	xp.clear()
	if d is Dictionary:
		for id in d:
			if not config.skill(str(id)).is_empty():
				xp[str(id)] = maxf(0.0, float(d[id]))
