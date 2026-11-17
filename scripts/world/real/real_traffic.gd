class_name RealTraffic
extends Node3D
## Traffic on the real streets: keeps up to `max_cars` cars driving the loaded street network
## around the player. Cars start on a street out of sight (never popping in beside you), are
## removed when they are far away or run off the loaded world, and are replaced elsewhere.
## Design: design/gdd/real_world.md.

const COLORS := ["#e67e22", "#bdc3c7", "#27ae60", "#c0392b", "#2e86c1", "#f1eee8", "#7f8c8d", "#8e44ad", "#f1c40f", "#16a085", "#1d1b24"]

@export var max_cars := 14
## Cars start at least this far from the player and are removed beyond `far_distance`.
@export var spawn_min := 70.0
@export var far_distance := 380.0

var world: RealWorld
var player: Node3D
var people: RealPopulation
var cars: Array[RealCar] = []
var spawned_total := 0
var _rng := RandomNumberGenerator.new()
var _accum := 0.0


func setup(p_world: RealWorld, p_player: Node3D, p_people: RealPopulation = null) -> void:
	world = p_world
	player = p_player
	people = p_people
	_rng.seed = 20261115


var enabled := true


## Settings > Traffic: off removes every car and stops new ones.
func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if not on:
		for car in cars:
			car.queue_free()
		cars.clear()


func _physics_process(delta: float) -> void:
	if world == null or not enabled:
		return
	_accum += delta
	if _accum >= 0.25:
		_accum = 0.0
		_tick()


func _tick() -> void:
	var origin := player.global_position if player else Vector3.ZERO
	for car: RealCar in cars.duplicate():
		if car.lost or car.global_position.distance_to(origin) > far_distance:
			cars.erase(car)
			car.queue_free()
	for car in cars:
		car.blockers = _blockers_for(car)
	if cars.size() < max_cars:
		spawn_one(origin)


func police_cars() -> Array:
	return cars.filter(func(c: RealCar): return c.model == "police")


## What a car must watch: the player, cars near it, people out on the street near it.
func _blockers_for(car: RealCar) -> Array:
	var out: Array = []
	if player and player.global_position.distance_to(car.global_position) < 25.0:
		out.append(player)
	for other in cars:
		if other != car and other.global_position.distance_to(car.global_position) < 25.0:
			out.append(other)
	if people:
		for r: Resident in people.residents.values():
			if not r.is_inside and r.global_position.distance_to(car.global_position) < 15.0:
				out.append(r)
	return out


## Starts a car at the beginning of a street that is far enough from the player and clear.
func spawn_one(origin: Vector3) -> RealCar:
	var ids: Array = world.graph.edges.keys()
	if ids.is_empty():
		return null
	for attempt in 12:
		var id: int = ids[_rng.randi() % ids.size()]
		var e: Dictionary = world.graph.edges[id]
		if float(e.length) < 12.0:
			continue
		var from: Vector2i = e.a if (bool(e.oneway) or _rng.randf() < 0.5) else e.b
		var start: Vector2 = world.graph.nodes[from].pos
		var at := Vector3(start.x, 0.0, start.y)
		var d := at.distance_to(origin)
		if d < spawn_min or d > far_distance - 60.0:
			continue
		if cars.any(func(c: RealCar): return c.global_position.distance_to(at) < 14.0):
			continue
		var car := RealCar.new()
		car.name = "RealCar_%d" % spawned_total
		add_child(car)
		# One SAPS bakkie is always somewhere on the streets around you.
		var police := not cars.any(func(c: RealCar): return c.model == "police")
		car.world = world
		car.setup(world.graph, id, from, _rng.randi(), Color.WHITE if police else Color(COLORS[_rng.randi() % COLORS.size()]), "police" if police else "")
		cars.append(car)
		spawned_total += 1
		return car
	return null
