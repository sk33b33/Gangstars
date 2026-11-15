class_name RealWorld
extends Node3D
## The real Westridge as a streamed world: chunks within `load_radius` of `focus` are built (one
## per frame, nearest first) and chunks beyond `load_radius + unload_margin` are freed. With
## `load_radius` = INF the whole suburb is built and kept (desktop); a phone uses a few hundred
## metres. Design: design/gdd/real_world.md.

signal chunk_loaded(key: Vector2i)
signal chunk_unloaded(key: Vector2i)

@export var load_radius := INF
@export var unload_margin := 120.0
## Chunks built per frame while catching up (more = faster loading, bigger hitches).
@export var builds_per_frame := 1

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
	if _since_scan >= 0.5 and (_last_scan_pos == Vector3.INF or pos.distance_to(_last_scan_pos) > 10.0 or not _queue.is_empty()):
		_since_scan = 0.0
		_last_scan_pos = pos
		scan(pos)
	for i in builds_per_frame:
		if _queue.is_empty():
			break
		load_chunk(_queue.pop_front())


## Works out which chunks to build and frees the ones that are now too far away.
func scan(pos: Vector3) -> void:
	_queue.clear()
	if is_inf(load_radius):
		for key in data.chunks_near(pos, 1e7):
			if not loaded.has(key):
				_queue.append(key)
		return
	for key in data.chunks_near(pos, load_radius):
		if not loaded.has(key):
			_queue.append(key)
	var limit := load_radius + unload_margin + data.chunk_size * 0.71
	for key: Vector2i in loaded.keys():
		if data.chunk_centre(key).distance_to(Vector3(pos.x, 0.0, pos.z)) > limit:
			unload_chunk(key)


func load_chunk(key: Vector2i) -> void:
	if loaded.has(key) or not data.has_chunk(key):
		return
	var stats := {}
	var node := RealChunkBuilder.build(key, data.load_chunk(key), stats)
	node.set_meta("buildings", int(stats.get("buildings", 0)))
	add_child(node)
	loaded[key] = node
	buildings_loaded += int(stats.get("buildings", 0))
	chunk_loaded.emit(key)


func unload_chunk(key: Vector2i) -> void:
	var node: Node3D = loaded.get(key)
	if node == null:
		return
	buildings_loaded -= int(node.get_meta("buildings", 0))
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
