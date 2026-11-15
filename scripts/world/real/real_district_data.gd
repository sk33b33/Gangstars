class_name RealDistrictData
extends RefCounted
## The real Westridge (data/world/westridge/, built by tools/osm/build_westridge.py): boundary,
## street names, landmarks, and the 200 m chunks of roads, building outlines and open areas.
## Coordinates: metres from the Westridge suburb point, x = east, z = south (true north is -z).
## Design: design/gdd/real_world.md.

const DIR := "res://data/world/westridge/"

var credit := ""
var chunk_size := 200.0
var boundary := PackedVector2Array()
var chunk_keys: Array[Vector2i] = []
var streets: PackedStringArray = []
var landmarks: Array = []      # {name, kind, at: Vector2}
var counts: Dictionary = {}
var bounds := Rect2()
var _has := {}
var _outlines := {}
var _road_lines := {}


func load_meta() -> bool:
	var m: Variant = DataFiles.load_json(DIR + "meta.json")
	if not m is Dictionary:
		return false
	credit = str(m.get("credit", ""))
	chunk_size = float(m.get("chunk", 200.0))
	for p in m.get("boundary", []):
		boundary.append(Vector2(float(p[0]), float(p[1])))
	for c in m.get("chunks", []):
		var key := Vector2i(int(c[0]), int(c[1]))
		chunk_keys.append(key)
		_has[key] = true
	streets = PackedStringArray(m.get("streets", []))
	for l in m.get("landmarks", []):
		landmarks.append({"name": str(l.name), "kind": str(l.kind), "at": Vector2(float(l.at[0]), float(l.at[1]))})
	counts = m.get("counts", {})
	if boundary.is_empty():
		return false
	bounds = Rect2(boundary[0], Vector2.ZERO)
	for p in boundary:
		bounds = bounds.expand(p)
	return true


func has_chunk(key: Vector2i) -> bool:
	return _has.has(key)


func chunk_at(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))


func chunk_centre(key: Vector2i) -> Vector3:
	return Vector3((key.x + 0.5) * chunk_size, 0.0, (key.y + 0.5) * chunk_size)


## {roads: [...], buildings: [...], areas: [...]} or {} if the chunk has no data.
func load_chunk(key: Vector2i) -> Dictionary:
	if not has_chunk(key):
		return {}
	var d: Variant = DataFiles.load_json("%sc_%d_%d.json" % [DIR, key.x, key.y])
	return d if d is Dictionary else {}


## Building outlines of a chunk (cached): the navigation bake needs a chunk's neighbours too.
func outlines(key: Vector2i) -> Array:
	if not _outlines.has(key):
		var rings: Array = []
		for b in load_chunk(key).get("buildings", []):
			rings.append(RealChunkBuilder._line(b.p))
		_outlines[key] = rings
	return _outlines[key]


## Centre lines of a chunk's streets (not footpaths), cached: houses face the nearest one.
func road_lines(key: Vector2i) -> Array:
	if not _road_lines.has(key):
		var lines: Array = []
		for r in load_chunk(key).get("roads", []):
			if str(r.c) != "path":
				lines.append(RealChunkBuilder._line(r.p))
		_road_lines[key] = lines
	return _road_lines[key]


## `what` ("outlines" or "road_lines") of the chunk and its eight neighbours.
func around(key: Vector2i, what: String) -> Array:
	var out: Array = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			out.append_array(call(what, key + Vector2i(dx, dz)))
	return out


func is_inside(pos: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(pos.x, pos.z), boundary)


func landmark(landmark_name: String) -> Dictionary:
	for l in landmarks:
		if l.name == landmark_name:
			return l
	return {}


## Chunk keys whose centre is within `radius` of `pos`, nearest first.
func chunks_near(pos: Vector3, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in chunk_keys:
		if chunk_centre(key).distance_to(Vector3(pos.x, 0.0, pos.z)) <= radius + chunk_size * 0.71:
			out.append(key)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return chunk_centre(a).distance_squared_to(pos) < chunk_centre(b).distance_squared_to(pos))
	return out
