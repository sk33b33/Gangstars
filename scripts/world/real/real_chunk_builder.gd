class_name RealChunkBuilder
extends RefCounted
## Turns one chunk of real map data into 3D: roads that follow the real street lines (any angle,
## any bend), pavements, footpaths, parks and pitches, and a building on every real outline.
## Everything in a chunk is merged into a few meshes and one collision body.
## Design: design/gdd/real_world.md.

const Y_AREA := 0.01
const Y_PATH := 0.016
const Y_PAVE := 0.02
const Y_ROAD := 0.03
const Y_PAINT := 0.04
const WALL_PAINTS := ["#e8967a", "#a6d455", "#8fb8d8", "#f2e4b8", "#c3b0d8", "#ece9e2", "#f1d36b", "#9fd8b8", "#d9b38c", "#e6c7b0"]
const AREA_COLORS := {"park": "#7fae55", "pitch": "#5c9a45", "playground": "#9bbf6a", "school": "#cdbfa5", "parking": "#77777d",
	"dunes": "#cdb980", "retail": "#b7b2bd", "pool": "#5aa0d0", "sports": "#86b06a"}
const PUBLIC_WALL := "#d9d4c8"


## Builds the chunk's node. `stats` (optional) receives counts for tests and the debug line.
## `near_roads`: street centre lines around the chunk (houses put their door on the wall nearest a
## street). `stats.houses` lists the homes: {id, door: Vector3 (1.2 m outside the door), area}.
## `story`: {house id: true} for homes that belong to the game's own families: they are built like
## any house but hang their own front door and are not offered to passers-by residents.
static func build(key: Vector2i, chunk: Dictionary, stats: Dictionary = {}, near_roads: Array = [], story: Dictionary = {}, near_outlines: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]
	var surfaces := {}      # material key -> SurfaceTool
	var materials := {}
	for a in chunk.get("areas", []):
		_area(a, surfaces, materials)
	for r in chunk.get("roads", []):
		_road(r, surfaces, materials, root)
	for at in lamp_points(chunk.get("roads", [])):
		var steel := _tool("steel", surfaces, materials, PixelMaterials.flat(Color("#7d828c")))
		var lamp := _tool("lamp", surfaces, materials, PixelMaterials.lamp())
		var pole := Vector3(at.x, 0.0, at.z)
		_box(steel, pole + Vector3(0, 2.5, 0), Vector3(0.14, 5.0, 0.14))
		_box(steel, pole + Vector3(0, 4.95, 0), Vector3(0.9, 0.1, 0.1))
		_box(lamp, at, Vector3(0.4, 0.12, 0.3))
	var collision := PackedVector3Array()
	var n := 0
	var houses: Array = []
	var rings: Array = near_outlines   # the chunk's own outlines and its neighbours': a doorstep must be clear of all of them
	if rings.is_empty():
		for b in chunk.get("buildings", []):
			rings.append(_line(b.p))
	var boxes: Array = rings.map(func(r): return ring_box(r))
	for b in chunk.get("buildings", []):
		var hid := "h_%d_%d_%d" % [key.x, key.y, n]
		var door: Variant = _building(b, surfaces, materials, collision, root, near_roads, rings_near(_line(b.p), rings, boxes), not story.has(hid))
		if door != null and not story.has(hid):
			houses.append({"id": hid, "door": door.at, "area": door.area})
		n += 1
	stats["houses"] = houses
	for k in surfaces:
		var st: SurfaceTool = surfaces[k]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh_" + str(k).validate_node_name()
		st.generate_normals()
		mesh_instance.mesh = st.commit()
		mesh_instance.material_override = materials[k]
		if not str(k).begins_with("wall") and not str(k).begins_with("roof") and str(k) != "steel":
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh_instance)
	if not collision.is_empty():
		var body := StaticBody3D.new()
		body.name = "Buildings"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
	stats["buildings"] = n
	stats["roads"] = chunk.get("roads", []).size()
	stats["surfaces"] = surfaces.size()
	return root


static func _tool(k: String, surfaces: Dictionary, materials: Dictionary, material: Material) -> SurfaceTool:
	if not surfaces.has(k):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[k] = st
		materials[k] = material
	return surfaces[k]


static func _line(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Adds the triangle wound so that its front face looks along `want` (Godot: clockwise = front).
static func _facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	if (c - a).cross(b - a).dot(want) >= 0.0:
		_tri(st, a, b, c)
	else:
		_tri(st, a, c, b)


static func _up(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	_facing(st, a, b, c, Vector3.UP)


const LAMP_SPACING := 32.0
const LAMP_HEIGHT := 4.85


## Where the street lights stand: every 32 m along each street, alternating sides, just behind
## the kerb. Worked out from the data alone, so the light pool knows them before a chunk is built.
static func lamp_points(roads: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for r in roads:
		if str(r.c) == "path" or str(r.c) == "lane":
			continue
		var line := _line(r.p)
		var offset := float(r.w) * 0.5 + 0.6
		var walked := 0.0
		var next := 8.0 + fmod(absf(line[0].x * 3.1 + line[0].y * 1.7), LAMP_SPACING)   # staggered, so pieces of one street don't bunch their lamps
		var side := 1.0 if int(absf(line[0].x + line[0].y)) % 2 == 0 else -1.0
		for i in line.size() - 1:
			var seg := line[i + 1] - line[i]
			var length := seg.length()
			if length < 0.01:
				continue
			var dir := seg / length
			while next <= walked + length:
				var p := line[i] + dir * (next - walked) + Vector2(-dir.y, dir.x) * offset * side
				out.append(Vector3(p.x, LAMP_HEIGHT, p.y))
				next += LAMP_SPACING
				side = -side
			walked += length
	return out


static func _box(st: SurfaceTool, centre: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	for axis in 3:
		for s in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = s
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var c := centre + n * h[axis]
			var a := c - u * h[(axis + 1) % 3] - v * h[(axis + 2) % 3]
			var b := c + u * h[(axis + 1) % 3] - v * h[(axis + 2) % 3]
			var d := c + u * h[(axis + 1) % 3] + v * h[(axis + 2) % 3]
			var e := c - u * h[(axis + 1) % 3] + v * h[(axis + 2) % 3]
			_facing(st, a, b, d, n)
			_facing(st, a, d, e, n)


## A flat ribbon of `width` along a polyline at height y: mitred at the bends, with a round cap on
## both ends so that streets meeting at any angle join without gaps.
static func ribbon(st: SurfaceTool, line: PackedVector2Array, width: float, y: float) -> void:
	var hw := width * 0.5
	var left: Array[Vector2] = []
	var right: Array[Vector2] = []
	for i in line.size():
		var dir_in := (line[i] - line[i - 1]).normalized() if i > 0 else (line[1] - line[0]).normalized()
		var dir_out := (line[i + 1] - line[i]).normalized() if i < line.size() - 1 else dir_in
		var tangent := (dir_in + dir_out).normalized()
		if tangent.is_zero_approx():
			tangent = dir_in
		var normal := Vector2(-tangent.y, tangent.x)
		var mitre := hw / maxf(0.35, normal.dot(Vector2(-dir_in.y, dir_in.x)))
		left.append(line[i] + normal * mitre)
		right.append(line[i] - normal * mitre)
	for i in line.size() - 1:
		var a := Vector3(left[i].x, y, left[i].y)
		var b := Vector3(right[i].x, y, right[i].y)
		var c := Vector3(right[i + 1].x, y, right[i + 1].y)
		var d := Vector3(left[i + 1].x, y, left[i + 1].y)
		_up(st, a, b, c)
		_up(st, a, c, d)
	for end: Vector2 in [line[0], line[line.size() - 1]]:
		var centre := Vector3(end.x, y, end.y)
		for s in 8:
			var a0 := TAU * s / 8.0
			var a1 := TAU * (s + 1) / 8.0
			_up(st, centre, centre + Vector3(cos(a0), 0, sin(a0)) * hw, centre + Vector3(cos(a1), 0, sin(a1)) * hw)


static func _road(r: Dictionary, surfaces: Dictionary, materials: Dictionary, root: Node3D) -> void:
	var line := _line(r.p)
	if line.size() < 2:
		return
	var width := float(r.w)
	var cls := str(r.c)
	if cls == "path":
		ribbon(_tool("path", surfaces, materials, PixelMaterials.surface("sidewalk", Vector2(2, 2), Color("#d6c7a8"))), line, width, Y_PATH)
		return
	var pave := float(r.get("s", 0.0))
	if pave > 0.0:
		ribbon(_tool("pave", surfaces, materials, PixelMaterials.surface("sidewalk", Vector2(2, 2))), line, width + pave * 2.0, Y_PAVE)
	ribbon(_tool("road", surfaces, materials, PixelMaterials.surface("road_asphalt", Vector2(2, 2))), line, width, Y_ROAD)
	if cls == "main" or cls == "collector":   # centre line dashes
		var paint := _tool("paint", surfaces, materials, PixelMaterials.flat(Color("#f1eee8")))
		for i in line.size() - 1:
			var seg := line[i + 1] - line[i]
			var length := seg.length()
			var dir := seg / maxf(length, 0.001)
			var t := 2.0
			while t + 2.0 < length:
				ribbon(paint, PackedVector2Array([line[i] + dir * t, line[i] + dir * (t + 2.0)]), 0.15, Y_PAINT)
				t += 7.0
	var road_name := str(r.get("n", ""))
	if not road_name.is_empty() and _length(line) > 35.0:
		var mid := line[line.size() / 2]
		var label := Label3D.new()
		label.text = road_name.to_upper()
		label.font_size = 40
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color.WHITE
		label.outline_modulate = Color("#1f5d3a")
		label.outline_size = 14
		label.position = Vector3(mid.x, 3.2, mid.y)
		label.visibility_range_end = 70.0
		label.set_meta("street", road_name)
		root.add_child(label)


static func _length(line: PackedVector2Array) -> float:
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	return total


static func _area(a: Dictionary, surfaces: Dictionary, materials: Dictionary) -> void:
	var ring := _line(a.p)
	var idx := Geometry2D.triangulate_polygon(ring)
	if idx.is_empty():
		return
	var kind := str(a.k)
	var st := _tool("area_" + kind, surfaces, materials, PixelMaterials.flat(Color(AREA_COLORS.get(kind, "#cdbfa5"))))
	for i in range(0, idx.size(), 3):
		_up(st, _v(ring[idx[i]], Y_AREA), _v(ring[idx[i + 1]], Y_AREA), _v(ring[idx[i + 2]], Y_AREA))


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## A building on its real outline: walls up to its height, and a roof (a low hip for house-sized
## convex outlines, flat otherwise). Paint and roof are picked from the outline's position, so a
## house always looks the same.
## Returns {at, area} for a home (its door anchor), or null for other buildings.
static func _building(b: Dictionary, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array, root: Node3D, near_roads: Array = [], rings: Array = [], own_door := true) -> Variant:
	var ring := _line(b.p)
	if ring.size() < 3:
		return null
	var h := float(b.get("h", 3.0))
	var centre := Vector2.ZERO
	for p in ring:
		centre += p
	centre /= ring.size()
	var seed_value := absi(int(centre.x * 13.0) * 7919 + int(centre.y * 17.0) * 104729)
	var public := b.has("k")
	var paint: String = PUBLIC_WALL if public else WALL_PAINTS[seed_value % WALL_PAINTS.size()]
	var walls := _tool("wall_" + paint, surfaces, materials, PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color(paint)))
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var a := _v(p0, 0.0)
		var c := _v(p1, 0.0)
		var a1 := _v(p0, h)
		var c1 := _v(p1, h)
		var out := Vector3(p0.x + p1.x, 0, p0.y + p1.y) * 0.5 - Vector3(centre.x, 0, centre.y)
		_facing(walls, a, a1, c1, out)
		_facing(walls, a, c1, c, out)
		collision.append_array([a, a1, c1, a, c1, c])
	var tiles := seed_value % 5 < 3
	var roof := _tool("roof_tiles" if tiles else "roof_ibr", surfaces, materials, PixelMaterials.surface("roof_tiles" if tiles else "roof_ibr", Vector2(2, 2)))
	var area := absf(_signed_area(ring))
	if not public and area < 420.0 and Geometry2D.is_polygon_clockwise(ring) == Geometry2D.is_polygon_clockwise(Geometry2D.convex_hull(ring)) and _is_convex(ring):
		var apex := _v(centre, h + clampf(sqrt(area) * 0.12, 0.8, 1.8))
		for i in ring.size():
			var e0 := ring[i] + (ring[i] - centre).normalized() * 0.35   # eaves overhang
			var e1 := ring[(i + 1) % ring.size()] + (ring[(i + 1) % ring.size()] - centre).normalized() * 0.35
			_up(roof, _v(e0, h), apex, _v(e1, h))
	else:
		var idx := Geometry2D.triangulate_polygon(ring)
		for i in range(0, idx.size(), 3):
			_up(roof, _v(ring[idx[i]], h + 0.05), _v(ring[idx[i + 1]], h + 0.05), _v(ring[idx[i + 2]], h + 0.05))
	var home: Variant = null
	if not public and area >= HOME_MIN_AREA and area <= HOME_MAX_AREA:
		home = _front(ring, centre, h, near_roads, surfaces, materials, rings, own_door)
		if home != null:
			home["area"] = area
	var building_name := str(b.get("n", ""))
	if not building_name.is_empty():
		var label := Label3D.new()
		label.text = building_name
		label.font_size = 48
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("#ffd75e")
		label.outline_modulate = Color("#1d1b24")
		label.outline_size = 12
		label.position = Vector3(centre.x, h + 2.0, centre.y)
		label.visibility_range_end = 160.0
		label.set_meta("landmark", building_name)
		root.add_child(label)
	return home


const HOME_MIN_AREA := 30.0
const HOME_MAX_AREA := 450.0
const DOOR_OUT := 1.2


## The house's front: a door in the middle of the wall nearest a street, windows beside it and on
## the other long walls. Returns {at: the point 1.2 m outside the door}, or null if no wall fits.
## Which wall is the front: the one (at least 2.2 m long) nearest a street whose doorstep is not
## inside another outline. Returns {index, mid: Vector2, normal: Vector2 (towards the street)} or {}.
static func home_front(ring: PackedVector2Array, near_roads: Array, rings: Array) -> Dictionary:
	var centre := Vector2.ZERO
	for p in ring:
		centre += p
	centre /= ring.size()
	var best := {}
	var best_d := INF
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		if p0.distance_to(p1) < 2.2:
			continue
		var mid := (p0 + p1) * 0.5
		var d := -mid.distance_to(centre) if near_roads.is_empty() else _distance_to_lines(mid, near_roads)
		if d >= best_d:
			continue
		var tangent := (p1 - p0).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		if normal.dot(mid - centre) < 0.0:
			normal = -normal
		var step := mid + normal * DOOR_OUT
		var hemmed := false
		for other: PackedVector2Array in rings:
			if other == ring:
				continue
			if Geometry2D.is_point_in_polygon(step, other) or _distance_to_ring(step, other) < DOOR_CLEAR:
				hemmed = true   # inside a neighbour, or in a gap too narrow to walk
				break
		if not hemmed:
			best_d = d
			best = {"index": i, "mid": mid, "normal": normal}
	return best


## The house's front: a door in the middle of the front wall (see home_front), windows beside it
## and on the other long walls. `own_door` false leaves the doorway bare (a story home hangs its
## own door there). Returns {at: the point 1.2 m outside the door}, or null if no wall fits.
static func _front(ring: PackedVector2Array, centre: Vector2, h: float, near_roads: Array, surfaces: Dictionary, materials: Dictionary, rings: Array = [], own_door := true) -> Variant:
	var front := home_front(ring, near_roads, rings)
	if front.is_empty():
		return null
	var best: int = front.index
	var door := _tool("panel_door", surfaces, materials, PixelMaterials.panel("door_gate"))
	var window := _tool("panel_window", surfaces, materials, PixelMaterials.panel("window_bars"))
	var anchor := Vector3.ZERO
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var length := p0.distance_to(p1)
		var mid := (p0 + p1) * 0.5
		var tangent := (p1 - p0) / maxf(length, 0.001)
		var normal := Vector2(-tangent.y, tangent.x)
		if normal.dot(mid - centre) < 0.0:
			normal = -normal
		var top := minf(2.15, h - 0.4)
		if i == best:
			if own_door:
				_panel(door, mid, tangent, normal, 1.0, 0.0, minf(2.0, h - 0.3))
			anchor = Vector3(mid.x + normal.x * DOOR_OUT, 0.0, mid.y + normal.y * DOOR_OUT)
			if length > 5.0:
				for side in [-1.0, 1.0]:
					_panel(window, mid + tangent * side * minf(length * 0.3, 3.0), tangent, normal, 1.4, 1.0, top)
		elif length > 3.2:
			_panel(window, mid, tangent, normal, 1.4, 1.0, top)
	return {"at": anchor}


const DOOR_CLEAR := 0.9


static func _distance_to_ring(p: Vector2, ring: PackedVector2Array) -> float:
	var best := INF
	for i in ring.size():
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, ring[i], ring[(i + 1) % ring.size()])))
	return best


static func ring_box(ring: PackedVector2Array) -> Rect2:
	var box := Rect2(ring[0], Vector2.ZERO)
	for p in ring:
		box = box.expand(p)
	return box


## The outlines close enough to `ring` to matter for its doorstep (`boxes[i]` is `rings[i]`'s box).
static func rings_near(ring: PackedVector2Array, rings: Array, boxes: Array) -> Array:
	var reach := ring_box(ring).grow(DOOR_OUT + DOOR_CLEAR + 0.5)
	var out: Array = []
	for i in rings.size():
		if (boxes[i] as Rect2).intersects(reach):
			out.append(rings[i])
	return out


static func _distance_to_lines(p: Vector2, lines: Array) -> float:
	var best := INF
	for line: PackedVector2Array in lines:
		for i in line.size() - 1:
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return best


## A textured rectangle on a wall: centred on `mid`, `width` along the wall, from y0 to y1, just proud of it.
static func _panel(st: SurfaceTool, mid: Vector2, tangent: Vector2, normal: Vector2, width: float, y0: float, y1: float) -> void:
	var out := Vector3(normal.x, 0, normal.y)
	var a2 := mid - tangent * width * 0.5 + normal * 0.04
	var b2 := mid + tangent * width * 0.5 + normal * 0.04
	var corners := [Vector3(a2.x, y0, a2.y), Vector3(b2.x, y0, b2.y), Vector3(b2.x, y1, b2.y), Vector3(a2.x, y1, a2.y)]
	# Seen from outside, the wall runs right to left when the tangent is the outward normal turned left.
	var flip := tangent.x * normal.y - tangent.y * normal.x > 0.0
	var uvs := [Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)] if flip else [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var order: Array = tri
		if (corners[order[2]] - corners[order[0]]).cross(corners[order[1]] - corners[order[0]]).dot(out) < 0.0:
			order = [tri[0], tri[2], tri[1]]
		for k in order:
			st.set_uv(uvs[k])
			st.add_vertex(corners[k])


static func _signed_area(ring: PackedVector2Array) -> float:
	var total := 0.0
	for i in ring.size():
		var p := ring[i]
		var q := ring[(i + 1) % ring.size()]
		total += p.x * q.y - q.x * p.y
	return total * 0.5


static func _is_convex(ring: PackedVector2Array) -> bool:
	var sign_seen := 0.0
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var c := ring[(i + 2) % ring.size()]
		var cross := (b - a).cross(c - b)
		if absf(cross) < 0.01:
			continue
		if sign_seen == 0.0:
			sign_seen = signf(cross)
		elif signf(cross) != sign_seen:
			return false
	return true
