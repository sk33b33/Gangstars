class_name StreetBuilder
extends RefCounted
## Builds shared district geometry from district data under `root` (the NavigationRegion3D,
## so solid parts are carved out of the nav mesh): ground, streets, landmarks, streetlights,
## street-name signs and the locked boundary. Ordinary houses come from HousePlot + data.

const WALL_H := 1.6
const SIGN_COLOR := Color("#2f6e3a")


## Returns {district_id: [DistrictGate]} for the boundary gates.
static func build(root: Node3D, info: Dictionary, destinations: DestinationRegistry) -> Dictionary:
	var b: Array = info.get("bounds", [-72, -78, 72, 22])
	var streets: Array = info.get("streets", [])
	# Ground: one solid slab (top at y = 0) extending past the bounds so the world never ends.
	# Sides shared with another area get no margin (that area brings its own ground).
	var m: Dictionary = {"west": 40.0, "east": 40.0, "north": 40.0, "south": 40.0}
	m.merge(info.get("ground_margin", {}), true)
	var g0 := Vector2(float(b[0]) - float(m.west), float(b[1]) - float(m.north))
	var g1 := Vector2(float(b[2]) + float(m.east), float(b[3]) + float(m.south))
	Geo.box(root, Vector3(g1.x - g0.x, 1, g1.y - g0.y), Vector3((g0.x + g1.x) * 0.5, -0.5, (g0.y + g1.y) * 0.5),
		PixelMaterials.surface(str(info.get("ground_texture", "yard_sand")), Vector2(2, 2), DataFiles.to_color(info.get("ground_tint"), Color(0.86, 0.8, 0.7))))
	for s in streets:
		_build_street(root, s)
	for s in streets:
		_build_streetlights(root, s, b)
	_build_street_signs(root, streets)
	for lm in info.get("landmarks", []):
		var p := DataFiles.to_vec2(lm.get("position"))
		var pos := Vector3(p.x, 0, p.y)
		match str(lm.get("type", "")):
			"cafe": _build_cafe(root, pos)
			"bus_stop": _build_bus_stop(root, pos, PI if lm.get("facing", "south") == "north" else 0.0)
			"court": _build_court(root, pos)
			"park": _build_park(root, pos)
			"corner": _build_corner(root, pos)
			"container_shop": _build_container_shop(root, pos, _facing_rot(lm), str(lm.get("sign", "sign_spaza")), DataFiles.to_color(lm.get("color"), Color("#2b6fb5")))
			"soccer_field": _build_soccer_field(root, pos)
			"taxi_rank": _build_bus_stop(root, pos, _facing_rot(lm), "sign_taxi", Color("#d9c49a"))
			"courtyard": _build_courtyard(root, pos)
			"church_hall": _build_church_hall(root, pos, _facing_rot(lm))
			"quarry_face": _build_quarry_face(root, pos, DataFiles.to_vec2(lm.get("size"), Vector2(34, 28)))
			"lookout": _build_lookout(root, pos, _facing_rot(lm))
			var other: push_warning("Unknown landmark type '%s'" % other)
	var gates := _build_boundary(root, b, streets, info.get("locked_neighbours", []), destinations, info.get("open_sides", []))
	_build_backdrop(root, b, streets, info.get("backdrop_skip", []))
	for car in info.get("parked_cars", []):
		if car.get("drivable", false):
			continue  # spawned as a DrivableCar after the nav bake
		var cp := DataFiles.to_vec2(car.get("position"))
		_build_car(root, Vector3(cp.x, 0, cp.y), deg_to_rad(float(car.get("rot", 0))), DataFiles.to_color(car.get("color"), Color.GRAY))
	for decal in info.get("decals", []):
		var pos: Array = decal.get("position", [0, 0, 0])
		var size := DataFiles.to_vec2(decal.get("size"), Vector2.ONE)
		Geo.quad(root, size, Vector3(pos[0], pos[1], pos[2]), PixelMaterials.panel(str(decal.texture), Color.WHITE, true),
			deg_to_rad(float(decal.get("rot", 0))))
	for poi in info.get("pois", []):
		var p := DataFiles.to_vec2(poi.get("position"))
		destinations.register(str(poi.id), Vector3(p.x, 0, p.y), float(poi.get("radius", 1.0)),
			str(poi.get("kind", "poi")), str(poi.get("name", poi.id)))
	return gates


## Converts a street-local rect (along, across) to a world Rect2 on the XZ plane.
static func _rect(s: Dictionary, a0: float, a1: float, c0: float, c1: float) -> Rect2:
	var at: float = s.at
	if s.axis == "x":
		return Rect2(minf(a0, a1), at + minf(c0, c1), absf(a1 - a0), absf(c1 - c0))
	return Rect2(at + minf(c0, c1), minf(a0, a1), absf(c1 - c0), absf(a1 - a0))


static func _world(s: Dictionary, along: float, across: float) -> Vector3:
	return Vector3(along, 0, s.at + across) if s.axis == "x" else Vector3(s.at + across, 0, along)


static func _build_street(root: Node3D, s: Dictionary) -> void:
	var hw: float = s.get("half_width", 4.0)
	var walk: float = s.get("sidewalk", 2.5)
	var a0: float = s.from
	var a1: float = s.to
	Geo.patch(root, _rect(s, a0, a1, -hw, hw), 0.01, PixelMaterials.surface("road_asphalt", Vector2(2, 2)))
	var w0: float = s.get("sidewalk_from", a0)
	var w1: float = s.get("sidewalk_to", a1)
	var pave := PixelMaterials.surface("sidewalk", Vector2(2, 2))
	for side in [-1.0, 1.0]:
		Geo.patch(root, _rect(s, w0, w1, side * hw, side * (hw + walk)), 0.015, pave)
	var rot := 0.0 if s.axis == "x" else PI * 0.5
	var length := absf(w1 - w0)
	var mid := (w0 + w1) * 0.5
	var kerb := PixelMaterials.flat(Color("#c9c6bf"))
	for side in [-1.0, 1.0]:
		Geo.box(root, Vector3(length, 0.06, 0.2), _world(s, mid, side * hw) + Vector3(0, 0.03, 0), kerb, false, rot)
	var paint := PixelMaterials.flat(Color("#f1eee8"))
	var step := 1.0 if a1 > a0 else -1.0
	var t := a0 + step
	while (t - a1) * step < 0.0:
		Geo.box(root, Vector3(2.0, 0.02, 0.15), _world(s, t + step, 0) + Vector3(0, 0.02, 0), paint, false, rot)
		t += 5.0 * step
	_build_crossings(root, s, minf(w0, w1), maxf(w0, w1), hw, rot, paint)


const CROSSING_SPACING := 24.0
const CROSSING_START := 16.0
const CROSSING_WIDTH := 3.0


## Residents walk on pavements and cross at zebra crossings: the roadway is carved out of the
## nav mesh (a projected NavigationObstacle3D, applied at bake time) except at the crossings.
## Vehicles and the player don't use the nav mesh, so this only shapes where people walk.
static func _build_crossings(root: Node3D, s: Dictionary, c0: float, c1: float, hw: float, rot: float, paint: Material) -> void:
	var centres: Array = []
	var t := c0 + CROSSING_START
	while t < c1 - 6.0:
		centres.append(t)
		t += CROSSING_SPACING
	var seg_start := c0
	for cx in centres:
		_carve_road(root, s, seg_start, cx - CROSSING_WIDTH * 0.5, hw)
		seg_start = cx + CROSSING_WIDTH * 0.5
		var k := -hw + 0.6
		while k <= hw - 0.4:
			Geo.box(root, Vector3(CROSSING_WIDTH, 0.02, 0.45), _world(s, cx, k) + Vector3(0, 0.022, 0), paint, false, rot)
			k += 0.9
	_carve_road(root, s, seg_start, c1, hw)


static func _carve_road(root: Node3D, s: Dictionary, a0: float, a1: float, hw: float) -> void:
	if a1 - a0 < 0.5:
		return
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "RoadCarve"
	obstacle.vertices = PackedVector3Array([_world(s, a0, -hw), _world(s, a1, -hw), _world(s, a1, hw), _world(s, a0, hw)])
	obstacle.height = 2.0
	obstacle.position = Vector3(0, -0.5, 0)
	obstacle.avoidance_enabled = false
	obstacle.affect_navigation_mesh = true
	obstacle.carve_navigation_mesh = true
	root.add_child(obstacle)


## Centres of the zebra crossings on a street (for tests / tools).
static func crossing_centres(s: Dictionary) -> Array:
	var c0: float = minf(s.get("sidewalk_from", s.from), s.get("sidewalk_to", s.to))
	var c1: float = maxf(s.get("sidewalk_from", s.from), s.get("sidewalk_to", s.to))
	var out: Array = []
	var t := c0 + CROSSING_START
	while t < c1 - 6.0:
		out.append(t)
		t += CROSSING_SPACING
	return out


static func _build_streetlights(root: Node3D, s: Dictionary, b: Array) -> void:
	var steel := PixelMaterials.flat(Color("#7d828c"))
	var lamp := PixelMaterials.lamp()
	var lo: float = s.get("sidewalk_from", s.from)
	var hi: float = s.get("sidewalk_to", s.to)
	if s.axis == "x":
		lo = maxf(minf(lo, hi), b[0] + 2.0)
		hi = minf(maxf(s.from, s.to), b[2] - 2.0)
	else:
		var l := minf(lo, hi)
		hi = maxf(lo, hi)
		lo = l
	var off: float = s.get("half_width", 4.0) + 0.6  # just behind the kerb: clear of parked cars and gates
	var rot := 0.0 if s.axis == "x" else PI * 0.5
	var t := lo + 6.0
	var side := 1.0
	var tops := {1.0: [], -1.0: []}
	while t < hi - 2.0:
		var p := _world(s, t, off * side)
		tops[side].append(p + Vector3(0, 4.9, 0))
		var arm := _world(s, 0, -side * 0.6) - _world(s, 0, 0)
		Geo.box(root, Vector3(0.14, 5.0, 0.14), p + Vector3(0, 2.5, 0), steel)
		Geo.box(root, Vector3(1.2, 0.12, 0.12), p + arm + Vector3(0, 4.95, 0), steel, false, rot + PI * 0.5)
		Geo.box(root, Vector3(0.4, 0.12, 0.3), p + arm * 1.8 + Vector3(0, 4.85, 0), lamp, false, rot)
		t += 14.0
		side = -side
	for k in tops:
		_build_wires(root, tops[k])


## Visual-only rows of simple houses outside the boundary, so the city continues past the
## wall (and hints at the locked districts). No colliders: they are unreachable anyway.
static func _facing_rot(lm: Dictionary) -> float:
	return {"south": 0.0, "north": PI, "east": PI * 0.5, "west": -PI * 0.5}.get(str(lm.get("facing", "south")), 0.0)


static func _build_backdrop(root: Node3D, b: Array, streets: Array, skip: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	var paints := ["#e8967a", "#a6d455", "#8fb8d8", "#f2e4b8", "#c3b0d8", "#ece9e2", "#f1d36b", "#9fd8b8"]
	var spots: Array = []  # [position, facing rotation]
	var minx: float = b[0]
	var minz: float = b[1]
	var maxx: float = b[2]
	var maxz: float = b[3]
	var x := minx - 18.0
	while x <= maxx + 18.0:
		if not skip.has("north"):
			spots.append([Vector3(x, 0, minz - 8.0), 0.0])
		if not skip.has("south"):
			spots.append([Vector3(x, 0, maxz + 8.0), PI])
		x += 11.0
	for s in streets:
		if s.axis != "x":
			continue
		var off: float = s.get("half_width", 4.0) + s.get("sidewalk", 2.5) + 5.0
		for dir in [-1.0, 1.0]:
			if skip.has("east" if dir > 0 else "west"):
				continue
			var edge: float = maxx if dir > 0 else minx
			var t: float = edge + dir * 8.0
			for i in 4:
				spots.append([Vector3(t, 0, s.at - off), 0.0])
				spots.append([Vector3(t, 0, s.at + off), PI])
				t += dir * 11.0
			# The road keeps going past the barrier.
			Geo.patch(root, Rect2(minf(edge, edge + dir * 50.0), s.at - 4.0, 50.0, 8.0), 0.01, PixelMaterials.surface("road_asphalt", Vector2(2, 2)))
	for spot in spots:
		var pos: Vector3 = spot[0]
		var w := rng.randf_range(6.5, 8.5)
		var d := rng.randf_range(5.5, 7.0)
		var h := 2.8 if rng.randf() < 0.75 else 5.4
		var pivot := Node3D.new()
		pivot.position = pos
		pivot.rotation.y = spot[1]
		root.add_child(pivot)
		var wall := PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color(paints[rng.randi() % paints.size()]))
		Geo.box(pivot, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall, false)
		var roof := MeshInstance3D.new()
		roof.mesh = Geo.roof_mesh(w + 0.6, d + 0.6, 1.3, (d + 0.6) * 0.5 if rng.randf() < 0.5 else 0.0)
		roof.material_override = PixelMaterials.surface("roof_tiles" if rng.randf() < 0.6 else "roof_ibr", Vector2(2, 2))
		roof.position = Vector3(0, h, 0)
		pivot.add_child(roof)
		Geo.quad(pivot, Vector2(1.5, 1.25), Vector3(-w * 0.25, 1.6, d * 0.5 + 0.02), PixelMaterials.panel("window_bars"))
		Geo.quad(pivot, Vector2(1.0, 2.0), Vector3(w * 0.2, 1.0, d * 0.5 + 0.02), PixelMaterials.panel("door_gate"))


## Two sagging cables between consecutive poles on the same side of a street.
static func _build_wires(root: Node3D, tops: Array) -> void:
	if tops.size() < 2:
		return
	var verts := PackedVector3Array()
	for i in tops.size() - 1:
		for drop in [0.0, 0.3]:
			var a: Vector3 = tops[i] - Vector3(0, drop, 0)
			var b: Vector3 = tops[i + 1] - Vector3(0, drop, 0)
			const SEGMENTS := 10
			for k in SEGMENTS:
				for e in [k, k + 1]:
					var f := float(e) / SEGMENTS
					verts.append(a.lerp(b, f) - Vector3(0, sin(f * PI) * 0.9, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#2a2a30")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Low-poly parked hatchback: body, glass cabin with roof, wheels, lights. One solid collider.
## Car model (long axis = local X, front at +X). solid=false for moving vehicles, which
## carry their own collision. Returns the pivot.
static func build_car(root: Node3D, c: Vector3, rot_y: float, color: Color, solid := true, length := 4.0) -> Node3D:
	return _build_car(root, c, rot_y, color, solid, length)


static func _build_car(root: Node3D, c: Vector3, rot_y: float, color: Color, solid := true, length := 4.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = c
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	var paint := PixelMaterials.flat(color)
	var glass := PixelMaterials.flat(Color("#29384a"))
	var tyre := PixelMaterials.flat(Color("#1d1b24"))
	Geo.box(pivot, Vector3(4.0, 0.62, 1.75), Vector3(0, 0.6, 0), paint, false)
	Geo.box(pivot, Vector3(2.3, 0.5, 1.6), Vector3(-0.25, 1.15, 0), glass, false)
	Geo.box(pivot, Vector3(2.2, 0.07, 1.62), Vector3(-0.25, 1.42, 0), paint, false)
	Geo.box(pivot, Vector3(0.05, 0.14, 0.4), Vector3(2.0, 0.72, 0.6), PixelMaterials.lamp(), false)
	Geo.box(pivot, Vector3(0.05, 0.14, 0.4), Vector3(2.0, 0.72, -0.6), PixelMaterials.lamp(), false)
	Geo.box(pivot, Vector3(0.05, 0.12, 0.35), Vector3(-2.0, 0.72, 0.6), PixelMaterials.flat(Color("#a63a4c")), false)
	Geo.box(pivot, Vector3(0.05, 0.12, 0.35), Vector3(-2.0, 0.72, -0.6), PixelMaterials.flat(Color("#a63a4c")), false)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.32
	wheel.bottom_radius = 0.32
	wheel.height = 0.22
	wheel.radial_segments = 12
	for wx in [-1.3, 1.3]:
		for wz in [-0.82, 0.82]:
			var w := MeshInstance3D.new()
			w.mesh = wheel
			w.material_override = tyre
			w.position = Vector3(wx, 0.32, wz)
			w.rotation.x = PI * 0.5
			pivot.add_child(w)
	if not is_equal_approx(length, 4.0):
		pivot.scale = Vector3(length / 4.0, 1.25, 1.12)  # minibus taxi: longer, taller
	if solid:
		Geo.collider(pivot, Vector3(4.0, 1.4, 1.8), Vector3(0, 0.7, 0))
	return pivot


## A name sign where each cross street meets an east-west street.
static func _build_street_signs(root: Node3D, streets: Array) -> void:
	var steel := PixelMaterials.flat(Color("#565a64"))
	for s in streets:
		if s.axis != "z":
			continue
		var hw: float = s.get("half_width", 4.0) + s.get("sidewalk", 2.5) - 0.4
		for end in [s.get("sidewalk_from", s.from), s.get("sidewalk_to", s.to)]:
			var inward := -1.0 if end > s.get("sidewalk_to", s.to) else 1.0
			var p: Vector3 = _world(s, end + inward * 0.6, hw)
			Geo.box(root, Vector3(0.1, 2.8, 0.1), p + Vector3(0, 1.4, 0), steel)
			for face in [0.0, PI]:
				var l := Geo.label(root, s.name.to_upper(), p + Vector3(0, 2.7, 0), 56, Color.WHITE, face)
				l.outline_modulate = SIGN_COLOR
				l.outline_size = 18
				l.double_sided = false


static func _build_cafe(root: Node3D, c: Vector3) -> void:
	var wall := PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color("#f3e3b3"))
	Geo.box(root, Vector3(10, 3.4, 8), c + Vector3(0, 1.7, 0), wall)
	Geo.box(root, Vector3(10.4, 0.5, 8.4), c + Vector3(0, 3.65, 0), PixelMaterials.flat(Color("#2f6e3a")), false)
	var face := c.z + 4.03
	Geo.quad(root, Vector2(7.5, 1.5), Vector3(c.x, 2.75, face), PixelMaterials.panel("sign_shop"))
	Geo.quad(root, Vector2(1.0, 2.0), Vector3(c.x, 1.0, face), PixelMaterials.panel("door_gate"))
	for wx in [-3.0, 3.0]:
		Geo.quad(root, Vector2(2.4, 1.6), Vector3(c.x + wx, 1.2, face), PixelMaterials.panel("window_bars"))
	Geo.patch(root, Rect2(c.x - 5, c.z + 4, 10, 2.1), 0.013, PixelMaterials.surface("sidewalk", Vector2(2, 2)))


## Shelter open towards local +Z; rot_y = PI turns it to face north.
static func _build_bus_stop(root: Node3D, c: Vector3, rot_y: float, sign := "sign_bus", panel_color := Color("#9fb6c9")) -> void:
	var pivot := Node3D.new()
	pivot.position = c
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	var steel := PixelMaterials.flat(Color("#565a64"))
	Geo.box(pivot, Vector3(3.2, 2.2, 0.1), Vector3(0, 1.1, -0.4), PixelMaterials.flat(panel_color))
	Geo.box(pivot, Vector3(3.4, 0.1, 1.4), Vector3(0, 2.3, 0.1), steel, false)
	Geo.bench(pivot, Vector3(0, 0, -0.1), 0.0, 2.4)
	Geo.box(pivot, Vector3(0.1, 2.6, 0.1), Vector3(2.2, 1.3, 1.3), steel)
	Geo.quad(pivot, Vector2(0.6, 0.6), Vector3(2.2, 2.6, 1.36), PixelMaterials.panel(sign))


## Converted shipping container shop (spaza, barber): serving hatch, awning and sign facing +Z.
static func _build_container_shop(root: Node3D, c: Vector3, rot_y: float, sign: String, color: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = c
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	Geo.box(pivot, Vector3(6.0, 2.6, 2.4), Vector3(0, 1.3, 0), PixelMaterials.surface("container_wall", Vector2(2, 2), color))
	Geo.quad(pivot, Vector2(2.4, 1.1), Vector3(-0.8, 1.45, 1.22), PixelMaterials.flat(Color("#141218")))
	Geo.box(pivot, Vector3(2.8, 0.08, 0.5), Vector3(-0.8, 0.9, 1.45), PixelMaterials.flat(Color("#8a5a3c")), false)
	Geo.box(pivot, Vector3(3.4, 0.06, 1.3), Vector3(-0.8, 2.3, 1.8), PixelMaterials.flat(Color("#c0392b")), false)
	Geo.quad(pivot, Vector2(3.6, 0.9), Vector3(0.5, 2.95, 1.22), PixelMaterials.panel(sign))
	Geo.quad(pivot, Vector2(0.9, 2.0), Vector3(2.2, 1.0, 1.22), PixelMaterials.panel("door_gate"))


## Dusty soccer pitch: red-dirt surface, white lines, two goals (solid posts).
static func _build_soccer_field(root: Node3D, c: Vector3) -> void:
	Geo.patch(root, Rect2(c.x - 14, c.z - 9, 28, 18), 0.011, PixelMaterials.surface("sand_red", Vector2(2, 2), Color(0.85, 0.72, 0.62)))
	var paint := PixelMaterials.flat(Color("#f1eee8"))
	for z in [-9.0, 9.0]:
		Geo.box(root, Vector3(28, 0.02, 0.12), Vector3(c.x, 0.02, c.z + z), paint, false)
	for x in [-14.0, 0.0, 14.0]:
		Geo.box(root, Vector3(0.12, 0.02, 18), Vector3(c.x + x, 0.02, c.z), paint, false)
	for side in [-1.0, 1.0]:
		var gx: float = c.x + side * 13.6
		for gz in [-1.8, 1.8]:
			Geo.box(root, Vector3(0.12, 2.0, 0.12), Vector3(gx, 1.0, c.z + gz), paint)
		Geo.box(root, Vector3(0.12, 0.12, 3.7), Vector3(gx, 2.0, c.z), paint, false)


## Small paved courtyard between the flats: benches round a tree.
static func _build_courtyard(root: Node3D, c: Vector3) -> void:
	Geo.patch(root, Rect2(c.x - 6, c.z - 6, 12, 12), 0.012, PixelMaterials.surface("sidewalk", Vector2(2, 2), Color("#cfc6b8")))
	Geo.box(root, Vector3(0.3, 2.4, 0.3), c + Vector3(0, 1.2, 0), PixelMaterials.flat(Color("#6b4630")))
	var crown := SphereMesh.new()
	crown.radius = 1.6
	crown.height = 2.6
	var mi := MeshInstance3D.new()
	mi.mesh = crown
	mi.material_override = PixelMaterials.flat(Color("#4f8a3c"))
	mi.position = c + Vector3(0, 3.2, 0)
	root.add_child(mi)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		Geo.bench(root, c + Vector3(cos(a), 0, sin(a)) * 3.5, -a - PI * 0.5)


## Kalkbos Hall: limestone church hall with a bell gable, sign and double doors facing +Z.
static func _build_church_hall(root: Node3D, c: Vector3, rot_y: float) -> void:
	var pivot := Node3D.new()
	pivot.position = c
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	var stone := PixelMaterials.surface("limestone_wall", Vector2(2, 2), Color("#f4efe4"))
	Geo.box(pivot, Vector3(12, 4.2, 9), Vector3(0, 2.1, 0), stone)
	var roof := MeshInstance3D.new()
	roof.mesh = Geo.roof_mesh(9.8, 12.8, 2.6, 0.0)
	roof.rotation.y = PI * 0.5
	roof.material_override = PixelMaterials.surface("roof_ibr", Vector2(2, 2), Color("#8a8f96"))
	roof.position = Vector3(0, 4.2, 0)
	pivot.add_child(roof)
	# Bell gable over the entrance, with a small bell.
	Geo.box(pivot, Vector3(2.0, 2.6, 0.5), Vector3(0, 6.1, 4.3), stone, false)
	Geo.box(pivot, Vector3(0.8, 0.9, 0.52), Vector3(0, 6.4, 4.31), PixelMaterials.flat(Color("#2a2a30")), false)
	var bell := CylinderMesh.new()
	bell.top_radius = 0.15
	bell.bottom_radius = 0.3
	bell.height = 0.45
	var b := MeshInstance3D.new()
	b.mesh = bell
	b.material_override = PixelMaterials.flat(Color("#c9a42e"))
	b.position = Vector3(0, 6.35, 4.35)
	pivot.add_child(b)
	Geo.quad(pivot, Vector2(4.8, 1.2), Vector3(0, 3.5, 4.53), PixelMaterials.panel("sign_hall"))
	for dx in [-0.55, 0.55]:
		Geo.quad(pivot, Vector2(1.0, 2.3), Vector3(dx, 1.15, 4.53), PixelMaterials.flat(Color("#5c3a2c")))
	for wx in [-4.0, 4.0]:
		Geo.quad(pivot, Vector2(1.2, 1.8), Vector3(wx, 2.0, 4.53), PixelMaterials.panel("window_bars"))
	Geo.box(pivot, Vector3(4.0, 0.25, 1.6), Vector3(0, 0.125, 5.3), stone, false)


## Old limestone quarry: a stepped, cut cliff face (solid, unreachable), rock piles, a rusting
## derrick crane, and a danger fence along the front (local +Z side is the street side).
static func _build_quarry_face(root: Node3D, c: Vector3, size: Vector2) -> void:
	var rock := PixelMaterials.surface("limestone_wall", Vector2(4, 4), Color("#d9d2c0"))
	var tiers := [[0.78, 4.0], [0.52, 8.0], [0.28, 12.0]]
	for t in tiers:
		var depth: float = size.y * float(t[0])
		var h: float = t[1]
		Geo.box(root, Vector3(size.x, h, depth), Vector3(c.x, h * 0.5, c.z - size.y * 0.5 + depth * 0.5), rock)
	var gravel := PixelMaterials.surface("chalk_ground", Vector2(2, 2), Color("#cfc8b4"))
	for i in 5:
		var px := c.x - size.x * 0.35 + i * size.x * 0.17
		Geo.box(root, Vector3(2.4, 1.2, 2.0), Vector3(px, 0.6, c.z + size.y * 0.5 - 2.2), gravel, true, 0.3 * i)
	# Derrick crane: mast and jib.
	var steel := PixelMaterials.flat(Color("#8c4a2f"))
	var mast := Vector3(c.x + size.x * 0.3, 0, c.z + size.y * 0.5 - 3.2)
	Geo.box(root, Vector3(0.5, 14.0, 0.5), mast + Vector3(0, 7.0, 0), steel)
	Geo.box(root, Vector3(12.0, 0.4, 0.4), mast + Vector3(-5.0, 13.2, 0), steel, false, 0.2)
	Geo.box(root, Vector3(0.06, 6.0, 0.06), mast + Vector3(-9.0, 10.2, 2.0), PixelMaterials.flat(Color("#2a2a30")), false)
	# Danger fence along the street side with signs.
	var fence := PixelMaterials.surface("fence_palisade", Vector2(2, 1.5), Color("#56606e"), true)
	var fz := c.z + size.y * 0.5 + 0.8
	Geo.box(root, Vector3(size.x + 2.0, 1.5, 0.12), Vector3(c.x, 0.75, fz), fence)
	for sx in [-size.x * 0.3, size.x * 0.3]:
		Geo.quad(root, Vector2(1.5, 0.5), Vector3(c.x + sx, 1.2, fz + 0.08), PixelMaterials.panel("sign_quarry"))


## Quarry lookout: a bench and a coin telescope facing the cliffs (local -Z).
static func _build_lookout(root: Node3D, c: Vector3, rot_y: float) -> void:
	var pivot := Node3D.new()
	pivot.position = c
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	Geo.bench(pivot, Vector3(-1.6, 0, 0.6), PI)
	var steel := PixelMaterials.flat(Color("#3d6e8f"))
	Geo.box(pivot, Vector3(0.15, 1.1, 0.15), Vector3(1.4, 0.55, 0.0), steel)
	Geo.box(pivot, Vector3(0.22, 0.22, 0.6), Vector3(1.4, 1.2, -0.1), steel, false)


static func _build_court(root: Node3D, c: Vector3) -> void:
	Geo.patch(root, Rect2(c.x - 7, c.z - 5, 14, 10), 0.012, PixelMaterials.surface("sidewalk", Vector2(2, 2), Color("#c8c4bb")))
	var steel := PixelMaterials.flat(Color("#565a64"))
	for side in [-1.0, 1.0]:
		var hx: float = c.x + side * 6.2
		Geo.box(root, Vector3(0.15, 3.0, 0.15), Vector3(hx, 1.5, c.z), steel)
		Geo.box(root, Vector3(0.1, 1.0, 1.6), Vector3(hx - side * 0.2, 3.0, c.z), PixelMaterials.flat(Color("#f1eee8")), false)
	for bz in [-4.0, 4.0]:
		Geo.bench(root, Vector3(c.x - 8.5, 0, c.z + bz), PI * 0.5)


## Small park: lawn, a ring of trees and benches around the centre (the POI).
static func _build_park(root: Node3D, c: Vector3) -> void:
	Geo.patch(root, Rect2(c.x - 8, c.z - 8, 16, 16), 0.011, PixelMaterials.flat(Color("#7fae55")))
	var trunk := PixelMaterials.flat(Color("#6b4630"))
	var leaves := PixelMaterials.flat(Color("#3f7d3a"))
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := c + Vector3(cos(a), 0, sin(a)) * 6.0
		Geo.box(root, Vector3(0.3, 2.4, 0.3), p + Vector3(0, 1.2, 0), trunk)
		var crown := SphereMesh.new()
		crown.radius = 1.3
		crown.height = 2.2
		var mi := MeshInstance3D.new()
		mi.mesh = crown
		mi.material_override = leaves
		mi.position = p + Vector3(0, 3.0, 0)
		root.add_child(mi)
	for a in [0.0, PI]:
		var p := c + Vector3(cos(a), 0, sin(a)) * 4.0
		Geo.bench(root, p, -PI * 0.5 if a == 0.0 else PI * 0.5)


static func _build_corner(root: Node3D, c: Vector3) -> void:
	# A painted wall people lean on, with a bench: the neighbourhood gathering spot.
	Geo.box(root, Vector3(6, 2.0, 0.3), c + Vector3(0, 1.0, -0.6), PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color("#e2585e")))
	Geo.bench(root, c + Vector3(-1.5, 0, -0.15))


## Precast wall around the playable area. Every east-west street that crosses the boundary
## gets a DistrictGate for the neighbouring district on that side, and behind it an enclosed
## approach street (walls both sides, a "coming soon" end wall) so an unlocked district can be
## walked into. Returns {district_id: [DistrictGate]}.
static func _build_boundary(root: Node3D, b: Array, streets: Array, neighbours: Array, destinations: DestinationRegistry, open_sides: Array = []) -> Dictionary:
	var gates := {}
	var mat := PixelMaterials.surface("fence_precast", Vector2(2, WALL_H), Color("#d9d4c8"), true)
	var minx: float = b[0]
	var minz: float = b[1]
	var maxx: float = b[2]
	var maxz: float = b[3]
	var w := maxx - minx
	Geo.box(root, Vector3(w, WALL_H, 0.2), Vector3((minx + maxx) * 0.5, WALL_H * 0.5, minz), mat)
	Geo.box(root, Vector3(w, WALL_H, 0.2), Vector3((minx + maxx) * 0.5, WALL_H * 0.5, maxz), mat)
	var crossing: Array = []
	for s in streets:
		if s.axis == "x" and minf(s.from, s.to) < minx and maxf(s.from, s.to) > maxx:
			crossing.append(s)
	var main_street_at: float = crossing[0].at if not crossing.is_empty() else 0.0  # first in data = main road
	crossing.sort_custom(func(p, q): return p.at < q.at)
	for x in [minx, maxx]:
		var side := "east" if is_equal_approx(x, maxx) else "west"
		var face := 1.0 if is_equal_approx(x, minx) else -1.0  # direction pointing into the district
		var neighbour := {}
		for n in neighbours:
			if n.get("side") == side:
				neighbour = n
		var z := minz
		for s in crossing:
			var half: float = s.get("half_width", 4.0) + s.get("sidewalk", 2.5)
			_wall_z(root, x, z, s.at - half, mat)
			z = s.at + half
			if open_sides.has(side):
				continue  # an open street into an adjacent area (its gate lives on the other side)
			if neighbour.is_empty():
				_wall_z(root, x, s.at - half, s.at + half, mat)
				continue
			var gate := DistrictGate.new()
			gate.position = Vector3(x, 0, s.at)
			root.add_child(gate)
			gate.setup(str(neighbour.id), str(neighbour.display_name), half * 2.0, face)
			gates.get_or_add(str(neighbour.id), []).append(gate)
			_build_approach(root, s, x, -face, half, neighbour, mat, destinations if is_equal_approx(s.at, main_street_at) else null)
		_wall_z(root, x, z, maxz, mat)
	return gates


const APPROACH_LENGTH := 36.0


static func _build_approach(root: Node3D, s: Dictionary, edge: float, dir: float, half: float,
		neighbour: Dictionary, mat: Material, destinations: DestinationRegistry) -> void:
	var x0 := edge
	var x1 := edge + dir * APPROACH_LENGTH
	var mid := (x0 + x1) * 0.5
	var hw: float = s.get("half_width", 4.0)
	for side in [-1.0, 1.0]:
		Geo.box(root, Vector3(APPROACH_LENGTH, WALL_H, 0.2), Vector3(mid, WALL_H * 0.5, s.at + side * half), mat)
		Geo.patch(root, Rect2(minf(x0, x1), s.at + minf(side * hw, side * half), APPROACH_LENGTH, half - hw), 0.015,
			PixelMaterials.surface("sidewalk", Vector2(2, 2)))
	var entrance_id := "%s:entrance" % neighbour.id
	if destinations != null and not destinations.has(entrance_id):
		destinations.register(entrance_id, Vector3(edge + dir * 20.0, 0, s.at), 2.0, "district_entrance", str(neighbour.display_name))
	if neighbour.has("data"):
		return  # the approach leads into a built district: no dead-end wall
	Geo.box(root, Vector3(0.3, 2.4, half * 2.0), Vector3(x1, 1.2, s.at), PixelMaterials.surface("wendy_wall", Vector2(2, 2), Color("#e8967a")))
	var label := Geo.label(root, "%s\nStreets under construction — more turf coming soon" % str(neighbour.display_name).to_upper(),
		Vector3(x1 - dir * 0.2, 1.8, s.at), 64, Color("#ffd75e"), PI * 0.5 * -dir)
	label.double_sided = false


static func _wall_z(root: Node3D, x: float, z0: float, z1: float, mat: Material) -> void:
	if z1 - z0 > 0.05:
		Geo.box(root, Vector3(0.2, WALL_H, z1 - z0), Vector3(x, WALL_H * 0.5, (z0 + z1) * 0.5), mat)
