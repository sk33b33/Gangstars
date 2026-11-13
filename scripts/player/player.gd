class_name Player
extends CharacterBody3D
## Third-person player: camera-relative movement, mouse/stick look with pitch limits,
## and contextual interaction with the nearest Interactable in range.

signal interaction_target_changed(target: Interactable)
signal interacted(message: String)
signal shouted(position: Vector3)
## Emitted with the target and its feedback; gameplay systems (missions) hook in here.
signal interacted_with(target: Interactable, message: String)
signal vehicle_changed(car: DrivableCar)   # null when stepping out
signal honked(position: Vector3)
signal fired(weapon: String)
signal knocked_out

const GRAVITY := 9.8
const CAMERA_HEIGHT := 1.6
const CAMERA_FOLLOW := 14.0  # higher = tighter; smooths steps and landings

@export var walk_speed := 3.4
@export var sprint_speed := 6.5
@export var acceleration := 14.0
@export var jump_velocity := 4.2
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 2.6
## Controller rumble on hoots and getting in/out of cars (settings: controls/vibration).
var vibration := true
@export var min_pitch := -1.1
@export var max_pitch := 0.35

@onready var pivot: Node3D = $CameraPivot
@onready var pitch: Node3D = $CameraPivot/Pitch
@onready var spring_arm: SpringArm3D = $CameraPivot/Pitch/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/Pitch/SpringArm3D/Camera3D
@onready var model: CharacterModel = $Model
@onready var sensor: Area3D = $InteractionSensor

var current_target: Interactable
var input_enabled := true:
	set(v):
		if v and not input_enabled:
			_enabled_frame = Engine.get_physics_frames()
		input_enabled = v
## Physics frame input was last re-enabled on: the button that closed a menu (A on a pad is
## both "accept" and "interact") must not also act in the world on the same press.
var _enabled_frame := -10
var vehicle: DrivableCar
var invert_y := false
var _saved_layer := 0
var _saved_mask := 0
## Combat: a pistol from the start; aim (RMB / LT) then fire (LMB / RT). See CombatSystem.
var health := Health.new()
var combat: CombatSystem
var weapon := "pistol"
var weapons: PackedStringArray = ["pistol"]
var aiming := false
## Touch auto-lock: while on, the weapon is raised and the camera swings onto the nearest armed
## stranger in range (set by TouchControls' LOCK button).
var auto_lock := false
var lock_target: Node3D
const LOCK_RANGE := 30.0
var shots_fired := 0
var _fire_cd := 0.0
var _draw_timer := 0.0
var _arm_length := 0.0
const AIM_ARM_LENGTH := 1.7
const AIM_SHOULDER := 0.55
const AIM_SPEED := 2.0


func _ready() -> void:
	wear_colours(Color("#f1eee8"), Color("#a63a4c"))
	spring_arm.add_excluded_object(get_rid())
	_arm_length = spring_arm.spring_length
	model.set_weapon(weapon)
	snap_camera()


## The camera rig is top-level and follows the *interpolated* body position every rendered
## frame, so motion stays smooth at any refresh rate (physics runs at 60 Hz).
func _process(delta: float) -> void:
	var target := get_global_transform_interpolated().origin + Vector3(0, CAMERA_HEIGHT, 0)
	var p := pivot.global_position
	p.x = target.x
	p.z = target.z
	p.y = lerpf(p.y, target.y, clampf(delta * CAMERA_FOLLOW, 0.0, 1.0))
	pivot.global_position = p


## Call after moving the player directly (spawn, load, debug teleport).
func snap_camera() -> void:
	reset_physics_interpolation()
	pivot.global_position = global_position + Vector3(0, CAMERA_HEIGHT, 0)


## False on a touchscreen: dragging a finger must not turn the camera (the look stick does that).
var mouse_look_enabled := true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and mouse_look_enabled:
		_look(Vector2(event.relative.x, event.relative.y) * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_driving() -> bool:
	return vehicle != null


## Gets into a car: hide, stop colliding, ride along with it (camera follows the car).
func enter_vehicle(car: DrivableCar) -> void:
	if vehicle or car == null or car.is_driven():
		return
	vehicle = car
	car.driver = self
	_saved_layer = collision_layer
	_saved_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	model.visible = false
	velocity = Vector3.ZERO
	if current_target:
		current_target = null
		interaction_target_changed.emit(null)
	pivot.rotation.y = car.rotation.y + PI
	rumble(0.0, 0.4, 0.2)
	vehicle_changed.emit(car)


func exit_vehicle() -> void:
	if vehicle == null:
		return
	var car := vehicle
	global_position = car.exit_position() + Vector3(0, 0.05, 0)
	car.driver = null
	vehicle = null
	collision_layer = _saved_layer
	collision_mask = _saved_mask
	model.visible = true
	snap_camera()
	vehicle_changed.emit(null)


func _physics_process(delta: float) -> void:
	if vehicle:
		global_position = vehicle.global_position
		if _pressed("interact"):
			exit_vehicle()
		elif _pressed("shout"):
			honked.emit(global_position)
			rumble(0.3, 0.0, 0.25)
		var look_v := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look_v != Vector2.ZERO:
			_look(look_v * stick_sensitivity * delta)
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_look(look * stick_sensitivity * delta)
	health.tick(delta)
	if health.down:
		velocity = Vector3(0, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, 0)
		move_and_slide()
		model.animate(delta, 0.0)
		return
	_update_aim(delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if input_enabled else Vector2.ZERO
	var dir := pivot.global_basis * Vector3(input.x, 0, input.y)
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var speed := AIM_SPEED if aiming else (sprint_speed if Input.is_action_pressed("sprint") else walk_speed)
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if is_on_floor():
		velocity.y = 0.0
		if _pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var flat := Vector2(velocity.x, velocity.z)
	if aiming:
		var fwd := -pivot.global_basis.z
		model.rotation.y = lerp_angle(model.rotation.y, atan2(fwd.x, fwd.z), clampf(delta * 18.0, 0.0, 1.0))
	elif flat.length() > 0.2:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(velocity.x, velocity.z), clampf(delta * 12.0, 0.0, 1.0))
	model.animate(delta, flat.length())

	if _pressed("shout"):
		shouted.emit(global_position)
	_update_target()
	if current_target and _pressed("interact"):
		var msg := current_target.interact(self)
		interacted_with.emit(current_target, msg)
		interacted.emit(msg)


## Dresses the player (crew colours: shirt and cap). Keeps the weapon.
func wear_colours(shirt: Color, cap: Color, crew := "") -> void:
	model.build(shirt, Color("#29384a"), Color("#8d5a3b"), cap, {"hair_style": "short", "height": 1.02, "sleeves": "short",
		"pants_style": "denim", "face": "face_m", "cap_logo": crew})
	if not weapon.is_empty():
		model.set_weapon(weapon)


func add_weapon(w: String) -> void:
	if not weapons.has(w) and not WeaponLibrary.stats(w).is_empty():
		weapons.append(w)


## Tab / RB: next weapon.
func switch_weapon() -> void:
	if weapons.size() < 2:
		return
	weapon = weapons[(weapons.find(weapon) + 1) % weapons.size()]
	model.set_weapon(weapon)
	model.draw_weapon(aiming or _draw_timer > 0.0)


## Aim with RMB / LT (over-the-shoulder camera, slower walk), fire with LMB / RT.
func _update_aim(delta: float) -> void:
	var locking := input_enabled and auto_lock and not weapon.is_empty()
	aiming = input_enabled and not weapon.is_empty() and (Input.is_action_pressed("aim") or locking)
	if locking:
		_lock_on(delta)
	else:
		lock_target = null
	_draw_timer = 3.0 if aiming else maxf(0.0, _draw_timer - delta)
	model.draw_weapon(_draw_timer > 0.0)
	model.aiming = aiming
	var k := clampf(delta * 10.0, 0.0, 1.0)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, AIM_ARM_LENGTH if aiming else _arm_length, k)
	spring_arm.position.x = lerpf(spring_arm.position.x, AIM_SHOULDER if aiming else 0.0, k)
	if _pressed("switch_weapon"):
		switch_weapon()
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if aiming and _fire_cd <= 0.0 and input_enabled and Input.is_action_just_pressed("fire"):
		shoot()


## Nearest armed, non-allied resident within range (or null).
func find_lock_target() -> Node3D:
	var best: Node3D = null
	var best_d := LOCK_RANGE
	for n in get_tree().get_nodes_in_group("residents"):
		var r := n as Resident
		if r == null or not r.visible or not r.can_fight() or r.is_ally():
			continue
		var d := global_position.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


func _lock_on(delta: float) -> void:
	if lock_target == null or not is_instance_valid(lock_target) or (lock_target as Resident).health.down \
			or global_position.distance_to(lock_target.global_position) > LOCK_RANGE + 5.0:
		lock_target = find_lock_target()
	if lock_target == null:
		return
	var chest: Vector3 = lock_target.global_position + Vector3(0, 1.3, 0)
	var dir := (chest - camera.global_position).normalized()
	var k := clampf(delta * 8.0, 0.0, 1.0)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(-dir.x, -dir.z), k)
	pitch.rotation.x = clampf(lerpf(pitch.rotation.x, asin(dir.y), k), min_pitch, max_pitch)


## Fires the weapon at whatever is under the screen centre.
func shoot() -> bool:
	if combat == null or weapon.is_empty() or health.down:
		return false
	var st := WeaponLibrary.stats(weapon)
	_fire_cd = 1.0 / float(st.rate)
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 80.0, CombatSystem.SHOT_MASK)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var aim_point: Vector3 = hit.position if not hit.is_empty() else from + dir * 80.0
	combat.fire(self, weapon, model.muzzle_position(), aim_point, 0.5)
	shots_fired += 1
	rumble(0.2, 0.5, 0.12)
	fired.emit(weapon)
	return true


## Hit by a shot. Returns true if it knocked the player out.
func on_shot(damage: float, _shooter: Node3D) -> bool:
	if health.down:
		return false
	model.flinch()
	rumble(0.6, 0.6, 0.2)
	if health.take(damage * (0.5 if vehicle else 1.0)):
		if vehicle:
			exit_vehicle()
		model.base_pose = "down"
		aiming = false
		model.aiming = false
		knocked_out.emit()
		return true
	return false


func is_down() -> bool:
	return health.down


## Wakes up (at the safehouse): back on your feet with full health.
func revive_at(pos: Vector3) -> void:
	global_position = pos + Vector3(0, 0.05, 0)
	health.revive(Health.MAX_HP)
	model.base_pose = ""
	snap_camera()


## Direction the character faces (used by crew members following the player).
func facing_dir() -> Vector3:
	return model.global_basis.z


func _look(delta_look: Vector2) -> void:
	pivot.rotate_y(-delta_look.x)
	var dy := -delta_look.y if invert_y else delta_look.y
	pitch.rotation.x = clampf(pitch.rotation.x - dy, min_pitch, max_pitch)


## Picks the nearest enabled interactable, preferring ones in front of the camera.
func _update_target() -> void:
	var best: Interactable = null
	var best_score := INF
	var forward := -pivot.global_basis.z
	for area in sensor.get_overlapping_areas():
		if not area is Interactable or not area.is_enabled():
			continue
		var to: Vector3 = area.global_position - global_position
		to.y = 0.0
		var score := to.length() - forward.dot(to.normalized()) * 0.8
		if score < best_score:
			best_score = score
			best = area
	if best != current_target:
		current_target = best
		interaction_target_changed.emit(best)


func _pressed(action: String) -> bool:
	return input_enabled and Engine.get_physics_frames() > _enabled_frame + 1 and Input.is_action_just_pressed(action)


## Short controller rumble, only when a pad is the active device.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if vibration and InputHints.gamepad:
		for pad in Input.get_connected_joypads():
			Input.start_joy_vibration(pad, weak, strong, seconds)
