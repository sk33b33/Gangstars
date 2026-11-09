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
	var center := Vector3((b[0] + b[2]) * 0.5, -0.5, (b[1] + b[3]) * 0.5)
	# Ground: one solid slab whose top is y = 0, larger than the bounds so the world never ends.
	Geo.box(root, Vector3(b[2] - b[0] + 80, 1, b[3] - b[1] + 80), center, PixelMaterials.surface("yard_sand", Vector2(2, 2), Color(0.86, 0.8, 0.7)))
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
			var other: push_warning("Unknown landmark type '%s'" % other)
	var gates := _build_boundary(root, b, streets, info.get("locked_neighbours", []), destinations)
	_build_backdrop(root, b, streets)
	for car in info.get("parked_cars", []):
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
	var off: float = s.get("half_width", 4.0) + 0.35  # kerbside, clear of garden gates
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
static func _build_backdrop(root: Node3D, b: Array, streets: Array) -> void:
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
		spots.append([Vector3(x, 0, minz - 8.0), 0.0])
		spots.append([Vector3(x, 0, maxz + 8.0), PI])
		x += 11.0
	for s in streets:
		if s.axis != "x":
			continue
		var off: float = s.get("half_width", 4.0) + s.get("sidewalk", 2.5) + 5.0
		for dir in [-1.0, 1.0]:
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
static func _build_car(root: Node3D, c: Vector3, rot_y: float, color: Color) -> void:
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
	Geo.collider(pivot, Vector3(4.0, 1.4, 1.8), Vector3(0, 0.7, 0))


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
static func _build_bus_stop(root: Node3D, c: Vector3, rot_y: float) -> void:
	var pivot := Node3D.new()
	pivot.position = c
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	var steel := PixelMaterials.flat(Color("#565a64"))
	Geo.box(pivot, Vector3(3.2, 2.2, 0.1), Vector3(0, 1.1, -0.4), PixelMaterials.flat(Color("#9fb6c9")))
	Geo.box(pivot, Vector3(3.4, 0.1, 1.4), Vector3(0, 2.3, 0.1), steel, false)
	Geo.bench(pivot, Vector3(0, 0, -0.1), 0.0, 2.4)
	Geo.box(pivot, Vector3(0.1, 2.6, 0.1), Vector3(2.2, 1.3, 1.3), steel)
	Geo.quad(pivot, Vector2(0.6, 0.6), Vector3(2.2, 2.6, 1.36), PixelMaterials.panel("sign_bus"))


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
static func _build_boundary(root: Node3D, b: Array, streets: Array, neighbours: Array, destinations: DestinationRegistry) -> Dictionary:
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
		var side := "east" if x > 0 else "west"
		var face := 1.0 if x < 0 else -1.0  # direction pointing into the district
		var neighbour := {}
		for n in neighbours:
			if n.get("side") == side:
				neighbour = n
		var z := minz
		for s in crossing:
			var half: float = s.get("half_width", 4.0) + s.get("sidewalk", 2.5)
			_wall_z(root, x, z, s.at - half, mat)
			z = s.at + half
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
	Geo.box(root, Vector3(0.3, 2.4, half * 2.0), Vector3(x1, 1.2, s.at), PixelMaterials.surface("wendy_wall", Vector2(2, 2), Color("#e8967a")))
	var label := Geo.label(root, "%s\nStreets under construction — more turf coming soon" % str(neighbour.display_name).to_upper(),
		Vector3(x1 - dir * 0.2, 1.8, s.at), 64, Color("#ffd75e"), PI * 0.5 * -dir)
	label.double_sided = false
	var entrance_id := "%s:entrance" % neighbour.id
	if destinations != null and not destinations.has(entrance_id):
		destinations.register(entrance_id, Vector3(edge + dir * 20.0, 0, s.at), 2.0, "district_entrance", str(neighbour.display_name))


static func _wall_z(root: Node3D, x: float, z0: float, z1: float, mat: Material) -> void:
	if z1 - z0 > 0.05:
		Geo.box(root, Vector3(0.2, WALL_H, z1 - z0), Vector3(x, WALL_H * 0.5, (z0 + z1) * 0.5), mat)
