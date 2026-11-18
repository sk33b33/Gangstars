class_name RealChunkBuilder
extends RefCounted
## Turns one chunk of real map data into 3D: roads that follow the real street lines (any angle,
## any bend), pavements, footpaths, parks and pitches, and a building on every real outline.
## Everything in a chunk is merged into a few meshes and one collision body.
## Design: design/gdd/real_world.md.

const Y_AREA := 0.01
const Y_PATH := 0.016
const Y_PAVE := 0.02
const Y_FOOT := 0.0215
const Y_KERB := 0.023
const Y_GUTTER := 0.027
const Y_ROAD := 0.03
const Y_PAINT := 0.04
const WALL_PAINTS := ["#e8967a", "#a6d455", "#8fb8d8", "#f2e4b8", "#c3b0d8", "#ece9e2", "#f1d36b", "#9fd8b8", "#d9b38c", "#e6c7b0"]
const AREA_COLORS := {"park": "#7fae55", "pitch": "#5c9a45", "playground": "#9bbf6a", "school": "#b8a888", "parking": "#77777d",
	"dunes": "#cdb980", "retail": "#77777d", "pool": "#5aa0d0", "sports": "#86b06a"}
const PUBLIC_WALL := "#d9d4c8"
## Roads: the kerb is a concrete strip just outside the carriageway, the gutter a darker concrete
## channel just inside it. They are drawn as wider ribbons under the asphalt, so where a side street
## opens into another its asphalt covers the other's kerb and gutter: junctions close by themselves.
const KERB_WIDTH := 0.25
const GUTTER_WIDTH := 0.35
const KERB_COLOR := "#bdb8ad"
const GUTTER_COLOR := "#8f8b83"
const PAVE_TINT := "#e2dccd"
## Pavements as in Mitchells Plain: residential streets have a sandy, trodden verge from the kerb to
## the boundary walls; main roads and collectors also have a paved footway of FOOTWAY width beside the kerb.
const FOOTWAY := 1.5
const EDGE_LINE_COLOR := "#e3bd3a"
## Main roads: yellow edge lines this far in from the edge, stopped short of the junctions.
const EDGE_LINE_IN := 0.45
const EDGE_LINE_TRIM := 6.0
## Walls: a darker painted band at the foot (the Cape Flats "plinth" that hides splash-back dirt),
## a fascia board and soffit under hip-roof eaves, a parapet with a concrete cap on flat roofs.
const PLINTH_PAINTS := ["#5b5f66", "#7a3d33", "#3f5a48", "#8a7f70", "#6e5a4a"]
const PLINTH_HEIGHT := 0.5
const FASCIA_PAINTS := ["#ece9e2", "#4a3a30", "#2f3b4a"]
const FASCIA_DEPTH := 0.2
const EAVES := 0.35
const PARAPET := 0.35
const COPING_COLOR := "#cfcac0"
const SILL_DEPTH := 0.12
## Where the house being built puts its roof fittings (set by `build`: the chunk's prop dictionary).
static var _roof_props: Dictionary = {}
const BRICK_TINTS := ["#c7775b", "#b9694f", "#a35d49", "#d39a7a", "#9c5a44"]
const ROOF_TILE_TINTS := ["#ffffff", "#d8d2cc", "#f0d6c4", "#bfb6b0"]
const ROOF_IBR_TINTS := ["#ffffff", "#e9a99c", "#a9c3b3", "#c8ccd2"]
## A house gets a pitched roof over its best-fitting rectangle when its outline fills at least this
## much of that rectangle; other outlines (L-shapes, odd traces) get a flat roof behind a parapet.
const ROOF_FILL := 0.75
## Semi-detached pairs: a pitched-roof house this big and at least SEMI_ASPECT times as long as wide;
## two in three are painted as two halves. The split is SEMI_DOOR_GAP past the real front door.
const SEMI_AREA := Vector2(110.0, 320.0)
const SEMI_ASPECT := 1.8
const SEMI_DOOR_GAP := 0.9
## Graffiti: one precast wall piece in TAG_ONE_IN carries a (made-up) crew tag on its street side.
const TAGS := ["tag_tortel", "tag_duin", "tag_klip", "tag_vlakte"]
const TAG_ONE_IN := 6


## Builds the chunk's node. `stats` (optional) receives counts for tests and the debug line.
## `near_roads`: street centre lines around the chunk (houses put their door on the wall nearest a
## street). `stats.houses` lists the homes: {id, door: Vector3 (1.2 m outside the door), area}.
## `story`: {house id: true} for homes that belong to the game's own families: they are built like
## any house but hang their own front door and are not offered to passers-by residents.
## `yards`: {building index: RealYards.plan} (from RealDistrictData.yards); none when empty.
## `fronts`: {building index: home_front} already worked out (RealDistrictData.home_fronts); found here when empty.
## `ctx`: more from RealDistrictData: "street" (street_context) for the street details; none when empty.
static func build(key: Vector2i, chunk: Dictionary, stats: Dictionary = {}, near_roads: Array = [], story: Dictionary = {}, near_outlines: Array = [], yards: Dictionary = {}, fronts: Dictionary = {}, ctx: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]
	var surfaces := {}      # material key -> SurfaceTool
	var materials := {}
	for a in chunk.get("areas", []):
		_area(a, surfaces, materials)
	for r in chunk.get("roads", []):
		_road(r, surfaces, materials, root)
	var props := {}   # prop name -> Array[Transform3D], built as one MultiMesh each
	_roof_props = props   # houses put their roof fittings (solar geysers, dishes) here
	var humps: Array = []
	if ctx.has("street"):
		RealStreetDecor.build(chunk.get("roads", []), ctx.street, surfaces, materials, props, humps, root)
	stats["humps"] = humps
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
		var known: Variant = fronts.get(n, {}) if not fronts.is_empty() else null
		var door: Variant = _building(b, surfaces, materials, collision, root, near_roads, [] if known != null else rings_near(_line(b.p), rings, boxes), not story.has(hid), known)
		if door != null and not story.has(hid):
			houses.append({"id": hid, "door": door.at, "area": door.area})
		if yards.has(n):
			_yard(yards[n], seed_of(_line(b.p)), surfaces, materials, collision)
		var decor: Dictionary = ctx.get("decor", {})
		if decor.has(n) and fronts.has(n):
			RealHomeDecor.draw(decor[n], yards.get(n, {}), fronts[n], _line(b.p), float(b.get("h", 3.0)), seed_of(_line(b.p)), root, surfaces, materials, props, collision, int(story[hid]) if story.get(hid) is int else 0)
		n += 1
	stats["houses"] = houses
	stats["yards"] = yards.size()
	if ctx.has("strips"):
		RealParkDecor.draw_areas(chunk.get("areas", []), ctx.strips, rings, surfaces, materials, props)
	RealParkDecor.draw_school_fence(ctx.get("schools", []), surfaces, materials, collision)
	RealParkDecor.draw_stalls(ctx.get("stalls", []), root, surfaces, materials, props, collision)
	for k in surfaces:
		var st: SurfaceTool = surfaces[k]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh_" + str(k).validate_node_name()
		st.generate_normals()
		mesh_instance.mesh = st.commit()
		mesh_instance.material_override = materials[k]
		if not str(k).begins_with("wall") and not str(k).begins_with("roof") and not str(k).begins_with("fence") and str(k) != "steel" and str(k) != "pole_wood" and str(k) != "canopy":
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh_instance)
	for prop: String in props:
		var m := PropLibrary.mesh(prop)
		if m == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		var list: Array = props[prop]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Props_" + prop
		mmi.multimesh = mm
		root.add_child(mmi)
	stats["props"] = props.keys().map(func(k): return [k, (props[k] as Array).size()])
	if not collision.is_empty():
		var body := StaticBody3D.new()
		body.name = "Buildings"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision)
		shape.backface_collision = true   # fences are single faces: solid from both sides
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


## The polyline moved sideways by `d` (positive: to the left of the direction of travel), mitred like `ribbon`.
static func offset_line(line: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in line.size():
		var dir_in := (line[i] - line[i - 1]).normalized() if i > 0 else (line[1] - line[0]).normalized()
		var dir_out := (line[i + 1] - line[i]).normalized() if i < line.size() - 1 else dir_in
		var tangent := (dir_in + dir_out).normalized()
		if tangent.is_zero_approx():
			tangent = dir_in
		var normal := Vector2(-tangent.y, tangent.x)
		out.append(line[i] + normal * d / maxf(0.35, normal.dot(Vector2(-dir_in.y, dir_in.x))))
	return out


## The part of a polyline between `from` and `to` metres along it.
static func sub_line(line: PackedVector2Array, from: float, to: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var walked := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var t0 := clampf((from - walked) / seg, 0.0, 1.0)
		var t1 := clampf((to - walked) / seg, 0.0, 1.0)
		if t1 > t0:
			var p0 := a.lerp(b, t0)
			if out.is_empty() or not out[out.size() - 1].is_equal_approx(p0):
				out.append(p0)
			out.append(a.lerp(b, t1))
		walked += seg
	return out


## A painted line: a ribbon without the round caps.
static func strip(st: SurfaceTool, line: PackedVector2Array, width: float, y: float) -> void:
	if line.size() < 2:
		return
	var l := offset_line(line, width * 0.5)
	var r := offset_line(line, -width * 0.5)
	for i in line.size() - 1:
		_up(st, _v(l[i], y), _v(r[i], y), _v(r[i + 1], y))
		_up(st, _v(l[i], y), _v(r[i + 1], y), _v(l[i + 1], y))


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
	var asphalt := PixelMaterials.surface("road_asphalt", Vector2(4, 4))
	if pave > 0.0:
		ribbon(_tool("verge", surfaces, materials, PixelMaterials.surface("verge", Vector2(2, 2))), line, width + pave * 2.0, Y_PAVE)
		if cls == "main" or cls == "collector":
			ribbon(_tool("pave", surfaces, materials, PixelMaterials.surface("sidewalk", Vector2(2, 2), Color(PAVE_TINT))), line, width + minf(pave, FOOTWAY) * 2.0, Y_FOOT)
		ribbon(_tool("kerb", surfaces, materials, PixelMaterials.flat(Color(KERB_COLOR))), line, width + KERB_WIDTH * 2.0, Y_KERB)
		ribbon(_tool("gutter", surfaces, materials, PixelMaterials.flat(Color(GUTTER_COLOR))), line, width, Y_GUTTER)
		ribbon(_tool("road", surfaces, materials, asphalt), line, maxf(1.0, width - GUTTER_WIDTH * 2.0), Y_ROAD)
	else:
		ribbon(_tool("road", surfaces, materials, asphalt), line, width, Y_ROAD)
	if cls == "main" and _length(line) > EDGE_LINE_TRIM * 2.0 + 4.0:
		var yellow := _tool("edge_line", surfaces, materials, PixelMaterials.flat(Color(EDGE_LINE_COLOR)))
		var inner := sub_line(line, EDGE_LINE_TRIM, _length(line) - EDGE_LINE_TRIM)
		for side: float in [-1.0, 1.0]:
			strip(yellow, offset_line(inner, side * (width * 0.5 - EDGE_LINE_IN)), 0.12, Y_PAINT)
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
	# The street's name floating over the road (also what the HUD and "which street am I on" read), besides the concrete name blocks.
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
	var st: SurfaceTool
	if kind == "parking" or kind == "retail":   # car parks and the shopping centre's grounds are tarmac
		st = _tool("area_tarmac", surfaces, materials, PixelMaterials.surface("road_asphalt", Vector2(4, 4), Color("#d8d6d2")))
	elif kind == "school":   # school grounds are bare, trodden sand
		st = _tool("verge", surfaces, materials, PixelMaterials.surface("verge", Vector2(2, 2)))
	else:
		st = _tool("area_" + kind, surfaces, materials, PixelMaterials.flat(Color(AREA_COLORS.get(kind, "#cdbfa5"))))
	for i in range(0, idx.size(), 3):
		_up(st, _v(ring[idx[i]], Y_AREA), _v(ring[idx[i + 1]], Y_AREA), _v(ring[idx[i + 2]], Y_AREA))


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## A building on its real outline: walls up to its height, and a roof (a low hip for house-sized
## convex outlines, flat otherwise). Paint and roof are picked from the outline's position, so a
## house always looks the same.
## Returns {at, area} for a home (its door anchor), or null for other buildings.
static func _building(b: Dictionary, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array, root: Node3D, near_roads: Array = [], rings: Array = [], own_door := true, known_front: Variant = null) -> Variant:
	var ring := _line(b.p)
	if ring.size() < 3:
		return null
	var h := float(b.get("h", 3.0))
	var centre := Vector2.ZERO
	for p in ring:
		centre += p
	centre /= ring.size()
	var seed_value := seed_of(ring)
	var public := b.has("k")
	var area := absf(_signed_area(ring))
	var rect := min_rect(ring)
	if public:
		RealLandmarks.build(b, ring, centre, area, rect, seed_value, near_roads, surfaces, materials, collision)
	else:
		_house(ring, centre, h, area, rect, seed_value, surfaces, materials, collision, known_front if known_front is Dictionary else {})
	var home: Variant = null
	if not public and area >= HOME_MIN_AREA and area <= HOME_MAX_AREA:
		home = _front(ring, centre, h, near_roads, surfaces, materials, rings, own_door, known_front)
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


## An ordinary house: painted walls with a plinth band; a pitched roof (hip or gable) when the outline is
## close to a rectangle, otherwise a flat roof behind a parapet.
static func _house(ring: PackedVector2Array, centre: Vector2, h: float, area: float, rect: Dictionary, seed_value: int, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array, front: Dictionary = {}) -> void:
	var paint: String = WALL_PAINTS[seed_value % WALL_PAINTS.size()]
	var finish := (seed_value / 3) % 6   # plaster 0 to 3, rough-cast 4, face brick 5
	var walls: SurfaceTool
	if finish == 5:
		var brick: String = BRICK_TINTS[(seed_value / 7) % BRICK_TINTS.size()]
		walls = _tool("wall_brick_" + brick, surfaces, materials, PixelMaterials.surface("wall_brick", Vector2(1.0, 1.0), Color(brick)))
	elif finish == 4:
		walls = _tool("wall_rough_" + paint, surfaces, materials, PixelMaterials.surface("wall_rough", Vector2(2, 2), Color(paint)))
	else:
		walls = _tool("wall_" + paint, surfaces, materials, PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color(paint)))
	var plinth_paint: String = PLINTH_PAINTS[(seed_value / 7) % PLINTH_PAINTS.size()]
	var plinth := _tool("plinth_" + plinth_paint, surfaces, materials, PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color(plinth_paint)))
	var hip := area < 420.0 and area / maxf(float(rect.area), 0.01) >= ROOF_FILL
	var half: Vector2 = rect.half
	var semi := hip and not front.is_empty() and area >= SEMI_AREA.x and area <= SEMI_AREA.y and half.x >= half.y * SEMI_ASPECT and seed_value % 3 != 0
	var gable := seed_value % 2 == 0
	var tiles := seed_value % 5 < 3
	var roof_tint: String = (ROOF_TILE_TINTS if tiles else ROOF_IBR_TINTS)[(seed_value / 13) % 4]
	var roof := _tool(("roof_tiles_" if tiles else "roof_ibr_") + roof_tint, surfaces, materials, PixelMaterials.surface("roof_tiles" if tiles else "roof_ibr", Vector2(2, 2), Color(roof_tint)))
	if semi:
		_semi(ring, centre, h, rect, seed_value, walls, plinth, roof, gable, front, surfaces, materials, collision)
		_house_details(ring, rect, h, true, gable, front, seed_value, surfaces, materials)   # a semi has a pitched roof too
		return
	wall_ring(ring, centre, h, walls, plinth, collision, 0.0 if hip else PARAPET)
	if hip:
		var fascia_paint: String = FASCIA_PAINTS[(seed_value / 11) % FASCIA_PAINTS.size()]
		var fascia := _tool("fascia_" + fascia_paint, surfaces, materials, PixelMaterials.flat(Color(fascia_paint)))
		_pitched_roof(roof, fascia, walls, rect, h, gable)
	else:
		flat_roof(ring, h, PARAPET, roof, _tool("coping", surfaces, materials, PixelMaterials.flat(Color(COPING_COLOR))))
	_house_details(ring, rect, h, hip, gable, front, seed_value, surfaces, materials)


## Where the rain gutters run on a pitched roof, as {at, dir, half} (centre, direction, half length). A hip roof (sloping ends,
## a pyramid hip included) is guttered all round, the long sides first and the ends closing the corners. A gable roof drains only
## to its two long sides (`rect.half.x` is the long side), so its gable ends have none.
static func gutter_runs(rect: Dictionary, gable: bool) -> Array:
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var l := half.x + EAVES
	var w := half.y + EAVES
	var runs: Array = []
	for sv: float in [-1.0, 1.0]:
		runs.append({"at": c + v * sv * (w + 0.06), "dir": u, "half": l + 0.11 if not gable else l})
	if not gable:
		for su: float in [-1.0, 1.0]:
			runs.append({"at": c + u * su * (l + 0.06), "dir": v, "half": w})
	return runs


## What a house is fitted with besides its walls and roof: rain gutters under the eaves, one or two downpipes on the corners, a
## ridge cap and now and then a chimney on a pitched roof, and at the front door a concrete stoep step, an electricity meter box and
## sometimes a small awning. (Window surrounds and air bricks are made with the windows, `_window`.)
static func _house_details(ring: PackedVector2Array, rect: Dictionary, h: float, hip: bool, gable: bool, front: Dictionary, seed_value: int, surfaces: Dictionary, materials: Dictionary) -> void:
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var gutter := _tool("eave_gutter", surfaces, materials, PixelMaterials.flat(Color("#8c8f96")))
	var pitched := hip   # `hip` is true for any outline the pitched roof fits (hip or gable)
	if pitched:
		var l := half.x + EAVES
		var w := half.y + EAVES
		for run: Dictionary in gutter_runs(rect, gable):
			RealLandmarks._obox(gutter, run.at, run.dir, Vector2(run.half, 0.05), h - 0.2, h - 0.06)
		var rise := clampf(half.y * 0.45, 0.8, 1.8)
		var ridge := l if gable else maxf(0.0, l - w)
		RealLandmarks._obox(_tool("ridge_cap", surfaces, materials, PixelMaterials.flat(Color("#4a403a"))), c, u, Vector2(ridge + 0.1, 0.1), h + rise - 0.02, h + rise + 0.1)
		if seed_value % 5 == 0:   # a brick chimney stack through the ridge
			var at := c + u * ridge * 0.45
			RealLandmarks._obox(_tool("chimney", surfaces, materials, PixelMaterials.flat(Color("#a2634c"))), at, u, Vector2(0.28, 0.28), h + rise * 0.3, h + rise + 0.95)
			RealLandmarks._obox(_tool("chimney_cap", surfaces, materials, PixelMaterials.flat(Color(COPING_COLOR))), at, u, Vector2(0.35, 0.35), h + rise + 0.95, h + rise + 1.04)
	if pitched:
		_roof_fittings(rect, h, gable, seed_value)
	# Downpipes on one or two convex corners.
	var sign_area := signf(_signed_area(ring))
	var corners: Array = []
	for i in ring.size():
		var a := ring[(i + ring.size() - 1) % ring.size()]
		var b := ring[i]
		var d := ring[(i + 1) % ring.size()]
		if (b - a).cross(d - b) * sign_area > 0.5:
			corners.append([b, (edge_out(ring, a, b) + edge_out(ring, b, d)).normalized()])
	if not corners.is_empty():
		for k in 2:
			var pick: Array = corners[(seed_value / (3 + k * 4)) % corners.size()]
			RealLandmarks._obox(gutter, (pick[0] as Vector2) + (pick[1] as Vector2) * 0.06, Vector2.RIGHT, Vector2(0.035, 0.035), 0.0, h - 0.12)
			if corners.size() == 1:
				break
	if front.is_empty():
		return
	var mid: Vector2 = front.mid
	var n: Vector2 = front.normal
	var t := left_of_wall(n)
	var concrete := _tool("coping", surfaces, materials, PixelMaterials.flat(Color(COPING_COLOR)))
	RealLandmarks._obox(concrete, mid + n * 0.32, t, Vector2(0.85, 0.32), 0.0, 0.14)   # the stoep step
	RealLandmarks._obox(_tool("meter_box", surfaces, materials, PixelMaterials.flat(Color("#bfc3c8"))), mid + t * 1.2 + n * 0.09, t, Vector2(0.2, 0.09), 1.2, 1.75)
	if seed_value % 3 == 0 and h > 2.6:   # a small concrete awning over the door
		RealLandmarks._obox(concrete, mid + n * 0.5, t, Vector2(0.85, 0.5), 2.3, 2.38)


## A solar water heater lying on the roof slope that faces north (true north is -z, where the sun is), on about one pitched roof in
## three, and a satellite dish at the eave of another few. Placed as props (one MultiMesh each) tilted to the slope.
static func _roof_fittings(rect: Dictionary, h: float, gable: bool, seed_value: int) -> void:
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var w := half.y + EAVES
	var l := half.x + EAVES
	var rise := clampf(half.y * 0.45, 0.8, 1.8)
	var ridge := l if gable else maxf(0.0, l - w)
	var sv := -signf(v.y) if absf(v.y) > 0.05 else 1.0   # the side whose slope falls towards the north
	var outward := v * sv
	if seed_value % 3 == 1 and w > 2.2 and ridge > 1.0:
		var s := w * 0.55
		var uo := clampf(float((seed_value / 3) % 5 - 2) * 0.3 * ridge, -ridge + 1.0, ridge - 1.0)
		var at := c + outward * s + u * uo
		var y := (Vector3(outward.x * rise, w, outward.y * rise)).normalized()
		var down := Vector3(outward.x * w, -rise, outward.y * w).normalized()
		var x := y.cross(down)
		var origin := Vector3(at.x, h + rise * (1.0 - s / w), at.y) + y * 0.03
		if not _roof_props.has("solar_geyser"):
			_roof_props["solar_geyser"] = []
		_roof_props["solar_geyser"].append(Transform3D(Basis(x, y, down), origin))
	if seed_value % 4 == 3 and w > 1.6:
		var at := c + outward * (w - 0.2) + u * float((seed_value / 4) % 3 - 1) * half.x * 0.5
		var facing := Vector2(0.35, -1.0).normalized()   # towards the satellite (north-east)
		RealStreetDecor.add_prop(_roof_props, "satellite_dish", at, atan2(facing.x, facing.y), 1.0, h + rise * 0.1 + 0.45)


## The direction along a wall whose outward normal is `n` (either way: only the line matters).
static func left_of_wall(n: Vector2) -> Vector2:
	return Vector2(n.y, -n.x)


## A semi-detached pair: the house split across its length, each half painted by its own owner, a
## party wall standing up through the roof between them, and a second front door for the other half.
## The split sits just past the real front door, so that door belongs to the first half.
static func _semi(ring: PackedVector2Array, centre: Vector2, h: float, rect: Dictionary, seed_value: int, walls: SurfaceTool, plinth: SurfaceTool, roof: SurfaceTool, gable: bool, front: Dictionary, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array) -> void:
	var u: Vector2 = rect.u
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var door_u := ((front.mid as Vector2) - c).dot(u)
	var split := door_u + (SEMI_DOOR_GAP if door_u <= 0.0 else -SEMI_DOOR_GAP)
	var side_of_door := -1.0 if split > door_u else 1.0   # which side of the split the real door is on
	var other: String = WALL_PAINTS[(seed_value / 17 + 3) % WALL_PAINTS.size()]
	if other == WALL_PAINTS[seed_value % WALL_PAINTS.size()]:
		other = WALL_PAINTS[(seed_value / 17 + 4) % WALL_PAINTS.size()]
	var walls_b := _tool("wall_" + other, surfaces, materials, PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color(other)))
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var out := _v(edge_out(ring, p0, p1), 0.0)
		var s0 := (p0 - c).dot(u) - split
		var s1 := (p1 - c).dot(u) - split
		var pieces: Array = [[p0, p1, s0 + s1]]
		if s0 * s1 < 0.0:
			var cut := p0.lerp(p1, s0 / (s0 - s1))
			pieces = [[p0, cut, s0], [cut, p1, s1]]
		for piece: Array in pieces:
			var tool: SurfaceTool = walls if signf(float(piece[2])) == side_of_door else walls_b
			_quad(tool, _v(piece[0], 0.0), _v(piece[1], 0.0), h, out)
		collision.append_array([_v(p0, 0.0), _v(p0, h), _v(p1, h), _v(p0, 0.0), _v(p1, h), _v(p1, 0.0)])
		var push := _wall_normal(p0, p1, out) * 0.02
		_quad(plinth, _v(p0 + push, 0.0), _v(p1 + push, 0.0), PLINTH_HEIGHT, out)
	var fascia_paint: String = FASCIA_PAINTS[(seed_value / 11) % FASCIA_PAINTS.size()]
	var fascia := _tool("fascia_" + fascia_paint, surfaces, materials, PixelMaterials.flat(Color(fascia_paint)))
	_pitched_roof(roof, fascia, walls, rect, h, gable, -1.0, walls_b if side_of_door < 0.0 else walls, walls if side_of_door < 0.0 else walls_b)
	var rise := clampf(half.y * 0.45, 0.8, 1.8)
	var ridge := (half.x + EAVES) if gable else maxf(0.0, half.x - half.y)
	if absf(split) < ridge:
		var v: Vector2 = rect.v
		var at := c + u * split
		var pw := [at - v * (half.y + EAVES), at + v * (half.y + EAVES)]
		for s: float in [-1.0, 1.0]:
			var a := _v(pw[0] as Vector2 + u * 0.08 * s, h)
			var b := _v(pw[1] as Vector2 + u * 0.08 * s, h)
			_facing(walls, a, b, _v(at + u * 0.08 * s, h + rise + 0.2), Vector3(u.x * s, 0, u.y * s))
	# The other half's front door, in the middle of its part of the front wall.
	var i: int = front.index
	var f0 := ring[i]
	var f1 := ring[(i + 1) % ring.size()]
	var e0 := (f0 - c).dot(u) - split
	var e1 := (f1 - c).dot(u) - split
	var far := f0 if signf(e0) != side_of_door else f1
	var cut_t := e0 / (e0 - e1) if e0 * e1 < 0.0 else 0.5
	var cut := f0.lerp(f1, cut_t)
	var door_at := (cut + far) * 0.5
	if cut.distance_to(far) > 2.0:
		_panel(_tool("panel_door", surfaces, materials, PixelMaterials.panel("door_gate")), door_at, (f1 - f0).normalized(), front.normal, 1.0, 0.0, minf(2.0, h - 0.3))


## Walls on the outline up to h (+ `parapet` above the roof, with its inner face), a plinth band at
## the foot (when `plinth` is given) and the walls' collision up to h.
static func wall_ring(ring: PackedVector2Array, centre: Vector2, h: float, walls: SurfaceTool, plinth: SurfaceTool, collision: PackedVector3Array, parapet: float) -> void:
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var a := _v(p0, 0.0)
		var c := _v(p1, 0.0)
		var out := _v(edge_out(ring, p0, p1), 0.0)
		_quad(walls, a, c, h + parapet, out)
		collision.append_array([a, _v(p0, h), _v(p1, h), a, _v(p1, h), c])
		if plinth != null:
			var push := _wall_normal(p0, p1, out) * 0.02
			_quad(plinth, _v(p0 + push, 0.0), _v(p1 + push, 0.0), PLINTH_HEIGHT, out)
		if parapet > 0.0:
			_quad(walls, _v(p0, h + 0.05), _v(p1, h + 0.05), parapet - 0.05, -out)   # the parapet's inner face


## A flat roof on the outline at h, with a concrete cap along the top of its parapet.
static func flat_roof(ring: PackedVector2Array, h: float, parapet: float, roof: SurfaceTool, coping: SurfaceTool) -> void:
	var idx := Geometry2D.triangulate_polygon(ring)
	for i in range(0, idx.size(), 3):
		_up(roof, _v(ring[idx[i]], h + 0.05), _v(ring[idx[i + 1]], h + 0.05), _v(ring[idx[i + 2]], h + 0.05))
	var closed := ring.duplicate()
	closed.append(ring[0])
	strip(coping, closed, 0.3, h + parapet + 0.01)


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
		if normal.dot(edge_out(ring, p0, p1)) < 0.0:
			normal = -normal
		var step := mid + normal * DOOR_OUT
		var hemmed := false
		for other: PackedVector2Array in rings:
			if other == ring:
				continue
			if point_in_ring(step, other) or _distance_to_ring(step, other) < DOOR_CLEAR:
				hemmed = true   # inside a neighbour, or in a gap too narrow to walk
				break
		if not hemmed:
			best_d = d
			best = {"index": i, "mid": mid, "normal": normal}
	return best


## The house's front: a door in the middle of the front wall (see home_front), windows beside it
## and on the other long walls. `own_door` false leaves the doorway bare (a story home hangs its
## own door there). Returns {at: the point 1.2 m outside the door}, or null if no wall fits.
static func _front(ring: PackedVector2Array, centre: Vector2, h: float, near_roads: Array, surfaces: Dictionary, materials: Dictionary, rings: Array = [], own_door := true, known_front: Variant = null) -> Variant:
	var front: Dictionary = known_front if known_front != null else home_front(ring, near_roads, rings)
	if front.is_empty():
		return null
	var best: int = front.index
	var door := _tool("panel_door", surfaces, materials, PixelMaterials.panel("door_gate"))
	var window := _tool("panel_window", surfaces, materials, PixelMaterials.panel("window_bars"))
	var sill := _tool("coping", surfaces, materials, PixelMaterials.flat(Color(COPING_COLOR)))
	var dark := _tool("airbrick", surfaces, materials, PixelMaterials.flat(Color("#2a2a2e")))
	var lit := _tool("window_light", surfaces, materials, NightGlow.window_material())
	var anchor := Vector3.ZERO
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var length := p0.distance_to(p1)
		var mid := (p0 + p1) * 0.5
		var tangent := (p1 - p0) / maxf(length, 0.001)
		var normal := Vector2(-tangent.y, tangent.x)
		if normal.dot(edge_out(ring, p0, p1)) < 0.0:
			normal = -normal
		var top := minf(2.15, h - 0.4)
		if i == best:
			if own_door:
				_panel(door, mid, tangent, normal, 1.0, 0.0, minf(2.0, h - 0.3))
			anchor = Vector3(mid.x + normal.x * DOOR_OUT, 0.0, mid.y + normal.y * DOOR_OUT)
			if length > 5.0:
				var garage_side := 0.0
				if length >= 6.5 and _wall_hash(mid) % 100 < 38:
					garage_side = 1.0 if (_wall_hash(mid) / 100) % 2 == 0 else -1.0   # a roller door where one of the windows would be
				for side in [-1.0, 1.0]:
					var at: Vector2 = mid + tangent * side * minf(length * 0.3, 3.0)
					if side == garage_side:
						_roller_door(surfaces, materials, at, tangent, normal)
					else:
						_window(window, sill, at, tangent, normal, top, dark, lit)
		elif length >= 5.0 and _wall_hash(mid) % 100 < 22:
			_roller_door(surfaces, materials, mid, tangent, normal)   # a garage on a side wall
		elif length > 3.2:
			_window(window, sill, mid, tangent, normal, top, dark, lit)
	return {"at": anchor}


const LIT_WINDOW_PERCENT := 55   # share of windows with a light on at night
const DOOR_CLEAR := 0.9


## A number from where a wall is, to choose which walls get a roller door.
static func _wall_hash(mid: Vector2) -> int:
	return absi(roundi(mid.x * 13.0) * 7 + roundi(mid.y * 7.0) * 3)


## A garage roller door, 2.4 m wide and 2.1 m high: the white ribbed shutter in a concrete frame, a steel roller housing above it and a
## step-up sill.
static func _roller_door(surfaces: Dictionary, materials: Dictionary, mid: Vector2, tangent: Vector2, normal: Vector2) -> void:
	var shutter := _tool("panel_garage", surfaces, materials, PixelMaterials.panel("garage_door"))
	_panel(shutter, mid, tangent, normal, 2.4, 0.04, 2.1)
	var concrete := _tool("coping", surfaces, materials, PixelMaterials.flat(Color(COPING_COLOR)))
	for side: float in [-1.0, 1.0]:
		RealLandmarks._obox(concrete, mid + tangent * side * 1.28 + normal * 0.05, tangent, Vector2(0.07, 0.06), 0.0, 2.25)   # the jambs
	RealLandmarks._obox(_tool("roller_housing", surfaces, materials, PixelMaterials.flat(Color("#a9adb3"))), mid + normal * 0.09, tangent, Vector2(1.35, 0.09), 2.1, 2.3)
	RealLandmarks._obox(concrete, mid + normal * 0.16, tangent, Vector2(1.35, 0.16), 0.0, 0.05)   # the threshold


static func _distance_to_ring(p: Vector2, ring: PackedVector2Array) -> float:
	var best := INF
	for i in ring.size():
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, ring[i], ring[(i + 1) % ring.size()])))
	return best


## Point-in-outline, by ray casting. (Geometry2D.is_point_in_polygon now and then answers true for
## a point far outside the polygon, so it is not used for the map.)
static func point_in_ring(p: Vector2, ring: PackedVector2Array) -> bool:
	var hit := false
	var n := ring.size()
	for i in n:
		var a := ring[i]
		var b := ring[(i + 1) % n]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			hit = not hit
	return hit


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


## A barred window 1.4 m wide from 1.0 m up to `top`, with a concrete sill under it.
static func _window(window: SurfaceTool, sill: SurfaceTool, mid: Vector2, tangent: Vector2, normal: Vector2, top: float, dark: SurfaceTool = null, lit: SurfaceTool = null) -> void:
	_panel(window, mid, tangent, normal, 1.4, 1.0, top)
	if lit != null and _wall_hash(mid) % 100 < LIT_WINDOW_PERCENT:   # a warm pane over the glass, shown only at night (NightGlow)
		_panel(lit, mid + normal * 0.012, tangent, normal, 1.18, 1.1, top - 0.1)
	# A concrete surround: a lintel over the opening and a reveal down each side.
	RealLandmarks._obox(sill, mid + normal * 0.05, tangent, Vector2(0.82, 0.06), top, top + 0.13)
	for side: float in [-1.0, 1.0]:
		RealLandmarks._obox(sill, mid + tangent * side * 0.75 + normal * 0.05, tangent, Vector2(0.06, 0.06), 1.0, top)
	if dark != null and (roundi(mid.x * 7.0) + roundi(mid.y * 3.0)) % 2 == 0:   # an air brick under the sill
		RealLandmarks._obox(dark, mid + normal * 0.03, tangent, Vector2(0.14, 0.03), 0.3, 0.42)
	var a := mid - tangent * 0.8
	var b := mid + tangent * 0.8
	var a_out := a + normal * SILL_DEPTH
	var b_out := b + normal * SILL_DEPTH
	_up(sill, _v(a, 1.0), _v(a_out, 1.0), _v(b_out, 1.0))
	_up(sill, _v(a, 1.0), _v(b_out, 1.0), _v(b, 1.0))
	_quad(sill, _v(a_out, 0.92), _v(b_out, 0.92), 0.08, Vector3(normal.x, 0, normal.y))


## A textured rectangle on a wall: centred on `mid`, `width` along the wall, from y0 to y1, just proud of it.
static func _panel(st: SurfaceTool, mid: Vector2, tangent: Vector2, normal: Vector2, width: float, y0: float, y1: float) -> void:
	var out := Vector3(normal.x, 0, normal.y)
	var a2 := mid - tangent * width * 0.5 + normal * 0.04
	var b2 := mid + tangent * width * 0.5 + normal * 0.04
	var corners := [Vector3(a2.x, y0, a2.y), Vector3(b2.x, y0, b2.y), Vector3(b2.x, y1, b2.y), Vector3(a2.x, y1, a2.y)]
	# For a viewer outside the wall, "right" is left_of(normal). When the tangent points to that side the picture runs along it, otherwise
	# against it. (This rule was the wrong way round: every tag, board and sign on a wall came out mirrored.)
	var flip := tangent.x * normal.y - tangent.y * normal.x < 0.0
	var uvs := [Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)] if flip else [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var order: Array = tri
		if (corners[order[2]] - corners[order[0]]).cross(corners[order[1]] - corners[order[0]]).dot(out) < 0.0:
			order = [tri[0], tri[2], tri[1]]
		for k in order:
			st.set_uv(uvs[k])
			st.add_vertex(corners[k])


## The smallest rectangle around the outline: {c: centre, u: long axis, v: short axis,
## half: Vector2(half length, half width), area}. Found by trying each edge of the convex hull.
static func min_rect(ring: PackedVector2Array) -> Dictionary:
	var hull := Geometry2D.convex_hull(ring)
	var best := {"c": Vector2.ZERO, "u": Vector2.RIGHT, "v": Vector2.DOWN, "half": Vector2.ZERO, "area": INF}
	for i in hull.size() - 1:
		var u := (hull[i + 1] - hull[i]).normalized()
		if u.is_zero_approx():
			continue
		var v := Vector2(-u.y, u.x)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in hull:
			var q := Vector2(p.dot(u), p.dot(v))
			lo = lo.min(q)
			hi = hi.max(q)
		var size := hi - lo
		if size.x * size.y < float(best.area):
			var mid := (lo + hi) * 0.5
			best = {"c": u * mid.x + v * mid.y, "u": u, "v": v, "half": size * 0.5, "area": size.x * size.y}
			if size.x < size.y:
				best.u = v
				best.v = -u
				best.half = Vector2(size.y, size.x) * 0.5
	return best


## Which edges of the eave rectangle get a fascia board (0 and 2 are the long sides, 1 and 3 the ends). A hip roof has an eave all
## round; a gable roof has none on its gable ends, where the wall goes straight up into the triangle.
static func fascia_edges(gable: bool) -> Array:
	return [0, 2] if gable else [0, 1, 2, 3]


## A pitched roof over the rectangle with eaves all round: a hip roof (sloping ends) or a gable roof
## (painted triangular end walls). Fascia boards along the eaves, a soffit underneath.
static func _pitched_roof(roof: SurfaceTool, fascia: SurfaceTool, walls: SurfaceTool, rect: Dictionary, h: float, gable: bool, rise_override := -1.0, end_low: SurfaceTool = null, end_high: SurfaceTool = null) -> void:
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var l := half.x + EAVES
	var w := half.y + EAVES
	var rise := clampf(half.y * 0.45, 0.8, 1.8) if rise_override < 0.0 else rise_override
	var ridge := l if gable else maxf(0.0, l - w)
	var corner := func(su: float, sv: float) -> Vector3: return _v(c + u * su * l + v * sv * w, h)
	var top := func(su: float) -> Vector3: return _v(c + u * su * ridge, h + rise)
	for sv: float in [-1.0, 1.0]:
		var want := Vector3(v.x * sv, 1.0, v.y * sv)
		_facing(roof, corner.call(-1.0, sv), corner.call(1.0, sv), top.call(1.0), want)
		_facing(roof, corner.call(-1.0, sv), top.call(1.0), top.call(-1.0), want)
	for su: float in [-1.0, 1.0]:
		var out := Vector3(u.x * su, 0.0, u.y * su)
		if gable:
			var end_walls: SurfaceTool = walls
			if su < 0.0 and end_low != null:
				end_walls = end_low
			elif su > 0.0 and end_high != null:
				end_walls = end_high
			var e := c + u * su * half.x   # the gable end: walls up to the roof's underside
			var shoulder := h + rise * EAVES / w
			var a0 := _v(e - v * half.y, h)
			var b0 := _v(e + v * half.y, h)
			var a1 := _v(e - v * half.y, shoulder)
			var b1 := _v(e + v * half.y, shoulder)
			_facing(end_walls, a0, b0, b1, out)
			_facing(end_walls, a0, b1, a1, out)
			_facing(end_walls, a1, b1, _v(e, h + rise), out)
		else:
			_facing(roof, corner.call(su, -1.0), corner.call(su, 1.0), top.call(su), out + Vector3.UP)
	var low := h - FASCIA_DEPTH
	var pts := [corner.call(-1.0, -1.0), corner.call(1.0, -1.0), corner.call(1.0, 1.0), corner.call(-1.0, 1.0)]
	for i: int in fascia_edges(gable):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 4]
		var mid := (a + b) * 0.5 - _v(c, h)
		_quad(fascia, a - Vector3(0, FASCIA_DEPTH, 0), b - Vector3(0, FASCIA_DEPTH, 0), FASCIA_DEPTH, mid)
	var down := Vector3(0, -FASCIA_DEPTH, 0)
	_facing(fascia, pts[0] + down, pts[1] + down, pts[2] + down, Vector3.DOWN)   # soffit
	_facing(fascia, pts[0] + down, pts[2] + down, pts[3] + down, Vector3.DOWN)


## The number that picks a building's paint, roof and fence: from its outline's centre, so it never changes.
static func seed_of(ring: PackedVector2Array) -> int:
	var centre := Vector2.ZERO
	for p in ring:
		centre += p
	centre /= ring.size()
	return absi(int(centre.x * 13.0) * 7919 + int(centre.y * 17.0) * 104729)


## True for an outline the builder treats as a home (not public, house-sized).
static func is_home(b: Dictionary, ring: PackedVector2Array) -> bool:
	if b.has("k") or ring.size() < 3:
		return false
	var area := absf(_signed_area(ring))
	return area >= HOME_MIN_AREA and area <= HOME_MAX_AREA


## A yard (RealYards.plan): fence pieces with posts at their ends and at the gate.
## Precast concrete panels and steel palisade are textured panels; low walls are plastered in the house's paint.
static func _yard(plan: Dictionary, seed_value: int, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array) -> void:
	var kind := str(plan.kind)
	var height := float(plan.height)
	var paint: String = WALL_PAINTS[seed_value % WALL_PAINTS.size()]
	var plaster := _tool("wall_" + paint, surfaces, materials, PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color(paint)))
	var coping := _tool("coping", surfaces, materials, PixelMaterials.flat(Color(COPING_COLOR)))
	var post_tool := coping if kind == "precast" else plaster
	for seg: Array in plan.segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		match kind:
			"precast":
				_fence_panel(_tool("fence_precast", surfaces, materials, PixelMaterials.panel("fence_precast", Color.WHITE, true)), a, b, 0.0, height, 2.0)
				if plan.has("n") and a.distance_to(b) >= 3.0 and (seed_value / 19 + int(a.x)) % TAG_ONE_IN == 0:
					var tag: String = TAGS[absi(int(a.x * 7.0 + a.y)) % TAGS.size()]
					var n: Vector2 = plan.n
					_panel(_tool("panel_" + tag, surfaces, materials, PixelMaterials.panel(tag, Color.WHITE, true)), (a + b) * 0.5 + n * 0.03, (b - a).normalized(), n, 2.2, 0.35, 1.25)
			"palisade":
				_fence_panel(_tool("fence_palisade", surfaces, materials, PixelMaterials.panel("fence_palisade", Color.WHITE, true)), a, b, 0.0, height, 2.0)
			"low_wall":
				_low_wall(plaster, coping, a, b, height)
			"wall_palisade":
				_low_wall(plaster, coping, a, b, 0.6)
				_fence_panel(_tool("fence_palisade", surfaces, materials, PixelMaterials.panel("fence_palisade", Color.WHITE, true)), a, b, 0.6, height, 2.0)
		var a0 := _v(a, 0.0)
		var b0 := _v(b, 0.0)
		var a1 := _v(a, height)
		var b1 := _v(b, height)
		collision.append_array([a0, a1, b1, a0, b1, b0])
	for p: Vector2 in plan.posts:
		_post(post_tool, coping, p, height + 0.15)


## A see-through fence panel from a to b, y0 to y1, its texture repeating every `tile` metres along it.
static func _fence_panel(st: SurfaceTool, a: Vector2, b: Vector2, y0: float, y1: float, tile: float) -> void:
	var u := a.distance_to(b) / tile
	var corners := [_v(a, y0), _v(b, y0), _v(b, y1), _v(a, y1)]
	var uvs := [Vector2(0, 1), Vector2(u, 1), Vector2(u, 0), Vector2(0, 0)]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[k])
		st.add_vertex(corners[k])


## A plastered wall 0.2 m thick from a to b with a concrete cap.
static func _low_wall(plaster: SurfaceTool, coping: SurfaceTool, a: Vector2, b: Vector2, height: float) -> void:
	var t := (b - a).normalized()
	var side := Vector2(-t.y, t.x) * 0.1
	_quad(plaster, _v(a + side, 0.0), _v(b + side, 0.0), height, _v(side, 0.0))
	_quad(plaster, _v(a - side, 0.0), _v(b - side, 0.0), height, _v(-side, 0.0))
	strip(coping, PackedVector2Array([a, b]), 0.26, height)


## A square post 0.35 m wide with a concrete cap, turned to no particular direction (it is square).
static func _post(st: SurfaceTool, cap: SurfaceTool, p: Vector2, height: float) -> void:
	var r := 0.175
	var c := [p + Vector2(-r, -r), p + Vector2(r, -r), p + Vector2(r, r), p + Vector2(-r, r)]
	for i in 4:
		var q0: Vector2 = c[i]
		var q1: Vector2 = c[(i + 1) % 4]
		_quad(st, _v(q0, 0.0), _v(q1, 0.0), height, _v((q0 + q1) * 0.5 - p, 0.0))
	_up(cap, _v(c[0], height), _v(c[1], height), _v(c[2], height))
	_up(cap, _v(c[0], height), _v(c[2], height), _v(c[3], height))


## A vertical wall face from a to c (both at ground height y), `height` tall, looking towards `out`.
static func _quad(st: SurfaceTool, a: Vector3, c: Vector3, height: float, out: Vector3) -> void:
	var up := Vector3(0, height, 0)
	_facing(st, a, a + up, c + up, out)
	_facing(st, a, c + up, c, out)


## The unit normal of the wall p0-p1 on the side of `out`.
static func _wall_normal(p0: Vector2, p1: Vector2, out: Vector3) -> Vector2:
	var t := (p1 - p0).normalized()
	var n := Vector2(-t.y, t.x)
	return n if n.dot(Vector2(out.x, out.z)) >= 0.0 else -n


## The unit normal of the outline's edge p0-p1 pointing out of the building. Worked out from the outline's winding, so it is right
## for L, T and U shapes too (the old test "away from the centre" turned the walls round the inside of a bend inward, and
## a wall facing inward is not drawn from the street: houses with missing walls).
static func edge_out(ring: PackedVector2Array, p0: Vector2, p1: Vector2) -> Vector2:
	var t := (p1 - p0).normalized()
	var n := Vector2(t.y, -t.x)   # outward for a counter-clockwise outline
	return n if _signed_area(ring) > 0.0 else -n


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
