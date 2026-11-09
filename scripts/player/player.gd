class_name Player
extends CharacterBody3D
## Third-person player: camera-relative movement, mouse/stick look with pitch limits,
## and contextual interaction with the nearest Interactable in range.

signal interaction_target_changed(target: Interactable)
signal interacted(message: String)
signal shouted(position: Vector3)

const GRAVITY := 9.8

@export var walk_speed := 3.4
@export var sprint_speed := 6.5
@export var acceleration := 14.0
@export var jump_velocity := 4.2
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 2.6
@export var min_pitch := -1.1
@export var max_pitch := 0.35

@onready var pivot: Node3D = $CameraPivot
@onready var pitch: Node3D = $CameraPivot/Pitch
@onready var spring_arm: SpringArm3D = $CameraPivot/Pitch/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/Pitch/SpringArm3D/Camera3D
@onready var model: CharacterModel = $Model
@onready var sensor: Area3D = $InteractionSensor

var current_target: Interactable
var input_enabled := true


func _ready() -> void:
	model.build(Color("#f1eee8"), Color("#29384a"), Color("#8d5a3b"), Color("#a63a4c"))
	spring_arm.add_excluded_object(get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(Vector2(event.relative.x, event.relative.y) * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_look(look * stick_sensitivity * delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if input_enabled else Vector2.ZERO
	var dir := pivot.global_basis * Vector3(input.x, 0, input.y)
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if is_on_floor():
		velocity.y = 0.0
		if input_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.2:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(velocity.x, velocity.z), clampf(delta * 12.0, 0.0, 1.0))
	model.animate(delta, flat.length())

	if input_enabled and Input.is_action_just_pressed("shout"):
		shouted.emit(global_position)
	_update_target()
	if input_enabled and current_target and Input.is_action_just_pressed("interact"):
		interacted.emit(current_target.interact(self))


func _look(delta_look: Vector2) -> void:
	pivot.rotate_y(-delta_look.x)
	pitch.rotation.x = clampf(pitch.rotation.x - delta_look.y, min_pitch, max_pitch)


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
