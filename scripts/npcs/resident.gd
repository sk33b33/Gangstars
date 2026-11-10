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
const LAYER_VEHICLES := 1 << 4
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
const MAX_TRIP_TIME := 90.0  # a trip this long is "moving but not arriving": re-plan
const FAR_ANIM_STEP := 0.1    # far NPCs animate at 10 Hz
## Activities during which a resident may settle into a nearby spot, and which kinds (in order).
const SPOT_ACTIVITIES := {"waiting": ["sit", "lean"], "relaxing": ["sit", "lean"], "socializing": ["lean", "sit"],
	"visiting": ["sit"], "playing": ["sit"], "shopping": ["lean"]}
const SPOT_RANGE := 7.0
const SPOT_CHANCE := 0.75
const SETTLE_SPEED := 0.9     # m/s while stepping into / out of a seat (scripted, no physics)
const WAVE_COOLDOWN := 120.0
## Who carries a weapon and fights back.
const FIGHT_ROLES := ["crew", "police", "player_crew"]
const FIGHT_RANGE := 40.0
const FIGHT_LOST_TIME := 12.0
## Shooting accuracy (spread multiplier): police are trained, gangsters spray.
const SPREAD := {"police": 1.8, "crew": 2.6, "player_crew": 2.2}
const FIGHT_LINES := {"police": ["Police! Drop it!", "Stop! Police!", "Get down!"],
	"crew": ["You picked the wrong street!", "Eish, now you've done it!", "Get him!"],
	"player_crew": ["I've got your back!", "Leave him alone!"]}

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
## Crew further than this behind the player jog to catch up.
const CATCH_UP_DISTANCE := 30.0
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
var spots: SpotRegistry
## Set by a KickAbout while this kid is playing: where to run (null = not playing).
var play_target: Variant = null
var play_speed := 0.0
## Settling into a spot: "" | "approach" (walking to it) | "settle" | "seated" | "rise".
var spot_phase := ""
var _spot := -1
var _spot_queue: Array = []    # commands that arrived while seated; run once standing again
var _wave_cooldown := 0.0
var _player_was_near := false
var _prev_state := -1
var waves := 0
## Combat (see CombatSystem): health, who we're fighting, and counters for tests.
var health := Health.new()
## The player's crew (set by District.set_player_crew): our crew-mates treat the player as one of us.
var player_faction := ""
var combat: CombatSystem
var fight_target: Node3D
var shots_fired := 0
var _fire_cd := 0.0
var _fight_repath := 0.0
var _fight_lost := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _los_timer := 0.0
var _los := false
var times_settled := 0
var settled_kinds := {}


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
	_arm()
	health.recovered.connect(_on_recovered)
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
	if tier == "far" and spot_phase == "approach":
		_leave_spot()
	if tier == sim_tier:
		return
	_frames_in_tier = 0
	if sim_tier == "far":
		# Far NPCs move without collisions and may overlap someone; don't let physics
		# shove them apart in one frame when they become physical again.
		collision_mask &= ~(LAYER_NPCS | LAYER_VEHICLES)
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
	brain.active_hours = Vector2(8, 2)
	brain.index = -1
	interactable.prompt = "Talk to %s (your crew)" % data.display_name
	_arm()


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
	if s == NpcBrain.State.FIGHTING or s == NpcBrain.State.DOWN:
		model.mode = "idle"
		model.look_at_point(fight_target.global_position + Vector3(0, 1.4, 0) if fight_target != null and is_instance_valid(fight_target) else null)
		return
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
	_maybe_wave(s)


## Friendly residents wave when the player walks up, and sometimes when a chat starts.
func _maybe_wave(s: NpcBrain.State) -> void:
	var pl: Node3D = lookup.call("player") if lookup.is_valid() else null
	var near := pl != null and pl.visible and pl.global_position.distance_to(global_position) < 7.0
	var friendly := (data.role in ["resident", "player_crew", "kid"] or is_ally()) and not brain.is_reacting() \
		and not brain.state in [NpcBrain.State.FIGHTING, NpcBrain.State.DOWN]
	if friendly and _wave_cooldown <= 0.0:
		if near and not _player_was_near:
			_wave_at(pl.global_position)
		elif s == NpcBrain.State.SOCIALIZING and _prev_state != NpcBrain.State.SOCIALIZING and _rng.randf() < 0.4:
			_wave_at(_face_point)
	_player_was_near = near
	_prev_state = s


func _wave_at(p: Vector3) -> void:
	model.wave()
	model.look_at_point(p + Vector3(0, 1.5, 0))
	_wave_cooldown = WAVE_COOLDOWN
	waves += 1


func _process(delta: float) -> void:
	_wave_cooldown = maxf(0.0, _wave_cooldown - delta)
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
	health.tick(delta)
	if health.down:
		_down_step(delta)
		return
	if spot_phase in ["settle", "seated", "rise"]:
		_spot_step(delta)
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
			if _overlaps_body():
				_ghost_timer = 0.5  # still inside someone: wait until we've walked clear
			else:
				collision_mask |= LAYER_NPCS | LAYER_VEHICLES
	var desired := Vector3.ZERO
	if _unstick_timer > 0.0:
		# Step clear of whatever we are wedged against, then resume the path.
		_unstick_timer -= delta
		desired = _unstick_dir * data.walk_speed
	elif spot_phase == "approach":
		var to_spot := spots.approach(_spot) - global_position
		to_spot.y = 0.0
		if agent.is_navigation_finished() or to_spot.length() < 0.25:
			spot_phase = "settle"
			model.base_pose = spots.kind(_spot)
			_move_vel = Vector3.ZERO
			return
		var step_to := agent.get_next_path_position() - global_position
		step_to.y = 0.0
		if step_to.length() > 0.05:
			desired = step_to.normalized() * data.walk_speed * 0.8 * clampf(to_spot.length() / SLOW_RADIUS, 0.45, 1.0)
	elif fight_target != null:
		desired = _fight_desired(delta)
	elif play_target != null and not _travelling:
		var to_play: Vector3 = play_target - global_position
		to_play.y = 0.0
		if to_play.length() > 0.35:
			desired = to_play.normalized() * play_speed * clampf(to_play.length() / 0.8, 0.5, 1.0)
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
	if agent.avoidance_enabled and play_target == null and fight_target == null:
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
	# Kids at play bypass avoidance (a tight group of standing kids makes RVO return zero).
	if not is_inside and spot_phase in ["", "approach"] and play_target == null and fight_target == null and not health.down:
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
	if fight_target != null and is_instance_valid(fight_target):
		var tf := fight_target.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(tf.x, tf.z), clampf(dt * 10.0, 0.0, 1.0))
	elif flat.length() > 0.1:
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
	if travel_time > MAX_TRIP_TIME:
		travel_time = 0.0
		_start_unstick()
		_retry("trip too long")
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
	# Crew following the player don't give up while still catching up, and jog when far behind.
	var gap := leader.global_position.distance_to(global_position)
	if not leader is Resident and gap > 20.0:
		brain.timer = maxf(brain.timer, 20.0)
	_speed_mult = NpcBrain.FLEE_SPEED if not leader is Resident and gap > CATCH_UP_DISTANCE else 1.2
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
	if spot_phase != "" and cmd.cmd in ["go", "follow", "stop", "exit_home", "enter_home"]:
		if spot_phase == "approach":
			_leave_spot()
		else:
			# Seated or leaning: stand up and step out first, then carry on.
			_spot_queue.append(cmd)
			if spot_phase != "rise":
				_rise()
			return
	match cmd.cmd:
		"__fight":
			if is_instance_valid(cmd.target):
				start_fight(cmd.target)
		"exit_home":
			_set_inside(false)
		"enter_home":
			_set_inside(true)
		"go":
			play_target = null
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


var _overlap_query: PhysicsShapeQueryParameters3D


## True if this NPC's capsule currently overlaps another NPC or a vehicle.
func _overlaps_body() -> bool:
	if _overlap_query == null:
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.75
		_overlap_query = PhysicsShapeQueryParameters3D.new()
		_overlap_query.shape = capsule
		_overlap_query.collision_mask = LAYER_NPCS | LAYER_VEHICLES
		_overlap_query.exclude = [get_rid()]
	_overlap_query.transform = Transform3D(Basis(), global_position + Vector3(0, 0.875, 0))
	return not get_world_3d().direct_space_state.intersect_shape(_overlap_query, 1).is_empty()


## Hooted at by a car: walk sideways out of the lane for a moment, then carry on.
func step_aside(direction: Vector3) -> void:
	if is_inside:
		return
	direction.y = 0.0
	_unstick_dir = direction.normalized()
	_unstick_timer = 1.6
	say("Ja, ja, I'm moving!", 2.0)


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
	_try_spot()


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


# ------------------------------------------------------------------ combat

func _arm() -> void:
	if not data.role in FIGHT_ROLES:
		return
	var h := absi(data.id.hash())
	var gun := "shotgun" if (data.role == "crew" and h % 3 == 0) or (data.role == "police" and h % 5 == 0) else "pistol"
	model.set_weapon(gun)


func is_down() -> bool:
	return health.down


func can_fight() -> bool:
	return not model.weapon.is_empty() and not is_inside and not health.down


## Hit by a shot. Returns true if it knocked us down.
func on_shot(damage: float, shooter: Node3D) -> bool:
	if is_inside or health.down:
		return false
	model.flinch()
	if health.take(damage):
		_knock_down()
		return true
	if fight_target == null and shooter != null:
		if can_fight() and _hostile_to(shooter):
			start_fight(shooter)
		elif not data.role in FIGHT_ROLES:
			react({"id": "shot_%d" % Time.get_ticks_msec(), "position": shooter.global_position}, "flee")
	return false


## A member of the player's own crew.
func is_ally() -> bool:
	return data.role == "crew" and not player_faction.is_empty() and data.faction_id == player_faction


func _hostile_to(other: Node3D) -> bool:
	if other == self:
		return false
	if other is Player and is_ally():
		return false
	if data.role == "player_crew" and other is Player:
		return false
	if other is Resident and (other as Resident).data.role == data.role and data.role != "crew":
		return false   # police don't fight police; crew rivalries are fine
	return true


## Starts (or redirects) a fight. False if this resident can't fight now.
func start_fight(target: Node3D) -> bool:
	if not can_fight() or target == null or target == self:
		return false
	if target == fight_target:
		return true
	if spot_phase in ["settle", "seated", "rise"]:
		_spot_queue = [{"cmd": "__fight", "target": target}]
		if spot_phase != "rise":
			_rise()
		return true
	if spot_phase == "approach":
		_leave_spot()
	if not brain.on_fight():
		return false
	var first := fight_target == null
	fight_target = target
	play_target = null
	_travelling = false
	_fight_lost = 0.0
	_fire_cd = _rng.randf_range(0.6, 1.4)   # a beat to draw before the first shot
	model.draw_weapon(true)
	if first and _rng.randf() < 0.7:
		var lines: Array = FIGHT_LINES.get(data.role, [])
		if not lines.is_empty():
			say(lines[_rng.randi() % lines.size()], 2.5)
	return true


func end_fight() -> void:
	if fight_target == null:
		return
	fight_target = null
	model.aiming = false
	model.draw_weapon(false)
	agent.target_position = global_position
	for cmd in brain.end_fight():
		_run(cmd)


func _fight_desired(dt: float) -> Vector3:
	var t := fight_target
	var gone: bool = not is_instance_valid(t) or (t.has_method("is_down") and t.is_down()) \
		or (t is Resident and (t as Resident).is_inside) or t.global_position.distance_to(global_position) > FIGHT_RANGE
	if gone:
		end_fight()
		return Vector3.ZERO
	var to := t.global_position - global_position
	to.y = 0.0
	var d := to.length()
	_los_timer -= dt
	if _los_timer <= 0.0:
		_los_timer = 0.25
		_los = _line_of_sight(t)
	_fight_lost = 0.0 if _los else _fight_lost + dt
	if _fight_lost > FIGHT_LOST_TIME:
		end_fight()
		return Vector3.ZERO
	model.aiming = _los and d < 28.0
	var desired := Vector3.ZERO
	if d > 14.0 or not _los:
		_fight_repath -= dt
		if _fight_repath <= 0.0:
			_fight_repath = 0.6
			agent.target_position = t.global_position
		if not agent.is_navigation_finished():
			var n := agent.get_next_path_position() - global_position
			n.y = 0.0
			if n.length() > 0.05:
				desired = n.normalized() * data.walk_speed * 1.6
	elif d < 5.0:
		desired = -to / d * data.walk_speed
	else:
		_strafe_t -= dt
		if _strafe_t <= 0.0:
			_strafe = -_strafe
			_strafe_t = _rng.randf_range(1.5, 3.0)
		desired = to.cross(Vector3.UP).normalized() * _strafe * 0.8
	_fire_cd -= dt
	if model.aiming and _fire_cd <= 0.0 and combat:
		var st := WeaponLibrary.stats(model.weapon)
		_fire_cd = 1.0 / float(st.rate) * _rng.randf_range(1.4, 2.4)
		combat.fire(self, model.weapon, model.muzzle_position(), t.global_position + Vector3(0, 1.2, 0), float(SPREAD.get(data.role, 2.5)))
		shots_fired += 1
	return desired


func _line_of_sight(t: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), t.global_position + Vector3(0, 1.3, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _knock_down() -> void:
	if fight_target != null:
		fight_target = null
	model.aiming = false
	model.draw_weapon(false)
	play_target = null
	_travelling = false
	if spot_phase != "":
		spot_phase = ""
		if spots and _spot >= 0:
			spots.release(_spot, data.id)
		_spot = -1
		_spot_queue = []
	brain.on_knocked_down()
	model.base_pose = "down"
	collision_layer = 0
	path_status = "knocked down"


func _down_step(dt: float) -> void:
	_move_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	if agent.avoidance_enabled:
		agent.velocity = Vector3.ZERO
	model.animate(dt, 0.0)
	_last_pos = global_position


func _on_recovered() -> void:
	model.base_pose = ""
	collision_layer = LAYER_NPCS
	say("Ag, my head...", 2.5)
	for cmd in brain.on_recovered():
		_run(cmd)


# ------------------------------------------------------------------ benches, chairs, walls

func _try_spot() -> void:
	if spots == null or spot_phase != "" or sim_tier == "far" or is_inside:
		return
	if not brain.state in [NpcBrain.State.AT_DESTINATION, NpcBrain.State.SOCIALIZING]:
		return
	var kinds: Array = SPOT_ACTIVITIES.get(brain.activity, [])
	if kinds.is_empty() or _rng.randf() > SPOT_CHANCE:
		return
	# Prefer the first kind; fall back to the second if nothing of the first is free nearby.
	for kind in kinds:
		_spot = spots.claim(global_position, [kind], SPOT_RANGE, data.id)
		if _spot >= 0:
			break
	if _spot < 0:
		return
	spot_phase = "approach"
	agent.target_position = spots.approach(_spot)
	path_status = "to a %s spot" % spots.kind(_spot)


## Scripted (physics-free) steps into and out of a seat or wall spot; always slower than walking,
## so it never counts as a teleport.
func _spot_step(dt: float) -> void:
	var target := spots.position(_spot) if spot_phase != "rise" else spots.approach(_spot)
	var to := target - global_position
	to.y = 0.0
	var step := SETTLE_SPEED * dt
	if to.length() > step:
		global_position += to.normalized() * step
	else:
		global_position = Vector3(target.x, global_position.y, target.z)
	if spot_phase != "rise":
		rotation.y = lerp_angle(rotation.y, spots.yaw(_spot), clampf(dt * 6.0, 0.0, 1.0))
		if spot_phase == "settle" and to.length() <= step:
			spot_phase = "seated"
			times_settled += 1
			settled_kinds[spots.kind(_spot)] = int(settled_kinds.get(spots.kind(_spot), 0)) + 1
			path_status = "%s down" % ("sitting" if spots.kind(_spot) == "sit" else "leaning")
	elif to.length() <= step:
		_leave_spot()
		var queued := _spot_queue
		_spot_queue = []
		for cmd in queued:
			_run(cmd)
	_move_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	if agent.avoidance_enabled:
		agent.velocity = Vector3.ZERO
	model.animate(dt, 0.0)
	_last_pos = global_position


func _rise() -> void:
	spot_phase = "rise"
	model.base_pose = ""


func _leave_spot() -> void:
	if spots and _spot >= 0:
		spots.release(_spot, data.id)
	_spot = -1
	spot_phase = ""
	model.base_pose = ""
	agent.target_position = global_position


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
