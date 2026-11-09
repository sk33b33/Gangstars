class_name SimulationDirector
extends Node
## Runs the neighbourhood simulation around the residents:
## - advances the SimClock,
## - assigns distance tiers (near/mid/far) from the observer (the player) every 0.5 s,
## - forms social groups at destinations every 2 s (SOCIALIZING + chat bubbles),
## - delivers incidents to NPCs in range via ReactionPolicy,
## - raises occasional ambient incidents (can be disabled for tests).

@export var near_distance := 30.0
@export var mid_distance := 60.0
@export var ambient_incidents := true
@export var ambient_interval := Vector2(90.0, 180.0)  # seconds between ambient incidents

var district: District
var clock := SimClock.new()
var events: NeighbourhoodEvents
var observer: Node3D
var tier_counts := {"near": 0, "mid": 0, "far": 0}
var reactions_delivered := 0

var _tier_accum := 0.0
var _social_accum := 0.0
var _ambient_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _chatter: Dictionary = {}


func setup(p_district: District, p_events: NeighbourhoodEvents) -> void:
	district = p_district
	events = p_events
	events.incident_started.connect(_on_incident)
	_rng.seed = 20261109
	_ambient_timer = _rng.randf_range(ambient_interval.x, ambient_interval.y)
	var raw: Variant = DataFiles.load_json("res://data/npcs/chatter.json")
	_chatter = raw if raw is Dictionary else {}


func _physics_process(delta: float) -> void:
	if district == null:
		return
	clock.advance(delta)
	_tier_accum += delta
	if _tier_accum >= 0.5:
		_tier_accum = 0.0
		update_tiers()
	_social_accum += delta
	if _social_accum >= 2.0:
		_social_accum = 0.0
		_update_social_groups()
	if ambient_incidents and district.is_navigation_ready:
		_ambient_timer -= delta
		if _ambient_timer <= 0.0:
			_ambient_timer = _rng.randf_range(ambient_interval.x, ambient_interval.y)
			_raise_ambient()


func update_tiers() -> void:
	var origin := observer.global_position if observer else Vector3.ZERO
	tier_counts = {"near": 0, "mid": 0, "far": 0}
	for r: Resident in district.residents.values():
		var d := r.global_position.distance_to(origin)
		var tier := "near" if d < near_distance else ("mid" if d < mid_distance else "far")
		r.set_tier(tier)
		tier_counts[tier] += 1


func line(kind: String) -> String:
	var pool: Array = _chatter.get(kind, [])
	return pool[_rng.randi() % pool.size()] if not pool.is_empty() else ""


func _update_social_groups() -> void:
	var groups := {}
	for r: Resident in district.residents.values():
		var s := r.brain.state
		if s == NpcBrain.State.AT_DESTINATION or s == NpcBrain.State.SOCIALIZING or s == NpcBrain.State.GUARDING:
			groups.get_or_add(r.target_id, []).append(r)
	for members: Array in groups.values():
		var social := members.size() >= 2
		var centre := Vector3.ZERO
		for r: Resident in members:
			centre += r.global_position
		centre /= members.size()
		for r: Resident in members:
			if r.brain.state != NpcBrain.State.GUARDING:
				r.brain.set_socializing(social)
			if social:
				r.face_point(centre)
		if social and _rng.randf() < 0.5:
			var speaker: Resident = members[_rng.randi() % members.size()]
			speaker.say(line("crew" if speaker.data.role in ["crew", "player_crew"] else "social"))


func _on_incident(event: Dictionary) -> void:
	for r: Resident in district.residents.values():
		if r.is_inside:
			continue
		var d := r.global_position.distance_to(event.position)
		var reaction := ReactionPolicy.choose(r.data.role, r.data.personality, event.severity, d, event.radius)
		if reaction.is_empty():
			continue
		var before := r.brain.reacting_to
		r.react(event, reaction)
		if r.brain.reacting_to != before:
			reactions_delivered += 1
			match reaction:
				"investigate": r.say(line("investigate"), 5.0)
				"flee": r.say(line("flee"), 5.0)
				"report": r.say(line("report"), 5.0)
				"notice": r.say("?", 2.5)


func _raise_ambient() -> void:
	var anchors := district.destinations.all_ids()
	if anchors.is_empty():
		return
	var id: String = anchors[_rng.randi() % anchors.size()]
	if id.begins_with("patrol:") or id.ends_with(":entrance"):
		return
	var roll := _rng.randf()
	var kind := "car_alarm" if roll < 0.5 else ("argument" if roll < 0.9 else "scuffle")
	if clock.is_night() and kind == "argument":
		kind = "car_alarm"
	events.raise(kind, district.destinations.anchor_position(id), district.destinations.display_name(id))
