class_name DogPack
extends Node
## Spawns the neighbourhood dogs from each area's "dogs" data ({"street": n, "yard": n}) and runs
## their level of detail: dogs further than ACTIVE_RANGE from the player freeze in place.
## Placement is deterministic (hash of house ids), so the same houses always have the same dogs.

signal barked(pos: Vector3, pitch: float)

const ACTIVE_RANGE := 60.0
const LOD_INTERVAL := 0.5
const COATS := [
	["#5a3a22", "#d8c4a0"], ["#1d1b20", "#e8e2d6"], ["#c9a26b", "#f0e2c4"], ["#8a7d70", "#d8d0c4"],
	["#7a4a2a", "#7a4a2a"], ["#e8e0d2", "#f6f2ea"], ["#3b2a20", "#b08a5e"],
]

var dogs: Array[StreetDog] = []
var _district: District
var _lod_timer := 0.0


func setup(district: District) -> void:
	_district = district
	var gates := district.destinations.ids_of_kind("house_gate")
	for area in district.areas:
		var spec: Dictionary = area.get("dogs", {})
		var houses: Array = []
		for id in district.registry.order:
			var h := district.registry.get_house(id)
			if h.district_id == str(area.id) and h.occupancy != "vacant":
				houses.append(h)
		# md5, not hash(): hash() of similar ids is nearly ordered, which would put every dog on one street.
		houses.sort_custom(func(a, b): return (a.id + "dog").md5_text() < (b.id + "dog").md5_text())
		var n_yard := mini(int(spec.get("yard", 0)), houses.size())
		for i in n_yard:
			var plot: HousePlot = district.plots[houses[i].id]
			var dog := _spawn("dog_yard_" + houses[i].id, "yard")
			dog.yard_plot = plot
			dog.yard_rect = plot.front_yard()
			dog.global_position = dog._yard_point(Vector2(0.3, 0.5))
		var area_gates: Array = []
		for g in gates:
			if district.area_at(district.destinations.anchor_position(g)) == str(area.id):
				area_gates.append(g)
		area_gates.sort_custom(func(a, b): return (a + "street").md5_text() < (b + "street").md5_text())
		for i in mini(int(spec.get("street", 0)), area_gates.size()):
			var home: Vector3 = district.destinations.anchor_position(area_gates[i])
			var dog := _spawn("dog_street_%s_%d" % [area.id, i], "street")
			dog.nav_map = district.destinations.navigation_map
			for g in area_gates:
				var p: Vector3 = district.destinations.anchor_position(g)
				if p.distance_to(home) < StreetDog.WANDER_RADIUS:
					dog.gate_points.append(p)
			dog.global_position = home
	_update_lod()


func _spawn(id: String, kind: String) -> StreetDog:
	var dog := StreetDog.new()
	_district.add_child(dog)
	var h := absi(hash(id))
	var coat: Array = COATS[h % COATS.size()]
	dog.setup(id, kind, Color(coat[0]), Color(coat[1]), 0.95 + float(h / 7 % 30) / 100.0)
	dog.barked.connect(func(d: StreetDog, pos: Vector3): barked.emit(pos, 1.25 - d.model.scale.x * 0.3))
	dogs.append(dog)
	return dog


func _process(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = LOD_INTERVAL
		_update_lod()


func _update_lod() -> void:
	var p: Node3D = _district.player
	for dog in dogs:
		dog.player = p
		dog.set_active(p != null and dog.global_position.distance_to(p.global_position) < ACTIVE_RANGE)


func count(kind: String) -> int:
	return dogs.filter(func(d): return d.kind == kind).size()
