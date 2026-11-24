class_name RemyPlayer
extends CharacterBody3D
## Third-person player that uses the Remy model (scenes/characters/remy/remy_player.tscn). It is a separate
## player from the game's own Player (scripts/player/player.gd): nothing in the game uses it yet.
## It reads the project's input actions, so keyboard, gamepad and the on-screen TouchControls all work:
##   move_*  look_*  sprint  jump  aim   (and `fire`, which it ignores for now)
## It has the same few properties TouchControls expects (input_enabled, mouse_look_enabled, auto_lock).

signal jumped
signal landed

const GRAVITY := 9.8
const CAMERA_HEIGHT := 1.5
const CAMERA_FOLLOW := 14.0      # higher = tighter; smooths steps and landings
const AIM_ARM_LENGTH := 1.8
const AIM_SHOULDER := 0.55
## A stick pushed less than this far walks (slowly to Walk speed); further it runs (Run speed).
const RUN_THRESHOLD := 0.55

@export var walk_speed := 1.7
@export var run_speed := 4.0
@export var sprint_speed := 6.0
@export var aim_speed := 1.7      # walking while the gun is up (there are no strafe clips yet: keep it slow)
@export var acceleration := 16.0
@export var air_control := 0.35   # how much of the ground acceleration works in the air
@export var jump_velocity := 4.6
@export var turn_rate := 12.0     # radians per second, towards the movement direction
@export var aim_turn_rate := 18.0
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 2.6
@export var min_pitch := -1.1
@export var max_pitch := 0.35

@onready var model: RemyModel = $RemyModel
@onready var pivot: Node3D = $CameraPivot
@onready var pitch: Node3D = $CameraPivot/Pitch
@onready var spring_arm: SpringArm3D = $CameraPivot/Pitch/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/Pitch/SpringArm3D/Camera3D

var input_enabled := true
## False on a touchscreen: the mouse events a touch emulates must not turn the camera (TouchControls turns it from the touch drags).
var mouse_look_enabled := true
## TouchControls' LOCK button: while on, the gun stays up (there is nothing to lock onto in this player).
var auto_lock := false
var aiming := false
var sprinting := false

var _arm_length := 0.0
var _was_on_floor := true


func _ready() -> void:
	model.walk_speed = walk_speed
	model.run_speed = run_speed
	model.sprint_speed = sprint_speed
	spring_arm.add_excluded_object(get_rid())
	_arm_length = spring_arm.spring_length
	snap_camera()


## The camera rig is top-level and follows the interpolated body every rendered frame (smooth at any refresh rate).
func _process(delta: float) -> void:
	var target := get_global_transform_interpolated().origin + Vector3(0, CAMERA_HEIGHT, 0)
	var p := pivot.global_position
	p.x = target.x
	p.z = target.z
	p.y = lerpf(p.y, target.y, clampf(delta * CAMERA_FOLLOW, 0.0, 1.0))
	pivot.global_position = p
	var k := clampf(delta * 10.0, 0.0, 1.0)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, AIM_ARM_LENGTH if aiming else _arm_length, k)
	spring_arm.position.x = lerpf(spring_arm.position.x, AIM_SHOULDER if aiming else 0.0, k)


## Call after moving the player directly (spawn, teleport).
func snap_camera() -> void:
	reset_physics_interpolation()
	pivot.global_position = global_position + Vector3(0, CAMERA_HEIGHT, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and mouse_look_enabled:
		_look(event.relative * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and mouse_look_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _look(delta_look: Vector2) -> void:
	pivot.rotate_y(-delta_look.x)
	pitch.rotation.x = clampf(pitch.rotation.x - delta_look.y, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down") if input_enabled else Vector2.ZERO
	if look != Vector2.ZERO:
		_look(look * stick_sensitivity * delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if input_enabled else Vector2.ZERO
	aiming = input_enabled and (Input.is_action_pressed("aim") or auto_lock)
	var strength := minf(input.length(), 1.0)
	sprinting = input_enabled and not aiming and strength > 0.1 and Input.is_action_pressed("sprint")
	# Movement relative to the camera (yaw only), at the speed the stick and buttons ask for.
	var dir := pivot.global_basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized()
	var speed := target_speed(strength, aiming, sprinting)
	var want := dir * speed
	var grip := acceleration * (1.0 if is_on_floor() else air_control)
	velocity.x = move_toward(velocity.x, want.x, grip * delta)
	velocity.z = move_toward(velocity.z, want.z, grip * delta)
	var on_floor := is_on_floor()
	if on_floor:
		velocity.y = 0.0
		if input_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity   # at once: the animation plays alongside, it never delays the jump
			model.jump()
			jumped.emit()
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		landed.emit()
	_was_on_floor = is_on_floor()
	# Facing: the camera's direction while aiming, otherwise the way we are going.
	var flat := Vector2(velocity.x, velocity.z)
	if aiming:
		var fwd := -pivot.global_basis.z
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-fwd.x, -fwd.z), clampf(delta * aim_turn_rate, 0.0, 1.0))
	elif flat.length() > 0.3:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-velocity.x, -velocity.z), clampf(delta * turn_rate, 0.0, 1.0))
	model.set_aiming(aiming)
	model.update_locomotion(flat.length(), sprinting, is_on_floor(), delta)


## The speed (m/s) for a stick pushed `strength` (0 to 1): a gentle push walks, a firm one runs, the sprint button sprints.
func target_speed(strength: float, is_aiming: bool, is_sprinting: bool) -> float:
	if strength < 0.05:
		return 0.0
	if is_aiming:
		return aim_speed * strength
	if is_sprinting:
		return sprint_speed
	if strength < RUN_THRESHOLD:
		return walk_speed * strength / RUN_THRESHOLD
	return lerpf(walk_speed, run_speed, (strength - RUN_THRESHOLD) / (1.0 - RUN_THRESHOLD))
