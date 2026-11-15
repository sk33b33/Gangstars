class_name RealRoadGraph
extends RefCounted
## The drivable street network of the loaded chunks: road pieces are edges, their ends are nodes
## (the map tool cuts every street at its junctions). Cars pick their way through it.
## Design: design/gdd/real_world.md.

const DRIVABLE := ["main", "collector", "street"]

var nodes := {}      # Vector2i (decimetres) -> {pos: Vector2, edges: Array[int]}
var edges := {}      # id -> {a, b: Vector2i, pts: PackedVector2Array, cls, oneway: bool, w, name, chunk: Vector2i, length}
var _by_chunk := {}  # chunk key -> Array[int]
var _next_id := 1


static func node_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 10.0), roundi(p.y * 10.0))


func add_chunk(key: Vector2i, roads: Array) -> void:
	if _by_chunk.has(key):
		return
	var ids: Array = []
	for r in roads:
		if not DRIVABLE.has(str(r.c)):
			continue
		var pts := RealChunkBuilder._line(r.p)
		if pts.size() < 2:
			continue
		var id := _next_id
		_next_id += 1
		var a := node_key(pts[0])
		var b := node_key(pts[pts.size() - 1])
		edges[id] = {"a": a, "b": b, "pts": pts, "cls": str(r.c), "oneway": int(r.get("o", 0)) == 1, "w": float(r.w),
			"name": str(r.get("n", "")), "chunk": key, "length": RealChunkBuilder._length(pts)}
		for end in [[a, pts[0]], [b, pts[pts.size() - 1]]]:
			if not nodes.has(end[0]):
				nodes[end[0]] = {"pos": end[1], "edges": []}
			nodes[end[0]].edges.append(id)
		ids.append(id)
	_by_chunk[key] = ids


func remove_chunk(key: Vector2i) -> void:
	for id in _by_chunk.get(key, []):
		var e: Dictionary = edges[id]
		for n in [e.a, e.b]:
			if nodes.has(n):
				nodes[n].edges.erase(id)
				if nodes[n].edges.is_empty():
					nodes.erase(n)
		edges.erase(id)
	_by_chunk.erase(key)


func has_edge(id: int) -> bool:
	return edges.has(id)


## Can a car drive `edge_id` starting from node `from`?
func can_enter(edge_id: int, from: Vector2i) -> bool:
	var e: Dictionary = edges[edge_id]
	return e.a == from or (e.b == from and not e.oneway)


## The far end of an edge entered at `from`.
func other_end(edge_id: int, from: Vector2i) -> Vector2i:
	var e: Dictionary = edges[edge_id]
	return e.b if e.a == from else e.a


## The edge's points in driving order when entered at `from`.
func points_from(edge_id: int, from: Vector2i) -> PackedVector2Array:
	var e: Dictionary = edges[edge_id]
	if e.a == from:
		return e.pts
	var back: PackedVector2Array = e.pts.duplicate()
	back.reverse()
	return back


## Where to go on reaching `node` along `came_by`: any edge you may enter, not straight back
## unless it is a dead end. Returns 0 if there is nowhere to go (the edge of the loaded world).
func next_edge(node: Vector2i, came_by: int, rng: RandomNumberGenerator) -> int:
	if not nodes.has(node):
		return 0
	var options: Array = []
	for id in nodes[node].edges:
		if id != came_by and can_enter(id, node):
			options.append(id)
	if options.is_empty():
		return came_by if edges.has(came_by) and not edges[came_by].oneway else 0
	return options[rng.randi() % options.size()]


func junctions() -> Array:
	var out: Array = []
	for n in nodes:
		if nodes[n].edges.size() >= 3:
			out.append(nodes[n].pos)
	return out
