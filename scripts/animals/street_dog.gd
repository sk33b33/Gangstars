class_name StreetDog
extends CharacterBody3D
## A neighbourhood dog. Two kinds:
## - street: wanders the pavements around its home patch on the navigation mesh, naps in the sun,
##   barks at the player from a few metres (or, if friendly, trots along for a bit).
## - yard: lives in one house's front yard (steers directly, never leaves it), runs to the fence
##   and barks when the player walks past.
## Cosmetic: no collisions with people or cars (world only), no effect on the simulation.

signal barked(dog: StreetDog, pos: Vector3)

const WALK := 1.0
const TROT := 2.4
const GRAVITY := 9.8
const WANDER_RADIUS := 22.0
const NOTICE_STREET := 5.5
const NOTICE_YARD := 7.0
const BARK_COOLDOWN := 18.0

var dog_id := ""
var kind := "street"
var friendly := false
var state := "idle"      # idle | wander | nap | alert | follow
var model: DogModel
var agent: NavigationAgent3D
var player: Node3D
var gate_points: PackedVector3Array = []   # street dogs: wander targets (pavement outside plots)
var yard_plot: Node3D                      # yard dogs: the plot (local +Z = street)
var yard_rect: Rect2
var nav_map: RID
var barks := 0
var max_step := 0.0                        # largest per-frame move seen (tests: no teleports)
var distance_walked := 0.0

var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _target := Vector3.ZERO
var _moving := false
var _speed := 0.0
var _bark_timer := 0.0
var _cooldown := 0.0
var _last := Vector3.ZERO
var _stuck := 0.0
var _started := false


func setup(p_id: String, p_kind: String, coat: Color, light: Color, size: float) -> void:
	dog_id = p_id
	kind = p_kind
	name = p_id
	_rng.seed = hash(p_id)
	friendly = kind == "street" and _rng.randf() < 0.4
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.22
	cap.height = 0.6
	shape.shape = cap
	shape.position = Vector3(0, 0.3, 0)
	add_child(shape)
	model = DogModel.new()
	add_child(model)
	model.build(coat, light, size)
	if kind == "street":
		agent = NavigationAgent3D.new()
		agent.path_desired_distance = 0.6
		agent.target_desired_distance = 0.6
		agent.radius = 0.3
		add_child(agent)
	_timer = _rng.randf_range(1.0, 6.0)
	_last = global_position


## LOD: far-away dogs freeze (no physics, no animation). They never move while frozen.
func set_active(active: bool) -> void:
	set_physics_process(active)


func _physics_process(dt: float) -> void:
	_timer -= dt
	_cooldown = maxf(0.0, _cooldown - dt)
	var near_player := _player_close()
	match state:
		"idle":
			if near_player and _cooldown <= 0.0:
				_alert()
			elif _timer <= 0.0:
				if _rng.randf() < 0.35:
					_nap()
				else:
					_wander()
		"nap":
			if near_player and _cooldown <= 0.0 and _rng.randf() < 0.02:
				_alert()   # wakes up eventually if you hang around
			elif _timer <= 0.0:
				model.lying = false
				state = "idle"
				_timer = _rng.randf_range(2.0, 5.0)
		"wander":
			if near_player and _cooldown <= 0.0:
				_alert()
			elif not _moving or _timer <= 0.0:
				state = "idle"
				_timer = _rng.randf_range(3.0, 10.0)
		"alert":
			_update_alert(dt)
		"follow":
			if player == null or _timer <= 0.0 or global_position.distance_to(player.global_position) > 14.0:
				_cooldown = BARK_COOLDOWN * 2.0
				_wander()
			else:
				_go_to(player.global_position + (global_position - player.global_position).normalized() * 1.4, TROT * 0.8)
	_move(dt)


func _player_close() -> bool:
	if player == null or not player.visible:
		return false
	var d := global_position.distance_to(player.global_position)
	return d < (NOTICE_YARD if kind == "yard" else NOTICE_STREET)


func _wander() -> void:
	state = "wander"
	model.lying = false
	_timer = 25.0
	if kind == "yard":
		_go_to(_yard_point(Vector2(_rng.randf_range(0, 1), _rng.randf_range(0, 1))), WALK)
	elif not gate_points.is_empty():
		var p := gate_points[_rng.randi() % gate_points.size()]
		p += Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
		_go_to(NavigationServer3D.map_get_closest_point(nav_map, p) if nav_map.is_valid() else p, WALK)


func _nap() -> void:
	state = "nap"
	_moving = false
	model.lying = true
	_timer = _rng.randf_range(20.0, 45.0)


func _alert() -> void:
	model.lying = false
	if friendly:
		state = "follow"
		_timer = _rng.randf_range(8.0, 14.0)
		return
	state = "alert"
	_timer = _rng.randf_range(6.0, 12.0)
	_bark_timer = 0.3
	if kind == "yard":
		# Run to the fence on the player's side.
		var local: Vector3 = yard_plot.global_transform.affine_inverse() * player.global_position
		_go_to(yard_plot.global_transform * Vector3(clampf(local.x, yard_rect.position.x, yard_rect.end.x), 0, yard_rect.end.y), TROT)
	else:
		_moving = false


func _update_alert(dt: float) -> void:
	if player == null or _timer <= 0.0 or not _player_close():
		state = "idle"
		_cooldown = BARK_COOLDOWN
		_timer = _rng.randf_range(2.0, 6.0)
		return
	if not _moving:
		_face(player.global_position, dt)
	_bark_timer -= dt
	if _bark_timer <= 0.0:
		_bark_timer = _rng.randf_range(0.7, 1.3)
		model.bark()
		barks += 1
		barked.emit(self, global_position + Vector3(0, 0.6, 0))


func _go_to(p: Vector3, speed: float) -> void:
	_target = p
	_speed = speed
	_moving = true
	_stuck = 0.0
	if agent:
		agent.target_position = p


func _yard_point(uv: Vector2) -> Vector3:
	var local := Vector3(yard_rect.position.x + uv.x * yard_rect.size.x, 0, yard_rect.position.y + uv.y * yard_rect.size.y)
	return yard_plot.global_transform * local


func _face(p: Vector3, dt: float) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(dt * 6.0, 0.0, 1.0))


func _move(dt: float) -> void:
	var desired := Vector3.ZERO
	if _moving:
		var next := _target
		if agent and not agent.is_navigation_finished():
			next = agent.get_next_path_position()
		var to := next - global_position
		to.y = 0.0
		var left := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
		if left < 0.4 or (agent and agent.is_navigation_finished() and left < 1.0):
			_moving = false
		elif to.length() > 0.05:
			desired = to.normalized() * _speed * clampf(left / 1.0, 0.4, 1.0)
		_stuck += dt
		if _stuck > 2.0:
			if global_position.distance_to(_last_stuck_check) < 0.3:
				_moving = false   # wedged against something: give up on this target
			_last_stuck_check = global_position
			_stuck = 0.0
	velocity.x = move_toward(velocity.x, desired.x, 6.0 * dt)
	velocity.z = move_toward(velocity.z, desired.z, 6.0 * dt)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * dt
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), clampf(dt * 8.0, 0.0, 1.0))
	model.animate(dt, flat.length())
	if _started:
		var step := Vector2(global_position.x - _last.x, global_position.z - _last.z).length()
		max_step = maxf(max_step, step)
		distance_walked += step
	_started = true
	_last = global_position


var _last_stuck_check := Vector3.ZERO
