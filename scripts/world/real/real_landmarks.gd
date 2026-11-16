class_name RealLandmarks
extends RefCounted
## Public buildings of the real Westridge built in the shape of what they are: churches with steep
## gables, a cross and (big ones) a bell tower; the mosque with a dome and a minaret; the civic centre
## with a raised hall and an entrance canopy; schools as long face-brick classroom blocks; shops with a
## sign band and a veranda; fuel stations with a forecourt canopy. Shapes first: textures come later.
## Design: design/gdd/real_world.md ("Public buildings").

const BRICK := "#9a5a40"         # face brick (schools, the civic centre, many churches)
const WHITE := "#ece6da"         # whitewashed plaster
const CREAM := "#e8e1d0"
const ROOF_DARK := "#5d6168"
const SIGN_BANDS := ["#c8392f", "#2b6fb5", "#2f8a4a", "#e0b02a"]
const FORECOURT_BANDS := ["#2f8a4a", "#e0b02a", "#c8392f"]
const STEEL := "#7d828c"
const DOME := "#3f8f6a"

## Heights (eaves) per style and the extras' sizes.
const CHURCH_WALL := 5.0
const CHURCH_PITCH := 0.9        # roof rise per metre of half width (about 42 degrees)
const TOWER_AREA := 600.0        # churches bigger than this get a bell tower
const TOWER_SIZE := 3.4
const SCHOOL_STOREY := 3.3
const TWO_STOREY_AREA := 500.0
const SHOP_WALL := 4.0
const SHOP_BAND := 1.0           # parapet sign band above a shop roof
const VERANDA_DEPTH := 2.6
const VERANDA_HEIGHT := 3.0
const CANOPY_HEIGHT := 5.2       # fuel forecourt canopy
const MINARET_HEIGHT := 17.0


## The style of a public building: "church", "mosque", "civic", "clinic", "school", "shop", "fuel",
## "canopy" (a roof on columns, no walls), "hall" or "small".
static func style_of(b: Dictionary) -> String:
	var kind := str(b.get("k", ""))
	var name_lc := str(b.get("n", "")).to_lower()
	match kind:
		"place_of_worship", "church":
			return "mosque" if name_lc.contains("masjid") or name_lc.contains("mosque") else "church"
		"community_centre":
			return "civic"
		"clinic", "kindergarten":
			return "clinic"
		"school", "school_block":
			return "school"
		"mall", "convenience", "alcohol", "fast_food", "shop_block", "retail":
			return "shop"
		"fuel", "garage":
			return "fuel"
		"roof":
			return "canopy"
		"sports_hall", "sports_block":
			return "hall"
	return "small"


static func build(b: Dictionary, ring: PackedVector2Array, centre: Vector2, area: float, rect: Dictionary, seed_value: int, near_roads: Array, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array) -> void:
	var style := style_of(b)
	var front := RealChunkBuilder.home_front(ring, near_roads, [])
	var coping := _mat("coping", RealChunkBuilder.COPING_COLOR, surfaces, materials)
	var fits := area / maxf(float(rect.area), 0.01) >= RealChunkBuilder.ROOF_FILL
	match style:
		"church":
			var walls := _plaster(BRICK if seed_value % 2 == 0 else WHITE, surfaces, materials)
			RealChunkBuilder.wall_ring(ring, centre, CHURCH_WALL, walls, null, collision, 0.0 if fits else RealChunkBuilder.PARAPET)
			if fits:
				_church(rect, area, near_roads, walls, surfaces, materials)
			else:
				RealChunkBuilder.flat_roof(ring, CHURCH_WALL, RealChunkBuilder.PARAPET, _roof("roof_tiles", surfaces, materials), coping)
		"mosque":
			var walls := _plaster(WHITE, surfaces, materials)
			RealChunkBuilder.wall_ring(ring, centre, 5.5, walls, null, collision, RealChunkBuilder.PARAPET)
			RealChunkBuilder.flat_roof(ring, 5.5, RealChunkBuilder.PARAPET, _mat("flat_roof", "#7c7f85", surfaces, materials), coping)
			_mosque(rect, front, 5.5, walls, surfaces, materials)
		"civic":
			var walls := _plaster(BRICK, surfaces, materials)
			RealChunkBuilder.wall_ring(ring, centre, 5.0, walls, null, collision, RealChunkBuilder.PARAPET)
			RealChunkBuilder.flat_roof(ring, 5.0, RealChunkBuilder.PARAPET, _mat("flat_roof", "#7c7f85", surfaces, materials), coping)
			_raised_hall(rect, 5.0, 8.5, walls, surfaces, materials)
			if not front.is_empty():
				_entrance_canopy(front, 7.0, 3.2, 3.4, surfaces, materials)
				_flagpole(front.mid + front.normal * 5.0 + _tangent(front) * 5.0, surfaces, materials)
		"clinic":
			var walls := _plaster(WHITE, surfaces, materials)
			var h := 3.6
			RealChunkBuilder.wall_ring(ring, centre, h, walls, _plaster("#3f7f6a", surfaces, materials), collision, RealChunkBuilder.PARAPET)
			RealChunkBuilder.flat_roof(ring, h, RealChunkBuilder.PARAPET, _mat("flat_roof", "#7c7f85", surfaces, materials), coping)
			if not front.is_empty():
				_entrance_canopy(front, 5.0, 2.6, 2.9, surfaces, materials)
		"school":
			var storeys := 2 if area > TWO_STOREY_AREA else 1
			var h := SCHOOL_STOREY * storeys
			var walls := _plaster(BRICK, surfaces, materials)
			RealChunkBuilder.wall_ring(ring, centre, h, walls, null, collision, 0.0 if fits else RealChunkBuilder.PARAPET)
			if fits:
				var trim := _mat("fascia_" + WHITE, WHITE, surfaces, materials)
				RealChunkBuilder._pitched_roof(_roof("roof_ibr", surfaces, materials), trim, walls, rect, h, true, clampf((rect.half as Vector2).y * 0.25, 0.6, 1.6))
			else:
				RealChunkBuilder.flat_roof(ring, h, RealChunkBuilder.PARAPET, _roof("roof_ibr", surfaces, materials), coping)
			_window_rows(ring, centre, storeys, surfaces, materials)
			_mural(ring, centre, front, seed_value, 0.5, minf(h - 0.4, 3.0), surfaces, materials)
		"shop":
			var walls := _plaster(CREAM, surfaces, materials)
			var band: String = SIGN_BANDS[seed_value % SIGN_BANDS.size()]
			RealChunkBuilder.wall_ring(ring, centre, SHOP_WALL, walls, null, collision, 0.0)
			_sign_band(ring, centre, SHOP_WALL, SHOP_BAND, _mat("band_" + band, band, surfaces, materials))
			RealChunkBuilder.flat_roof(ring, SHOP_WALL, SHOP_BAND, _mat("flat_roof", "#7c7f85", surfaces, materials), coping)
			if not front.is_empty():
				_shopfront(ring, front, surfaces, materials)
			_mural(ring, centre, front, seed_value, 0.4, 3.4, surfaces, materials)
		"fuel":
			var walls := _plaster(WHITE, surfaces, materials)
			RealChunkBuilder.wall_ring(ring, centre, 3.4, walls, null, collision, RealChunkBuilder.PARAPET)
			RealChunkBuilder.flat_roof(ring, 3.4, RealChunkBuilder.PARAPET, _mat("flat_roof", "#7c7f85", surfaces, materials), coping)
			if not front.is_empty() and str(b.get("k", "")) == "fuel":
				_forecourt(front, near_roads, seed_value, surfaces, materials)
		"canopy":
			_canopy_on_columns(ring, rect, CANOPY_HEIGHT, FORECOURT_BANDS[seed_value % FORECOURT_BANDS.size()], surfaces, materials)
		"hall":
			var h := 6.5 if str(b.get("k", "")) == "sports_hall" else 3.6
			var walls := _plaster("#c9c2b4", surfaces, materials)
			RealChunkBuilder.wall_ring(ring, centre, h, walls, null, collision, 0.0 if fits else RealChunkBuilder.PARAPET)
			if fits:
				RealChunkBuilder._pitched_roof(_roof("roof_ibr", surfaces, materials), _mat("fascia_" + WHITE, WHITE, surfaces, materials), walls, rect, h, true, clampf((rect.half as Vector2).y * 0.2, 0.6, 2.0))
			else:
				RealChunkBuilder.flat_roof(ring, h, RealChunkBuilder.PARAPET, _roof("roof_ibr", surfaces, materials), coping)
		_:
			var h := float(b.get("h", 3.0))
			var walls := _plaster(BRICK if seed_value % 3 == 0 else RealChunkBuilder.PUBLIC_WALL, surfaces, materials)
			RealChunkBuilder.wall_ring(ring, centre, h, walls, null, collision, RealChunkBuilder.PARAPET)
			RealChunkBuilder.flat_roof(ring, h, RealChunkBuilder.PARAPET, _roof("roof_ibr", surfaces, materials), coping)


# ------------------------------------------------------------------ materials

static func _plaster(color: String, surfaces: Dictionary, materials: Dictionary) -> SurfaceTool:
	return RealChunkBuilder._tool("wall_" + color, surfaces, materials, PixelMaterials.surface("wall_plaster", Vector2(2, 2), Color(color)))


static func _roof(tex: String, surfaces: Dictionary, materials: Dictionary) -> SurfaceTool:
	return RealChunkBuilder._tool(tex, surfaces, materials, PixelMaterials.surface(tex, Vector2(2, 2)))


static func _mat(key: String, color: String, surfaces: Dictionary, materials: Dictionary) -> SurfaceTool:
	return RealChunkBuilder._tool(key, surfaces, materials, PixelMaterials.flat(Color(color)))


static func _tangent(front: Dictionary) -> Vector2:
	var n: Vector2 = front.normal
	return Vector2(-n.y, n.x)


# ------------------------------------------------------------------ styles

## A steep gable roof along the long side, the front gable towards the nearest street with a cross
## on its peak, and a square bell tower beside the front for big churches.
static func _church(rect: Dictionary, area: float, near_roads: Array, walls: SurfaceTool, surfaces: Dictionary, materials: Dictionary) -> void:
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var rise := half.y * CHURCH_PITCH
	RealChunkBuilder._pitched_roof(_roof("roof_tiles", surfaces, materials), _mat("fascia_" + WHITE, WHITE, surfaces, materials), walls, rect, CHURCH_WALL, true, rise)
	var end_a := c + u * half.x
	var end_b := c - u * half.x
	var su := 1.0 if near_roads.is_empty() or RealChunkBuilder._distance_to_lines(end_a, near_roads) <= RealChunkBuilder._distance_to_lines(end_b, near_roads) else -1.0
	var gable := c + u * su * (half.x + RealChunkBuilder.EAVES)
	var top := CHURCH_WALL + rise
	var cross := _mat("cross", "#f4f1ea", surfaces, materials)
	_obox(cross, gable, u, Vector2(0.12, 0.12), top, top + 2.2)
	_obox(cross, gable, v, Vector2(0.7, 0.12), top + 1.3, top + 1.55)
	if area > TOWER_AREA:
		var t := TOWER_SIZE * 0.5
		var at := c + u * su * (half.x - t) + v * (half.y + t)
		var tower_top := top + 3.0
		_obox(walls, at, u, Vector2(t, t), 0.0, tower_top)
		_pyramid(_roof("roof_tiles", surfaces, materials), at, u, t + 0.2, tower_top, tower_top + 3.5)


## A green dome on a low drum over the middle of the prayer hall, and a slender minaret with a
## balcony at the front corner.
static func _mosque(rect: Dictionary, front: Dictionary, h: float, walls: SurfaceTool, surfaces: Dictionary, materials: Dictionary) -> void:
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var r := clampf(half.y * 0.55, 2.0, 5.5)
	var drum_top := h + 1.0
	_prism(walls, c, r, 16, h, drum_top, false)
	var dome := _mat("dome", DOME, surfaces, materials)
	_dome(dome, Vector3(c.x, drum_top, c.y), r, 16, 5)
	var corner: Vector2 = c + (rect.u as Vector2) * (half.x - 1.0) + (rect.v as Vector2) * (half.y - 1.0)
	if not front.is_empty():
		var n: Vector2 = front.normal
		var best := -INF
		for su: float in [-1.0, 1.0]:
			for sv: float in [-1.0, 1.0]:
				var p: Vector2 = c + (rect.u as Vector2) * su * (half.x - 1.0) + (rect.v as Vector2) * sv * (half.y - 1.0)
				if (p - c).dot(n) > best:
					best = (p - c).dot(n)
					corner = p
	_prism(walls, corner, 1.1, 8, 0.0, MINARET_HEIGHT, false)
	var trim := _mat("coping", RealChunkBuilder.COPING_COLOR, surfaces, materials)
	_prism(trim, corner, 1.6, 8, MINARET_HEIGHT - 4.0, MINARET_HEIGHT - 3.7, true)
	_dome(dome, Vector3(corner.x, MINARET_HEIGHT, corner.y), 1.1, 8, 3)
	_obox(trim, corner, Vector2.RIGHT, Vector2(0.06, 0.06), MINARET_HEIGHT + 1.0, MINARET_HEIGHT + 2.0)


## The middle third of the building raised into a taller hall with a low gable roof.
static func _raised_hall(rect: Dictionary, h: float, hall_h: float, walls: SurfaceTool, surfaces: Dictionary, materials: Dictionary) -> void:
	var hall := rect.duplicate()
	hall.half = Vector2((rect.half as Vector2).x * 0.35, (rect.half as Vector2).y * 0.8)
	_obox(walls, rect.c, rect.u, hall.half, h, hall_h)
	RealChunkBuilder._pitched_roof(_roof("roof_ibr", surfaces, materials), _mat("fascia_" + WHITE, WHITE, surfaces, materials), walls, hall, hall_h, true, 1.2)


## A flat concrete canopy over the entrance on two steel posts.
static func _entrance_canopy(front: Dictionary, width: float, depth: float, height: float, surfaces: Dictionary, materials: Dictionary) -> void:
	var n: Vector2 = front.normal
	var t := _tangent(front)
	var mid: Vector2 = front.mid + n * depth * 0.5
	_obox(_mat("canopy", "#d8d3c8", surfaces, materials), mid, t, Vector2(width * 0.5, depth * 0.5), height, height + 0.3)
	var steel := _mat("steel", STEEL, surfaces, materials)
	for s: float in [-1.0, 1.0]:
		_obox(steel, mid + n * (depth * 0.5 - 0.3) + t * s * (width * 0.5 - 0.3), t, Vector2(0.1, 0.1), 0.0, height)


static func _flagpole(at: Vector2, surfaces: Dictionary, materials: Dictionary) -> void:
	_obox(_mat("steel", STEEL, surfaces, materials), at, Vector2.RIGHT, Vector2(0.06, 0.06), 0.0, 9.0)
	var flag := _mat("flag", "#2b6fb5", surfaces, materials)
	_obox(flag, at + Vector2(0.75, 0), Vector2.RIGHT, Vector2(0.7, 0.02), 7.8, 8.8)


## Rows of barred classroom windows along every wall longer than 5 m, one row per storey.
static func _window_rows(ring: PackedVector2Array, centre: Vector2, storeys: int, surfaces: Dictionary, materials: Dictionary) -> void:
	var window := RealChunkBuilder._tool("panel_window", surfaces, materials, PixelMaterials.panel("window_bars"))
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var length := p0.distance_to(p1)
		if length < 5.0:
			continue
		var tangent := (p1 - p0) / length
		var normal := Vector2(-tangent.y, tangent.x)
		if normal.dot((p0 + p1) * 0.5 - centre) < 0.0:
			normal = -normal
		var count := int((length - 1.0) / 3.0)
		for k in count:
			var mid := p0 + tangent * (length - (count - 1) * 3.0) * 0.5 + tangent * k * 3.0
			for s in storeys:
				var y := s * SCHOOL_STOREY
				RealChunkBuilder._panel(window, mid, tangent, normal, 1.8, y + 1.0, y + 2.4)


## A painted sign band round the top of a shop: the parapet's outer face in the band colour.
static func _sign_band(ring: PackedVector2Array, centre: Vector2, h: float, band_h: float, band: SurfaceTool) -> void:
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var out := Vector3(p0.x + p1.x, 0, p0.y + p1.y) * 0.5 - Vector3(centre.x, 0, centre.y)
		var push := RealChunkBuilder._wall_normal(p0, p1, out) * 0.03
		RealChunkBuilder._quad(band, RealChunkBuilder._v(p0 + push, h), RealChunkBuilder._v(p1 + push, h), band_h, out)
		RealChunkBuilder._quad(band, RealChunkBuilder._v(p0, h), RealChunkBuilder._v(p1, h), band_h, -out)


## Along the front wall: roller-shuttered shopfronts and a veranda on posts.
static func _shopfront(ring: PackedVector2Array, front: Dictionary, surfaces: Dictionary, materials: Dictionary) -> void:
	var i: int = front.index
	var p0 := ring[i]
	var p1 := ring[(i + 1) % ring.size()]
	var length := p0.distance_to(p1)
	var t := (p1 - p0) / maxf(length, 0.01)
	var n: Vector2 = front.normal
	var shutter := RealChunkBuilder._tool("panel_shutter", surfaces, materials, PixelMaterials.panel("garage_door"))
	var count := maxi(1, int(length / 4.0))
	for k in count:
		var mid := p0 + t * (length / count) * (k + 0.5)
		RealChunkBuilder._panel(shutter, mid, t, n, minf(3.0, length / count - 0.6), 0.0, 2.6)
	var mid_all := (p0 + p1) * 0.5 + n * VERANDA_DEPTH * 0.5
	_obox(_mat("veranda", "#8a8f96", surfaces, materials), mid_all, t, Vector2(length * 0.5, VERANDA_DEPTH * 0.5), VERANDA_HEIGHT, VERANDA_HEIGHT + 0.15)
	var steel := _mat("steel", STEEL, surfaces, materials)
	var posts := maxi(2, int(length / 4.0) + 1)
	for k in posts:
		var at := p0 + t * (0.3 + (length - 0.6) * k / (posts - 1)) + n * (VERANDA_DEPTH - 0.2)
		_obox(steel, at, t, Vector2(0.06, 0.06), 0.0, VERANDA_HEIGHT)


## A forecourt canopy between the kiosk and the road, on four columns, over two pump islands. Left
## out when the kiosk is too close to the road for one.
static func _forecourt(front: Dictionary, near_roads: Array, seed_value: int, surfaces: Dictionary, materials: Dictionary) -> void:
	var n: Vector2 = front.normal
	var t := _tangent(front)
	var room := RealChunkBuilder._distance_to_lines(front.mid, near_roads) - 6.0 if not near_roads.is_empty() else 14.0
	var depth := clampf(room - 2.0, 0.0, 11.0)
	if depth < 6.0:
		return
	var mid: Vector2 = front.mid + n * (2.0 + depth * 0.5)
	var half := Vector2(8.0, depth * 0.5)
	var band: String = FORECOURT_BANDS[seed_value % FORECOURT_BANDS.size()]
	_obox(_mat("canopy", "#eeeae2", surfaces, materials), mid, t, half, CANOPY_HEIGHT, CANOPY_HEIGHT + 0.25)
	_obox(_mat("band_" + band, band, surfaces, materials), mid, t, half + Vector2(0.05, 0.05), CANOPY_HEIGHT + 0.25, CANOPY_HEIGHT + 0.95)
	var steel := _mat("coping", RealChunkBuilder.COPING_COLOR, surfaces, materials)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_obox(steel, mid + t * sx * (half.x - 2.0) + n * sy * (half.y - 1.5), t, Vector2(0.25, 0.25), 0.0, CANOPY_HEIGHT)
		var island := mid + t * sx * 3.5
		_obox(steel, island, n, Vector2(2.2, 0.6), 0.0, 0.2)
		_obox(_mat("pump", "#d9d4c8", surfaces, materials), island, n, Vector2(0.35, 0.3), 0.2, 1.9)
		_obox(_mat("band_" + band, band, surfaces, materials), island, n, Vector2(0.37, 0.32), 1.5, 1.9)


## A roof on columns over the outline (a forecourt canopy in the data): no walls.
static func _canopy_on_columns(ring: PackedVector2Array, rect: Dictionary, height: float, band: String, surfaces: Dictionary, materials: Dictionary) -> void:
	var slab := _mat("canopy", "#eeeae2", surfaces, materials)
	var idx := Geometry2D.triangulate_polygon(ring)
	for i in range(0, idx.size(), 3):
		var a := RealChunkBuilder._v(ring[idx[i]], height)
		var b := RealChunkBuilder._v(ring[idx[i + 1]], height)
		var c := RealChunkBuilder._v(ring[idx[i + 2]], height)
		RealChunkBuilder._facing(slab, a, b, c, Vector3.DOWN)
		RealChunkBuilder._facing(slab, a + Vector3.UP * 0.9, b + Vector3.UP * 0.9, c + Vector3.UP * 0.9, Vector3.UP)
	var centre: Vector2 = rect.c
	var band_tool := _mat("band_" + band, band, surfaces, materials)
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var out := RealChunkBuilder._v((p0 + p1) * 0.5 - centre, 0.0)
		RealChunkBuilder._quad(band_tool, RealChunkBuilder._v(p0, height), RealChunkBuilder._v(p1, height), 0.9, out)
	var half: Vector2 = rect.half
	var steel := _mat("coping", RealChunkBuilder.COPING_COLOR, surfaces, materials)
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			var at: Vector2 = centre + (rect.u as Vector2) * su * maxf(0.5, half.x - 2.0) + (rect.v as Vector2) * sv * maxf(0.5, half.y - 2.0)
			_obox(steel, at, rect.u, Vector2(0.25, 0.25), 0.0, height)


## A community mural or a crew tag on the longest wall that is not the front, on one building in two.
static func _mural(ring: PackedVector2Array, centre: Vector2, front: Dictionary, seed_value: int, y0: float, y1: float, surfaces: Dictionary, materials: Dictionary) -> void:
	if seed_value % 2 != 0:
		return
	var best := -1
	var best_len := 7.0
	for i in ring.size():
		if not front.is_empty() and i == int(front.index):
			continue
		var l := ring[i].distance_to(ring[(i + 1) % ring.size()])
		if l > best_len:
			best_len = l
			best = i
	if best < 0:
		return
	var p0 := ring[best]
	var p1 := ring[(best + 1) % ring.size()]
	var t := (p1 - p0).normalized()
	var n := Vector2(-t.y, t.x)
	if n.dot((p0 + p1) * 0.5 - centre) < 0.0:
		n = -n
	var art: String = ["mural_plain", "mural_mountain", "tag_tortel", "tag_klip"][(seed_value / 2) % 4]
	var tag := art.begins_with("tag")
	var width := minf(best_len - 1.0, 2.6 if tag else 6.5)
	var top := y0 + width * (20.0 / 48.0)
	RealChunkBuilder._panel(RealChunkBuilder._tool("panel_" + art, surfaces, materials, PixelMaterials.panel(art, Color.WHITE, tag)), (p0 + p1) * 0.5, t, n, width, y0, minf(top, y1))


# ------------------------------------------------------------------ solids

## A box standing on the ground plane from y0 to y1: centre `at`, long axis `u`, half sizes `half` (along u, across).
static func _obox(st: SurfaceTool, at: Vector2, u: Vector2, half: Vector2, y0: float, y1: float) -> void:
	var v := Vector2(-u.y, u.x)
	var c := [at - u * half.x - v * half.y, at + u * half.x - v * half.y, at + u * half.x + v * half.y, at - u * half.x + v * half.y]
	for i in 4:
		var p0: Vector2 = c[i]
		var p1: Vector2 = c[(i + 1) % 4]
		RealChunkBuilder._quad(st, RealChunkBuilder._v(p0, y0), RealChunkBuilder._v(p1, y0), y1 - y0, RealChunkBuilder._v((p0 + p1) * 0.5 - at, 0.0))
	RealChunkBuilder._up(st, RealChunkBuilder._v(c[0], y1), RealChunkBuilder._v(c[1], y1), RealChunkBuilder._v(c[2], y1))
	RealChunkBuilder._up(st, RealChunkBuilder._v(c[0], y1), RealChunkBuilder._v(c[2], y1), RealChunkBuilder._v(c[3], y1))
	RealChunkBuilder._facing(st, RealChunkBuilder._v(c[0], y0), RealChunkBuilder._v(c[1], y0), RealChunkBuilder._v(c[2], y0), Vector3.DOWN)
	RealChunkBuilder._facing(st, RealChunkBuilder._v(c[0], y0), RealChunkBuilder._v(c[2], y0), RealChunkBuilder._v(c[3], y0), Vector3.DOWN)


## An upright prism (a cylinder with `sides` faces) of radius r from y0 to y1, capped on top when `cap`.
static func _prism(st: SurfaceTool, at: Vector2, r: float, sides: int, y0: float, y1: float, cap: bool) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := at + Vector2(cos(a0), sin(a0)) * r
		var p1 := at + Vector2(cos(a1), sin(a1)) * r
		RealChunkBuilder._quad(st, RealChunkBuilder._v(p0, y0), RealChunkBuilder._v(p1, y0), y1 - y0, RealChunkBuilder._v((p0 + p1) * 0.5 - at, 0.0))
		if cap:
			RealChunkBuilder._up(st, RealChunkBuilder._v(at, y1), RealChunkBuilder._v(p0, y1), RealChunkBuilder._v(p1, y1))
			RealChunkBuilder._facing(st, RealChunkBuilder._v(at, y0), RealChunkBuilder._v(p0, y0), RealChunkBuilder._v(p1, y0), Vector3.DOWN)


## A half sphere of radius r sitting on `base`.
static func _dome(st: SurfaceTool, base: Vector3, r: float, sides: int, rings: int) -> void:
	for j in rings:
		var b0 := PI * 0.5 * j / rings
		var b1 := PI * 0.5 * (j + 1) / rings
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var p00 := base + Vector3(cos(a0) * cos(b0), sin(b0), sin(a0) * cos(b0)) * r
			var p10 := base + Vector3(cos(a1) * cos(b0), sin(b0), sin(a1) * cos(b0)) * r
			var p01 := base + Vector3(cos(a0) * cos(b1), sin(b1), sin(a0) * cos(b1)) * r
			var p11 := base + Vector3(cos(a1) * cos(b1), sin(b1), sin(a1) * cos(b1)) * r
			var out := ((p00 + p11) * 0.5 - base)
			RealChunkBuilder._facing(st, p00, p10, p11, out)
			if j < rings - 1:
				RealChunkBuilder._facing(st, p00, p11, p01, out)


## A square pyramid roof (half size `half`) from y0 up to a point at y1.
static func _pyramid(st: SurfaceTool, at: Vector2, u: Vector2, half: float, y0: float, y1: float) -> void:
	var v := Vector2(-u.y, u.x)
	var c := [at - u * half - v * half, at + u * half - v * half, at + u * half + v * half, at - u * half + v * half]
	var apex := RealChunkBuilder._v(at, y1)
	for i in 4:
		var p0: Vector2 = c[i]
		var p1: Vector2 = c[(i + 1) % 4]
		RealChunkBuilder._facing(st, RealChunkBuilder._v(p0, y0), RealChunkBuilder._v(p1, y0), apex, RealChunkBuilder._v((p0 + p1) * 0.5 - at, 0.0) + Vector3.UP)
