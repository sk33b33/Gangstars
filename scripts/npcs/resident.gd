class_name Resident
extends CharacterBody3D
## Walking NPC body. Movement is physics-driven along NavigationAgent3D paths; decisions come
## from NpcBrain on a staggered think tick (not every frame). Leaving/entering home happens
## at the house's door marker while the NPC is hidden "inside", so nobody pops in mid-street.

const LAYER_NPCS := 1 << 2
const GRAVITY := 9.8
const THINK_INTERVAL := 0.5
const STUCK_WINDOW := 2.5
const STUCK_MIN_MOVE := 0.3
const MAX_REPATHS := 3

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: CharacterModel = $Model
@onready var interactable: Interactable = $Interactable
@onready var name_label: Label3D = $NameLabel

var data: NpcData
var brain: NpcBrain
var destinations: DestinationRegistry
var home_door_id := ""
var is_inside := true
var path_status := "idle"
var target_id := ""
var sim_tier := "near"  # Phase 3 adds distance tiers.

# Diagnostics read by tests and the debug overlay.
var arrivals := 0
var travel_failures := 0
var teleport_violations := 0
var travel_time := 0.0
var max_travel_time := 0.0

var _think_accum := 0.0
var _stuck_accum := 0.0
var _stuck_origin := Vector3.ZERO
var _repaths := 0
var _travelling := false
var _check_reachable := false
var _last_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _deferred: Array = []
var _door_query: PhysicsShapeQueryParameters3D


func setup(p_data: NpcData, p_destinations: DestinationRegistry, think_offset: float) -> void:
	data = p_data
	destinations = p_destinations
	name = data.id
	home_door_id = data.home_id + ":door"
	brain = NpcBrain.new(data.schedule, data.start_delay)
	_rng.seed = hash(data.id)
	_think_accum = fmod(think_offset, THINK_INTERVAL)
	agent.max_speed = data.walk_speed * 1.2
	agent.velocity_computed.connect(_on_velocity_computed)
	model.build(data.shirt_color, data.pants_color, data.skin_color)
	name_label.text = data.display_name
	interactable.prompt = "Talk to %s" % data.display_name
	interactable.on_interact = _talk
	global_position = destinations.anchor_position(home_door_id)
	_set_inside(true)


func state_name() -> String:
	return brain.state_name() if brain else "NONE"


func current_path() -> PackedVector3Array:
	return agent.get_current_navigation_path() if _travelling else PackedVector3Array()


func _physics_process(delta: float) -> void:
	if brain == null:
		return
	_think_accum += delta
	if _think_accum >= THINK_INTERVAL:
		_think(_think_accum)
		_think_accum = 0.0
	if is_inside:
		return
	var desired := Vector3.ZERO
	if _travelling:
		travel_time += delta
		max_travel_time = maxf(max_travel_time, travel_time)
		if agent.is_navigation_finished():
			_on_arrived()
		else:
			var to_next := agent.get_next_path_position() - global_position
			to_next.y = 0.0
			if to_next.length() > 0.05:
				desired = to_next.normalized() * data.walk_speed
	if agent.avoidance_enabled:
		agent.velocity = desired
	else:
		_apply_velocity(desired)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_inside:
		_apply_velocity(safe_velocity)


func _apply_velocity(v: Vector3) -> void:
	var dt := get_physics_process_delta_time()
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * dt
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), clampf(dt * 8.0, 0.0, 1.0))
	model.animate(dt, flat.length())
	# Movement regression guard: a visible NPC may never jump further than it can walk.
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	if moved > data.walk_speed * 2.5 * dt + 0.05:
		teleport_violations += 1
	_last_pos = global_position


func _think(dt: float) -> void:
	if not _deferred.is_empty():
		# Waiting inside for someone to clear the doorway before stepping out.
		if _door_blocked():
			path_status = "waiting at door"
			return
		var cmds := _deferred
		_deferred = []
		for cmd in cmds:
			_run(cmd)
	var cmds := brain.update(dt)
	if not cmds.is_empty() and cmds[0].cmd == "exit_home" and _door_blocked():
		_deferred = cmds
		path_status = "waiting at door"
		return
	for cmd in cmds:
		_run(cmd)
	if not _travelling:
		return
	if _check_reachable:
		_check_reachable = false
		if not agent.is_target_reachable():
			_retry("unreachable")
			return
	_stuck_accum += dt
	if _stuck_accum >= STUCK_WINDOW:
		if global_position.distance_to(_stuck_origin) < STUCK_MIN_MOVE:
			_retry("stuck")
		_stuck_accum = 0.0
		_stuck_origin = global_position


## True if a visible person (player or NPC) is standing in this NPC's doorway.
func _door_blocked() -> bool:
	if _door_query == null:
		var sphere := SphereShape3D.new()
		sphere.radius = 0.75
		_door_query = PhysicsShapeQueryParameters3D.new()
		_door_query.shape = sphere
		_door_query.collision_mask = (1 << 1) | LAYER_NPCS
		_door_query.exclude = [get_rid()]
	_door_query.transform = Transform3D(Basis(), destinations.anchor_position(home_door_id) + Vector3(0, 0.9, 0))
	return not get_world_3d().direct_space_state.intersect_shape(_door_query, 1).is_empty()


func _run(cmd: Dictionary) -> void:
	match cmd.cmd:
		"exit_home":
			_set_inside(false)
		"enter_home":
			_set_inside(true)
		"go":
			_go(cmd.destination)


func _go(dest: String) -> void:
	target_id = home_door_id if dest == NpcBrain.HOME else dest
	_repaths = 0
	travel_time = 0.0
	if not _set_target(0.0):
		_fail("destination unavailable")


func _set_target(extra_jitter: float) -> bool:
	var pos: Variant = destinations.resolve(target_id, _rng, extra_jitter)
	if pos == null:
		return false
	agent.target_position = pos
	_travelling = true
	_check_reachable = true
	_stuck_accum = 0.0
	_stuck_origin = global_position
	path_status = "moving"
	return true


func _retry(reason: String) -> void:
	_repaths += 1
	if _repaths > MAX_REPATHS or not _set_target(0.5 * _repaths):
		_fail(reason)
	else:
		path_status = "repath %d (%s)" % [_repaths, reason]


func _fail(reason: String) -> void:
	_travelling = false
	travel_failures += 1
	path_status = "failed: " + reason
	for cmd in brain.on_travel_failed():
		_run(cmd)


func _on_arrived() -> void:
	_travelling = false
	arrivals += 1
	path_status = "arrived"
	for cmd in brain.on_arrived():
		_run(cmd)


func _set_inside(inside: bool) -> void:
	is_inside = inside
	visible = not inside
	velocity = Vector3.ZERO
	collision_layer = 0 if inside else LAYER_NPCS
	agent.avoidance_enabled = not inside
	interactable.set_enabled(not inside)
	if not inside:
		global_position = destinations.anchor_position(home_door_id)
	_last_pos = global_position


func _talk() -> String:
	var where := destinations.display_name(target_id) if _travelling else ""
	var line := data.lines[_rng.randi() % data.lines.size()] if not data.lines.is_empty() else "..."
	if where.is_empty():
		return "%s: \"%s\"" % [data.display_name, line]
	return "%s (on the way to %s): \"%s\"" % [data.display_name, where, line]
