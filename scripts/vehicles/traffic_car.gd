class_name TrafficCar
extends AnimatableBody3D
## AI car following a closed lane route (left-hand traffic). Kinematic: it never pushes anyone,
## because it brakes for anything in its lane ahead (pedestrians, the player, other cars) and
## hoots if kept waiting. A NavigationObstacle3D makes walking NPCs steer around it.
## Taxis pause at their stop points.

signal honked(car: TrafficCar)

## AI traffic has its own layer (6): residents don't collide with it (cars brake for them and
## they steer around cars), so a car corner can never shove a pedestrian; the player and
## drivable cars do collide with it.
const LAYER_VEHICLES := 1 << 5
const CORNER_SPEED := 3.5
const ACCEL := 2.5
const BRAKE := 9.0
const LOOK_AHEAD := 8.0
const HALF_WIDTH := 1.0
const HONK_AFTER := 3.0

@export var cruise_speed := 8.0

var vehicle_id := ""
var is_taxi := false
var route := PackedVector3Array()
var curve_points := {}       # route index -> true when the point is part of a corner curve
var stops := {}              # route index -> seconds to wait (taxis)
var speed := 0.0
var blocked_time := 0.0
var times_braked := 0
var obstacle: NavigationObstacle3D

var _i := 0
var _stop_timer := 0.0
var _served_stop := -1
var _was_blocked := false
var candidates: Array = []   # filled by the TrafficSystem each frame
var _anim_time := 0.0
var _stuck_time := 0.0
var _clock := 0.0
var _ignore_until := {}
const STUCK_GIVE_WAY := 10.0
var _full_radius := 2.2
var blocker: Node3D
## Model override (e.g. "police"); "" = taxi or a civilian model from the id.
var model := ""
var body: Node3D


func setup(id: String, p_route: PackedVector3Array, p_curves: Dictionary, p_stops: Dictionary,
		color: Color, taxi: bool, start_index: int) -> void:
	# Must be off before positioning: with sync on, the first physics-state sync would
	# overwrite our transform with the body's initial (origin) state.
	sync_to_physics = false
	vehicle_id = id
	name = id
	is_taxi = taxi
	route = p_route
	curve_points = p_curves
	stops = p_stops
	_i = (start_index + 1) % route.size()
	global_position = route[start_index]
	var to := route[_i] - route[start_index]
	rotation.y = atan2(to.x, to.z)
	reset_physics_interpolation()
	collision_layer = LAYER_VEHICLES
	collision_mask = 0
	var length := 5.2 if taxi else 4.0
	body = StreetBuilder.build_car(self, Vector3.ZERO, -PI * 0.5, color, false, length,
		model if not model.is_empty() else ("taxi" if taxi else VehicleLibrary.civilian_for(id)))
	VehicleLibrary.add_headlights(body, model if not model.is_empty() else ("taxi" if taxi else VehicleLibrary.civilian_for(id)))
	VehicleLibrary.add_occupants(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.75, 1.5, length)
	shape.shape = box
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)
	obstacle = NavigationObstacle3D.new()
	_full_radius = length * 0.55
	obstacle.radius = _full_radius
	obstacle.height = 1.6
	obstacle.avoidance_enabled = true
	add_child(obstacle)


func _physics_process(delta: float) -> void:
	if route.is_empty():
		return
	_clock += delta
	var target := route[_i]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		if stops.has(_i) and _served_stop != _i:
			_served_stop = _i
			_stop_timer = float(stops[_i])
		_i = (_i + 1) % route.size()
		target = route[_i]
		to = target - global_position
		to.y = 0.0
	var desired := CORNER_SPEED if curve_points.has(_i) else cruise_speed
	if _stop_timer > 0.0:
		_stop_timer -= delta
		desired = 0.0
	var blocked := is_blocked()
	if blocked:
		desired = 0.0
		if not _was_blocked:
			times_braked += 1
		blocked_time += delta
		if blocked_time > HONK_AFTER:
			blocked_time = -2.0
			honked.emit(self)
			# A hoot makes a pedestrian in the lane step aside (away from the lane centre).
			if blocker is Resident:
				var side: float = signf(to_local(blocker.global_position).x)
				blocker.step_aside(global_basis.x * (side if side != 0.0 else 1.0))
	else:
		blocked_time = 0.0
	# A resident who stays put in the lane for a long time (chatting, guarding) is eased past:
	# avoidance pushes walkers aside from a moving car. Never the player or another car.
	if blocked and blocker is Resident:
		_stuck_time += delta
		if _stuck_time > STUCK_GIVE_WAY:
			_ignore_until[blocker] = _clock + 6.0
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0
	_was_blocked = blocked
	var before := speed
	var yaw_before := rotation.y
	speed = move_toward(speed, desired, (ACCEL if desired > speed else BRAKE) * delta)
	if to.length() > 0.01:
		var dir := to.normalized()
		global_position += dir * minf(speed * delta, to.length())
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * 5.0, 0.0, 1.0))
		obstacle.velocity = dir * speed
	_animate_body(delta, before, yaw_before)
	# Moving cars push walkers aside via avoidance; a waiting car has no avoidance footprint,
	# so a pedestrian it is waiting for can always walk on (no car <-> pedestrian deadlock).
	obstacle.radius = lerpf(1.0, _full_radius, clampf(speed / cruise_speed, 0.0, 1.0))
	obstacle.avoidance_enabled = speed > 0.5 and visible


## Wheels, suspension, brake lights and indicators (a turn coming up in the next two points).
func _animate_body(delta: float, speed_before: float, yaw_before: float) -> void:
	if body == null or delta <= 0.0 or not visible:
		return
	_anim_time += delta
	var yaw_rate := angle_difference(yaw_before, rotation.y) / delta
	var steer := clampf(yaw_rate * 2.8 / maxf(speed, 1.0), -1.0, 1.0)
	var indicate := 0
	if curve_points.has(_i) or curve_points.has((_i + 1) % route.size()):
		var ahead := route[(_i + 2) % route.size()] - global_position
		var f := global_basis.z
		var side := ahead.dot(Vector3(f.z, 0, -f.x))   # + = to the car's left
		if absf(side) > 1.5:
			indicate = -1 if side > 0.0 else 1
	VehicleLibrary.animate(body, speed, steer, (speed - speed_before) / delta, indicate, delta, _anim_time)


## Anything inside the lane box ahead (car-local +Z is forward).
func is_blocked() -> bool:
	var reach := LOOK_AHEAD + speed * 0.6
	if _was_blocked:
		reach += 2.0   # hysteresis: braking shortens the reach, so don't let go and creep forward
	for n: Node3D in candidates:
		if n == self or (_ignore_until.has(n) and float(_ignore_until[n]) > _clock):
			continue
		var local := to_local(n.global_position)
		if local.z > 1.0 and local.z < reach and absf(local.x) < HALF_WIDTH + 0.7:
			blocker = n
			return true
	blocker = null
	return false


func lane_index() -> int:
	return _i
