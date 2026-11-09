class_name StreetBuilder
extends RefCounted
## Builds the shared district geometry (ground, Duif Street, sidewalks, landmarks, boundary)
## under `root` (the NavigationRegion3D, so solid parts are carved out of the nav mesh).
## Landmarks are unique; ordinary houses come from HousePlot + data.

const WALL_H := 1.6


static func build(root: Node3D, info: Dictionary, destinations: DestinationRegistry) -> void:
	var street: Dictionary = info.get("street", {})
	var x0: float = street.get("x_from", -60.0)
	var x1: float = street.get("x_to", 60.0)
	var road: float = street.get("road_half_width", 4.0)
	var walk: float = street.get("sidewalk_width", 2.5)
	var b: Array = info.get("bounds", [-42, -26, 42, 22])

	# Ground: one solid slab whose top is y = 0. Sand everywhere, then surfaces on top.
	Geo.box(root, Vector3(140, 1, 90), Vector3(0, -0.5, 0), PixelMaterials.surface("yard_sand", Vector2(2, 2)))
	Geo.patch(root, Rect2(x0, -road, x1 - x0, road * 2), 0.01, PixelMaterials.surface("road_asphalt", Vector2(2, 2)))
	for z in [road, -road - walk]:
		Geo.patch(root, Rect2(x0, z, x1 - x0, walk), 0.015, PixelMaterials.surface("sidewalk", Vector2(2, 2)))
	var kerb := PixelMaterials.flat(Color("#c9c6bf"))
	for z in [road, -road]:
		Geo.box(root, Vector3(x1 - x0, 0.06, 0.2), Vector3((x0 + x1) * 0.5, 0.03, z), kerb, false)
	var paint := PixelMaterials.flat(Color("#f1eee8"))
	var x := x0 + 1.0
	while x < x1:
		Geo.box(root, Vector3(2.0, 0.02, 0.15), Vector3(x + 1.0, 0.02, 0), paint, false)
		x += 5.0

	_build_cafe(root, Vector3(-18, 0, -14))
	_build_bus_stop(root, Vector3(8, 0, -7.2))
	_build_court(root, Vector3(22, 0, -16))
	_build_corner(root, Vector3(32, 0, -7.2))
	_build_streetlights(root, x0, x1, road + walk - 0.3)
	_build_boundary(root, b, road + walk, info.get("locked_neighbours", []))

	for poi in info.get("pois", []):
		var p := DataFiles.to_vec2(poi.get("position"))
		destinations.register(str(poi.id), Vector3(p.x, 0, p.y), float(poi.get("radius", 1.0)),
			str(poi.get("kind", "poi")), str(poi.get("name", poi.id)))


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


static func _build_bus_stop(root: Node3D, c: Vector3) -> void:
	var steel := PixelMaterials.flat(Color("#565a64"))
	Geo.box(root, Vector3(3.2, 2.2, 0.1), c + Vector3(0, 1.1, -0.4), PixelMaterials.flat(Color("#9fb6c9")))
	Geo.box(root, Vector3(3.4, 0.1, 1.4), c + Vector3(0, 2.3, 0.1), steel, false)
	Geo.box(root, Vector3(2.4, 0.45, 0.4), c + Vector3(0, 0.225, -0.1), PixelMaterials.flat(Color("#7d828c")))
	Geo.box(root, Vector3(0.1, 2.6, 0.1), c + Vector3(2.2, 1.3, 1.3), steel)
	Geo.quad(root, Vector2(0.6, 0.6), c + Vector3(2.2, 2.6, 1.36), PixelMaterials.panel("sign_bus"))


static func _build_court(root: Node3D, c: Vector3) -> void:
	Geo.patch(root, Rect2(c.x - 7, c.z - 5, 14, 10), 0.012, PixelMaterials.surface("sidewalk", Vector2(2, 2), Color("#c8c4bb")))
	var steel := PixelMaterials.flat(Color("#565a64"))
	for side in [-1.0, 1.0]:
		var hx: float = c.x + side * 6.2
		Geo.box(root, Vector3(0.15, 3.0, 0.15), Vector3(hx, 1.5, c.z), steel)
		Geo.box(root, Vector3(0.1, 1.0, 1.6), Vector3(hx - side * 0.2, 3.0, c.z), PixelMaterials.flat(Color("#f1eee8")), false)
	for bz in [-4.0, 4.0]:
		Geo.box(root, Vector3(2.0, 0.45, 0.45), Vector3(c.x - 8.5, 0.225, c.z + bz), PixelMaterials.flat(Color("#8a5a3c")))


static func _build_corner(root: Node3D, c: Vector3) -> void:
	# A painted wall people lean on, with a bench: the neighbourhood gathering spot.
	Geo.box(root, Vector3(6, 2.0, 0.3), c + Vector3(0, 1.0, -0.6), PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color("#e2585e")))
	Geo.box(root, Vector3(2.0, 0.45, 0.45), c + Vector3(-1.5, 0.225, -0.15), PixelMaterials.flat(Color("#8a5a3c")))


static func _build_streetlights(root: Node3D, x0: float, x1: float, z: float) -> void:
	var steel := PixelMaterials.flat(Color("#7d828c"))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color("#fff0a8")
	lamp.emission_enabled = true
	lamp.emission = Color("#ffc85e")
	var x := x0 + 6.0
	var side := 1.0
	while x < x1:
		var pz := z * side
		Geo.box(root, Vector3(0.14, 5.0, 0.14), Vector3(x, 2.5, pz), steel)
		Geo.box(root, Vector3(0.12, 0.12, 1.2), Vector3(x, 4.95, pz - side * 0.6), steel, false)
		Geo.box(root, Vector3(0.3, 0.12, 0.4), Vector3(x, 4.85, pz - side * 1.1), lamp, false)
		x += 14.0
		side = -side


## Precast wall around the playable area. The road ends at "LOCKED TURF" barriers; the street
## visibly continues beyond them to hint at the locked neighbouring districts.
static func _build_boundary(root: Node3D, b: Array, street_half: float, neighbours: Array) -> void:
	var mat := PixelMaterials.surface("fence_precast", Vector2(2, WALL_H), Color("#d9d4c8"), true)
	var minx: float = b[0]
	var minz: float = b[1]
	var maxx: float = b[2]
	var maxz: float = b[3]
	var w := maxx - minx
	Geo.box(root, Vector3(w, WALL_H, 0.2), Vector3((minx + maxx) * 0.5, WALL_H * 0.5, minz), mat)
	Geo.box(root, Vector3(w, WALL_H, 0.2), Vector3((minx + maxx) * 0.5, WALL_H * 0.5, maxz), mat)
	var barrier := PixelMaterials.flat(Color("#e7c64a"))
	for x in [minx, maxx]:
		# Side walls with the street opening blocked by a barrier instead of a wall.
		var north_len := (-street_half) - minz
		var south_len := maxz - street_half
		Geo.box(root, Vector3(0.2, WALL_H, north_len), Vector3(x, WALL_H * 0.5, minz + north_len * 0.5), mat)
		Geo.box(root, Vector3(0.2, WALL_H, south_len), Vector3(x, WALL_H * 0.5, street_half + south_len * 0.5), mat)
		Geo.box(root, Vector3(0.4, 1.1, street_half * 2), Vector3(x, 0.55, 0), barrier)
		var face_dir := 1.0 if x < 0 else -1.0
		Geo.quad(root, Vector2(3.2, 1.2), Vector3(x + face_dir * 0.21, 1.35, 0), PixelMaterials.panel("sign_locked"), PI * 0.5 * face_dir)
		var label := "Locked turf"
		for n in neighbours:
			if (n.get("side") == "east") == (x > 0):
				label = "%s — LOCKED" % n.get("display_name", "?")
		Geo.label(root, label, Vector3(x + face_dir * 0.25, 2.4, 0), 64, Color("#ffd75e"), PI * 0.5 * face_dir)
