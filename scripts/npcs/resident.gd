class_name Resident
extends CharacterBody3D
## Walking NPC body. Decisions come from NpcBrain on a staggered think tick; movement follows
## NavigationAgent3D paths. Simulation tier (set by SimulationDirector from distance to the
## player) controls cost:
##   near: physics movement + avoidance, think every 0.5 s, chat bubbles
##   mid:  physics movement, no avoidance, think every 1.5 s
##   far:  cheap stepping along the same nav path (no physics), think every 3 s
## Leaving/entering home happens at the door marker while hidden "inside".

signal reported(resident: Resident, event_id: String)
## Emitted when stepping out of / into the house, so the house can swing its door.
signal door_used(house_id: String)

const LAYER_NPCS := 1 << 2
const GRAVITY := 9.8
const THINK_INTERVAL := {"near": 0.5, "mid": 1.5, "far": 3.0}
const STUCK_WINDOW := 2.5
const STUCK_MIN_MOVE := 0.3
const MAX_REPATHS := 3
const UNSTICK_TIME := 0.8
const FOLLOW_GAP := 1.6
const TELEPORT_DISTANCE := 0.5
const ACCELERATION := 3.5     # m/s^2: smooth starts
const DECELERATION := 5.0     # m/s^2: smooth stops
const SLOW_RADIUS := 1.2      # ease in over the last metre of a trip
const GHOST_TIME := 1.5       # after leaving the far tier, ignore other NPCs while overlaps clear
const FAR_ANIM_STEP := 0.1    # far NPCs animate at 10 Hz

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: CharacterModel = $Model
@onready var interactable: Interactable = $Interactable
@onready var name_label: Label3D = $NameLabel

var data: NpcData
var brain: NpcBrain
var destinations: DestinationRegistry
var clock: SimClock
## Callable(npc_id: String) -> Resident, used to follow a leader.
var lookup: Callable
var home_door_id := ""
var is_inside := true
var path_status := "idle"
var target_id := ""
var sim_tier := "near"

# Diagnostics read by tests and the debug overlay.
var arrivals := 0
var travel_failures := 0
var teleport_violations := 0
var offscreen_nudges := 0
var near_nudges := 0
var unsticks := 0
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
var _last_wall_normal := Vector3.ZERO
var _unstick_timer := 0.0
var _unstick_dir := Vector3.ZERO
var _door_query: PhysicsShapeQueryParameters3D
var _speed_mult := 1.0
var _incident_pos := Vector3.ZERO
var _special_point := Vector3.ZERO
var _leader_id := ""
var _face_point := Vector3.ZERO
var _has_face_point := false
var _bubble: Label3D
var _bubble_timer := 0.0
var _frames_in_tier := 0
var _marker: Label3D
var _move_vel := Vector3.ZERO
var _ghost_timer := 0.0
var _far_anim_accum := 0.0


func setup(p_data: NpcData, p_destinations: DestinationRegistry, think_offset: float,
		p_clock: SimClock = null, p_lookup: Callable = Callable()) -> void:
	data = p_data
	destinations = p_destinations
	clock = p_clock
	lookup = p_lookup
	name = data.id
	home_door_id = data.home_id + ":door"
	brain = NpcBrain.new(data.schedule, data.start_delay, data.active_hours)
	_rng.seed = hash(data.id)
	_think_accum = fmod(think_offset, 0.5)
	agent.max_speed = data.walk_speed * NpcBrain.FLEE_SPEED * 1.1
	agent.velocity_computed.connect(_on_velocity_computed)
	model.build(data.shirt_color, data.pants_color, data.skin_color,
		Color("#1d1b24") if data.role == "crew" else Color(0, 0, 0, 0), data.appearance())
	name_label.text = data.display_name
	interactable.prompt = "Talk to %s" % data.display_name
	interactable.kind = "npc"
	interactable.target = data.id
	interactable.on_interact = _talk
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.position = Vector3(0, 2.75, 0)
	_marker.font_size = 96
	_marker.pixel_size = 0.005
	_marker.outline_size = 16
	_marker.modulate = Color("#ffd75e")
	_marker.visible = false
	add_child(_marker)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0, 2.45, 0)
	_bubble.font_size = 44
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 10
	_bubble.modulate = Color("#fff6e0")
	_bubble.visible = false
	add_child(_bubble)
	global_position = destinations.anchor_position(home_door_id)
	_set_inside(true)


func state_name() -> String:
	return brain.state_name() if brain else "NONE"


func current_path() -> PackedVector3Array:
	return agent.get_current_navigation_path() if _travelling else PackedVector3Array()


func set_tier(tier: String) -> void:
	if tier == sim_tier:
		return
	_frames_in_tier = 0
	if sim_tier == "far":
		# Far NPCs move without collisions and may overlap someone; don't let physics
		# shove them apart in one frame when they become physical again.
		collision_mask &= ~LAYER_NPCS
		_ghost_timer = GHOST_TIME
	sim_tier = tier
	_update_avoidance()
	if tier != "near":
		_bubble.visible = false


## Shows a speech bubble for a few seconds (only rendered for nearby NPCs).
func say(text: String, seconds := 3.0) -> void:
	if is_inside or sim_tier != "near":
		return
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer = seconds


## Mission marker above the head: "!" = has a mission for you, "▼" = current target, "" = none.
func set_marker(text: String) -> void:
	_marker.text = text
	_marker.visible = not text.is_empty()


## Joins the player's crew: new role, cap in the player's colour, and a crew schedule.
func recruit(schedule: Array) -> void:
	data.role = "player_crew"
	model.set_hat(Color("#a63a4c"))
	brain.schedule = schedule
	brain.active_hours = Vector2(8, 24)
	brain.index = -1
	interactable.prompt = "Talk to %s (your crew)" % data.display_name


func face_point(p: Vector3) -> void:
	_face_point = p
	_has_face_point = true


## Incident perception, delivered by the SimulationDirector with a reaction already chosen.
func react(event: Dictionary, reaction: String) -> void:
	if is_inside or brain == null:
		return
	var cmds := brain.on_incident(reaction, str(event.id))
	if cmds.is_empty():
		return
	_incident_pos = event.position
	for cmd in cmds:
		_run(cmd)


## Pose and gaze (near tier only): chat gestures, folded arms on guard, heads turn towards
## incidents, the group, or the player standing close by.
func _update_pose() -> void:
	if is_inside or sim_tier != "near":
		return
	var s := brain.state
	model.mode = "talk" if s == NpcBrain.State.SOCIALIZING else ("guard" if s == NpcBrain.State.GUARDING else "idle")
	var look: Variant = null
	if s == NpcBrain.State.NOTICING or s == NpcBrain.State.INVESTIGATING:
		look = _incident_pos
	elif s == NpcBrain.State.SOCIALIZING and _has_face_point:
		look = _face_point
	else:
		var pl: Node3D = lookup.call("player") if lookup.is_valid() else null
		if pl and pl.visible and pl.global_position.distance_to(global_position) < 5.0 and _move_vel.length() < 0.8:
			look = pl.global_position + Vector3(0, 1.5, 0)
	model.look_at_point(look)


func _process(delta: float) -> void:
	_update_pose()
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false


func _physics_process(delta: float) -> void:
	if brain == null:
		return
	_think_accum += delta
	if _think_accum >= THINK_INTERVAL[sim_tier]:
		_think(_think_accum)
		_think_accum = 0.0
	if is_inside:
		return
	if _travelling:
		travel_time += delta
		max_travel_time = maxf(max_travel_time, travel_time)
	if sim_tier == "far":
		_far_step(delta)
		return
	if _ghost_timer > 0.0:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			collision_mask |= LAYER_NPCS
	var desired := Vector3.ZERO
	if _unstick_timer > 0.0:
		# Step clear of whatever we are wedged against, then resume the path.
		_unstick_timer -= delta
		desired = _unstick_dir * data.walk_speed
	elif _travelling:
		if agent.is_navigation_finished():
			_on_path_end()
		else:
			var to_next := agent.get_next_path_position() - global_position
			to_next.y = 0.0
			if to_next.length() > 0.05:
				desired = to_next.normalized() * data.walk_speed * _speed_mult
				# Ease in over the last stretch instead of stopping dead.
				var left := Vector2(agent.target_position.x - global_position.x, agent.target_position.z - global_position.z).length()
				if left < SLOW_RADIUS and brain.state != NpcBrain.State.FOLLOWING:
					desired *= clampf(left / SLOW_RADIUS, 0.45, 1.0)
	var rate := ACCELERATION if desired.length() > _move_vel.length() else DECELERATION
	_move_vel = _move_vel.move_toward(desired, rate * delta)
	if agent.avoidance_enabled:
		agent.velocity = _move_vel
	else:
		_apply_velocity(_move_vel)


## Far tier: advance along the same navigation path every frame, without physics.
func _far_step(dt: float) -> void:
	_far_anim_accum += dt
	if not _travelling:
		_move_vel = Vector3.ZERO
		if _far_anim_accum >= FAR_ANIM_STEP:
			model.animate(_far_anim_accum, 0.0)
			_far_anim_accum = 0.0
		return
	if agent.is_navigation_finished():
		_on_path_end()
		return
	var to_next := agent.get_next_path_position() - global_position
	to_next.y = 0.0
	var dist := to_next.length()
	if dist > 0.01:
		var step := minf(dist, data.walk_speed * _speed_mult * dt)
		global_position += to_next / dist * step
		rotation.y = lerp_angle(rotation.y, atan2(to_next.x, to_next.z), clampf(dt * 6.0, 0.0, 1.0))
		_move_vel = to_next / dist * data.walk_speed * _speed_mult
		if _far_anim_accum >= FAR_ANIM_STEP:
			model.animate(_far_anim_accum, _move_vel.length())
			_far_anim_accum = 0.0
	_last_pos = global_position


func _on_path_end() -> void:
	if brain.state == NpcBrain.State.FOLLOWING:
		return  # caught up with the leader; keep following until the timer ends
	_on_arrived()


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_inside:
		_apply_velocity(safe_velocity)


func _apply_velocity(v: Vector3) -> void:
	var dt := get_physics_process_delta_time()
	_frames_in_tier += 1
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * dt
	move_and_slide()
	_last_wall_normal = Vector3.ZERO
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		n.y = 0.0
		if n.length() > 0.5:
			_last_wall_normal = n.normalized()
	var flat := Vector2(velocity.x, velocity.z)
	var turn := clampf(dt * 8.0, 0.0, 1.0)
	if flat.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), turn)
	elif _has_face_point:
		var to := _face_point - global_position
		if Vector2(to.x, to.z).length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), turn * 0.5)
	model.animate(dt, flat.length())
	# Movement regression guards (see docs/TECH_NOTES.md):
	# - teleport: a jump of more than TELEPORT_DISTANCE in one frame. Must never happen.
	# - nudge: more than a walking step, from physics depenetration after a brief contact
	#   (e.g. leaving the collision-free far tier). Allowed but tracked and kept rare.
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	if moved > TELEPORT_DISTANCE:
		teleport_violations += 1
	elif moved > data.walk_speed * NpcBrain.FLEE_SPEED * 2.0 * dt + 0.05:
		if sim_tier == "near":
			near_nudges += 1
		else:
			offscreen_nudges += 1
	if moved > data.walk_speed * NpcBrain.FLEE_SPEED * 2.0 * dt + 0.05:
		if OS.has_environment("CK_DEBUG"):
			print("DBG jump ", data.id, " moved ", moved, " tier ", sim_tier, " since_tier ", _frames_in_tier, " state ", brain.state_name())
	_last_pos = global_position


func _think(dt: float) -> void:
	if clock:
		brain.clock_hour = clock.hour()
	if not _deferred.is_empty():
		# Waiting inside for someone to clear the doorway before stepping out.
		if _door_blocked():
			path_status = "waiting at door"
			return
		var waiting := _deferred
		_deferred = []
		for cmd in waiting:
			_run(cmd)
	var cmds := brain.update(dt)
	if not cmds.is_empty() and cmds[0].cmd == "exit_home" and _door_blocked():
		_deferred = cmds
		path_status = "waiting at door"
		return
	for cmd in cmds:
		_run(cmd)
	if brain.state == NpcBrain.State.FOLLOWING:
		_update_follow()
		return
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
			_start_unstick()
			_retry("stuck")
		_stuck_accum = 0.0
		_stuck_origin = global_position


func _update_follow() -> void:
	var leader: Node3D = lookup.call(_leader_id) if lookup.is_valid() else null
	if leader == null or (leader is Resident and leader.is_inside):
		_fail("leader unavailable")
		return
	var forward: Vector3 = leader.facing_dir() if leader.has_method("facing_dir") else leader.global_basis.z
	var behind := leader.global_position - forward * FOLLOW_GAP
	_special_point = behind
	_set_target(0.0)
	face_point(leader.global_position)
	path_status = "following " + _leader_id


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
			_speed_mult = float(cmd.get("speed", 1.0))
			_go(cmd.destination)
		"follow":
			_speed_mult = 1.2
			_leader_id = cmd.leader
			target_id = "@leader"
			_update_follow()
		"stop":
			_travelling = false
			agent.target_position = global_position
			path_status = "stopped"
		"face_incident":
			face_point(_incident_pos)
		"reported":
			reported.emit(self, brain.reacting_to)


func _go(dest: String) -> void:
	_repaths = 0
	travel_time = 0.0
	_has_face_point = false
	match dest:
		NpcBrain.HOME:
			target_id = home_door_id
		"@incident":
			target_id = "@incident"
			var a := _rng.randf() * TAU
			_special_point = _incident_pos + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 5.0)
		"@report":
			target_id = destinations.nearest_of_kind(global_position, "house_door", home_door_id)
		"@gate":
			target_id = data.home_id + ":gate"
		_:
			target_id = dest
	if dest == "@incident":
		face_point(_incident_pos)
	if not _set_target(0.0):
		_fail("destination unavailable")


func _set_target(extra_jitter: float) -> bool:
	var pos: Variant
	if target_id.begins_with("@"):
		pos = _special_point + Vector3(_rng.randf_range(-extra_jitter, extra_jitter), 0, _rng.randf_range(-extra_jitter, extra_jitter))
		if destinations.navigation_map.is_valid():
			pos = NavigationServer3D.map_get_closest_point(destinations.navigation_map, pos)
	else:
		pos = destinations.resolve(target_id, _rng, extra_jitter)
	if pos == null:
		return false
	agent.target_position = pos
	if not _travelling:
		_stuck_accum = 0.0
		_stuck_origin = global_position
	_travelling = true
	_check_reachable = true
	path_status = "moving"
	return true


func _start_unstick() -> void:
	var side := Vector3(-_last_wall_normal.z, 0, _last_wall_normal.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_unstick_dir = (_last_wall_normal + side).normalized()
	if _unstick_dir == Vector3.ZERO:
		var a := _rng.randf() * TAU
		_unstick_dir = Vector3(cos(a), 0, sin(a))
	_unstick_timer = UNSTICK_TIME
	unsticks += 1


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
	if OS.has_environment("CK_DEBUG"): print("DBG fail ", data.id, " ", target_id, " ", reason, " ", brain.state_name(), " at ", global_position)
	for cmd in brain.on_travel_failed():
		_run(cmd)


func _on_arrived() -> void:
	_travelling = false
	arrivals += 1
	path_status = "arrived"
	_speed_mult = 1.0
	for cmd in brain.on_arrived():
		_run(cmd)


func _set_inside(inside: bool) -> void:
	var changed := inside != is_inside
	is_inside = inside
	visible = not inside
	velocity = Vector3.ZERO
	_move_vel = Vector3.ZERO
	if changed:
		door_used.emit(data.home_id)
	collision_layer = 0 if inside else LAYER_NPCS
	interactable.set_enabled(not inside)
	_update_avoidance()
	if not inside:
		global_position = destinations.anchor_position(home_door_id)
		reset_physics_interpolation()
	else:
		_bubble.visible = false
	_last_pos = global_position


func _update_avoidance() -> void:
	agent.avoidance_enabled = not is_inside and sim_tier == "near"


func _talk() -> String:
	var line := data.lines[_rng.randi() % data.lines.size()] if not data.lines.is_empty() else "..."
	if data.role == "player_crew":
		return "%s: \"Boss! I'm with you. What's the plan?\"" % data.display_name
	if brain.is_reacting():
		return "%s (%s): \"Did you see that? Something's going on.\"" % [data.display_name, brain.activity]
	var where := destinations.display_name(target_id) if _travelling and not target_id.begins_with("@") else ""
	if where.is_empty():
		return "%s: \"%s\"" % [data.display_name, line]
	return "%s (on the way to %s): \"%s\"" % [data.display_name, where, line]
