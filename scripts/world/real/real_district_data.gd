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
## Places the game uses (corners, shops, landmarks, parked cars, patrol points), set by District; with
## the story homes' doors and gates they are kept clear: no stall, parked car, wendy house, tank or
## school fence piece within KEEP_CLEAR of them.
var game_spots := PackedVector2Array()
const KEEP_CLEAR := 3.0
var _clear_spots := PackedVector2Array()
var _clear_ready := false
## Real houses that belong to the game's own families (house id -> true); set by District.
var story := {}
var _has := {}
var _outlines := {}
var _chunks := {}
var _road_lines := {}
var _strips := {}
var _fronts := {}
var _yards := {}
var _street_ctx := {}
var _decor := {}
var _schools := {}
var _stalls := {}


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
	if not _chunks.has(key):
		var d: Variant = DataFiles.load_json("%sc_%d_%d.json" % [DIR, key.x, key.y])
		_chunks[key] = d if d is Dictionary else {}
	return _chunks[key]


## Every street light in the suburb (from the data; the builder puts a pole at each).
func all_lamps() -> PackedVector3Array:
	var out := PackedVector3Array()
	for key in chunk_keys:
		out.append_array(RealChunkBuilder.lamp_points(load_chunk(key).get("roads", [])))
	return out


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


## Street and footpath centre lines of a chunk with how far from the line a yard must stay: half the
## width plus the pavement, but at most RealYards.PAVE_KEEP of it (a fence may stand on the back of a
## wide pavement): [{line, reach}], cached.
func road_strips(key: Vector2i) -> Array:
	if not _strips.has(key):
		var out: Array = []
		for r in load_chunk(key).get("roads", []):
			var line := RealChunkBuilder._line(r.p)
			out.append({"line": line, "reach": float(r.w) * 0.5 + minf(float(r.get("s", 0.0)), RealYards.PAVE_KEEP), "box": RealChunkBuilder.ring_box(line), "half": float(r.w) * 0.5 if str(r.c) != "path" else 0.0})
		_strips[key] = out
	return _strips[key]


## The fronts of a chunk's homes: {building index: home_front}, cached.
func home_fronts(key: Vector2i) -> Dictionary:
	if not _fronts.has(key):
		var fronts := {}
		var all := around(key, "outlines")
		var boxes: Array = all.map(func(r): return RealChunkBuilder.ring_box(r))
		var roads := around(key, "road_lines")
		var rings := outlines(key)
		var buildings: Array = load_chunk(key).get("buildings", [])
		for i in buildings.size():
			if RealChunkBuilder.is_home(buildings[i], rings[i]):
				var front := RealChunkBuilder.home_front(rings[i], roads, RealChunkBuilder.rings_near(rings[i], all, boxes))
				if not front.is_empty():
					fronts[i] = front
		_fronts[key] = fronts
	return _fronts[key]


## Walk-out lanes of a chunk's homes: from the doorstep (1.2 m outside the front door) straight out
## RealYards.LANE metres. No fence may cross another home's lane.
func door_lanes(key: Vector2i) -> Array:
	var out: Array = []
	for f: Dictionary in home_fronts(key).values():
		var step: Vector2 = f.mid + f.normal * RealChunkBuilder.DOOR_OUT
		out.append(PackedVector2Array([step, step + f.normal * RealYards.LANE]))
	return out


## The yards of a chunk's homes: {building index: RealYards.plan}, cached.
func yards(key: Vector2i) -> Dictionary:
	if not _yards.has(key):
		var out := {}
		var all := around(key, "outlines")
		var boxes: Array = all.map(func(r): return RealChunkBuilder.ring_box(r))
		var strips := around(key, "road_strips")
		var lanes := around(key, "door_lanes")
		var rings := outlines(key)
		var fronts := home_fronts(key)
		for i: int in fronts:
			var plan := RealYards.plan(rings[i], fronts[i], strips, RealChunkBuilder.rings_near(rings[i], all, boxes), lanes,
				story.has("h_%d_%d_%d" % [key.x, key.y, i]), RealChunkBuilder.seed_of(rings[i]))
			if not plan.is_empty():
				var drive: Dictionary = plan.drive
				if drive.has("car") and not keeps_clear(RealYards.obstacle_box(drive.car.at, drive.car.dir, Vector2(RealYards.CAR_LENGTH * 0.5, RealYards.CAR_WIDTH * 0.5))):
					drive.erase("car")
				out[i] = plan
		_yards[key] = out
	return _yards[key]


## The fences of a chunk as thin outlines for the navigation bake.
func fence_rings(key: Vector2i) -> Array:
	var out: Array = []
	for plan: Dictionary in yards(key).values():
		for seg: Array in plan.segments:
			out.append(RealYards.obstacle(seg[0], seg[1]))
	return out


## Fence pieces ([a, b]) of a chunk's yards.
func fence_segments(key: Vector2i) -> Array:
	var out: Array = []
	for plan: Dictionary in yards(key).values():
		out.append_array(plan.segments)
	return out


## The decor of a chunk's homes: {building index: RealHomeDecor.plan}, cached.
func home_decor(key: Vector2i) -> Dictionary:
	if not _decor.has(key):
		var out := {}
		var all := around(key, "outlines")
		var boxes: Array = all.map(func(r): return RealChunkBuilder.ring_box(r))
		var strips := around(key, "road_strips")
		var lanes := around(key, "door_lanes")
		var fences := around(key, "fence_segments")
		var rings := outlines(key)
		var fronts := home_fronts(key)
		var plans := yards(key)
		for i: int in fronts:
			var d := RealHomeDecor.plan(rings[i], fronts[i], plans.get(i, {}), RealChunkBuilder.rings_near(rings[i], all, boxes), strips, lanes, fences,
				story.has("h_%d_%d_%d" % [key.x, key.y, i]), RealChunkBuilder.seed_of(rings[i]))
			var kept: Array = (d.obstacles as Array).filter(func(o): return keeps_clear(o))
			if kept.size() < (d.obstacles as Array).size():   # a wendy house or tank on a game place: leave it out
				if d.has("back") and d.back.kind == "wendy" and not keeps_clear(RealYards.obstacle_box(d.back.at, d.back.u, RealHomeDecor.WENDY_HALF)):
					d.erase("back")
				if d.has("tank") and not keeps_clear(RealYards.obstacle_box(d.tank, Vector2.RIGHT, Vector2(RealHomeDecor.TANK_RADIUS, RealHomeDecor.TANK_RADIUS))):
					d.erase("tank")
				d.obstacles = kept
			out[i] = d
		_decor[key] = out
	return _decor[key]


## The game places (from a district's area data): pois, landmarks, parked cars and patrol points.
static func spots_of(areas: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for a: Dictionary in areas:
		for key in ["pois", "landmarks", "parked_cars"]:
			for e: Dictionary in a.get(key, []):
				if e.has("position"):
					out.append(DataFiles.to_vec2(e.position))
		for route: Array in (a.get("patrol_routes", {}) as Dictionary).values():
			for p in route:
				out.append(DataFiles.to_vec2(p))
	return out


## game_spots plus the story homes' doors (0.9 m out) and gates (5 m out).
func clear_spots() -> PackedVector2Array:
	if not _clear_ready:
		_clear_spots = game_spots.duplicate()
		for hid: String in story:
			var f := house_front(hid)
			if not f.is_empty():
				_clear_spots.append(f.mid + f.normal * 0.9)
				_clear_spots.append(f.mid + f.normal * 5.0)
		_clear_ready = true
	return _clear_spots


## True when the outline keeps KEEP_CLEAR from every game place.
func keeps_clear(ring: PackedVector2Array) -> bool:
	for p in clear_spots():
		if RealChunkBuilder.point_in_ring(p, ring) or RealChunkBuilder._distance_to_ring(p, ring) < KEEP_CLEAR:
			return false
	return true


## True when everything the builder needs for the chunk has been worked out (see prepare).
func is_prepared(key: Vector2i) -> bool:
	return _decor.has(key) and _schools.has(key) and _stalls.has(key) and _street_ctx.has(key)


## Works out (and caches) the chunk's yards, home details, street details, school fences and stalls.
func prepare(key: Vector2i) -> void:
	street_context(key)
	home_decor(key)
	school_fences(key)
	stalls(key)


## Palisade pieces round the school grounds stored in a chunk (cached).
func school_fences(key: Vector2i) -> Array:
	if not _schools.has(key):
		var out: Array = []
		var all := around(key, "outlines")
		var strips := around(key, "road_strips")
		var lanes := around(key, "door_lanes")
		for a: Dictionary in load_chunk(key).get("areas", []):
			if str(a.k) == "school":
				var ring := RealChunkBuilder._line(a.p)
				var box := RealChunkBuilder.ring_box(ring).grow(5.0)
				out.append_array(RealParkDecor.school_fence(ring, all.filter(func(r): return RealChunkBuilder.ring_box(r).intersects(box)),
					strips.filter(func(s): return (s.box as Rect2).intersects(box.grow(30.0))), lanes.filter(func(l): return box.has_point(l[0]))))
		_schools[key] = out.filter(func(piece): return keeps_clear(RealYards.obstacle(piece[0], piece[1])))
	return _schools[key]


## Street stalls on this chunk's crossings (cached).
func stalls(key: Vector2i) -> Array:
	if not _stalls.has(key):
		_stalls[key] = RealParkDecor.stalls(street_context(key).crossings, around(key, "outlines"), around(key, "door_lanes")).filter(
			func(s): return keeps_clear(RealParkDecor.stall_box(s)))
	return _stalls[key]


## Everything people must walk round besides the buildings: fences, parked cars, wendy houses, tanks,
## school fences and street stalls.
func obstacles(key: Vector2i) -> Array:
	var out := fence_rings(key)
	for piece: Array in school_fences(key):
		out.append(RealYards.obstacle(piece[0], piece[1]))
	for s: Dictionary in stalls(key):
		out.append(RealParkDecor.stall_box(s))
	for plan: Dictionary in yards(key).values():
		var drive: Dictionary = plan.get("drive", {})
		if drive.has("car"):
			out.append(RealYards.obstacle_box(drive.car.at, drive.car.dir, Vector2(RealYards.CAR_LENGTH * 0.5, RealYards.CAR_WIDTH * 0.5)))
	for d: Dictionary in home_decor(key).values():
		out.append_array(d.obstacles)
	return out


## What the street details of a chunk need to know about the roads round it (cached):
## nodes: {junction key: [[class rank, width], ...]} for every road piece end (stop lines);
## crossings: [{at, dir, w}] zebra crossings on this chunk's roads, one at the road point nearest each
## school, shop, clinic, crèche and the civic centre; oneways: [{line, w, n}] one-way main
## carriageways around (medians); lamps: the street lights around (other details keep clear of them).
func street_context(key: Vector2i) -> Dictionary:
	if _street_ctx.has(key):
		return _street_ctx[key]
	var nodes := {}
	var oneways: Array = []
	var lamps := PackedVector3Array()
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var roads: Array = load_chunk(key + Vector2i(dx, dz)).get("roads", [])
			lamps.append_array(RealChunkBuilder.lamp_points(roads))
			for r: Dictionary in roads:
				var line := RealChunkBuilder._line(r.p)
				if line.size() < 2:
					continue
				var entry := [RealStreetDecor.rank(str(r.c)), float(r.w)]
				for end in [line[0], line[line.size() - 1]]:
					var nk := RealStreetDecor.node_key(end)
					if not nodes.has(nk):
						nodes[nk] = []
					nodes[nk].append(entry)
				if str(r.c) == "main" and int(r.get("o", 0)) != 0:
					oneways.append({"line": line, "w": float(r.w), "n": str(r.get("n", ""))})
	var crossings: Array = []
	for l: Dictionary in landmarks:
		if not str(l.kind) in RealStreetDecor.CROSSING_KINDS:
			continue
		var at: Vector2 = l.at
		if chunk_at(Vector3(at.x, 0, at.y)).distance_squared_to(key) > 2:
			continue
		var best := {}
		var best_d := RealStreetDecor.CROSSING_REACH
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var k2 := chunk_at(Vector3(at.x, 0, at.y)) + Vector2i(dx, dz)
				for r: Dictionary in load_chunk(k2).get("roads", []):
					if not str(r.c) in ["street", "collector", "main"]:
						continue
					var line := RealChunkBuilder._line(r.p)
					for i in line.size() - 1:
						var q := Geometry2D.get_closest_point_to_segment(at, line[i], line[i + 1])
						if q.distance_to(at) < best_d and q.distance_to(line[0]) > 12.0 and q.distance_to(line[line.size() - 1]) > 12.0:
							best_d = q.distance_to(at)
							best = {"at": q, "dir": (line[i + 1] - line[i]).normalized(), "w": float(r.w), "chunk": k2, "kind": str(l.kind)}
		if not best.is_empty() and best.chunk == key:
			crossings.append(best)
	_street_ctx[key] = {"nodes": nodes, "crossings": crossings, "oneways": oneways, "lamps": lamps}
	return _street_ctx[key]


## `what` ("outlines" or "road_lines") of the chunk and its eight neighbours.
func around(key: Vector2i, what: String) -> Array:
	var out: Array = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			out.append_array(call(what, key + Vector2i(dx, dz)))
	return out


## The front door of a real house: {mid: Vector2 (middle of the door wall), normal: Vector2 (towards
## the street)}, or {} if the id is unknown or the house is hemmed in on every side.
func house_front(house_id: String) -> Dictionary:
	var parts := house_id.split("_")
	if parts.size() != 4:
		return {}
	var key := Vector2i(int(parts[1]), int(parts[2]))
	var rings := outlines(key)
	var index := int(parts[3])
	if index < 0 or index >= rings.size():
		return {}
	var all := around(key, "outlines")
	var near := RealChunkBuilder.rings_near(rings[index], all, all.map(func(r): return RealChunkBuilder.ring_box(r)))
	return RealChunkBuilder.home_front(rings[index], around(key, "road_lines"), near)


func is_inside(pos: Vector3) -> bool:
	return RealChunkBuilder.point_in_ring(Vector2(pos.x, pos.z), boundary)


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
