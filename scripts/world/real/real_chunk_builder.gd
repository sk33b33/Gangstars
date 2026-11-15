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
static func build(key: Vector2i, chunk: Dictionary, stats: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]
	var surfaces := {}      # material key -> SurfaceTool
	var materials := {}
	for a in chunk.get("areas", []):
		_area(a, surfaces, materials)
	for r in chunk.get("roads", []):
		_road(r, surfaces, materials, root)
	var collision := PackedVector3Array()
	var n := 0
	for b in chunk.get("buildings", []):
		_building(b, surfaces, materials, collision, root)
		n += 1
	for k in surfaces:
		var st: SurfaceTool = surfaces[k]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh_" + str(k).validate_node_name()
		st.generate_normals()
		mesh_instance.mesh = st.commit()
		mesh_instance.material_override = materials[k]
		if not str(k).begins_with("wall") and not str(k).begins_with("roof"):
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
static func _building(b: Dictionary, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array, root: Node3D) -> void:
	var ring := _line(b.p)
	if ring.size() < 3:
		return
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
