class_name RealWorld
extends Node3D
## The real Westridge as a streamed world: chunks within `load_radius` of `focus` are built (one
## per frame, nearest first) and chunks beyond `load_radius + unload_margin` are freed. With
## `load_radius` = INF the whole suburb is built and kept (desktop); a phone uses a few hundred
## metres. Design: design/gdd/real_world.md.

signal chunk_loaded(key: Vector2i)
signal chunk_unloaded(key: Vector2i)
signal nav_ready(key: Vector2i)
signal nav_removed(key: Vector2i)

@export var load_radius := INF
@export var unload_margin := 120.0
## Chunks built per frame while catching up (more = faster loading, bigger hitches): at least this many
## steps (planning a chunk's details, or building it), then more while the frame has used under frame_budget_ms.
@export var builds_per_frame := 1
@export var frame_budget_ms := 40.0

## People and traffic only exist within this distance of the focus: chunks inside it get a
## navigation mesh (baked in the background) and lose it again beyond `sim_radius + sim_margin`.
@export var sim_radius := 300.0
@export var sim_margin := 150.0
## Tests: bake navigation on the spot instead of on a background thread.
var sync_nav := false

var places := DestinationRegistry.new()   # house doors ("<house id>:door") and landmarks ("lm_<n>")
## Chunks that always keep their navigation, wherever the focus is (the game's own places), baked
## from the map data even when the chunk's buildings are not loaded.
var keep_nav := {}          # chunk key -> true
var humps := {}             # chunk key -> Array[Vector2]: the speed humps of each loaded chunk
## A street vendor was used: stock kind ("fruit_stall", "snoek_bakkie") and the vendor's name; the session opens the shop menu.
signal vendor_used(stock_kind: String, label: String)
## Bake the rest of the suburb too, in the background (nearest first) and keep it: people can
## then walk from any part of Westridge to any other (a crew-mate following you across town).
var bake_all := false
## Things the game built on top of the real map (landmark props): outlines the navigation must go round.
var extra_obstacles: Array = []   # PackedVector2Array
var graph := RealRoadGraph.new()
var houses := {}            # chunk key -> [{id, door, area}]
var nav_regions := {}       # chunk key -> NavigationRegion3D
var _nav_baking := {}       # chunk key -> true while its bake runs
var data: RealDistrictData
var focus: Node3D
var loaded := {}            # Vector2i -> Node3D
var buildings_loaded := 0
var _queue: Array[Vector2i] = []
var _since_scan := 1.0
var _last_scan_pos := Vector3.INF


func setup(p_data: RealDistrictData, p_focus: Node3D) -> void:
	data = p_data
	focus = p_focus
	_build_ground()
	_register_landmarks()


const LANDMARK_KINDS := {"park": "park", "playground": "park", "retail": "shop", "convenience": "shop", "fast_food": "shop", "fuel": "shop",
	"community_centre": "gathering", "clinic": "gathering", "place_of_worship": "gathering", "church": "gathering", "library": "gathering",
	"pitch": "court", "sports": "court", "pool": "court"}


## Named real places people go to: parks, shops, the civic centre, churches and mosques, pitches.
func _register_landmarks() -> void:
	for i in data.landmarks.size():
		var l: Dictionary = data.landmarks[i]
		if LANDMARK_KINDS.has(l.kind):
			places.register("lm_%d" % i, Vector3(l.at.x, 0.0, l.at.y), 3.0, LANDMARK_KINDS[l.kind], l.name)


func _enter_tree() -> void:
	places.navigation_map = get_world_3d().navigation_map


## One flat slab under everything (collision layer 1, like the old districts' ground).
func _build_ground() -> void:
	var r := data.bounds.grow(400.0)
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := BoxShape3D.new()
	shape.size = Vector3(r.size.x, 1.0, r.size.y)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.material_override = PixelMaterials.surface("yard_sand", Vector2(2, 2), Color(0.86, 0.8, 0.7))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	body.position = Vector3(r.get_center().x, -0.5, r.get_center().y)
	add_child(body)


func _process(delta: float) -> void:
	if data == null or focus == null:
		return
	_since_scan += delta
	var pos := focus.global_position
	if _since_scan >= 0.5:
		_since_scan = 0.0
		if _last_scan_pos == Vector3.INF or pos.distance_to(_last_scan_pos) > 10.0 or not _queue.is_empty():
			_last_scan_pos = pos
			scan(pos)
		else:
			_scan_nav(pos)
	var start := Time.get_ticks_usec()
	var steps := 0
	while not _queue.is_empty() and (steps < builds_per_frame or (Time.get_ticks_usec() - start) / 1000.0 < frame_budget_ms):
		if not data.is_prepared(_queue[0]):
			data.prepare(_queue[0])   # planning and building are separate steps, so no single step is long
		else:
			load_chunk(_queue.pop_front())
		steps += 1


## Works out which chunks to build and frees the ones that are now too far away.
func scan(pos: Vector3) -> void:
	_queue.clear()
	if is_inf(load_radius):
		for key in data.chunks_near(pos, 1e7):
			if not loaded.has(key):
				_queue.append(key)
		_scan_nav(pos)
		return
	for key in data.chunks_near(pos, load_radius):
		if not loaded.has(key):
			_queue.append(key)
	var limit := load_radius + unload_margin + data.chunk_size * 0.71
	for key: Vector2i in loaded.keys():
		if data.chunk_centre(key).distance_to(Vector3(pos.x, 0.0, pos.z)) > limit:
			unload_chunk(key)
	_scan_nav(pos)


func _near(key: Vector2i, pos: Vector3, radius: float) -> bool:
	return data.chunk_centre(key).distance_to(Vector3(pos.x, 0.0, pos.z)) <= radius + data.chunk_size * 0.71


## Navigation follows the focus: bake the nearest loaded chunk that lacks it (one at a time),
## and drop the meshes that are now far away.
func _scan_nav(pos: Vector3) -> void:
	if not bake_all:
		for key: Vector2i in nav_regions.keys():
			if not keep_nav.has(key) and not _near(key, pos, sim_radius + sim_margin):
				_remove_nav(key)
	if not _nav_baking.is_empty():
		return
	for key: Vector2i in keep_nav:
		if not nav_regions.has(key) and data.has_chunk(key):
			_bake_nav(key)
			if not sync_nav:
				return
	for key in data.chunks_near(pos, sim_radius):
		if loaded.has(key) and not nav_regions.has(key):
			_bake_nav(key)
			if not sync_nav:
				return
	if bake_all:
		for key in data.chunks_near(pos, 1e7):
			if not nav_regions.has(key):
				_bake_nav(key)
				if not sync_nav:
					return


func _bake_nav(key: Vector2i) -> void:
	var rings := data.around(key, "outlines")
	rings.append_array(data.around(key, "obstacles"))
	rings.append_array(extra_obstacles)
	if sync_nav:
		_on_nav_baked(RealNav.bake(key, data.chunk_size, rings), key)
		return
	_nav_baking[key] = true
	RealNav.bake_async(key, data.chunk_size, rings, _on_nav_baked.bind(key))


func _on_nav_baked(nm: NavigationMesh, key: Vector2i) -> void:
	_nav_baking.erase(key)
	if not is_inside_tree() or not (loaded.has(key) or keep_nav.has(key) or bake_all) or nav_regions.has(key):
		return
	var region := NavigationRegion3D.new()
	region.name = "Nav_%d_%d" % [key.x, key.y]
	region.navigation_mesh = nm
	add_child(region)
	nav_regions[key] = region
	nav_ready.emit(key)


func _remove_nav(key: Vector2i) -> void:
	var region: NavigationRegion3D = nav_regions.get(key)
	if region == null:
		return
	nav_regions.erase(key)
	nav_removed.emit(key)
	region.queue_free()


## True once the whole suburb has navigation.
func all_nav_ready() -> bool:
	return nav_regions.size() >= data.chunk_keys.size()


## True once every kept chunk has its navigation and the map has taken it in.
func keep_nav_ready() -> bool:
	for key: Vector2i in keep_nav:
		if data.has_chunk(key) and not nav_synced(data.chunk_centre(key)):
			return false
	return true


## True once the navigation map has taken in the region under `pos` (regions are added to the
## map on a later, background sync; until then queries answer with the origin).
func nav_synced(pos: Vector3) -> bool:
	if not has_nav(pos):
		return false
	var flat := Vector3(pos.x, 0.0, pos.z)
	var on_map := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, flat)
	return Vector2(on_map.x - flat.x, on_map.z - flat.z).length() < 60.0


## Metres to the nearest speed hump in the lane ahead of `pos` heading `forward`, within `reach`
## (a hump just passed, up to 2.5 m behind, counts as 0); INF when there is none.
func hump_ahead(pos: Vector3, forward: Vector3, reach: float) -> float:
	var here := data.chunk_at(pos)
	var f := Vector2(forward.x, forward.z).normalized()
	var p := Vector2(pos.x, pos.z)
	var best := INF
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for h: Vector2 in humps.get(here + Vector2i(dx, dz), []):
				var v := h - p
				var along := v.dot(f)
				if along > -2.5 and along < reach and absf(v.dot(Vector2(-f.y, f.x))) < 3.5:
					best = minf(best, maxf(along, 0.0))
	return best


func has_nav(pos: Vector3) -> bool:
	return nav_regions.has(data.chunk_at(pos))


func load_chunk(key: Vector2i) -> void:
	if loaded.has(key) or not data.has_chunk(key):
		return
	var stats := {}
	var chunk := data.load_chunk(key)
	var node := RealChunkBuilder.build(key, chunk, stats, data.around(key, "road_lines"), data.story, data.around(key, "outlines"), data.yards(key), data.home_fronts(key), {"street": data.street_context(key), "decor": data.home_decor(key),
		"schools": data.school_fences(key), "stalls": data.stalls(key), "strips": data.around(key, "road_strips")})
	houses[key] = stats.get("houses", [])
	humps[key] = stats.get("humps", [])
	for h in houses[key]:
		places.register(str(h.id) + ":door", h.door, 0.3, "home", "a house")
	graph.add_chunk(key, chunk.get("roads", []))
	node.set_meta("buildings", int(stats.get("buildings", 0)))
	add_child(node)
	for s: Dictionary in data.stalls(key):   # the person behind each stall (freed with the chunk)
		var vendor := RealVendor.new()
		node.add_child(vendor)
		var behind: Vector2 = s.at + s.out * (0.75 if s.kind == "fruit" else 1.3) + (s.dir * -2.4 if s.kind == "snoek" else Vector2.ZERO)
		vendor.setup(str(s.kind), behind, -s.out, hash(Vector2i(roundi(s.at.x), roundi(s.at.y))), func(stock: String, label: String): vendor_used.emit(stock, label))
	for pp: Dictionary in stats.get("people", []):   # car guards and taxi conductors (nothing to sell, just there)
		var person := RealVendor.new()
		node.add_child(person)
		person.setup(str(pp.kind), pp.at, pp.face, hash(Vector2i(roundi(pp.at.x), roundi(pp.at.y))), func(_stock: String, _label: String): pass)
	loaded[key] = node
	buildings_loaded += int(stats.get("buildings", 0))
	chunk_loaded.emit(key)


func unload_chunk(key: Vector2i) -> void:
	var node: Node3D = loaded.get(key)
	if node == null:
		return
	buildings_loaded -= int(node.get_meta("buildings", 0))
	if not keep_nav.has(key) and not bake_all:
		_remove_nav(key)
	for h in houses.get(key, []):
		places.remove(str(h.id) + ":door")
	houses.erase(key)
	humps.erase(key)
	graph.remove_chunk(key)
	loaded.erase(key)
	node.queue_free()
	chunk_unloaded.emit(key)


## Builds everything now (tests, screenshots).
func load_all_now() -> void:
	for key in data.chunk_keys:
		load_chunk(key)
	_queue.clear()


func pending() -> int:
	return _queue.size()


## The named street nearest to `pos` among the loaded chunks' signs ("" if none within 60 m).
func street_near(pos: Vector3) -> String:
	var best := ""
	var best_d := 60.0
	for key: Vector2i in loaded:
		if data.chunk_centre(key).distance_to(pos) > data.chunk_size * 1.5:
			continue
		for child in (loaded[key] as Node3D).get_children():
			if child.has_meta("street"):
				var d := Vector2(child.position.x, child.position.z).distance_to(Vector2(pos.x, pos.z))
				if d < best_d:
					best_d = d
					best = str(child.get_meta("street"))
	return best
