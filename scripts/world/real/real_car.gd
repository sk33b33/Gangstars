class_name RealCar
extends AnimatableBody3D
## A car on the real street network: follows the centre line of its street on the left-hand lane
## (South Africa drives on the left), slows for bends and junctions, stops for whatever is in
## front (cars, the player, people), and picks a new street at each junction. Its position only
## ever changes by driving: it steers towards a point a few metres ahead on its lane, so lane
## changes at junctions are turns, not jumps. Design: design/gdd/real_world.md.

const LAYER_VEHICLES := 1 << 5
const SPEEDS := {"main": 12.0, "collector": 9.5, "street": 7.0}
const ACCEL := 2.5
const BRAKE := 8.0
const LOOK_AHEAD := 5.0
const TURN_RATE := 2.4           # radians per second
const JUNCTION_SPEED := 3.5
const STOP_GAP := 7.0

var graph: RealRoadGraph
var rng := RandomNumberGenerator.new()
var edge := 0
var next := 0                    # the edge after this one (0 until chosen)
var from_node := Vector2i.ZERO
var pts := PackedVector2Array()  # the current edge in driving order
var next_pts := PackedVector2Array()
var s := 0.0                     # metres driven along the current edge
var length := 0.0
var speed := 0.0
var lost := false                # ran out of road (the edge of the loaded world): the traffic removes it
var blockers: Array = []         # Node3D to stop for, filled by RealTraffic
var body: Node3D
var model := ""
var times_stopped := 0
var _anim_time := 0.0
var _was_stopped := false
var _blocker: Node3D
var _stuck := 0.0
var _creep := 0.0
const GIVE_WAY_AFTER := 5.0


func setup(p_graph: RealRoadGraph, p_edge: int, p_from: Vector2i, seed_value: int, color: Color, p_model := "") -> void:
	sync_to_physics = false
	graph = p_graph
	rng.seed = seed_value
	collision_layer = LAYER_VEHICLES
	collision_mask = 0
	_take(p_edge, p_from)
	s = 0.0
	var start := lane_point(0.0)
	var ahead := lane_point(2.0)
	global_position = Vector3(start.x, 0.0, start.y)
	rotation.y = atan2(ahead.x - start.x, ahead.y - start.y)
	reset_physics_interpolation()
	model = p_model if not p_model.is_empty() else (VehicleLibrary.civilian_for(str(seed_value)) if seed_value % 9 != 0 else "taxi")
	var car_length: float = VehicleLibrary.LENGTH.get(model, 4.0)
	body = StreetBuilder.build_car(self, Vector3.ZERO, -PI * 0.5, color, false, car_length, model)
	VehicleLibrary.add_occupants(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.75, 1.5, car_length)
	shape.shape = box
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)


func _take(p_edge: int, p_from: Vector2i) -> void:
	edge = p_edge
	from_node = p_from
	pts = graph.points_from(edge, from_node)
	length = float(graph.edges[edge].length)
	next = 0
	next_pts = PackedVector2Array()


## The point `dist` metres along the route (running on into the next street), on the left lane.
func lane_point(dist: float) -> Vector2:
	var line := pts
	var e: Dictionary = graph.edges[edge]
	if dist > length and not next_pts.is_empty():
		dist -= length
		line = next_pts
		e = graph.edges[next]
	var walked := 0.0
	for i in line.size() - 1:
		var seg := line[i].distance_to(line[i + 1])
		if walked + seg >= dist or i == line.size() - 2:
			var dir := (line[i + 1] - line[i]) / maxf(seg, 0.001)
			var left := Vector2(dir.y, -dir.x)
			var offset := 0.0 if bool(e.oneway) else float(e.w) * 0.25
			return line[i] + dir * clampf(dist - walked, 0.0, seg + 2.0) + left * offset
		walked += seg
	return line[line.size() - 1]


func _physics_process(delta: float) -> void:
	if lost or graph == null:
		return
	if not graph.has_edge(edge):
		lost = true
		return
	if next == 0 or not graph.has_edge(next):
		next = graph.next_edge(graph.other_end(edge, from_node), edge, rng)
		next_pts = graph.points_from(next, graph.other_end(edge, from_node)) if next != 0 else PackedVector2Array()
	var target_speed: float = SPEEDS.get(str(graph.edges[edge].cls), 7.0)
	var to_end := length - s
	if to_end < 14.0:   # ease into the junction, or stop at the end of the loaded world
		target_speed = minf(target_speed, JUNCTION_SPEED + to_end * 0.4) if next != 0 else minf(target_speed, to_end * 0.6)
	var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var stopped := _blocked(forward)
	# Two cars waiting for each other at a junction: after a while one creeps through.
	_stuck = _stuck + delta if stopped and _blocker is RealCar else 0.0
	if _stuck > GIVE_WAY_AFTER:
		_creep = 2.5
	_creep = maxf(0.0, _creep - delta)
	if stopped and _creep > 0.0 and _blocker is RealCar:
		stopped = false
		target_speed = minf(target_speed, 2.0)
	if stopped:
		target_speed = 0.0
	if stopped and not _was_stopped:
		times_stopped += 1
	_was_stopped = stopped
	var before := speed
	speed = move_toward(speed, target_speed, (BRAKE if target_speed < speed else ACCEL) * delta)
	var aim := lane_point(s + LOOK_AHEAD)
	var to_aim := Vector2(aim.x - global_position.x, aim.y - global_position.z)
	var yaw_before := rotation.y
	if to_aim.length() > 0.5 and speed > 0.05:
		var want := atan2(to_aim.x, to_aim.y)
		rotation.y = rotate_toward(rotation.y, want, TURN_RATE * delta * clampf(speed / 3.0, 0.2, 1.0))
		forward = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		speed = minf(speed, maxf(JUNCTION_SPEED, target_speed * (1.0 - absf(angle_difference(rotation.y, want)) * 0.8)))
	global_position += forward * speed * delta
	s += speed * delta
	if s >= length:
		if next == 0:
			lost = true
			return
		var node := graph.other_end(edge, from_node)
		var carry := s - length
		_take(next, node)
		s = carry
	if body:
		_anim_time += delta
		VehicleLibrary.animate(body, speed, clampf(angle_difference(yaw_before, rotation.y) / maxf(delta, 0.001) * 0.4, -1.0, 1.0),
			(speed - before) / maxf(delta, 0.001), 0, delta, _anim_time)


## Something to stop for inside the lane ahead.
func _blocked(forward: Vector3) -> bool:
	_blocker = null
	for b: Node3D in blockers:
		if not is_instance_valid(b) or b == self:
			continue
		var to := b.global_position - global_position
		to.y = 0.0
		var ahead := to.dot(forward)
		if ahead > 0.5 and ahead < STOP_GAP + speed * 0.6 and absf(to.cross(forward).y) < 1.6:
			_blocker = b
			return true
	return false
