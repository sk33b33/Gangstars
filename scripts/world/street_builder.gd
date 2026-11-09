class_name StreetBuilder
extends RefCounted
## Builds shared district geometry from district data under `root` (the NavigationRegion3D,
## so solid parts are carved out of the nav mesh): ground, streets, landmarks, streetlights,
## street-name signs and the locked boundary. Ordinary houses come from HousePlot + data.

const WALL_H := 1.6
const SIGN_COLOR := Color("#2f6e3a")


static func build(root: Node3D, info: Dictionary, destinations: DestinationRegistry) -> void:
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
	_build_boundary(root, b, streets, info.get("locked_neighbours", []))
	for poi in info.get("pois", []):
		var p := DataFiles.to_vec2(poi.get("position"))
		destinations.register(str(poi.id), Vector3(p.x, 0, p.y), float(poi.get("radius", 1.0)),
			str(poi.get("kind", "poi")), str(poi.get("name", poi.id)))


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
	while t < hi - 2.0:
		var p := _world(s, t, off * side)
		var arm := _world(s, 0, -side * 0.6) - _world(s, 0, 0)
		Geo.box(root, Vector3(0.14, 5.0, 0.14), p + Vector3(0, 2.5, 0), steel)
		Geo.box(root, Vector3(1.2, 0.12, 0.12), p + arm + Vector3(0, 4.95, 0), steel, false, rot + PI * 0.5)
		Geo.box(root, Vector3(0.4, 0.12, 0.3), p + arm * 1.8 + Vector3(0, 4.85, 0), lamp, false, rot)
		t += 14.0
		side = -side


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
## ends at a "LOCKED TURF" barrier; the road visibly continues to hint at locked districts.
static func _build_boundary(root: Node3D, b: Array, streets: Array, neighbours: Array) -> void:
	var mat := PixelMaterials.surface("fence_precast", Vector2(2, WALL_H), Color("#d9d4c8"), true)
	var minx: float = b[0]
	var minz: float = b[1]
	var maxx: float = b[2]
	var maxz: float = b[3]
	var w := maxx - minx
	Geo.box(root, Vector3(w, WALL_H, 0.2), Vector3((minx + maxx) * 0.5, WALL_H * 0.5, minz), mat)
	Geo.box(root, Vector3(w, WALL_H, 0.2), Vector3((minx + maxx) * 0.5, WALL_H * 0.5, maxz), mat)
	# Openings on the east/west walls where x-axis streets pass through.
	var openings: Array = []
	for s in streets:
		if s.axis == "x" and minf(s.from, s.to) < minx and maxf(s.from, s.to) > maxx:
			var half: float = s.get("half_width", 4.0) + s.get("sidewalk", 2.5)
			openings.append([s.at - half, s.at + half])
	openings.sort_custom(func(p, q): return p[0] < q[0])
	var barrier := PixelMaterials.flat(Color("#e7c64a"))
	for x in [minx, maxx]:
		var face_dir := 1.0 if x < 0 else -1.0
		var label := "Locked turf"
		for n in neighbours:
			if (n.get("side") == "east") == (x > 0):
				label = "%s — LOCKED" % n.get("display_name", "?")
		var z := minz
		for o in openings:
			_wall_z(root, x, z, o[0], mat)
			var mid: float = (o[0] + o[1]) * 0.5
			Geo.box(root, Vector3(0.4, 1.1, o[1] - o[0]), Vector3(x, 0.55, mid), barrier)
			Geo.quad(root, Vector2(3.2, 1.2), Vector3(x + face_dir * 0.21, 1.35, mid), PixelMaterials.panel("sign_locked"), PI * 0.5 * face_dir)
			Geo.label(root, label, Vector3(x + face_dir * 0.25, 2.4, mid), 64, Color("#ffd75e"), PI * 0.5 * face_dir)
			z = o[1]
		_wall_z(root, x, z, maxz, mat)


static func _wall_z(root: Node3D, x: float, z0: float, z1: float, mat: Material) -> void:
	if z1 - z0 > 0.05:
		Geo.box(root, Vector3(0.2, WALL_H, z1 - z0), Vector3(x, WALL_H * 0.5, (z0 + z1) * 0.5), mat)
