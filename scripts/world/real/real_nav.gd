class_name RealNav
extends RefCounted
## Navigation for the real Westridge: one NavigationRegion3D per chunk, baked from a flat ground
## quad with every building outline cut out (projected obstructions), so NavigationAgent3D paths
## go round the real buildings. Chunks are baked with a border and a shared cell grid, so the
## regions of neighbouring chunks meet edge to edge. Design: design/gdd/real_world.md.

const CELL := 0.25
const AGENT_RADIUS := 0.6
const BORDER := 1.0          # > agent radius, a multiple of the cell size


static func new_mesh(key: Vector2i, chunk_size: float) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = CELL
	nm.cell_height = CELL
	nm.agent_radius = AGENT_RADIUS
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.border_size = BORDER
	var origin := Vector3(key.x * chunk_size, 0.0, key.y * chunk_size)
	nm.filter_baking_aabb = AABB(origin - Vector3(BORDER, 2.0, BORDER), Vector3(chunk_size + BORDER * 2.0, 6.0, chunk_size + BORDER * 2.0))
	return nm


## The ground of the chunk (with a margin so the border is filled) and the outlines that block it.
## `outlines`: building rings (PackedVector2Array) from this chunk and its neighbours.
static func source(key: Vector2i, chunk_size: float, outlines: Array) -> NavigationMeshSourceGeometryData3D:
	var src := NavigationMeshSourceGeometryData3D.new()
	var m := BORDER + 2.0
	var x0 := key.x * chunk_size - m
	var z0 := key.y * chunk_size - m
	var x1 := (key.x + 1) * chunk_size + m
	var z1 := (key.y + 1) * chunk_size + m
	src.add_faces(PackedVector3Array([Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1),
		Vector3(x0, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]), Transform3D.IDENTITY)
	var area := Rect2(x0, z0, x1 - x0, z1 - z0)
	for ring: PackedVector2Array in outlines:
		var box := Rect2(ring[0], Vector2.ZERO)
		for p in ring:
			box = box.expand(p)
		if not box.intersects(area):
			continue
		var verts := PackedVector3Array()
		for p in ring:
			verts.append(Vector3(p.x, 0.0, p.y))
		# carve = false: the outline is treated like a wall, so the bake keeps the agent radius clear
		# of it. (Carved outlines ignore the radius: routes then squeeze through gaps under a metre.)
		src.add_projected_obstruction(verts, -1.0, 4.0, false)
	return src


## The engine gives up a route search after 4,096 polygons by default; the whole suburb has about
## 85,000, so a walk across it needs the limit lifted.
const SEARCH_POLYGONS := 200000


## A walking route between two points anywhere on the map (the plain map_get_path is cut short on long walks).
static func long_path(map: RID, from: Vector3, to: Vector3) -> PackedVector3Array:
	var params := NavigationPathQueryParameters3D.new()
	params.map = map
	params.start_position = from
	params.target_position = to
	params.path_search_max_polygons = SEARCH_POLYGONS
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(params, result)
	return result.path


## Bakes now (blocking) and returns the mesh.
static func bake(key: Vector2i, chunk_size: float, outlines: Array) -> NavigationMesh:
	var nm := new_mesh(key, chunk_size)
	NavigationServer3D.bake_from_source_geometry_data(nm, source(key, chunk_size, outlines))
	return nm


## Bakes on a background thread; `done` is called with the mesh on the main thread.
static func bake_async(key: Vector2i, chunk_size: float, outlines: Array, done: Callable) -> void:
	var nm := new_mesh(key, chunk_size)
	var src := source(key, chunk_size, outlines)
	WorkerThreadPool.add_task(func():
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		if done.is_valid():   # the world may have been freed while the bake ran
			done.call_deferred(nm))
