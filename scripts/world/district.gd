class_name District
extends Node3D
## Owns district geometry, house plots, destinations, navigation and residents.
## Everything is built from data files; navigation is baked at load from the built geometry.

signal navigation_ready
signal vehicle_horn(position: Vector3)
signal door_opened(position: Vector3)
signal navigation_rebaked
signal dog_barked(position: Vector3, pitch: float)

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
var vehicles: Dictionary = {}    # drivable car id -> DrivableCar
var weather: Weather
var skyline: Skyline
var light_pool: LightPool
## Set false before adding to the tree to skip LOD ranges (profiling A/B).
var use_lod := true
var lod_count := 0
var merge_stats := {}
var rebake_count := 0
var _braai: Node3D
var residents: Dictionary = {}   # npc id -> Resident
## Set by the GameSession: lets residents who answer the door invite the player in.
var interiors: InteriorSystem
## A door interaction that should take the player inside (read and cleared by the GameSession).
var enter_request := ""
var is_navigation_ready := false
var events: NeighbourhoodEvents
var director: SimulationDirector
var day_night: DayNight
## Residents that don't come from a district's generated data (the neighbourhood kids).
@export var extra_residents_files: PackedStringArray = ["res://data/npcs/kids.json", "res://data/npcs/police.json", "res://data/npcs/vipers.json", "res://data/npcs/shebeen.json", "res://data/npcs/smokkies.json"]
## The joinable crews; crew members wear their crew's colour.
var crews := CrewCatalog.load_default()
## The crew the player joined ("" until chosen). Its members are allies, the rest rivals.
var player_crew_id := ""
## Kids' kick-about games, one per pitch in the area data ("kickabouts").
var kickabouts: Array[KickAbout] = []
## Shots, hits and gunfire incidents (see CombatSystem).
var combat: CombatSystem
## Street and yard dogs (cosmetic; see DogPack).
var dogs: DogPack
## Benches, chairs and walls residents settle into while dwelling (cosmetic).
var spots := SpotRegistry.new()
## The player, so crew members can follow them ("@leader:player"). Set by the session.
var player: Node3D:
	set(v):
		player = v
		if real:   # the real map loads and simulates around the player
			real.focus = v
		if real_people:
			real_people.player = v
		if real_traffic:
			real_traffic.player = v


## Real-world mode (design/gdd/real_world.md): the districts are parts of the real Westridge. The
## real map draws the streets and buildings and bakes the navigation; this class places the game's
## own homes, landmarks, people and cars on it.
var real: RealWorld
var real_people: RealPopulation
var real_traffic: RealTraffic


func _ready() -> void:
	_load_areas()
	_build_real_world()
	_build_houses()
	_register_patrol_routes()
	events = NeighbourhoodEvents.new()
	events.name = "Events"
	add_child(events)
	combat = CombatSystem.new()
	combat.name = "Combat"
	add_child(combat)
	combat.events = events
	director = SimulationDirector.new()
	director.name = "SimulationDirector"
	add_child(director)
	director.setup(self, events)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(director.clock, $Sun, $WorldEnvironment.environment)
	skyline = Skyline.new()
	add_child(skyline)
	day_night.skyline = skyline
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(self, director.clock, day_night)
	light_pool = LightPool.new()
	light_pool.name = "LightPool"
	add_child(light_pool)
	light_pool.setup(day_night, real.data.all_lamps())
	_await_real_navigation()


## The real map under the game: every home of the game's families is a real house, landmarks stand
## on real ground, and the chunks that hold any of them keep their navigation for good.
func _build_real_world() -> void:
	var data := RealDistrictData.new()
	if not data.load_meta():
		push_error("Real-world mode: map data missing")
		return
	for id in registry.order:
		var h := registry.get_house(id)
		if not h.real_id.is_empty():
			data.story[h.real_id] = true
	data.game_spots = RealDistrictData.spots_of(areas)   # generated details keep clear of the game's places
	real = RealWorld.new()
	real.name = "RealWestridge"
	real.places = destinations
	add_child(real)
	var phone := is_phone()
	real.bake_all = not phone
	if phone:
		real.load_radius = PHONE_LOAD_RADIUS
		real.builds_per_frame = 1
		real.frame_budget_ms = PHONE_FRAME_MS
		real.sim_radius = PHONE_SIM_RADIUS
		real.sim_margin = PHONE_SIM_MARGIN
	real.setup(data, player if player else self)
	for area in areas:
		real.extra_obstacles.append_array(StreetBuilder.build_real(nav_region, area, destinations))
	for area in areas:   # where "walk into <part>" objectives send you: that part's first place
		var pois: Array = area.get("pois", [])
		if str(area.id) != str(info.id) and not pois.is_empty():
			var at := DataFiles.to_vec2(pois[0].get("position"))
			destinations.register("%s:entrance" % area.id, Vector3(at.x, 0, at.y), 3.0, "district_entrance", str(area.get("display_name", area.id)))
	# Homes: stand each family's plot in its real house's doorway.
	for id in registry.order:
		var h := registry.get_house(id)
		var front := data.house_front(h.real_id)
		if front.is_empty():
			push_error("Real-world mode: %s has no real front door (%s)" % [h.id, h.real_id])
			continue
		var mid: Vector2 = front.mid
		var n: Vector2 = front.normal
		h.position = mid + n * HousePlot.SETBACK
		h.yaw = atan2(n.x, n.y)
	# Navigation is kept wherever the game has a home, a place or a patrol point.
	var points: Array = []
	for id in registry.order:
		var h := registry.get_house(id)
		points.append(Vector3(h.position.x, 0, h.position.y))
	for area in areas:
		for key in ["pois", "landmarks"]:
			for item in area.get(key, []):
				var p := DataFiles.to_vec2(item.get("position"))
				points.append(Vector3(p.x, 0, p.y))
		for route in area.get("patrol_routes", {}).values():
			for q in route:
				points.append(Vector3(float(q[0]), 0, float(q[1])))
	for p: Vector3 in points:
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var near := p + Vector3(dx, 0, dz) * 25.0   # a place near a chunk edge needs the neighbour too
				real.keep_nav[data.chunk_at(near)] = true
	# ...and everything between them: each part's people walk across the whole of its patch.
	for area in areas:
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-(1 << 20), -(1 << 20))
		for key: Vector2i in real.keep_nav.keys():
			if area_at(data.chunk_centre(key)) == str(area.id):
				lo = Vector2i(mini(lo.x, key.x), mini(lo.y, key.y))
				hi = Vector2i(maxi(hi.x, key.x), maxi(hi.y, key.y))
		for cx in range(lo.x, hi.x + 1):
			for cz in range(lo.y, hi.y + 1):
				if data.has_chunk(Vector2i(cx, cz)):
					real.keep_nav[Vector2i(cx, cz)] = true
	if phone:   # only round the player's own patch: the rest is baked when they walk there (RealWorld.scan)
		var home := registry.get_house(GameSession.SAFEHOUSE_ID)
		var centre := Vector3(home.position.x, 0.0, home.position.y)
		for key: Vector2i in real.keep_nav.keys():
			if data.chunk_centre(key).distance_to(centre) > PHONE_KEEP_RADIUS:
				real.keep_nav.erase(key)


## A phone or tablet (a touchscreen, or `-- --touch`) cannot hold the whole suburb: it builds only what
## is near the player, keeps navigation only round the player's own patch (and round wherever they walk),
## carries fewer people and cars, and builds in shorter slices. phone_override: -1 decides by the device,
## 0 never, 1 always (tests). Design: design/gdd/real_world.md ("Phone profile").
const PHONE_LOAD_RADIUS := 320.0
const PHONE_SIM_RADIUS := 220.0
const PHONE_SIM_MARGIN := 100.0
const PHONE_KEEP_RADIUS := 450.0        # navigation kept for good this far round the safehouse
const PHONE_FRAME_MS := 12.0
const PHONE_RESIDENTS := 18
const PHONE_HOMES_PER_CHUNK := 3
const PHONE_CARS := 6
## Far-off people sleep beyond this: where the phone has no navigation for them.
const PHONE_DORMANT := PHONE_SIM_RADIUS + PHONE_SIM_MARGIN
static var phone_override := -1


static func is_phone() -> bool:
	if phone_override >= 0:
		return phone_override == 1
	return DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")


## Game minutes per real second in the real Westridge. The old districts were a few hundred metres
## across, so one real second per game minute (1.0) suited them; people now walk hundreds of metres
## to the next shop, which at that rate would take hours of game time. 0.25 makes a day last 96
## real minutes and a 500 m walk about an hour and a half of game time. (Tests set it back to 1.0.)
static var real_clock_rate := 0.25


## Waits for the kept navigation to be baked and taken in by the map, then brings the world to life.
func _await_real_navigation() -> void:
	var started := Time.get_ticks_msec()
	while not real.keep_nav_ready() and Time.get_ticks_msec() - started < 180000:
		real.scan(player.global_position if player else Vector3.ZERO)
		await get_tree().physics_frame
	if not real.keep_nav_ready():
		push_error("Real-world navigation was not ready after 3 minutes; NPC movement may fail.")
	destinations.navigation_map = get_world_3d().navigation_map
	director.clock.minutes_per_second = real_clock_rate
	_spawn_residents()
	_spawn_vehicles()
	dogs = DogPack.new()
	dogs.name = "Dogs"
	add_child(dogs)
	dogs.setup(self)
	dogs.barked.connect(func(pos: Vector3, pitch: float): dog_barked.emit(pos, pitch))
	for area in areas:
		for k in area.get("kickabouts", []):
			var game := KickAbout.new()
			game.name = "KickAbout_" + str(k.poi)
			add_child(game)
			var c := DataFiles.to_vec2(k.get("center"))
			game.setup(self, str(k.poi), Vector3(c.x, 0, c.y), DataFiles.to_vec2(k.get("half"), Vector2(4, 3)))
			kickabouts.append(game)
	real_people = RealPopulation.new()
	real_people.name = "RealPeople"
	real_people.clock = director.clock
	real_people.own_clock = false
	add_child(real_people)
	real_people.setup(real, player if player else self)
	if is_phone():
		real_people.max_residents = PHONE_RESIDENTS
		real_people.homes_per_chunk = PHONE_HOMES_PER_CHUNK
	real_traffic = RealTraffic.new()
	real_traffic.name = "RealTraffic"
	add_child(real_traffic)
	real_traffic.setup(real, player if player else self, real_people)
	if is_phone():
		real_traffic.max_cars = PHONE_CARS
	if use_lod:
		merge_stats = MeshMerger.merge(nav_region)
		lod_count = Lod.apply(nav_region)
		for r: Resident in residents.values():
			lod_count += Lod.apply(r.model, true)
	is_navigation_ready = true
	navigation_ready.emit()


## Data pipeline: the starter part of Westridge, then every other part in the catalog that has a `data` file.
## The parts are places on one real map: where each one's people and things are, not walls between them.
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
	if catalog is Dictionary:
		for a in areas:   # a part's heart on the real map (for area_at): from the catalog
			for d in catalog.get("districts", []):
				if d is Dictionary and str(d.id) == str(a.id) and d.has("anchor"):
					a["anchor"] = d.anchor
	registry = HouseRegistry.new()
	for area in areas:
		var reg := HouseRegistry.load_file(str(area.get("houses_file", "")))
		registry.errors.append_array(reg.errors)
		for id in reg.order:
			registry.add(reg.get_house(id))


## Degrees the game's compass is turned from true north: none (the real map is not turned).
func grid_bearing() -> float:
	return 0.0


## Which part of Westridge a world position is in: the one whose heart is nearest ("" outside the suburb).
func area_at(pos: Vector3) -> String:
	if not real.data.is_inside(pos):
		return ""
	var best := ""
	var best_d := INF
	for area in areas:
		var a := DataFiles.to_vec2(area.get("anchor"))
		var d := Vector2(pos.x, pos.z).distance_to(a)
		if d < best_d:
			best_d = d
			best = str(area.id)
	return best


func area_by_id(id: String) -> Dictionary:
	for area in areas:
		if area.id == id:
			return area
	return {}


## District a resident lives in (via their home's district_id).
func resident_district(r: Resident) -> String:
	var h := registry.get_house(r.data.home_id)
	if h:
		return h.district_id
	return area_at(destinations.anchor_position(r.data.home_id + ":door")) if destinations.has(r.data.home_id + ":door") else ""


func display_name() -> String:
	var own := 0
	if registry:
		for id in registry.order:
			own += 1 if registry.get_house(id).district_id == info.id else 0
	return "%s · %d of its families are your neighbours · %d real streets" % [info.get("display_name", "?"), own, real.data.streets.size()]


func _build_houses() -> void:
	for id in registry.order:
		var house := registry.get_house(id)
		var plot: HousePlot = HOUSE_SCENE.instantiate()
		nav_region.add_child(plot)
		plot.build_real(house)
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
	# (the real street network carries the moving traffic: RealTraffic)


## The parts of Westridge have no gates, so there is nothing to re-bake when one opens; this still
## announces a change a frame later (the session waits for it after an unlock).
func rebake_navigation() -> void:
	await get_tree().physics_frame
	rebake_count += 1
	navigation_rebaked.emit()


func _spawn_residents() -> void:
	spots.collect(self)
	var i := 0
	var all_npcs: Array[NpcData] = []
	for area in areas:
		all_npcs.append_array(NpcData.load_file(str(area.get("residents_file", ""))))
	for f in extra_residents_files:
		all_npcs.append_array(NpcData.load_file(f))
	for npc in all_npcs:
		# Homes are houses, or (police) a post that registered its own door anchor.
		if registry.get_house(npc.home_id) == null and not destinations.has(npc.home_id + ":door"):
			push_warning("Resident %s has unknown home %s; not spawned." % [npc.id, npc.home_id])
			continue
		if npc.role == "crew" and crews.has(npc.faction_id):
			npc.shirt_color = crews.colour(npc.faction_id)
		var r: Resident = RESIDENT_SCENE.instantiate()
		add_child(r)
		r.setup(npc, destinations, i * 0.11, director.clock, _lookup)
		r.spots = spots
		r.combat = combat
		r.reported.connect(func(who: Resident, event_id: String): events.report(event_id, who.data.display_name))
		r.door_used.connect(_on_door_used)
		residents[npc.id] = r
		i += 1


## Called when the player joins a crew (new game or load): tells every resident.
func set_player_crew(crew_id: String) -> void:
	player_crew_id = crew_id
	for r: Resident in residents.values():
		r.player_faction = crew_id


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
func set_district_open(district_id: String, open: bool, _animate := true) -> bool:
	var was := bool(_open_parts.get(district_id, false))
	_open_parts[district_id] = open
	return was != open


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


var _open_parts := {}


func is_district_open(district_id: String) -> bool:
	return bool(_open_parts.get(district_id, false))


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
			if interiors:
				enter_request = house_id
				return "Nobody home at %s. You slip in round the back." % where
			return "Nobody answers at %s. Someone has sprayed TORTEL on the gate." % where
		return "A voice behind the gate at %s: \"Wrong house, bru. Walk.\"" % where
	if not home.is_empty():
		if interiors and interiors.is_welcome(house_id):
			enter_request = house_id
			return ""
		var who := " and ".join(home)
		var verb := "opens" if home.size() == 1 else "open"
		plots[house_id].open_door(3.0)
		door_opened.emit(plots[house_id].door_position())
		if interiors:
			interiors.welcome(house_id)
			return "%s %s the security gate at %s: \"Ja? Come in, come in.\"  (%s to go inside)" % [who, verb, where, InputHints.key("interact")]
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
			var path := RealNav.long_path(map, from, to)
			if path.size() >= 2 and path[path.size() - 1].distance_to(to) < 0.6:
				report.ok += 1
			else:
				report.failed.append("%s -> %s" % [id, poi_id])
	return report
