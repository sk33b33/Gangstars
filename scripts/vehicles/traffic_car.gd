class_name TrafficCar
extends AnimatableBody3D
## AI car following a closed lane route (left-hand traffic). Kinematic: it never pushes anyone,
## because it brakes for anything in its lane ahead (pedestrians, the player, other cars) and
## hoots if kept waiting. A NavigationObstacle3D makes walking NPCs steer around it.
## Taxis pause at their stop points.

signal honked(car: TrafficCar)

const LAYER_VEHICLES := 1 << 4
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
var _full_radius := 2.2


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
	var look := StreetBuilder.build_car(self, Vector3.ZERO, -PI * 0.5, color, false, length)
	if taxi:
		Geo.box(look, Vector3(0.6, 0.12, 0.25), Vector3(-0.2, 1.52, 0), PixelMaterials.flat(Color("#f1c40f")), false)
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
	else:
		blocked_time = 0.0
	_was_blocked = blocked
	speed = move_toward(speed, desired, (ACCEL if desired > speed else BRAKE) * delta)
	if to.length() > 0.01:
		var dir := to.normalized()
		global_position += dir * minf(speed * delta, to.length())
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * 5.0, 0.0, 1.0))
		obstacle.velocity = dir * speed
	# A waiting car shrinks its avoidance footprint so pedestrians can cross in front of it.
	obstacle.radius = lerpf(1.0, _full_radius, clampf(speed / cruise_speed, 0.0, 1.0))


## Anything inside the lane box ahead (car-local +Z is forward).
func is_blocked() -> bool:
	var reach := LOOK_AHEAD + speed * 0.6
	for n: Node3D in candidates:
		if n == self:
			continue
		var local := to_local(n.global_position)
		if local.z > 1.0 and local.z < reach and absf(local.x) < HALF_WIDTH + 0.7:
			return true
	return false


func lane_index() -> int:
	return _i
