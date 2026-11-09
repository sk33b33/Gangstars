class_name NpcBrain
extends RefCounted
## Timer-driven schedule state machine. Pure logic (no nodes), so it can be unit-tested.
## The body reports events (arrived / travel failed); the brain answers with commands:
##   {"cmd": "exit_home"}, {"cmd": "enter_home"}, {"cmd": "go", "destination": id}

enum State { AT_HOME, PREPARING_TO_LEAVE, TRAVELLING, AT_DESTINATION, RETURNING_HOME, UNAVAILABLE }

const HOME := "home"
const PREPARE_TIME := 1.5
const UNAVAILABLE_TIME := 6.0
const DEFAULT_HOME_TIME := 10.0
const MAX_CONSECUTIVE_FAILURES := 3

var state: State = State.AT_HOME
var schedule: Array = []
var index := -1
var timer := 0.0
var destination_id := HOME
var activity := "home"
var last_transition := "spawned at home"
var transitions := 0
var _failures := 0


func _init(p_schedule: Array = [], start_delay := 0.0) -> void:
	schedule = p_schedule
	timer = start_delay


func state_name() -> String:
	return State.keys()[state]


func update(dt: float) -> Array:
	match state:
		State.AT_HOME:
			timer -= dt
			if timer <= 0.0:
				_set_state(State.PREPARING_TO_LEAVE, "leaving home")
				timer = PREPARE_TIME
		State.PREPARING_TO_LEAVE:
			timer -= dt
			if timer <= 0.0:
				var cmds: Array = [{"cmd": "exit_home"}]
				cmds.append_array(_go_to_next())
				return cmds
		State.AT_DESTINATION:
			timer -= dt
			if timer <= 0.0:
				return _go_to_next()
		State.UNAVAILABLE:
			timer -= dt
			if timer <= 0.0:
				return _return_home("retrying route home")
	return []


func on_arrived() -> Array:
	_failures = 0
	match state:
		State.TRAVELLING:
			var e: Dictionary = schedule[index]
			activity = e.activity
			timer = e.duration
			_set_state(State.AT_DESTINATION, "arrived at " + destination_id)
		State.RETURNING_HOME:
			activity = "home"
			timer = _home_duration()
			_set_state(State.AT_HOME, "went inside")
			return [{"cmd": "enter_home"}]
	return []


func on_travel_failed() -> Array:
	_failures += 1
	if _failures >= MAX_CONSECUTIVE_FAILURES or state == State.RETURNING_HOME:
		timer = UNAVAILABLE_TIME
		activity = "waiting"
		_set_state(State.UNAVAILABLE, "route failed to " + destination_id)
		return []
	if state == State.TRAVELLING:
		return _go_to_next("skipped unreachable " + destination_id)
	return []


func _go_to_next(reason := "") -> Array:
	if schedule.is_empty():
		return _return_home("no schedule")
	index = (index + 1) % schedule.size()
	var e: Dictionary = schedule[index]
	if e.destination == HOME:
		return _return_home(reason if not reason.is_empty() else "heading home")
	destination_id = e.destination
	activity = "walking"
	_set_state(State.TRAVELLING, reason if not reason.is_empty() else "heading to " + destination_id)
	return [{"cmd": "go", "destination": destination_id}]


func _return_home(reason: String) -> Array:
	destination_id = HOME
	activity = "walking home"
	_set_state(State.RETURNING_HOME, reason)
	return [{"cmd": "go", "destination": HOME}]


func _home_duration() -> float:
	if index >= 0 and index < schedule.size() and schedule[index].destination == HOME:
		return schedule[index].duration
	return DEFAULT_HOME_TIME


func _set_state(new_state: State, reason: String) -> void:
	state = new_state
	last_transition = "%s (%s)" % [State.keys()[new_state], reason]
	transitions += 1
