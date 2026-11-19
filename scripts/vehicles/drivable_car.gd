class_name DrivableCar
extends CharacterBody3D
## A car the player can get into (E / A), drive (WASD or stick + RT/LT, arcade handling) and hoot (Q / Y).
## Collides with the world, NPCs and other vehicles; a bump scrubs speed instead of pushing.

signal bumped(car: DrivableCar)

const LAYER_VEHICLES := 1 << 4
const GRAVITY := 9.8
const STEER_SPEED := 2.6          # how fast the wheel follows the stick (per second, full lock = 1)
const STEER_RETURN := 3.6         # and how fast it returns to centre
const MAX_LOCK := 0.62            # front wheel angle at full lock when crawling (rad)
const MIN_LOCK := 0.10            # and at top speed
const LATERAL_GRIP := 8.5         # m/s^2 the tyres hold sideways
const UNDERSTEER_SCRUB := 0.35    # per second, of speed, lost while the tyres are past their grip
const ENGINE_PITCH_LOW := 0.55    # the engine hum's pitch at idle, and how far it rises up the rev range
const ENGINE_PITCH_RANGE := 1.25

var vehicle_id := ""
var display_name := ""
var driver: Node3D
var speed := 0.0
var interactable: Interactable
var obstacle: NavigationObstacle3D
var body: Node3D
var _anim_time := 0.0
var drivetrain: Drivetrain
var wheelbase := 2.4
var _steer := 0.0
## For the engine sound (AudioDirector): the pitch follows the engine speed, the volume the pedal.
var engine_pitch := 0.6
var engine_volume := -14.0
var _remy: RemyPlayerModel   # the seated driver of a car that has a seat for him (REMY_SEAT)


func setup(id: String, p_name: String, color: Color) -> void:
	vehicle_id = id
	display_name = p_name
	name = id
	collision_layer = LAYER_VEHICLES
	collision_mask = 1 | (1 << 2) | LAYER_VEHICLES | RealCar.LAYER_VEHICLES
	var model := VehicleLibrary.model_for(id)
	drivetrain = Drivetrain.for_model(model)
	wheelbase = float(VehicleLibrary.LENGTH.get(model, 4.0)) * 0.6
	body = StreetBuilder.build_car(self, Vector3.ZERO, -PI * 0.5, color, false, 4.0, model)
	VehicleLibrary.add_headlights(body, model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var van := model == "hiace"
	box.size = Vector3(1.95, 2.0, float(VehicleLibrary.LENGTH[model])) if van else Vector3(1.85, 1.4, 4.0)
	shape.shape = box
	shape.position = Vector3(0, 1.05 if van else 0.75, 0)
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


## Remy's own van seats Remy himself at the wheel (his model, sitting, hands on the wheel); every other car shows the plain driver bust.
func _show_driver(on: bool) -> void:
	var seat: Variant = VehicleLibrary.REMY_SEAT.get(str(body.get_meta("model", "")))
	if seat == null or not driver is Player:
		VehicleLibrary.set_driver(body, on, Color("#f1eee8"))
		return
	if _remy == null:
		_remy = (load("res://scenes/characters/remy/remy_player_model.tscn") as PackedScene).instantiate()
		_remy.name = "RemyAtTheWheel"
		_remy.position = seat
		(body.get_meta("tilt") as Node3D).add_child(_remy)
		_remy.set_seated(true, true)
	_remy.visible = on
	VehicleLibrary.set_driver(body, false)


## How far (rad) the front wheels can turn at full lock at a speed: wide when crawling, hardly at all at top speed.
static func steer_lock(speed: float, top_speed: float) -> float:
	return lerpf(MAX_LOCK, MIN_LOCK, pow(clampf(absf(speed) / maxf(top_speed, 1.0), 0.0, 1.0), 0.7))


func is_driven() -> bool:
	return driver != null


func _physics_process(delta: float) -> void:
	if body and bool(body.get_meta("driver_shown", false)) != (driver != null):
		body.set_meta("driver_shown", driver != null)   # the player shows at the wheel while driving
		_show_driver(driver != null)
	if driver == null and absf(speed) < 0.05:
		# Parked: no physics step, so passing traffic can never nudge it out of its bay.
		speed = 0.0
		velocity = Vector3.ZERO
		obstacle.velocity = Vector3.ZERO
		interactable.set_enabled(true)
		return
	var pedal := 0.0
	var steer_input := 0.0
	if driver and driver.input_enabled:
		# W/S or the left stick, plus the triggers (RT accelerate, LT brake/reverse) on a pad.
		pedal = clampf(Input.get_axis("move_backward", "move_forward") + Input.get_axis("brake", "accelerate"), -1.0, 1.0)
		steer_input = Input.get_axis("move_right", "move_left")
	drivetrain.skill = driver.drive_factor if driver is Player else 1.0
	var accel := drivetrain.update(delta, speed, pedal)
	speed += accel * delta
	if pedal == 0.0 and absf(speed) < 0.25 and absf(accel) < 1.0:
		speed = 0.0   # rolled to a stop
	speed = clampf(speed, -drivetrain.reverse_kmh / 3.6 * drivetrain.skill, drivetrain.top_speed())
	_anim_time += delta
	# The steering wheel has weight: it follows the stick, and comes back to centre a little faster than it went out.
	_steer = move_toward(_steer, steer_input, delta * (STEER_RETURN if absf(steer_input) < absf(_steer) else STEER_SPEED))
	var steer := _steer
	var light_accel := accel * signf(speed) if absf(speed) > 0.3 else accel   # braking lights only for braking, not for backing up or coasting
	if pedal == 0.0:
		light_accel = maxf(light_accel, -0.4)
	var indicate := 0 if absf(steer) < 0.3 else (-1 if steer > 0.0 else 1)   # the lamps on the side it is turning towards blink
	VehicleLibrary.animate(body, speed, steer, light_accel, indicate, delta, _anim_time)
	engine_pitch = ENGINE_PITCH_LOW + drivetrain.rpm_fraction * ENGINE_PITCH_RANGE
	engine_volume = lerpf(-14.0, -4.0, clampf(maxf(absf(pedal), drivetrain.rpm_fraction * 0.6), 0.0, 1.0))
	# Steering: the front wheels turn less the faster you go (a bicycle model: the yaw rate is speed over wheelbase times the tan of the
	# steering angle), and the tyres can only hold so much sideways: past that the car runs wide and scrubs speed.
	var yaw_rate := speed / wheelbase * tan(steer * steer_lock(speed, drivetrain.top_speed()))
	var grip_limit := LATERAL_GRIP / maxf(absf(speed), 0.5)
	if absf(yaw_rate) > grip_limit:
		yaw_rate = signf(yaw_rate) * grip_limit
		speed -= signf(speed) * UNDERSTEER_SCRUB * delta * absf(speed)
	rotation.y += yaw_rate * delta
	var forward := global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if get_slide_collision_count() > 0 and absf(speed) > 2.0:
		for i in get_slide_collision_count():
			if absf(get_slide_collision(i).get_normal().y) < 0.5:
				VehicleLibrary.hit(body, clampf(absf(speed) / 4.0, 0.3, 3.0))   # dents, and a cracked screen after a hard one
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
	q.collision_mask = 1 | (1 << 2) | LAYER_VEHICLES | RealCar.LAYER_VEHICLES
	q.exclude = [get_rid()]
	for offset in [global_basis.x * 1.9, -global_basis.x * 1.9, -global_basis.z * 3.0, global_basis.z * 3.0]:
		var p: Vector3 = global_position + offset
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.95, 0))
		if space.intersect_shape(q, 1).is_empty():
			return p
	return global_position + Vector3(0, 2.0, 0)
