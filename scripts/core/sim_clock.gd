class_name SimClock
extends RefCounted
## Game time of day. Owned by the district's SimulationDirector and advanced on physics ticks,
## so it is deterministic under --fixed-fps. 1 real second = `minutes_per_second` game minutes.

signal hour_changed(hour: int)
signal day_changed(day: int)

var minutes := 7.0 * 60.0   # minutes since midnight
var day := 1
var minutes_per_second := 1.0


func advance(dt: float) -> void:
	var before := int(minutes / 60.0)
	minutes += dt * minutes_per_second
	while minutes >= 1440.0:
		minutes -= 1440.0
		day += 1
		day_changed.emit(day)
	var now := int(minutes / 60.0)
	if now != before:
		hour_changed.emit(now)


## Moves forward (never back) to the next occurrence of `h`, e.g. "rest until 07:00".
func skip_to(h: float) -> void:
	var delta := fposmod(h * 60.0 - minutes, 1440.0)
	if delta < 1.0:
		delta += 1440.0
	advance(delta / minutes_per_second)


func hour() -> float:
	return minutes / 60.0


func set_hour(h: float) -> void:
	minutes = fposmod(h * 60.0, 1440.0)


func label() -> String:
	return "%02d:%02d" % [int(minutes / 60.0), int(minutes) % 60]


func is_night() -> bool:
	return not in_window(hour(), 6.0, 19.0)


## True if `h` is inside [start, end); windows may wrap midnight (e.g. 22 -> 2).
static func in_window(h: float, start: float, end: float) -> bool:
	if is_equal_approx(start, end):
		return true
	if start < end:
		return h >= start and h < end
	return h >= start or h < end
