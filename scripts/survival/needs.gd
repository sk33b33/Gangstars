class_name Needs
extends RefCounted
## Food, water and rest: 100 = fine, 0 = empty. Pure logic (design/gdd/survival.md, Needs).

signal warned(need: String)      # dropped below the warning level
signal emptied(need: String)

const IDS := ["food", "water", "rest"]

var config: SurvivalConfig
var enabled := true
var food := 100.0
var water := 100.0
var rest := 100.0


func _init(p_config: SurvivalConfig) -> void:
	config = p_config


func value(need: String) -> float:
	return float(get(need))


## Runs the needs down by `hours` of game time.
func drain(hours: float, sprinting := false, asleep := false, rest_factor := 1.0) -> void:
	if not enabled or hours <= 0.0:
		return
	var rates: Dictionary = config.values.get("drain", {})
	var half := 0.5 if asleep else 1.0
	_lower("food", float(rates.get("food", 0.0)) * hours * half)
	_lower("water", float(rates.get("water", 0.0)) * hours * half * (config.num("sprint_water_factor", 1.0) if sprinting else 1.0))
	if not asleep:
		_lower("rest", float(rates.get("rest", 0.0)) * hours * rest_factor)


func _lower(need: String, amount: float) -> void:
	var before := value(need)
	var after := maxf(0.0, before - amount)
	set(need, after)
	var warn := config.num("warn_level", 25.0)
	if before >= warn and after < warn:
		warned.emit(need)
	if before > 0.0 and after <= 0.0:
		emptied.emit(need)


func restore(need: String, amount: float) -> void:
	if IDS.has(need):
		set(need, clampf(value(need) + amount, 0.0, 100.0))


func is_low(need: String) -> bool:
	return enabled and value(need) < config.num("warn_level", 25.0)


func starving() -> bool:
	return enabled and (food <= 0.0 or water <= 0.0)


func exhausted() -> bool:
	return enabled and rest <= 0.0


## Hours a sleep lasts now: a full sleep when tired, shorter when nearly rested (at least one hour).
func sleep_length() -> float:
	return clampf(config.num("sleep_hours", 8.0) * (100.0 - rest) / 60.0, 1.0, config.num("sleep_hours", 8.0))


func sleep() -> float:
	var hours := sleep_length()
	drain(hours, false, true)
	rest = 100.0
	return hours


## After a knock-out: never wake with an empty stomach (you would be stuck).
func wake_up() -> void:
	var m := config.num("wake_minimum", 30.0)
	food = maxf(food, m)
	water = maxf(water, m)
	rest = maxf(rest, m)


func to_dict() -> Dictionary:
	return {"food": food, "water": water, "rest": rest}


func load_dict(d: Variant) -> void:
	if not d is Dictionary:
		return
	for id in IDS:
		set(id, clampf(float(d.get(id, 100.0)), 0.0, 100.0))
