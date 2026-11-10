class_name DrivableCar
extends CharacterBody3D
## A car the player can get into (E / A), drive (WASD or stick + RT/LT, arcade handling) and hoot (Q / Y).
## Collides with the world, NPCs and other vehicles; a bump scrubs speed instead of pushing.

signal bumped(car: DrivableCar)

const LAYER_VEHICLES := 1 << 4
const MAX_SPEED := 14.0
const REVERSE_SPEED := 5.0
const ACCEL := 6.0
const BRAKE := 14.0
const DRAG := 3.0
const STEER_RATE := 1.9
const GRAVITY := 9.8

var vehicle_id := ""
var display_name := ""
var driver: Node3D
var speed := 0.0
var interactable: Interactable
var obstacle: NavigationObstacle3D


func setup(id: String, p_name: String, color: Color) -> void:
	vehicle_id = id
	display_name = p_name
	name = id
	collision_layer = LAYER_VEHICLES
	collision_mask = 1 | (1 << 2) | LAYER_VEHICLES | TrafficCar.LAYER_VEHICLES
	StreetBuilder.build_car(self, Vector3.ZERO, -PI * 0.5, color, false, 4.0, VehicleLibrary.civilian_for(id))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.85, 1.4, 4.0)
	shape.shape = box
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)
	interactable = Interactable.new()
	interactable.radius = 2.6
	interactable.kind = "vehicle"
	interactable.target = id
	interactable.prompt = "Get in %s" % display_name
	interactable.position = Vector3(0, 1.0, 0)
	add_child(interactable)
	obstacle = NavigationObstacle3D.new()
	obstacle.radius = 2.2
	obstacle.height = 1.5
	obstacle.avoidance_enabled = true
	add_child(obstacle)


func is_driven() -> bool:
	return driver != null


func _physics_process(delta: float) -> void:
	if driver == null and absf(speed) < 0.05:
		# Parked: no physics step, so passing traffic can never nudge it out of its bay.
		speed = 0.0
		velocity = Vector3.ZERO
		obstacle.velocity = Vector3.ZERO
		interactable.set_enabled(true)
		return
	var throttle := 0.0
	var steer := 0.0
	if driver and driver.input_enabled:
		# W/S or the left stick, plus the triggers (RT accelerate, LT brake/reverse) on a pad.
		throttle = clampf(Input.get_axis("move_backward", "move_forward") + Input.get_axis("brake", "accelerate"), -1.0, 1.0)
		steer = Input.get_axis("move_right", "move_left")
	if throttle > 0.0:
		speed += (ACCEL if speed >= 0.0 else BRAKE) * throttle * delta
	elif throttle < 0.0:
		speed -= (BRAKE if speed > 0.0 else ACCEL * 0.6) * -throttle * delta
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)
	speed = clampf(speed, -REVERSE_SPEED, MAX_SPEED)
	rotation.y += steer * STEER_RATE * clampf(speed / 5.0, -1.0, 1.0) * delta
	var forward := global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if get_slide_collision_count() > 0 and absf(speed) > 2.0:
		for i in get_slide_collision_count():
			if absf(get_slide_collision(i).get_normal().y) < 0.5:
				speed *= 0.35
				bumped.emit(self)
				break
	obstacle.velocity = Vector3(velocity.x, 0, velocity.z)
	interactable.set_enabled(driver == null)


## Where the driver can step out: left side, else right, else behind (checked for space).
func exit_position() -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	q.shape = capsule
	q.collision_mask = 1 | (1 << 2) | LAYER_VEHICLES | TrafficCar.LAYER_VEHICLES
	q.exclude = [get_rid()]
	for offset in [global_basis.x * 1.9, -global_basis.x * 1.9, -global_basis.z * 3.0, global_basis.z * 3.0]:
		var p: Vector3 = global_position + offset
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.95, 0))
		if space.intersect_shape(q, 1).is_empty():
			return p
	return global_position + Vector3(0, 2.0, 0)
