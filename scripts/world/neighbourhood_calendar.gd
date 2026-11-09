class_name NeighbourhoodCalendar
extends RefCounted
## Recurring neighbourhood events from data/events/calendar.json: an event runs on days where
## day % every_days == offset % every_days, between hours[0] and hours[1].

signal event_started(event: Dictionary)
signal event_ended(event: Dictionary)

var events: Array = []
var active: Dictionary = {}   # id -> event


static func load_file(path: String) -> NeighbourhoodCalendar:
	var c := NeighbourhoodCalendar.new()
	var raw: Variant = DataFiles.load_json(path)
	if raw is Dictionary:
		for e in raw.get("events", []):
			if e is Dictionary and e.has("id") and e.get("hours") is Array:
				c.events.append(e)
	return c


static func runs_at(e: Dictionary, day: int, hour: float) -> bool:
	var every := maxi(1, int(e.get("every_days", 1)))
	if day % every != int(e.get("offset", 0)) % every:
		return false
	var h: Array = e.hours
	return SimClock.in_window(hour, float(h[0]), float(h[1]))


func is_active(id: String) -> bool:
	return active.has(id)


func get_event(id: String) -> Dictionary:
	for e in events:
		if e.id == id:
			return e
	return {}


func update(clock: SimClock) -> void:
	for e in events:
		var on := runs_at(e, clock.day, clock.hour())
		if on and not active.has(e.id):
			active[e.id] = e
			event_started.emit(e)
		elif not on and active.has(e.id):
			active.erase(e.id)
			event_ended.emit(e)
