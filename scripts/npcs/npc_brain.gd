class_name NpcBrain
extends RefCounted
## Schedule + reaction state machine. Pure logic (no nodes), so it is unit-testable.
## The body reports events (arrived, travel failed, incident) and the brain answers with
## commands for the body to execute:
##   {"cmd": "exit_home"} {"cmd": "enter_home"} {"cmd": "stop"} {"cmd": "face_incident"}
##   {"cmd": "go", "destination": id, "speed"?: mult}   ids: "home", "@incident", "@report", anchors
##   {"cmd": "follow", "leader": npc_id}                {"cmd": "reported"}
## Time of day gates schedule entries (entry "window", NPC "active_hours"); outside active
## hours the NPC goes home and stays there.

enum State {
	AT_HOME, PREPARING_TO_LEAVE, TRAVELLING, AT_DESTINATION, SOCIALIZING, PATROLLING, FOLLOWING,
	GUARDING, NOTICING, INVESTIGATING, FLEEING, REPORTING, RETURNING_HOME, UNAVAILABLE,
}

const HOME := "home"
const PREPARE_TIME := 1.5
const UNAVAILABLE_TIME := 6.0
const DEFAULT_HOME_TIME := 10.0
const HOME_RECHECK := 15.0
const MAX_CONSECUTIVE_FAILURES := 3
const NOTICE_TIME := 2.5
const WATCH_TIME := 8.0
const REPORT_TIME := 5.0
const HIDE_TIME := 25.0
const FLEE_SPEED := 1.8
const REACTION_RANK := {"notice": 1, "investigate": 2, "report": 3, "flee": 4}
const REACTION_STATES := [State.NOTICING, State.INVESTIGATING, State.FLEEING, State.REPORTING]
const DWELL_STATES := [State.AT_DESTINATION, State.SOCIALIZING, State.GUARDING]

var state: State = State.AT_HOME
var schedule: Array = []
var index := -1
var timer := 0.0
var destination_id := HOME
var activity := "home"
var last_transition := "spawned at home"
var transitions := 0
var clock_hour := 12.0
var active_hours := Vector2(6, 22)
var reaction := ""
## Set by Weather: outdoor leisure is skipped while it rains (errands still happen).
var raining := false
## One-off event entry (braai, load-shedding) taken before the next schedule entry.
var pending_event: Dictionary = {}
var _current_event: Dictionary = {}
const RAIN_SKIPPED := ["socializing", "playing", "relaxing", "braai"]
var reacting_to := ""

var _failures := 0
var _route_i := 0
var _watching := false
var _resume_state: State = State.TRAVELLING


func _init(p_schedule: Array = [], start_delay := 0.0, p_active_hours := Vector2(6, 22)) -> void:
	schedule = p_schedule
	timer = start_delay
	active_hours = p_active_hours


func state_name() -> String:
	return State.keys()[state]


func is_reacting() -> bool:
	return state in REACTION_STATES


func is_active_hours() -> bool:
	return SimClock.in_window(clock_hour, active_hours.x, active_hours.y)


func current_entry() -> Dictionary:
	if not _current_event.is_empty():
		return _current_event
	return schedule[index] if index >= 0 and index < schedule.size() else {}


func update(dt: float) -> Array:
	match state:
		State.AT_HOME:
			timer -= dt
			if timer <= 0.0:
				if _any_entry_allowed():
					_set_state(State.PREPARING_TO_LEAVE, "leaving home")
					timer = PREPARE_TIME
				else:
					timer = HOME_RECHECK
		State.PREPARING_TO_LEAVE:
			timer -= dt
			if timer <= 0.0:
				var cmds: Array = [{"cmd": "exit_home"}]
				cmds.append_array(_go_to_next())
				return cmds
		State.AT_DESTINATION, State.SOCIALIZING, State.GUARDING:
			if not is_active_hours():
				return _return_home("curfew")
			timer -= dt
			if timer <= 0.0:
				return _go_to_next()
		State.FOLLOWING:
			timer -= dt
			if timer <= 0.0 or not is_active_hours():
				return _go_to_next("done following")
		State.NOTICING:
			timer -= dt
			if timer <= 0.0:
				return _resume()
		State.INVESTIGATING, State.REPORTING:
			if _watching:
				timer -= dt
				if timer <= 0.0:
					return _resume()
		State.UNAVAILABLE:
			timer -= dt
			if timer <= 0.0:
				return _return_home("retrying route home")
	return []


func on_arrived() -> Array:
	_failures = 0
	match state:
		State.TRAVELLING:
			var e := current_entry()
			activity = e.get("activity", "idle")
			timer = e.get("duration", 10.0)
			var guard: bool = activity == "guard"
			_set_state(State.GUARDING if guard else State.AT_DESTINATION, "arrived at " + destination_id)
		State.PATROLLING:
			var route: PackedStringArray = current_entry().get("route", PackedStringArray())
			_route_i += 1
			if _route_i >= route.size():
				return _go_to_next("patrol complete")
			destination_id = route[_route_i]
			return [{"cmd": "go", "destination": destination_id}]
		State.INVESTIGATING:
			_watching = true
			timer = WATCH_TIME
			activity = "watching"
		State.REPORTING:
			_watching = true
			timer = REPORT_TIME
			activity = "telling the neighbours"
			return [{"cmd": "reported"}]
		State.FLEEING, State.RETURNING_HOME:
			var reason := "hid inside" if state == State.FLEEING else "went inside"
			timer = HIDE_TIME if state == State.FLEEING else _home_duration()
			_clear_reaction()
			activity = "home"
			_set_state(State.AT_HOME, reason)
			return [{"cmd": "enter_home"}]
	return []


func on_travel_failed() -> Array:
	_failures += 1
	if state in REACTION_STATES and state != State.FLEEING:
		return _resume()
	if state == State.FOLLOWING:
		return _go_to_next("lost the leader")
	if _failures >= MAX_CONSECUTIVE_FAILURES or state == State.RETURNING_HOME or state == State.FLEEING:
		_clear_reaction()
		timer = UNAVAILABLE_TIME
		activity = "waiting"
		_set_state(State.UNAVAILABLE, "route failed to " + destination_id)
		return []
	if state == State.TRAVELLING or state == State.PATROLLING:
		return _go_to_next("skipped unreachable " + destination_id)
	return []


## Called by the simulation director when this NPC is part of a group at a destination.
func set_socializing(social: bool) -> void:
	if social and state == State.AT_DESTINATION:
		_set_state(State.SOCIALIZING, "chatting at " + destination_id)
	elif not social and state == State.SOCIALIZING:
		_set_state(State.AT_DESTINATION, "group broke up")


## Reaction to an incident (already chosen by ReactionPolicy). Only escalates: a stronger
## reaction can replace a weaker one, never the reverse.
func on_incident(p_reaction: String, event_id: String) -> Array:
	if p_reaction.is_empty() or not REACTION_RANK.has(p_reaction):
		return []
	if state in [State.AT_HOME, State.PREPARING_TO_LEAVE, State.UNAVAILABLE, State.FLEEING]:
		return []
	if event_id == reacting_to:
		return []
	if is_reacting():
		if REACTION_RANK[p_reaction] <= REACTION_RANK.get(reaction, 0):
			return []
	else:
		_resume_state = state
	reaction = p_reaction
	reacting_to = event_id
	_watching = false
	match p_reaction:
		"notice":
			timer = NOTICE_TIME
			activity = "looking around"
			_set_state(State.NOTICING, "noticed " + event_id)
			return [{"cmd": "stop"}, {"cmd": "face_incident"}]
		"investigate":
			activity = "investigating"
			_set_state(State.INVESTIGATING, "investigating " + event_id)
			return [{"cmd": "go", "destination": "@incident"}]
		"report":
			activity = "going to tell someone"
			_set_state(State.REPORTING, "reporting " + event_id)
			return [{"cmd": "go", "destination": "@report"}]
		_:
			destination_id = HOME
			activity = "fleeing"
			_set_state(State.FLEEING, "fleeing " + event_id)
			return [{"cmd": "go", "destination": HOME, "speed": FLEE_SPEED}]


func _resume() -> Array:
	var was := _resume_state
	_clear_reaction()
	if was == State.RETURNING_HOME or not is_active_hours():
		return _return_home("back to routine")
	if was == State.PATROLLING:
		var route: PackedStringArray = current_entry().get("route", PackedStringArray())
		if _route_i < route.size():
			destination_id = route[_route_i]
			_set_state(State.PATROLLING, "back on patrol")
			return [{"cmd": "go", "destination": destination_id}]
	# Re-run the current schedule entry (if still allowed), otherwise move on.
	index -= 1
	return _go_to_next("back to routine")


func _clear_reaction() -> void:
	reaction = ""
	reacting_to = ""
	_watching = false


func _entry_allowed(e: Dictionary) -> bool:
	if e.destination == HOME:
		return true
	if not is_active_hours():
		return false
	if raining and RAIN_SKIPPED.has(str(e.get("activity", ""))) and not e.has("route"):
		return false
	if e.has("window"):
		return SimClock.in_window(clock_hour, e.window.x, e.window.y)
	return true


func _any_entry_allowed() -> bool:
	if not pending_event.is_empty() and _entry_allowed(pending_event):
		return true
	for e in schedule:
		if e.destination != HOME and _entry_allowed(e):
			return true
	return false


func _go_to_next(reason := "") -> Array:
	_current_event = {}
	if not pending_event.is_empty():
		var pe := pending_event
		pending_event = {}
		if _entry_allowed(pe) and str(pe.destination).begins_with("@leader:"):
			return _start_entry(pe, "called by the boss")
		if _entry_allowed(pe):
			_current_event = pe
			destination_id = pe.destination
			activity = "walking"
			_set_state(State.TRAVELLING, "joining " + str(pe.get("activity", "an event")))
			return [{"cmd": "go", "destination": destination_id}]
	if schedule.is_empty():
		return _return_home("no schedule")
	for _i in schedule.size():
		index = (index + 1) % schedule.size()
		var e: Dictionary = schedule[index]
		if not _entry_allowed(e):
			continue
		if e.destination == HOME:
			return _return_home(reason if not reason.is_empty() else "heading home")
		return _start_entry(e, reason)
	return _return_home("nothing to do now")


func _start_entry(e: Dictionary, reason: String) -> Array:
	if e.has("route"):
		_route_i = 0
		destination_id = e.route[0]
		activity = "patrolling"
		_set_state(State.PATROLLING, reason if not reason.is_empty() else "starting patrol")
		return [{"cmd": "go", "destination": destination_id}]
	if e.destination.begins_with("@leader:"):
		var leader: String = e.destination.trim_prefix("@leader:")
		destination_id = e.destination
		activity = "following " + leader
		timer = e.duration
		_set_state(State.FOLLOWING, reason if not reason.is_empty() else "following " + leader)
		return [{"cmd": "follow", "leader": leader}]
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
	var e := current_entry()
	if not e.is_empty() and e.destination == HOME:
		return e.duration
	return DEFAULT_HOME_TIME


func _set_state(new_state: State, reason: String) -> void:
	state = new_state
	last_transition = "%s (%s)" % [State.keys()[new_state], reason]
	transitions += 1
