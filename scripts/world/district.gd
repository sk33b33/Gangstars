class_name District
extends Node3D
## Owns district geometry, house plots, destinations, navigation and residents.
## Everything is built from data files; navigation is baked at load from the built geometry.

signal navigation_ready
signal vehicle_horn(position: Vector3)
signal door_opened(position: Vector3)
signal navigation_rebaked

const HOUSE_SCENE := preload("res://scenes/houses/house_plot.tscn")
const RESIDENT_SCENE := preload("res://scenes/npcs/resident.tscn")

@export_file("*.json") var district_file := "res://data/districts/starter.json"
@export_file("*.json") var houses_file := "res://data/houses/starter_houses.json"
@export_file("*.json") var residents_file := "res://data/npcs/starter_residents.json"
@export_file("*.json") var districts_file := "res://data/districts/districts.json"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

var info: Dictionary = {}       # the starter area's data (kept for compatibility)
## Every built area (starter first): district data dictionaries with an "id".
var areas: Array = []
var registry: HouseRegistry
var destinations := DestinationRegistry.new()
var plots: Dictionary = {}       # house id -> HousePlot
var gates: Dictionary = {}       # neighbouring district id -> [DistrictGate]
var vehicles: Dictionary = {}    # drivable car id -> DrivableCar
var traffic: TrafficSystem
var weather: Weather
var light_pool: LightPool
## Set false before adding to the tree to skip LOD ranges (profiling A/B).
var use_lod := true
var lod_count := 0
var merge_stats := {}
var rebake_count := 0
var _rebaking := false
var _braai: Node3D
var residents: Dictionary = {}   # npc id -> Resident
var is_navigation_ready := false
var events: NeighbourhoodEvents
var director: SimulationDirector
var day_night: DayNight
## Benches, chairs and walls residents settle into while dwelling (cosmetic).
var spots := SpotRegistry.new()
## The player, so crew members can follow them ("@leader:player"). Set by the session.
var player: Node3D


func _ready() -> void:
	_load_areas()
	for area in areas:
		var built := StreetBuilder.build(nav_region, area, destinations)
		for id in built:
			gates.get_or_add(id, []).append_array(built[id])
	_build_houses()
	_register_patrol_routes()
	events = NeighbourhoodEvents.new()
	events.name = "Events"
	add_child(events)
	director = SimulationDirector.new()
	director.name = "SimulationDirector"
	add_child(director)
	director.setup(self, events)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(director.clock, $Sun, $WorldEnvironment.environment)
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(self, director.clock, day_night)
	light_pool = LightPool.new()
	light_pool.name = "LightPool"
	add_child(light_pool)
	light_pool.setup(day_night, LightPool.collect_lamps(nav_region))
	_bake_navigation()


## Data pipeline: the starter district file, then every catalog district with a `data` file.
## All areas share one navigation bake; the gates (solid at bake time) keep them disconnected,
## so residents stay in their own district while the player can travel once a gate opens.
func _load_areas() -> void:
	var raw: Variant = DataFiles.load_json(district_file)
	info = raw if raw is Dictionary else {}
	info["id"] = str(info.get("id", "starter"))
	var catalog: Variant = DataFiles.load_json(districts_file)
	var neighbours: Array = []
	var extra: Array = []
	if catalog is Dictionary:
		for d in catalog.get("districts", []):
			if not d is Dictionary:
				continue
			if d.has("side"):
				neighbours.append(d)
			if d.has("data") and str(d.id) != info.id:
				var a: Variant = DataFiles.load_json(str(d.data))
				if a is Dictionary:
					a["id"] = str(d.id)
					extra.append(a)
	info["locked_neighbours"] = neighbours
	if not info.has("houses_file"):
		info["houses_file"] = houses_file
	if not info.has("residents_file"):
		info["residents_file"] = residents_file
	areas = [info]
	areas.append_array(extra)
	registry = HouseRegistry.new()
	for area in areas:
		var reg := HouseRegistry.load_file(str(area.get("houses_file", "")))
		registry.errors.append_array(reg.errors)
		for id in reg.order:
			registry.add(reg.get_house(id))


## Which area a world position is in ("" if outside every area, e.g. an approach street).
func area_at(pos: Vector3) -> String:
	for area in areas:
		var b: Array = area.get("bounds", [0, 0, 0, 0])
		if pos.x >= float(b[0]) and pos.x <= float(b[2]) and pos.z >= float(b[1]) and pos.z <= float(b[3]):
			return str(area.id)
	return ""


func area_by_id(id: String) -> Dictionary:
	for area in areas:
		if area.id == id:
			return area
	return {}


## District a resident lives in (via their home's district_id).
func resident_district(r: Resident) -> String:
	var h := registry.get_house(r.data.home_id)
	return h.district_id if h else ""


func display_name() -> String:
	var own := 0
	if registry:
		for id in registry.order:
			own += 1 if registry.get_house(id).district_id == info.id else 0
	return "%s · %d houses · %d streets" % [info.get("display_name", "?"), own, info.get("streets", []).size()]


func _build_houses() -> void:
	var positions: Array = []
	for id in registry.order:
		positions.append(registry.get_house(id).plot_transform())
	for id in registry.order:
		var house := registry.get_house(id)
		var plot: HousePlot = HOUSE_SCENE.instantiate()
		nav_region.add_child(plot)
		plot.build(house, _needs_closing_fence(house, positions))
		plots[id] = plot
		destinations.register(house.entrance_id(), plot.door_position(), 0.1, "house_door",
			"%s (%s)" % [house.address(), house.display_name])
		destinations.register(house.id + ":gate", plot.gate_position(), 0.3, "house_gate",
			"the gate of %s" % house.address())
		plot.door_interactable.on_interact = _on_door.bind(id)


func _register_patrol_routes() -> void:
	var routes: Dictionary = {}
	for area in areas:
		routes.merge(area.get("patrol_routes", {}))
	for route_id in routes:
		var points: Array = routes[route_id]
		for i in points.size():
			var p := DataFiles.to_vec2(points[i])
			destinations.register("patrol:%s:%d" % [route_id, i], Vector3(p.x, 0, p.y), 0.8, "patrol",
				"patrol point %d" % i)


## A plot closes its own +X side only when no neighbour sits there.
func _needs_closing_fence(house: HouseData, all: Array) -> bool:
	var t := house.plot_transform()
	var probe := t * Vector3(house.plot_size.x, 0, 0)
	for other in all:
		if other.origin.distance_to(probe) < 1.0:
			return false
	return true


func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# Only world geometry (layer 1): moving traffic (AnimatableBody, a static-body type) and
	# opened gates (layer 0) are never baked in.
	nm.geometry_collision_mask = 1
	nav_region.navigation_mesh = nm
	nav_region.bake_finished.connect(_on_bake_finished, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	# The navigation map applies region changes on a later sync; wait until it has.
	var map := nav_region.get_navigation_map()
	var waited := 0
	while not _region_is_live(map) and waited < 300:
		await get_tree().physics_frame
		waited += 1
	if waited >= 300:
		push_error("Navigation map never synced after bake; NPC movement will fail.")
	destinations.navigation_map = map
	_spawn_residents()
	_spawn_vehicles()
	if use_lod:
		merge_stats = MeshMerger.merge(nav_region)
		lod_count = Lod.apply(nav_region)
		for r: Resident in residents.values():
			lod_count += Lod.apply(r.model, true)
	is_navigation_ready = true
	navigation_ready.emit()


## Vehicles move, so they are created after the bake and never carve the nav mesh.
func _spawn_vehicles() -> void:
	var cars: Array = []
	for area in areas:
		cars.append_array(area.get("parked_cars", []))
	for c in cars:
		if not c.get("drivable", false):
			continue
		var car := DrivableCar.new()
		add_child(car)
		car.setup(str(c.id), str(c.get("name", c.id)), DataFiles.to_color(c.get("color"), Color.GRAY))
		var p := DataFiles.to_vec2(c.get("position"))
		car.global_position = Vector3(p.x, 0.05, p.y)
		car.rotation.y = deg_to_rad(float(c.get("rot", 0))) + PI * 0.5
		car.reset_physics_interpolation()
		vehicles[car.vehicle_id] = car
	traffic = TrafficSystem.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(self)
	traffic.extra_obstacles.append_array(vehicles.values())


## Re-bakes on a thread after a gate opens/closes, so the districts' walkable areas connect
## (crew can follow the player across). Residents still keep to their own district because
## their schedules only point there. Emits navigation_rebaked when the map has the new mesh.
func rebake_navigation() -> void:
	if _rebaking:
		return
	_rebaking = true
	await get_tree().physics_frame  # let deferred collision-shape changes apply first
	await get_tree().physics_frame
	nav_region.bake_finished.connect(_on_rebake_finished, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh(true)


func _on_rebake_finished() -> void:
	# Map iterations build asynchronously: one already in flight when the new mesh landed may
	# not include it, so wait for two fresh iterations (bounded) before announcing the change.
	var map := nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_iteration_id(map)
	var waited := 0
	while NavigationServer3D.map_get_iteration_id(map) < start + 2 and waited < 300:
		await get_tree().physics_frame
		waited += 1
	await get_tree().physics_frame
	_rebaking = false
	rebake_count += 1
	navigation_rebaked.emit()


func _region_is_live(map: RID) -> bool:
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var probe := Vector3(0, 0, 0)
	return NavigationServer3D.map_get_closest_point_owner(map, probe) == nav_region.get_rid()


func _spawn_residents() -> void:
	spots.collect(self)
	var i := 0
	var all_npcs: Array[NpcData] = []
	for area in areas:
		all_npcs.append_array(NpcData.load_file(str(area.get("residents_file", ""))))
	for npc in all_npcs:
		if registry.get_house(npc.home_id) == null:
			push_warning("Resident %s has unknown home %s; not spawned." % [npc.id, npc.home_id])
			continue
		var r: Resident = RESIDENT_SCENE.instantiate()
		add_child(r)
		r.setup(npc, destinations, i * 0.11, director.clock, _lookup)
		r.spots = spots
		r.reported.connect(func(who: Resident, event_id: String): events.report(event_id, who.data.display_name))
		r.door_used.connect(_on_door_used)
		residents[npc.id] = r
		i += 1


func _lookup(id: String) -> Node3D:
	if id == "player":
		return player
	return residents.get(id)


## Mission/world queries (kept here so gameplay systems don't walk the scene tree).
func resident_info(npc_id: String) -> Dictionary:
	var r: Resident = residents.get(npc_id)
	if r == null:
		return {}
	return {"inside": r.is_inside, "home_id": r.data.home_id, "name": r.data.display_name}


func occupants_inside(house_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var house := registry.get_house(house_id)
	if house == null:
		return out
	for npc_id in house.occupant_ids:
		var r: Resident = residents.get(npc_id)
		if r and r.is_inside:
			out.append(npc_id)
	return out


## True if a recruited (player crew) member is outside within `radius` of `pos`.
func crew_near(pos: Vector3, radius: float) -> bool:
	for r: Resident in residents.values():
		if r.data.role == "player_crew" and not r.is_inside and r.global_position.distance_to(pos) <= radius:
			return true
	return false


func anchor_or_null(id: String) -> Variant:
	return destinations.anchor_position(id) if destinations.has(id) else null


## Moves a recruited resident onto the player's crew schedule (follow, guard safehouse, corner).
func apply_recruit(npc_id: String, safehouse_id: String) -> void:
	var r: Resident = residents.get(npc_id)
	if r == null or r.data.role == "player_crew":
		return
	r.recruit([
		{"activity": "follow", "destination": "@leader:player", "duration": 180.0},
		{"activity": "guard", "destination": safehouse_id + ":gate", "duration": 40.0},
		{"activity": "socializing", "destination": "poi_corner", "duration": 25.0},
		{"activity": "home", "destination": "home", "duration": 15.0}])


## Opens/closes every gate to a neighbouring district. Only the session calls this, in
## response to DistrictManager unlocks (or when restoring a save).
func set_district_open(district_id: String, open: bool, animate := true) -> bool:
	var changed := false
	for gate: DistrictGate in gates.get(district_id, []):
		changed = changed or gate.is_open != open
		gate.set_open(open, animate)
	return changed


## Drum braai with smoke at the park while the braai event runs.
func set_braai(on: bool) -> void:
	if _braai == null:
		_braai = Node3D.new()
		_braai.name = "Braai"
		_braai.position = destinations.anchor_position("poi_park") + Vector3(2.5, 0, 2.5)
		add_child(_braai)
		var drum := CylinderMesh.new()
		drum.top_radius = 0.35
		drum.bottom_radius = 0.35
		drum.height = 0.8
		var mi := MeshInstance3D.new()
		mi.mesh = drum
		mi.material_override = PixelMaterials.flat(Color("#2a2a30"))
		mi.position = Vector3(0, 0.6, 0)
		mi.rotation.z = PI * 0.5
		_braai.add_child(mi)
		Geo.box(_braai, Vector3(0.9, 0.05, 0.6), Vector3(0, 0.98, 0), PixelMaterials.flat(Color("#7d828c")), false)
		Geo.box(_braai, Vector3(0.7, 0.04, 0.45), Vector3(0, 1.0, 0), PixelMaterials.lamp(), false)
		var smoke := CPUParticles3D.new()
		smoke.name = "Smoke"
		smoke.amount = 40
		smoke.lifetime = 4.0
		smoke.direction = Vector3(0.2, 1, 0)
		smoke.spread = 12.0
		smoke.gravity = Vector3(0.3, 0.6, 0)
		smoke.initial_velocity_min = 0.4
		smoke.initial_velocity_max = 0.8
		smoke.scale_amount_min = 0.6
		smoke.scale_amount_max = 1.4
		var puff := QuadMesh.new()
		puff.size = Vector2(0.7, 0.7)
		var soft := GradientTexture2D.new()
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(1.0, 0.5)
		soft.width = 32
		soft.height = 32
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		soft.gradient = grad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = soft
		mat.albedo_color = Color(0.85, 0.85, 0.85, 0.4)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		puff.material = mat
		smoke.mesh = puff
		smoke.position = Vector3(0, 1.1, 0)
		_braai.add_child(smoke)
	_braai.visible = on
	(_braai.get_node("Smoke") as CPUParticles3D).emitting = on


func is_braai_on() -> bool:
	return _braai != null and _braai.visible


func is_district_open(district_id: String) -> bool:
	var list: Array = gates.get(district_id, [])
	return not list.is_empty() and list.all(func(g): return g.is_open)


func _on_door_used(house_id: String) -> void:
	var plot: HousePlot = plots.get(house_id)
	if plot:
		plot.open_door()
		door_opened.emit(plot.door_position())


func _on_door(house_id: String) -> String:
	var house := registry.get_house(house_id)
	var where := house.address()
	if house.ownership == "player":
		return "Your safehouse, %s." % where
	if house.occupancy == "vacant":
		return "%s is empty. The curtains are drawn." % where
	var home: PackedStringArray = []
	var out: PackedStringArray = []
	for npc_id in house.occupant_ids:
		var r: Resident = residents.get(npc_id)
		if r == null:
			continue
		if r.is_inside:
			home.append(r.data.display_name)
		else:
			out.append("%s (%s)" % [r.data.display_name, r.destinations.display_name(r.target_id)])
	if house.ownership == "hostile":
		if home.is_empty():
			return "Nobody answers at %s. Someone has sprayed TORTEL on the gate." % where
		return "A voice behind the gate at %s: \"Wrong house, bru. Walk.\"" % where
	if not home.is_empty():
		var who := " and ".join(home)
		var verb := "opens" if home.size() == 1 else "open"
		plots[house_id].open_door(3.0)
		door_opened.emit(plots[house_id].door_position())
		return "%s %s the security gate at %s: \"Ja? Can I help you?\"" % [who, verb, where]
	return "No answer at %s. Out: %s." % [where, ", ".join(out)]


## Debug/test helper: path from every occupied house door to every public destination.
func reachability_report() -> Dictionary:
	var map := nav_region.get_navigation_map()
	var report := {"ok": 0, "failed": PackedStringArray()}
	var pois_by_area := {}
	for area in areas:
		var list: PackedStringArray = []
		for poi in area.get("pois", []):
			list.append(str(poi.id))
		pois_by_area[str(area.id)] = list
	for id in registry.order:
		var house := registry.get_house(id)
		if house.occupancy != "occupied" and house.ownership != "player":
			continue
		var pois: PackedStringArray = pois_by_area.get(house.district_id, PackedStringArray())
		var from := NavigationServer3D.map_get_closest_point(map, destinations.anchor_position(house.entrance_id()))
		for poi_id in pois:
			var to := NavigationServer3D.map_get_closest_point(map, destinations.anchor_position(poi_id))
			var path := NavigationServer3D.map_get_path(map, from, to, true)
			if path.size() >= 2 and path[path.size() - 1].distance_to(to) < 0.6:
				report.ok += 1
			else:
				report.failed.append("%s -> %s" % [id, poi_id])
	return report
