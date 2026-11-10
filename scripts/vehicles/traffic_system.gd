class_name TrafficSystem
extends Node3D
## Builds lane routes from district data and runs the AI traffic. Left-hand traffic: each
## loop's lane is offset to the left of its driving direction; corners are rounded with a
## quadratic curve. Spawned after the nav bake so moving cars never carve the nav mesh.

var district: District
var cars: Array[TrafficCar] = []
var extra_obstacles: Array = []    # e.g. drivable cars


func setup(p_district: District) -> void:
	district = p_district
	for area in district.areas:
		_setup_area(area.get("traffic", {}))


func _setup_area(spec: Dictionary) -> void:
	if spec.is_empty():
		return
	var offset := float(spec.get("lane_offset", 1.4))
	var radius := float(spec.get("corner_radius", 6.0))
	var stop_points: Array = []
	for id in spec.get("taxi_stops", []):
		if district.destinations.has(str(id)):
			stop_points.append(district.destinations.anchor_position(str(id)))
	for loop in spec.get("loops", []):
		var pts: Array = []
		for p in loop.get("points", []):
			var v := DataFiles.to_vec2(p)
			pts.append(Vector3(v.x, 0, v.y))
		var built := build_route(pts, offset, radius)
		var route: PackedVector3Array = built.route
		var stops := {}
		for sp in stop_points:
			var best := -1
			var best_d := 6.0
			for i in route.size():
				var d := Vector2(route[i].x - sp.x, route[i].z - sp.z).length()
				if d < best_d and not built.curves.has(i):
					best_d = d
					best = i
			if best >= 0:
				stops[best] = float(spec.get("taxi_wait", 4.0))
		for c in loop.get("cars", []):
			var car := TrafficCar.new()
			add_child(car)
			var start := int(float(c.get("start", 0.0)) * route.size()) % route.size()
			var taxi := bool(c.get("taxi", false))
			car.model = str(c.get("model", ""))
			car.setup(str(c.id), route, built.curves, stops if taxi else {}, DataFiles.to_color(c.get("color"), Color.GRAY), taxi, start)
			car.honked.connect(_on_honk)
			cars.append(car)


## Lane polyline (closed loop) with rounded corners. Returns {route, curves: {index: true}}.
static func build_route(points: Array, offset: float, radius: float) -> Dictionary:
	var n := points.size()
	var route := PackedVector3Array()
	var curves := {}
	for i in n:
		var prev: Vector3 = points[(i - 1 + n) % n]
		var cur: Vector3 = points[i]
		var nxt: Vector3 = points[(i + 1) % n]
		var a := (cur - prev).normalized()
		var b := (nxt - cur).normalized()
		var corner := cur + _left(a) * offset + _left(b) * offset
		var r := minf(radius, minf(cur.distance_to(prev), cur.distance_to(nxt)) * 0.4)
		var p0 := corner - a * r
		var p2 := corner + b * r
		for k in 7:
			var t := k / 6.0
			var q := p0.lerp(corner, t).lerp(corner.lerp(p2, t), t)
			if k > 0 and k < 6:
				curves[route.size()] = true
			route.append(q)
	return {"route": route, "curves": curves}


static func _left(d: Vector3) -> Vector3:
	return Vector3(d.z, 0, -d.x)


## Settings toggle: hide, stop and de-collide all AI traffic.
func set_enabled(on: bool) -> void:
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	for car in cars:
		car.collision_layer = TrafficCar.LAYER_VEHICLES if on else 0
		car.obstacle.avoidance_enabled = false


func _physics_process(_delta: float) -> void:
	if district == null:
		return
	var list: Array = []
	for r: Resident in district.residents.values():
		if not r.is_inside:
			list.append(r)
	if district.player and district.player.visible and not district.player.is_driving():
		list.append(district.player)
	list.append_array(cars)
	list.append_array(extra_obstacles)
	for car in cars:
		car.candidates = list


func _on_honk(car: TrafficCar) -> void:
	district.vehicle_horn.emit(car.global_position)
