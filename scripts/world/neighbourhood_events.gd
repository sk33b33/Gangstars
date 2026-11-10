class_name NeighbourhoodEvents
extends Node
## District-level event hub (a child of the district, not a global singleton).
## Gameplay raises incidents here; the SimulationDirector delivers them to nearby NPCs,
## and the HUD listens for player-facing messages.

signal incident_started(event: Dictionary)
signal incident_reported(event: Dictionary, reporter_name: String)
signal message(text: String)

const KINDS := {
	"whistle": {"severity": 1, "radius": 14.0, "text": "You whistle loudly down the street."},
	"car_alarm": {"severity": 1, "radius": 16.0, "text": "A car alarm goes off near %s."},
	"argument": {"severity": 2, "radius": 18.0, "text": "A loud argument breaks out near %s."},
	"scuffle": {"severity": 3, "radius": 22.0, "text": "A scuffle starts near %s!"},
	"car_horn": {"severity": 1, "radius": 16.0, "text": ""},
	"reckless_driving": {"severity": 2, "radius": 12.0, "text": "People jump out of the way of your car!"},
	"gunfire": {"severity": 4, "radius": 40.0, "text": "Gunshots ring out near %s!"},
}

var _next_id := 1
var recent: Array = []  # last few events, newest last


## Raises an incident and returns its event dictionary.
func raise(kind: String, position: Vector3, place_name := "the street") -> Dictionary:
	var spec: Dictionary = KINDS.get(kind, KINDS.argument)
	var event := {
		"id": "evt_%d" % _next_id, "kind": kind, "position": position,
		"severity": spec.severity, "radius": spec.radius,
		"text": spec.text % place_name if "%s" in spec.text else spec.text,
	}
	_next_id += 1
	recent.append(event)
	if recent.size() > 8:
		recent.pop_front()
	incident_started.emit(event)
	if not str(event.text).is_empty():
		message.emit(event.text)
	return event


func find(event_id: String) -> Dictionary:
	for e in recent:
		if e.id == event_id:
			return e
	return {}


func report(event_id: String, reporter_name: String) -> void:
	var event := find(event_id)
	if event.is_empty():
		return
	incident_reported.emit(event, reporter_name)
	message.emit("%s is telling the neighbours about the %s." % [reporter_name, str(event.kind).replace("_", " ")])
