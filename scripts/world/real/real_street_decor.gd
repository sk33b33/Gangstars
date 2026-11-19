class_name RealStreetDecor
extends RefCounted
## The details that make the real Westridge streets look lived in: speed humps on residential
## streets, stop lines and STOP where a side street meets a bigger road, zebra crossings by schools
## and shops, grass medians between dual carriageways, wooden power poles with sagging wires (and
## the odd pair of sneakers), wear (potholes, tar patches, oil, sand in the gutters, litter), drain
## grates and manholes, bus and taxi stops, and the trees along Park Avenue.
## Worked out from a chunk's roads and RealDistrictData.street_context only, so a street always
## looks the same. Nothing here blocks people (no navigation obstacles): it is flat, thin or overhead.
## Design: design/gdd/real_world.md ("Street details").

const RANKS := {"path": 0, "lane": 1, "street": 2, "collector": 3, "main": 4}
## Kinds of real place that get a zebra crossing on the road nearest them, and how far away that road may be.
const CROSSING_KINDS := ["school", "retail", "kindergarten", "clinic", "community_centre", "convenience", "mall"]
const CROSSING_REACH := 70.0
const Y_GROUND_DECAL := 0.0245   # above the verge, footway and kerb
const Y_MEDIAN := 0.0222         # above the footway and verge, below the kerb
const Y_ROAD_DECAL := 0.035      # above the asphalt, below the paint
const MEDIAN_MIN_GAP := 1.0      # a gap narrower than this, at either carriageway's middle (a taper at a junction), gets no grass
const HUMP_MIN_PIECE := 70.0
const HUMP_HEIGHT := 0.08
const HUMP_LENGTH := 3.6
const STOP_BACK := 1.2           # stop line this far before the crossing road's kerb
const POLE_SPACING := 38.0
const POLE_HEIGHT := 8.5
const WIRE_SAG := 0.6
const SNEAKER_ONE_IN := 12
const STOP_MIN_PIECE := 120.0    # bus / taxi stop on main roads and collectors at least this long
const TREE_STREETS := ["Park Avenue"]
const TREE_SPACING := 14.0
const PAINT := "#f1eee8"
const WOOD := "#6b4a33"
const WIRE := "#26262a"


static func rank(cls: String) -> int:
	return int(RANKS.get(cls, 1))


## Road piece ends that meet are within a centimetre or two of each other: half-metre cells join them.
static func node_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 2.0), roundi(p.y * 2.0))


## Where a chunk's speed humps are (the same rule the builder uses), without building anything.
static func humps_of(roads: Array) -> Array:
	var out: Array = []
	for r: Dictionary in roads:
		var hump_at := hump_distance(r)
		if hump_at >= 0.0:
			out.append(at_distance(RealChunkBuilder._line(r.p), hump_at)[0])
	return out


## Metres along the road piece where its speed hump is, or -1 when it has none. Fixed by the piece's first point.
static func hump_distance(r: Dictionary) -> float:
	if str(r.c) != "street":
		return -1.0
	var line := RealChunkBuilder._line(r.p)
	if line.size() < 2:
		return -1.0
	var length := RealChunkBuilder._length(line)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(line[0].x * 10.0), roundi(line[0].y * 10.0)))
	if length >= HUMP_MIN_PIECE and rng.randi() % 2 == 0:
		return length * (0.35 + rng.randf() * 0.3)
	return -1.0


## Adds the street details of a chunk. `props`: {prop name: Array[Transform3D]} filled for the
## builder's MultiMeshes (trees).
## `humps`: receives the speed humps' middle points (Vector2), for cars to slow down at.
static func build(roads: Array, ctx: Dictionary, surfaces: Dictionary, materials: Dictionary, props: Dictionary, humps: Array = [], root: Node3D = null) -> void:
	var lamps: PackedVector3Array = ctx.get("lamps", PackedVector3Array())
	for r: Dictionary in roads:
		var cls := str(r.c)
		if cls == "path" or cls == "lane":
			continue
		var line := RealChunkBuilder._line(r.p)
		if line.size() < 2:
			continue
		var width := float(r.w)
		var pave := float(r.get("s", 0.0))
		var length := RealChunkBuilder._length(line)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(roundi(line[0].x * 10.0), roundi(line[0].y * 10.0)))
		if cls == "street" and length >= HUMP_MIN_PIECE and rng.randi() % 2 == 0:
			var hump_at := length * (0.35 + rng.randf() * 0.3)
			_hump(line, hump_at, width, surfaces, materials)
			humps.append(at_distance(line, hump_at)[0])
		_stop_lines(r, line, width, ctx.get("nodes", {}), surfaces, materials)
		if cls == "main" and int(r.get("o", 0)) != 0:
			_median(line, width, str(r.get("n", "")), ctx.get("oneways", []), surfaces, materials)
		var poles: Array = []
		if cls == "street" or cls == "collector":
			poles = _power_line(line, width, pave, lamps, rng, surfaces, materials)
		_wear(cls, line, width, pave, length, rng, surfaces, materials)
		if pave >= FURNITURE_MIN_PAVE:
			street_furniture(cls, line, width, length, lamps, poles, rng, props)
		if (cls == "main" or cls == "collector") and length >= STOP_MIN_PIECE and pave >= 2.0:
			_shelter(line, width, length, rng, surfaces, materials, props)
		if str(r.get("n", "")) in TREE_STREETS and pave > 0.0:
			_street_trees(line, width, pave, lamps, poles, rng, props)
		elif pave >= GREEN_MIN_PAVE and cls != "lane":
			_verge_greenery(line, width, pave, cls, length, lamps, poles, rng, props)
	for c: Dictionary in ctx.get("crossings", []):
		_zebra(c.at, c.dir, float(c.w), surfaces, materials)
	_street_slabs(roads, ctx, surfaces, materials, root)


# ------------------------------------------------------------------ verge greenery

const GREEN_MIN_PAVE := 1.4
const GREEN_END_CLEAR := 9.0      # no planting this close to a junction (the stop signs, name blocks and crossings are there)
const TREE_SPACING_MIN := 12.0
const BUSHES := ["bush", "bush", "bush_pink", "bush_yellow", "bush_white"]
const BEDS := ["flowers_pink", "flowers_yellow", "flowers_purple"]
const TUFTS := ["grass_green", "grass_dry", "grass_green"]


## Trees, shrubs, flower beds and grass at the back of the verge on both sides of a street: a tree now and then (palms on the
## bigger roads), bushes, flower beds and tufts in between. Clear of lamps and power poles, the junction ends and the bus shelter.
static func _verge_greenery(line: PackedVector2Array, width: float, pave: float, cls: String, length: float, lamps: PackedVector3Array, poles: Array, rng: RandomNumberGenerator, props: Dictionary) -> void:
	var offset := width * 0.5 + maxf(0.8, minf(pave, RealYards.PAVE_KEEP) - 0.3)
	for side: float in [-1.0, 1.0]:
		var dist := GREEN_END_CLEAR + rng.randf() * 4.0
		var last_tree := -100.0
		while dist < length - GREEN_END_CLEAR:
			var step := 3.0 + rng.randf() * 3.5
			var here: Array = at_distance(line, dist)
			var p: Vector2 = here[0] + left_of(here[1]) * offset * side
			var clear := absf(dist - length * 0.5) > 4.0 or cls == "street"
			for l in lamps:
				if Vector2(l.x, l.z).distance_to(p) < 2.2:
					clear = false
			for pole: Array in poles:
				if (pole[0] as Vector2).distance_to(p) < 2.8:
					clear = false
			if clear and rng.randf() < 0.9:
				var roll := rng.randf()
				if roll < 0.28 and dist - last_tree >= TREE_SPACING_MIN:
					last_tree = dist
					var tree := "tree_c" if rng.randi() % 3 == 0 else ("tree_a" if rng.randi() % 2 == 0 else "tree_b")
					if cls != "street" and rng.randi() % 3 == 0:
						tree = "palm"
					add_prop(props, tree, p, rng.randf() * TAU, rng.randf_range(0.8, 1.15))
				elif roll < 0.5:
					add_prop(props, BUSHES[rng.randi() % BUSHES.size()], p, rng.randf() * TAU, rng.randf_range(0.8, 1.2))
				elif roll < 0.75:
					add_prop(props, BEDS[rng.randi() % BEDS.size()], p, here[1].angle() + (PI * 0.5 if rng.randi() % 2 == 0 else 0.0))
				else:
					for k in 2:
						add_prop(props, TUFTS[rng.randi() % TUFTS.size()], p + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)), rng.randf() * TAU, rng.randf_range(0.8, 1.4))
			dist += step


# ------------------------------------------------------------------ street furniture

const FURNITURE_MIN_PAVE := 1.2
const HYDRANT_SPACING := 110.0
const BIN_SPACING := 70.0       # public litter bins on collectors and main roads
const BENCH_SPACING := 130.0
const WHEELIE_SPACING := 42.0   # wheelie bins put out at the kerb on ordinary streets
const WEED_SPACING := 7.0


## What stands on a street's pavement: fire hydrants, wheelie bins put out at the kerb, public litter bins and benches on the bigger
## roads, a post box, and tufts of dry grass growing from the kerb. Clear of lamps, power poles and the junction ends.
static func street_furniture(cls: String, line: PackedVector2Array, width: float, length: float, lamps: PackedVector3Array, poles: Array, rng: RandomNumberGenerator, props: Dictionary) -> void:
	var kerb := width * 0.5 + RealChunkBuilder.KERB_WIDTH
	var big := cls == "main" or cls == "collector"
	var side := 1.0 if rng.randi() % 2 == 0 else -1.0
	var rows: Array = [["fire_hydrant", HYDRANT_SPACING, 0.5], ["litter_bin", BIN_SPACING if big else 0.0, 0.9], ["park_bench", BENCH_SPACING if big else 0.0, 1.4],
		["wheelie_bin", 0.0 if big else WHEELIE_SPACING, 0.55]]
	for row: Array in rows:
		var spacing := float(row[1])
		if spacing <= 0.0:
			continue
		var dist := GREEN_END_CLEAR + rng.randf() * spacing
		while dist < length - GREEN_END_CLEAR:
			var here: Array = at_distance(line, dist)
			var out: Vector2 = left_of(here[1]) * side
			var p: Vector2 = here[0] + out * (kerb + float(row[2]))
			if _free_of_posts(p, lamps, poles, 1.6) and (str(row[0]) != "wheelie_bin" or rng.randf() < 0.55):
				var face := out if str(row[0]) == "park_bench" else -out   # a bench looks at the houses, the rest at the road
				add_prop(props, str(row[0]), p, atan2(face.x, face.y) if str(row[0]) != "wheelie_bin" else rng.randf_range(-0.3, 0.3) + atan2(face.x, face.y))
			side = -side
			dist += spacing * rng.randf_range(0.8, 1.25)
	if length >= 60.0 and rng.randf() < 0.45:
		var here: Array = at_distance(line, length * rng.randf_range(0.3, 0.7))
		var out: Vector2 = left_of(here[1]) * side
		var p: Vector2 = here[0] + out * (kerb + 0.6)
		if _free_of_posts(p, lamps, poles, 1.8):
			add_prop(props, "post_box", p, atan2(-out.x, -out.y))
	var dist := rng.randf() * WEED_SPACING
	while dist < length:
		var here: Array = at_distance(line, dist)
		var s := 1.0 if rng.randi() % 2 == 0 else -1.0
		add_prop(props, "grass_dry", here[0] + left_of(here[1]) * s * (kerb + 0.07), rng.randf() * TAU, rng.randf_range(0.35, 0.7))
		dist += WEED_SPACING * rng.randf_range(0.6, 1.6)


static func _free_of_posts(p: Vector2, lamps: PackedVector3Array, poles: Array, clear: float) -> bool:
	for l in lamps:
		if Vector2(l.x, l.z).distance_to(p) < clear:
			return false
	for pole: Array in poles:
		if (pole[0] as Vector2).distance_to(p) < clear:
			return false
	return true


# ------------------------------------------------------------------ street name slabs

## The STOP sign: the octagon from 1.55 m to 2.3 m sits on top of its pole, which ends at the octagon's lower edge.
const STOP_SIGN_BOTTOM := 1.55
const STOP_SIGN_TOP := 2.3
const STOP_POLE_TOP := 1.55
const SLAB_COLOR := "#ebe8df"
const BLOCK_LENGTH := 1.0
const BLOCK_DEPTH := 0.105
const BLOCK_HEIGHT := 0.265
const BLOCK_STEP := 0.125
const BLOCK_BACKOFF := [0.0, 0.3, 0.6, 1.0]   # metres the block may be moved back from the kerb when a bend leaves it on the road
const BLOCK_SETBACK := 0.15   # from the kerb to the block's front face
const ABBREV := {"Street": "St", "Avenue": "Ave", "Road": "Rd", "Close": "Cl", "Drive": "Dr", "Crescent": "Cres", "Court": "Ct", "Place": "Pl", "Way": "Way", "Lane": "Ln"}


## "Excelsior Street" -> "EXCELSIOR ST": the names are short enough for a small slab.
static func short_name(street: String) -> String:
	var words := street.split(" ")
	if words.size() > 1 and ABBREV.has(words[words.size() - 1]):
		words[words.size() - 1] = ABBREV[words[words.size() - 1]]
	return " ".join(words).to_upper()


## A squat white-painted concrete slab on the pavement corner of a junction, the two street names on both faces (the way
## suburban South African corners are marked). One per junction, placed by the chunk the junction lies in.
static func _street_slabs(roads: Array, ctx: Dictionary, surfaces: Dictionary, materials: Dictionary, root: Node3D) -> void:
	var nodes: Dictionary = ctx.get("nodes", {})
	var chunk_key: Vector2i = ctx.get("key", Vector2i(9999, 9999))
	var size := 200.0
	var done := {}
	for r: Dictionary in roads:
		var line := RealChunkBuilder._line(r.p)
		if line.size() < 2 or not str(r.c) in ["street", "collector", "main"]:
			continue
		for end: Vector2 in [line[0], line[line.size() - 1]]:
			var nk := node_key(end)
			if done.has(nk):
				continue
			done[nk] = true
			if Vector2i(floori(end.x / size), floori(end.y / size)) != chunk_key:
				continue   # the neighbour chunk places its own
			var pair := _slab_pair(nodes.get(nk, []))
			if pair.is_empty():
				continue
			_slab(end, pair[0], pair[1], roads, surfaces, materials, root)


## Two entries of a junction with different street names (the biggest roads first), or [].
static func _slab_pair(entries: Array) -> Array:
	var named: Array = entries.filter(func(e: Array): return int(e[0]) >= 2 and not str(e[2]).is_empty())
	named.sort_custom(func(a: Array, b: Array): return int(a[0]) > int(b[0]))
	for i in named.size():
		for j in range(i + 1, named.size()):
			if str(named[i][2]) != str(named[j][2]) and absf((named[i][3] as Vector2).dot(named[j][3])) < 0.8:
				return [named[i], named[j]]
	return []


static func _slab(node: Vector2, a: Array, b: Array, roads: Array, surfaces: Dictionary, materials: Dictionary, root: Node3D) -> void:
	# One block for each street, lying along that street just behind its kerb, on the corner's side of the junction.
	_name_block(node, a, b, roads, surfaces, materials, root)
	_name_block(node, b, a, roads, surfaces, materials, root)


## Where the block for street `own` stands at its junction with `other`: the middle of its back face, the direction from the block to the
## road, and the direction the name runs. It lies along `own` clear of `other`'s kerb (which a slanted junction pushes further along `own`).
static func block_frame(node: Vector2, own: Array, other: Array, roads: Array = []) -> Dictionary:
	var along: Vector2 = own[3]
	var side: Vector2 = other[3]   # the corner is on this side of `own`
	var toward := left_of(along)   # horizontal and across the street
	if toward.dot(side) > 0.0:
		toward = -toward           # the face looks at the road: away from the corner's side
	var kerb := RealChunkBuilder.KERB_WIDTH
	var front_gap := float(own[1]) * 0.5 + kerb + BLOCK_SETBACK   # centre line of the street to the block's front face
	var slant := maxf(absf(along.cross(side)), 0.45)   # a junction that is not square: the other road's kerb crosses `own` further out
	var clear := (float(other[1]) * 0.5 + kerb) / slant + 0.6 + BLOCK_LENGTH * 0.5
	var u := left_of(toward)
	var back_at := node + along * clear - toward * (front_gap + BLOCK_DEPTH)
	# Streets bend, so the straight-line spot can land on a carriageway: step the block back until it is clear of every road, or give up.
	for slide: float in [0.0, 1.5, 3.0]:   # a bend may also be avoided by standing further along the street
		for extra: float in BLOCK_BACKOFF:
			var at := back_at + along * slide - toward * extra
			if block_clear(at, toward, u, roads):
				return {"toward": toward, "u": u, "back_at": at, "clear": true}
	return {"toward": toward, "u": u, "back_at": back_at, "clear": roads.is_empty()}


## True when the block's four footprint corners are all off the carriageways and kerbs of `roads`.
static func block_clear(back_at: Vector2, toward: Vector2, u: Vector2, roads: Array) -> bool:
	var corners: Array[Vector2] = []
	for su: float in [-0.5, 0.5]:
		for st: float in [0.0, BLOCK_DEPTH]:
			corners.append(back_at + u * su * BLOCK_LENGTH + toward * st)
	for r: Dictionary in roads:
		if not str(r.c) in ["street", "collector", "main"]:
			continue
		var line := RealChunkBuilder._line(r.p)
		var need := float(r.w) * 0.5 + RealChunkBuilder.KERB_WIDTH
		for c: Vector2 in corners:
			for i in line.size() - 1:
				if c.distance_to(Geometry2D.get_closest_point_to_segment(c, line[i], line[i + 1])) < need:
					return false
	return true


## The concrete street name block (1 m x 105 mm, 265 mm high at the back, a 125 mm step in front, the name on the sloping face),
## white-painted, with the street's name in black, standing behind the kerb of street `own` at the corner with street `other`.
static func _name_block(node: Vector2, own: Array, other: Array, roads: Array, surfaces: Dictionary, materials: Dictionary, root: Node3D) -> void:
	var frame := block_frame(node, own, other, roads)
	if not frame.clear:
		return   # no clear spot on this corner: no block rather than one standing in the road
	var toward: Vector2 = frame.toward
	var back_at: Vector2 = frame.back_at
	var u: Vector2 = frame.u
	var concrete := _flat("slab", SLAB_COLOR, surfaces, materials)
	var sect: Array[Vector2] = [Vector2(0, 0), Vector2(BLOCK_DEPTH, 0), Vector2(BLOCK_DEPTH, BLOCK_STEP), Vector2(BLOCK_DEPTH - 0.02, BLOCK_STEP + 0.015),
		Vector2(BLOCK_DEPTH - 0.035, BLOCK_HEIGHT), Vector2(0, BLOCK_HEIGHT)]
	var half := BLOCK_LENGTH * 0.5
	var n3 := Vector3(toward.x, 0, toward.y)
	var u3 := Vector3(u.x, 0, u.y)
	var base := Vector3(back_at.x, 0, back_at.y)
	for i in sect.size():   # the long faces, each facing out of the section
		var p0 := sect[i]
		var p1 := sect[(i + 1) % sect.size()]
		var out := n3 * (p1.y - p0.y) + Vector3.UP * (p0.x - p1.x)   # outward for the counter-clockwise section
		var q := [base + n3 * p0.x + Vector3.UP * p0.y - u3 * half, base + n3 * p0.x + Vector3.UP * p0.y + u3 * half,
			base + n3 * p1.x + Vector3.UP * p1.y + u3 * half, base + n3 * p1.x + Vector3.UP * p1.y - u3 * half]
		RealChunkBuilder._facing(concrete, q[0], q[1], q[2], out)
		RealChunkBuilder._facing(concrete, q[0], q[2], q[3], out)
	var idx := Geometry2D.triangulate_polygon(PackedVector2Array(sect))
	for end_s: float in [-1.0, 1.0]:   # the two ends
		for k in range(0, idx.size(), 3):
			var c: Array = []
			for j in 3:
				var sp := sect[idx[k + j]]
				c.append(base + n3 * sp.x + Vector3.UP * sp.y + u3 * half * end_s)
			RealChunkBuilder._facing(concrete, c[0], c[1], c[2], u3 * end_s)
	if root == null or str(own[2]).is_empty():
		return
	# The name, on the sloping face, in black capitals sized to fit the metre.
	var name_text := str(own[2]).to_upper()
	var label := Label3D.new()
	label.text = name_text
	label.font_size = 40
	label.pixel_size = minf(0.0022, 0.86 / (maxf(float(name_text.length()), 1.0) * 26.0))
	label.shaded = false
	label.double_sided = false
	label.modulate = Color("#141418")
	label.outline_size = 0
	var face_n := (n3 * (BLOCK_HEIGHT - BLOCK_STEP - 0.015) + Vector3.UP * 0.015).normalized()   # the sloping face's normal
	var mid_d := BLOCK_DEPTH - 0.0275
	var mid_h := (BLOCK_STEP + 0.015 + BLOCK_HEIGHT) * 0.5
	label.position = base + n3 * (mid_d + 0.003) + Vector3.UP * mid_h
	var xa := u3
	var ya := face_n.cross(xa)
	label.basis = Basis(xa, ya, face_n)
	label.visibility_range_end = 30.0
	label.set_meta("street_slab", true)
	root.add_child(label)


# ------------------------------------------------------------------ helpers

## Queues one prop (a PropLibrary mesh) for the chunk's MultiMesh of that prop.
static func add_prop(props: Dictionary, prop: String, p: Vector2, rot: float, scale := 1.0, y := 0.0) -> void:
	if not props.has(prop):
		props[prop] = []
	props[prop].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * scale), Vector3(p.x, y, p.y)))


static func _flat(key: String, color: String, surfaces: Dictionary, materials: Dictionary) -> SurfaceTool:
	return RealChunkBuilder._tool(key, surfaces, materials, PixelMaterials.flat(Color(color)))


static func _decal_tool(tex: String, surfaces: Dictionary, materials: Dictionary) -> SurfaceTool:
	return RealChunkBuilder._tool("decal_" + tex, surfaces, materials, PixelMaterials.panel(tex, Color.WHITE, true))


## A textured rectangle standing on end, facing `normal` (the way the sign looks, towards whoever reads it), centred on `mid`,
## `width` across, from y0 to y1, with the texture the right way round and not mirrored: a viewer looking at it has the viewer's
## right = left_of(normal) (x east, z south). (RealChunkBuilder._panel is for walls: its flip rule mirrors a sign on a pole.)
## How far a sign plate stands in front of the middle of its pole: more than the pole's half thickness (0.04 m), so the pole is
## behind the plate and never shows across the face of the sign.
const SIGN_STANDOFF := 0.06


static func face_quad(st: SurfaceTool, mid: Vector2, normal: Vector2, width: float, y0: float, y1: float, standoff := SIGN_STANDOFF) -> void:
	var right := left_of(normal)
	var m := mid + normal * standoff
	var bl := m - right * width * 0.5
	var br := m + right * width * 0.5
	var corners := [Vector3(bl.x, y0, bl.y), Vector3(br.x, y0, br.y), Vector3(br.x, y1, br.y), Vector3(bl.x, y1, bl.y)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k: int in [0, 2, 1, 0, 3, 2]:   # clockwise seen from the front: Godot's front face
		st.set_uv(uvs[k])
		st.set_normal(Vector3(normal.x, 0, normal.y))
		st.add_vertex(corners[k])


## The point `dist` metres along the polyline and the direction there.
static func at_distance(line: PackedVector2Array, dist: float) -> Array:
	var walked := 0.0
	for i in line.size() - 1:
		var seg := line[i + 1] - line[i]
		var l := seg.length()
		if l <= 0.0001:
			continue
		if walked + l >= dist:
			return [line[i] + seg / l * (dist - walked), seg / l]
		walked += l
	var last := (line[line.size() - 1] - line[line.size() - 2]).normalized()
	return [line[line.size() - 1], last]


## The driver's left for a direction of travel (x east, z south): keep-left traffic drives on this side.
static func left_of(d: Vector2) -> Vector2:
	return Vector2(d.y, -d.x)


## A textured quad lying flat: centre c, `d` along its length (the texture's top towards +d),
## `width` across, `length` along, at height y.
static func decal(st: SurfaceTool, c: Vector2, d: Vector2, width: float, length: float, y: float) -> void:
	var left := left_of(d)
	var fl := c + d * length * 0.5 + left * width * 0.5
	var fr := c + d * length * 0.5 - left * width * 0.5
	var br := c - d * length * 0.5 - left * width * 0.5
	var bl := c - d * length * 0.5 + left * width * 0.5
	var pts := [fl, fr, br, bl]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[k])
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(pts[k].x, y, pts[k].y))


# ------------------------------------------------------------------ details

## A speed hump across the road (the gutters stay open), painted in the hump stripes.
static func _hump(line: PackedVector2Array, dist: float, width: float, surfaces: Dictionary, materials: Dictionary) -> void:
	var here: Array = at_distance(line, dist)
	var c: Vector2 = here[0]
	var d: Vector2 = here[1]
	var left := left_of(d)
	var half_w := width * 0.5 - RealChunkBuilder.GUTTER_WIDTH
	var st := RealChunkBuilder._tool("hump", surfaces, materials, PixelMaterials.panel("speed_hump"))
	var y0 := RealChunkBuilder.Y_ROAD + 0.002
	var steps := [[-HUMP_LENGTH * 0.5, y0], [-HUMP_LENGTH * 0.25, y0 + HUMP_HEIGHT], [HUMP_LENGTH * 0.25, y0 + HUMP_HEIGHT], [HUMP_LENGTH * 0.5, y0]]
	# The stripe texture is 32 x 8 px; one tile is 4 m across and 1 m along, so a pixel is 12.5 cm both ways and the slanted stripes keep
	# their angle on the ramps and the top alike (the texture is mapped by metres, not stretched to each piece).
	var u := half_w * 2.0 / 4.0
	for k in 3:
		var a: Array = steps[k]
		var b: Array = steps[k + 1]
		var v0 := float(a[0]) + HUMP_LENGTH * 0.5
		var v1 := float(b[0]) + HUMP_LENGTH * 0.5
		var p0 := c + d * float(a[0])
		var p1 := c + d * float(b[0])
		var quad := [Vector3((p0 + left * half_w).x, a[1], (p0 + left * half_w).y), Vector3((p0 - left * half_w).x, a[1], (p0 - left * half_w).y),
			Vector3((p1 - left * half_w).x, b[1], (p1 - left * half_w).y), Vector3((p1 + left * half_w).x, b[1], (p1 + left * half_w).y)]
		var uvs := [Vector2(0, v0), Vector2(u, v0), Vector2(u, v1), Vector2(0, v1)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[i])
			st.add_vertex(quad[i])
		for i: int in [0, 2, 1, 0, 3, 2]:   # both windings: seen from either way along the road
			st.set_uv(uvs[i])
			st.add_vertex(quad[i])


## A stop line across the arriving lane and STOP painted before it, at each end of a piece that
## meets a bigger road.
static func _stop_lines(r: Dictionary, line: PackedVector2Array, width: float, nodes: Dictionary, surfaces: Dictionary, materials: Dictionary) -> void:
	var own := rank(str(r.c))
	for end_i: int in [0, line.size() - 1]:
		var e := line[end_i]
		var inward := (e - line[1]).normalized() if end_i == 0 else (e - line[line.size() - 2]).normalized()
		var biggest := -1
		var cross_w := 0.0
		var skipped_self := false
		for entry: Array in nodes.get(node_key(e), []):
			if int(entry[0]) == own and absf(float(entry[1]) - width) < 0.01 and not skipped_self:
				skipped_self = true
				continue
			if int(entry[0]) > biggest:
				biggest = int(entry[0])
				cross_w = float(entry[1])
		if biggest <= own:
			continue
		var back := cross_w * 0.5 + RealChunkBuilder.KERB_WIDTH + STOP_BACK
		if back + 6.0 > RealChunkBuilder._length(line):
			continue
		var left := left_of(inward)
		var at := e - inward * back
		RealChunkBuilder.strip(_flat("paint", PAINT, surfaces, materials), PackedVector2Array([at, at + left * (width * 0.5 - 0.3)]), 0.4, RealChunkBuilder.Y_PAINT)
		# STOP across the lane, letters side by side left to right as the driver sees them (the texture's top is the far end, the stop line): 2.4 m across, 1.8 m along.
		decal(_decal_tool("stop_text", surfaces, materials), at - inward * 1.7 + left * width * 0.25, inward, 2.4, 1.8, Y_ROAD_DECAL)
		# The sign itself: a red octagon on a pole at the kerb beside the stop line, facing the arriving driver.
		var pole_at := at + left * (width * 0.5 + RealChunkBuilder.KERB_WIDTH + 0.55)
		# One octagon on top of a pole, red with STOP on both faces (each reads the right way round from its own side): the faces are
		# a centimetre either side of the pole's axis and the pole ends at the octagon's lower edge, so nothing shows through.
		RealLandmarks._obox(_flat("steel", RealLandmarks.STEEL, surfaces, materials), pole_at, left, Vector2(0.035, 0.035), 0.0, STOP_POLE_TOP)
		var facing := -inward
		var sign_tool := RealChunkBuilder._tool("panel_sign_stop", surfaces, materials, PixelMaterials.panel("sign_stop", Color.WHITE, true))
		face_quad(sign_tool, pole_at, facing, 0.75, STOP_SIGN_BOTTOM, STOP_SIGN_TOP, 0.012)
		face_quad(sign_tool, pole_at, -facing, 0.75, STOP_SIGN_BOTTOM, STOP_SIGN_TOP, 0.012)


## Zebra stripes across the whole road, 3 m long, every metre.
static func _zebra(at: Vector2, d: Vector2, width: float, surfaces: Dictionary, materials: Dictionary) -> void:
	var paint := _flat("paint", PAINT, surfaces, materials)
	var left := left_of(d)
	var x := -width * 0.5 + 0.6
	while x <= width * 0.5 - 0.6:
		var c := at + left * x
		RealChunkBuilder.strip(paint, PackedVector2Array([c - d * 1.5, c + d * 1.5]), 0.5, RealChunkBuilder.Y_PAINT)
		x += 1.0


## Grass in the middle of a dual road: each carriageway grasses its half of the gap to the other one.
static func _median(line: PackedVector2Array, width: float, street_name: String, oneways: Array, surfaces: Dictionary, materials: Dictionary) -> void:
	var here: Array = at_distance(line, RealChunkBuilder._length(line) * 0.5)
	var across := _gap_across(here[0], -left_of(here[1]), line, width, street_name, oneways)
	if across.is_empty():
		return
	var gap := float(across.gap)
	if gap < MEDIAN_MIN_GAP or gap > 40.0:
		return
	# The whole gap between the two kerbs. The other carriageway lays the same strip: they overlap on one texture,
	# and where a taper is too narrow for the mate to draw, the gap is still grassed. It lies under the kerb and asphalt.
	var inner := RealChunkBuilder.offset_line(line, width * 0.5 + RealChunkBuilder.KERB_WIDTH + gap * 0.5)   # offset_line: positive is the side the mate was found on
	RealChunkBuilder.ribbon(RealChunkBuilder._tool("median", surfaces, materials, PixelMaterials.surface("median_grass", Vector2(2, 2))), inner, gap + 0.1, Y_MEDIAN)


## The nearest other carriageway of the same street on the `right` of `at`: {gap: between the two kerbs,
## mate: its record}, or {} when there is none.
static func _gap_across(at: Vector2, right: Vector2, line: PackedVector2Array, width: float, street_name: String, oneways: Array) -> Dictionary:
	var best := INF
	var mate: Dictionary = {}
	for o: Dictionary in oneways:
		var ol: PackedVector2Array = o.line
		if ol == line or str(o.n) != street_name:
			continue
		for i in ol.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(at, ol[i], ol[i + 1])
			var dd := at.distance_to(q)
			if dd < best and (q - at).dot(right) > 0.0:
				best = dd
				mate = o
	if mate.is_empty():
		return {}
	return {"gap": best - width * 0.5 - float(mate.w) * 0.5 - RealChunkBuilder.KERB_WIDTH * 2.0, "mate": mate}


## Wooden power poles at the back of the verge on one side, with three sagging wires between them.
## Returns the poles' positions.
static func _power_line(line: PackedVector2Array, width: float, pave: float, lamps: PackedVector3Array, rng: RandomNumberGenerator, surfaces: Dictionary, materials: Dictionary) -> Array:
	var length := RealChunkBuilder._length(line)
	if length < 25.0:
		return []
	var side := 1.0 if rng.randi() % 2 == 0 else -1.0
	var offset := width * 0.5 + maxf(0.6, minf(pave, RealYards.PAVE_KEEP) - 0.2)
	var poles: Array = []
	var dist := 10.0
	while dist < length - 5.0:
		var here: Array = at_distance(line, dist)
		var p: Vector2 = here[0] + left_of(here[1]) * offset * side
		var clear := true
		for l in lamps:
			if Vector2(l.x, l.z).distance_to(p) < 2.0:
				clear = false
				break
		if clear:
			poles.append([p, here[1]])
		dist += POLE_SPACING
	var wood := _flat("pole_wood", WOOD, surfaces, materials)
	var wire := _flat("wire", WIRE, surfaces, materials)
	for pole: Array in poles:
		RealLandmarks._prism(wood, pole[0], 0.13, 6, 0.0, POLE_HEIGHT, true)
		RealLandmarks._obox(wood, pole[0], pole[1], Vector2(0.8, 0.06), POLE_HEIGHT - 0.5, POLE_HEIGHT - 0.38)
	pole_posters(poles, rng, surfaces, materials)
	for i in poles.size() - 1:
		var a: Vector2 = poles[i][0]
		var b: Vector2 = poles[i + 1][0]
		var da: Vector2 = poles[i][1]
		var db: Vector2 = poles[i + 1][1]
		for k: float in [-0.65, 0.0, 0.65]:
			var top := POLE_HEIGHT - 0.38 + (0.25 if k == 0.0 else 0.0)
			_wire(wire, Vector3(a.x + da.x * k, top, a.y + da.y * k), Vector3(b.x + db.x * k, top, b.y + db.y * k))
		if rng.randi() % SNEAKER_ONE_IN == 0:
			var mid := (a + b) * 0.5
			var y := POLE_HEIGHT - 0.38 + 0.25 - WIRE_SAG - 0.35
			var shoe := _flat("sneaker", "#ececec", surfaces, materials)
			RealLandmarks._obox(shoe, mid + da * 0.12, da.orthogonal(), Vector2(0.14, 0.05), y, y + 0.1)
			RealLandmarks._obox(shoe, mid - da * 0.12, da.orthogonal(), Vector2(0.14, 0.05), y - 0.05, y + 0.05)
			RealLandmarks._obox(wire, mid, da, Vector2(0.15, 0.01), y + 0.1, y + 0.35)
	return poles


## A hand-made poster stapled to about a third of the power poles, on the faces looking along the street (the way people walk past).
const POSTERS := ["poster_choir", "poster_dog", "poster_special"]
const POSTER_PERCENT := 34
const POSTER_SIZE := Vector2(0.26, 0.32)


static func pole_posters(poles: Array, rng: RandomNumberGenerator, surfaces: Dictionary, materials: Dictionary) -> int:
	var count := 0
	for pole: Array in poles:
		if rng.randi() % 100 >= POSTER_PERCENT:
			continue
		var tex: String = POSTERS[rng.randi() % POSTERS.size()]
		var tool := RealChunkBuilder._tool("panel_" + tex, surfaces, materials, PixelMaterials.panel(tex))
		var d: Vector2 = pole[1]
		var y0 := 1.5 + rng.randf() * 0.5
		for s: float in [1.0, -1.0]:
			face_quad(tool, pole[0], d * s, POSTER_SIZE.x, y0, y0 + POSTER_SIZE.y, 0.15)
		count += 1
	return count


## A wire from a to b hanging WIRE_SAG at the middle: four straight pieces, each a thin cross of two strips.
static func _wire(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var pts: Array = []
	for k in 5:
		var t := k / 4.0
		var p := a.lerp(b, t)
		p.y -= WIRE_SAG * 4.0 * t * (1.0 - t)
		pts.append(p)
	var flat_side := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * 0.018
	for k in 4:
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[k + 1]
		for off: Vector3 in [Vector3(0, 0.018, 0), flat_side]:
			for tri: Array in [[p0 - off, p0 + off, p1 + off], [p0 - off, p1 + off, p1 - off]]:
				for v: Vector3 in tri:
					st.add_vertex(v)
				for v: Vector3 in [tri[0], tri[2], tri[1]]:
					st.add_vertex(v)


## Drain grates in the gutters, manholes in the middle, and wear: potholes, tar patches, oil where
## cars park, sand blown into the gutters, litter on the verge.
static func _wear(cls: String, line: PackedVector2Array, width: float, pave: float, length: float, rng: RandomNumberGenerator, surfaces: Dictionary, materials: Dictionary) -> void:
	var gutter := width * 0.5 - RealChunkBuilder.GUTTER_WIDTH * 0.5
	if pave > 0.0:
		var dist := 12.0 + rng.randf() * 10.0
		var side := 1.0
		while dist < length - 4.0:
			var here: Array = at_distance(line, dist)
			decal(_decal_tool("drain_grate", surfaces, materials), here[0] + left_of(here[1]) * gutter * side, here[1], 0.38, 1.0, RealChunkBuilder.Y_ROAD - 0.001 + 0.003)
			side = -side
			dist += 45.0
	if cls != "main":
		var dist := 25.0 + rng.randf() * 20.0
		while dist < length - 5.0:
			var here: Array = at_distance(line, dist)
			decal(_decal_tool("manhole", surfaces, materials), here[0], here[1], 0.75, 0.75, Y_ROAD_DECAL)
			dist += 80.0
	var items := [["pothole", 90.0, Vector2(1.0, 0.75)], ["tar_patch", 60.0, Vector2(1.6, 1.6)], ["oil_stain", 35.0, Vector2(0.9, 0.9)], ["sand_drift", 70.0, Vector2(1.1, 3.2)], ["puddle", 38.0, Vector2(1.9, 1.15)]]
	for item: Array in items:
		var tex := str(item[0])
		if tex == "sand_drift" and cls == "main":
			continue
		var dist := rng.randf() * float(item[1])
		while dist < length - 2.0:
			var here: Array = at_distance(line, dist)
			var d: Vector2 = here[1]
			var left := left_of(d)
			var c: Vector2 = here[0]
			var dir := d
			match tex:
				"pothole", "tar_patch":
					c += left * rng.randf_range(-width * 0.3, width * 0.3)
					dir = d.rotated(rng.randf() * TAU)
				"oil_stain":
					c += left * (width * 0.5 - 1.1) * (1.0 if rng.randi() % 2 == 0 else -1.0)
				"puddle":   # in the gutter side of the lane, where the water collects
					c += left * (width * 0.5 - 0.9 - rng.randf() * 0.8) * (1.0 if rng.randi() % 2 == 0 else -1.0)
					dir = d.rotated((rng.randf() - 0.5) * 0.5)
				"sand_drift":
					c += left * (width * 0.5 - 0.45) * (1.0 if rng.randi() % 2 == 0 else -1.0)
			var size: Vector2 = item[2]
			var tool := RealChunkBuilder._tool("puddle", surfaces, materials, Puddles.material()) if tex == "puddle" else _decal_tool(tex, surfaces, materials)
			decal(tool, c, dir, size.x, size.y, Y_ROAD_DECAL + (0.001 if tex == "sand_drift" else (0.002 if tex == "puddle" else 0.0)))
			dist += float(item[1]) * rng.randf_range(0.7, 1.3)
	if pave > 0.6:
		var litter := ["litter_paper", "litter_can", "litter_chips", "litter_bottle"]
		var dist := rng.randf() * 20.0
		while dist < length:
			var here: Array = at_distance(line, dist)
			var side := 1.0 if rng.randi() % 2 == 0 else -1.0
			var c: Vector2 = here[0] + left_of(here[1]) * side * (width * 0.5 + RealChunkBuilder.KERB_WIDTH + rng.randf_range(0.2, pave - 0.2))
			decal(_decal_tool(litter[rng.randi() % litter.size()], surfaces, materials), c, Vector2.RIGHT.rotated(rng.randf() * TAU), 0.5, 0.5, Y_GROUND_DECAL)
			dist += rng.randf_range(12.0, 28.0)


## A bus or taxi stop on the left verge halfway along: back wall, roof, bench, and a sign on a pole.
static func _shelter(line: PackedVector2Array, width: float, length: float, rng: RandomNumberGenerator, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var here: Array = at_distance(line, length * 0.5)
	var d: Vector2 = here[1]
	var left := left_of(d)
	var front: Vector2 = here[0] + left * (width * 0.5 + RealChunkBuilder.KERB_WIDTH + 0.4)
	var back := front + left * 1.6
	var mid := (front + back) * 0.5
	var steel := _flat("steel", RealLandmarks.STEEL, surfaces, materials)
	RealLandmarks._obox(_flat("shelter_wall", "#3f6f8f", surfaces, materials), back, d, Vector2(1.6, 0.04), 0.0, 2.2)
	RealLandmarks._obox(_flat("canopy", "#d8d3c8", surfaces, materials), mid, d, Vector2(1.7, 0.95), 2.3, 2.4)
	for s: float in [-1.0, 1.0]:
		RealLandmarks._obox(steel, front + d * s * 1.5, d, Vector2(0.05, 0.05), 0.0, 2.3)
	RealLandmarks._obox(_flat("bench_wood", "#8c6044", surfaces, materials), back - left * 0.3, d, Vector2(1.3, 0.2), 0.45, 0.52)
	var sign_at := front + d * 2.3
	RealLandmarks._obox(steel, sign_at, d, Vector2(0.04, 0.04), 0.0, 2.5)
	var tex := "sign_bus" if rng.randi() % 2 == 0 else "sign_taxi"
	var sign := RealChunkBuilder._tool("panel_" + tex, surfaces, materials, PixelMaterials.panel(tex))
	for s: float in [1.0, -1.0]:
		face_quad(sign, sign_at, d * s, 0.5, 2.1, 2.6)
	RealTransitDecor.draw_stop(line, length * 0.5, width, left, d, left, tex == "sign_taxi", rng, surfaces, materials, props)


## Trees along both sides of the street at the back of the verge, clear of lamps and power poles.
static func _street_trees(line: PackedVector2Array, width: float, pave: float, lamps: PackedVector3Array, poles: Array, rng: RandomNumberGenerator, props: Dictionary) -> void:
	var length := RealChunkBuilder._length(line)
	var offset := width * 0.5 + maxf(0.8, minf(pave, RealYards.PAVE_KEEP) - 0.3)
	for side: float in [-1.0, 1.0]:
		var dist := 6.0 + rng.randf() * 4.0
		while dist < length - 3.0:
			var here: Array = at_distance(line, dist)
			var p: Vector2 = here[0] + left_of(here[1]) * offset * side
			var clear := true
			for l in lamps:
				if Vector2(l.x, l.z).distance_to(p) < 2.5:
					clear = false
			for pole: Array in poles:
				if (pole[0] as Vector2).distance_to(p) < 3.0:
					clear = false
			if clear:
				add_prop(props, "tree_a" if rng.randi() % 3 != 0 else "tree_b", p, rng.randf() * TAU, rng.randf_range(0.8, 1.15))
			dist += TREE_SPACING
