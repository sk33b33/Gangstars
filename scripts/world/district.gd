class_name District
extends Node3D
## Owns district geometry, house plots, destinations, navigation and residents.
## Everything is built from data files; navigation is baked at load from the built geometry.

signal navigation_ready

const HOUSE_SCENE := preload("res://scenes/houses/house_plot.tscn")
const RESIDENT_SCENE := preload("res://scenes/npcs/resident.tscn")

@export_file("*.json") var district_file := "res://data/districts/starter.json"
@export_file("*.json") var houses_file := "res://data/houses/starter_houses.json"
@export_file("*.json") var residents_file := "res://data/npcs/starter_residents.json"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

var info: Dictionary = {}
var registry: HouseRegistry
var destinations := DestinationRegistry.new()
var plots: Dictionary = {}       # house id -> HousePlot
var residents: Dictionary = {}   # npc id -> Resident
var is_navigation_ready := false


func _ready() -> void:
	var raw: Variant = DataFiles.load_json(district_file)
	info = raw if raw is Dictionary else {}
	registry = HouseRegistry.load_file(houses_file)
	StreetBuilder.build(nav_region, info, destinations)
	_build_houses()
	_bake_navigation()


func display_name() -> String:
	return "%s · %s" % [info.get("display_name", "?"), info.get("street_name", "")]


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
			"No. %d (%s)" % [house.number, house.display_name])
		plot.door_interactable.on_interact = _on_door.bind(id)


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
	nav_region.navigation_mesh = nm
	nav_region.bake_finished.connect(_on_bake_finished, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh(false)


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
	is_navigation_ready = true
	navigation_ready.emit()


func _region_is_live(map: RID) -> bool:
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var probe := Vector3(0, 0, 0)
	return NavigationServer3D.map_get_closest_point_owner(map, probe) == nav_region.get_rid()


func _spawn_residents() -> void:
	var i := 0
	for npc in NpcData.load_file(residents_file):
		if registry.get_house(npc.home_id) == null:
			push_warning("Resident %s has unknown home %s; not spawned." % [npc.id, npc.home_id])
			continue
		var r: Resident = RESIDENT_SCENE.instantiate()
		add_child(r)
		r.setup(npc, destinations, i * 0.11)
		residents[npc.id] = r
		i += 1


func _on_door(house_id: String) -> String:
	var house := registry.get_house(house_id)
	if house.ownership == "player":
		return "Your safehouse, No. %d. It's quiet. (Saving and upgrades arrive in Phase 4.)" % house.number
	if house.occupancy == "vacant":
		return "No. %d is empty. The curtains are drawn." % house.number
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
	if not home.is_empty():
		var who := " and ".join(home)
		var verb := "opens" if home.size() == 1 else "open"
		return "%s %s the security gate at No. %d: \"Ja? Can I help you?\"" % [who, verb, house.number]
	return "No answer at No. %d. Out: %s." % [house.number, ", ".join(out)]


## Debug/test helper: path from every occupied house door to every public destination.
func reachability_report() -> Dictionary:
	var map := nav_region.get_navigation_map()
	var report := {"ok": 0, "failed": PackedStringArray()}
	var pois: PackedStringArray = []
	for poi in info.get("pois", []):
		pois.append(str(poi.id))
	for id in registry.order:
		var house := registry.get_house(id)
		var from := NavigationServer3D.map_get_closest_point(map, destinations.anchor_position(house.entrance_id()))
		for poi_id in pois:
			var to := NavigationServer3D.map_get_closest_point(map, destinations.anchor_position(poi_id))
			var path := NavigationServer3D.map_get_path(map, from, to, true)
			if path.size() >= 2 and path[path.size() - 1].distance_to(to) < 0.6:
				report.ok += 1
			else:
				report.failed.append("%s -> %s" % [id, poi_id])
	return report
