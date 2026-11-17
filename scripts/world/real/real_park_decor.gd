class_name RealParkDecor
extends RefCounted
## Public places of the real Westridge: palisade fences round the school grounds with gates on the
## street side, trees and benches in the parks, swings, a slide and a roundabout in the playgrounds,
## soccer goals on the pitches, fruit stalls by the zebra crossings near shops and schools, and a
## snoek bakkie by the shopping centre. Fences and stalls are planned from the data
## (RealDistrictData.school_fences / stalls) so the navigation walks round them.
## Design: design/gdd/real_world.md ("Public places").

const SCHOOL_FENCE_HEIGHT := 2.1
const SCHOOL_PIECE := 20.0          # perimeter cut into pieces of at most this (a blocked piece is left out alone)
const SCHOOL_GATES := 2
const SCHOOL_GATE_WIDTH := 5.0
const PARK_TREE_SPACING := 11.0
const PARK_TREE_CLEAR := 2.5        # from paths and buildings
const STALL_HALF := Vector2(0.95, 0.45)
const STALL_FROM_CROSSING := 4.5
const SNOEK_HALF := Vector2(2.5, 1.0)


## The palisade pieces ([a, b]) round a school's grounds, with SCHOOL_GATES gates on the sides nearest
## a street. Pieces that would cross a building, a pavement or another home's way out are left out.
static func school_fence(area: PackedVector2Array, rings: Array, strips: Array, lanes: Array) -> Array:
	var pieces: Array = []
	var n := area.size()
	for i in n:
		var a := area[i]
		var b := area[(i + 1) % n]
		var length := a.distance_to(b)
		var count := maxi(1, ceili(length / SCHOOL_PIECE))
		for k in count:
			pieces.append([a.lerp(b, float(k) / count), a.lerp(b, float(k + 1) / count)])
	# Gates: the pieces nearest a street (by their middle), at least 30 m apart.
	var by_road: Array = []
	for i in pieces.size():
		var m: Vector2 = ((pieces[i][0] as Vector2) + (pieces[i][1] as Vector2)) * 0.5
		var d := INF
		for s: Dictionary in strips:
			if float(s.get("half", 0.0)) > 0.0:
				d = minf(d, RealChunkBuilder._distance_to_lines(m, [s.line]) - float(s.half))
		by_road.append([d, i])
	by_road.sort_custom(func(x, y): return x[0] < y[0])
	var gates: Array = []
	for e: Array in by_road:
		if gates.size() >= SCHOOL_GATES:
			break
		var m: Vector2 = ((pieces[e[1]][0] as Vector2) + (pieces[e[1]][1] as Vector2)) * 0.5
		if gates.all(func(g): return (g as Vector2).distance_to(m) > 30.0) and (pieces[e[1]][0] as Vector2).distance_to(pieces[e[1]][1]) > SCHOOL_GATE_WIDTH + 1.0:
			gates.append(m)
	var out: Array = []
	for piece: Array in pieces:
		var a: Vector2 = piece[0]
		var b: Vector2 = piece[1]
		var m := (a + b) * 0.5
		var parts: Array = [[a, b]]
		if gates.any(func(g): return (g as Vector2).distance_to(m) < 0.01):
			var dir := (b - a).normalized()
			parts = [[a, m - dir * SCHOOL_GATE_WIDTH * 0.5], [m + dir * SCHOOL_GATE_WIDTH * 0.5, b]]
		for part: Array in parts:
			if RealYards._clear_of_streets(part[0], part[1], strips) and RealYards._segment_ok(part[0], part[1], PackedVector2Array(), rings, lanes):
				out.append(part)
	return out


## Fruit stalls beside the zebra crossings near shops and schools (left verge, a few metres along),
## and one snoek bakkie: [{kind: "fruit"|"snoek", at, dir (along the road), out (towards the verge)}].
static func stalls(crossings: Array, rings: Array, lanes: Array) -> Array:
	var out: Array = []
	for c: Dictionary in crossings:
		var d: Vector2 = c.dir
		var left := RealStreetDecor.left_of(d)
		var at: Vector2 = c.at + d * STALL_FROM_CROSSING + left * (float(c.w) * 0.5 + RealChunkBuilder.KERB_WIDTH + 1.0)
		var box := RealYards.obstacle_box(at, d, STALL_HALF)
		if RealYards.box_clear(box, PackedVector2Array(), rings, lanes):
			out.append({"kind": "fruit", "at": at, "dir": d, "out": left})
		if str(c.get("kind", "")) == "retail":   # the snoek bakkie parks on the verge on the other side
			var bakkie_at: Vector2 = c.at - d * 9.0 + left * (float(c.w) * 0.5 + RealChunkBuilder.KERB_WIDTH + 1.4)
			var bakkie_box := RealYards.obstacle_box(bakkie_at, d, SNOEK_HALF)
			if RealYards.box_clear(bakkie_box, PackedVector2Array(), rings, lanes):
				out.append({"kind": "snoek", "at": bakkie_at, "dir": d, "out": left})
	return out


## The outline a stall takes up (the navigation walks round it).
static func stall_box(s: Dictionary) -> PackedVector2Array:
	return RealYards.obstacle_box(s.at, s.dir, SNOEK_HALF if s.kind == "snoek" else STALL_HALF)


# ------------------------------------------------------------------ drawing

static func draw_school_fence(pieces: Array, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array) -> void:
	var fence := RealChunkBuilder._tool("fence_palisade", surfaces, materials, PixelMaterials.panel("fence_palisade", Color.WHITE, true))
	var steel := RealStreetDecor._flat("steel", RealLandmarks.STEEL, surfaces, materials)
	for piece: Array in pieces:
		var a: Vector2 = piece[0]
		var b: Vector2 = piece[1]
		RealChunkBuilder._fence_panel(fence, a, b, 0.0, SCHOOL_FENCE_HEIGHT, 2.0)
		for p: Vector2 in [a, b]:
			RealLandmarks._obox(steel, p, (b - a).normalized(), Vector2(0.06, 0.06), 0.0, SCHOOL_FENCE_HEIGHT + 0.1)
		var a0 := RealChunkBuilder._v(a, 0.0)
		var b0 := RealChunkBuilder._v(b, 0.0)
		var up := Vector3.UP * SCHOOL_FENCE_HEIGHT
		collision.append_array([a0, a0 + up, b0 + up, a0, b0 + up, b0])


static func draw_stalls(list: Array, root: Node3D, surfaces: Dictionary, materials: Dictionary, props: Dictionary, collision: PackedVector3Array) -> void:
	for s: Dictionary in list:
		var at: Vector2 = s.at
		var d: Vector2 = s.dir
		if s.kind == "snoek":
			_snoek_bakkie(s, root, surfaces, materials, collision)
			continue
		var wood := RealStreetDecor._flat("stall_wood", "#8c6044", surfaces, materials)
		RealLandmarks._obox(wood, at, d, STALL_HALF, 0.75, 0.85)
		for su: float in [-1.0, 1.0]:
			for sv: float in [-1.0, 1.0]:
				RealLandmarks._obox(wood, at + d * su * (STALL_HALF.x - 0.08) + (s.out as Vector2) * sv * (STALL_HALF.y - 0.08), d, Vector2(0.04, 0.04), 0.0, 0.75)
		var fruit_colours := ["#f08a24", "#3f9a3a", "#d6403e", "#f2d23a"]
		for k in 4:
			var spot := at + d * (-0.65 + k * 0.43)
			RealLandmarks._obox(RealStreetDecor._flat("fruit_" + fruit_colours[k], fruit_colours[k], surfaces, materials), spot, d, Vector2(0.18, 0.28), 0.85, 1.02)
		RealLandmarks._obox(RealStreetDecor._flat("steel", RealLandmarks.STEEL, surfaces, materials), at - (s.out as Vector2) * 0.3, d, Vector2(0.03, 0.03), 0.0, 2.2)
		var awning := RealChunkBuilder._tool("awning", surfaces, materials, PixelMaterials.panel("awning_stripes"))
		RealStreetDecor.decal(awning, at, d, 1.4, 2.2, 2.2)
		RealStreetDecor.add_prop(props, "crate_stack", at + (s.out as Vector2) * 1.2 - d * 1.2, 0.0)
		RealStreetDecor.add_prop(props, "plastic_chair", at + (s.out as Vector2) * 1.2 + d * 1.3, PI)
		var box := RealYards.obstacle_box(at, d, STALL_HALF)
		for k in 4:
			var a := RealChunkBuilder._v(box[k], 0.0)
			var b := RealChunkBuilder._v(box[(k + 1) % 4], 0.0)
			collision.append_array([a, a + Vector3.UP, b + Vector3.UP, a, b + Vector3.UP, b])


## Trees and benches in parks, play equipment in playgrounds, goals on pitches.
static func draw_areas(areas: Array, strips: Array, rings: Array, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	for a: Dictionary in areas:
		var ring := RealChunkBuilder._line(a.p)
		if ring.size() < 3:
			continue
		var kind := str(a.k)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(roundi(ring[0].x * 10.0), roundi(ring[0].y * 10.0)))
		match kind:
			"park":
				_park(ring, strips, rings, rng, surfaces, materials, props)
			"playground":
				_playground(ring, rng, surfaces, materials)
			"pitch":
				_goals(ring, surfaces, materials)


static func _park(ring: PackedVector2Array, strips: Array, rings: Array, rng: RandomNumberGenerator, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var box := RealChunkBuilder.ring_box(ring)
	var near_strips: Array = strips.filter(func(s): return (s.box as Rect2).intersects(box.grow(5.0)))
	var near_rings: Array = rings.filter(func(r): return RealChunkBuilder.ring_box(r).intersects(box.grow(5.0)))
	var x := box.position.x + PARK_TREE_SPACING * 0.5
	while x < box.end.x:
		var y := box.position.y + PARK_TREE_SPACING * 0.5
		while y < box.end.y:
			var p := Vector2(x, y) + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			if RealChunkBuilder.point_in_ring(p, ring) and rng.randf() < 0.55 and _clear(p, near_strips, near_rings):
				RealStreetDecor.add_prop(props, "tree_a" if rng.randi() % 3 != 0 else "tree_b", p, rng.randf() * TAU, rng.randf_range(0.8, 1.25))
			y += PARK_TREE_SPACING
		x += PARK_TREE_SPACING
	var c := box.get_center()
	if RealChunkBuilder.point_in_ring(c, ring):
		var wood := RealStreetDecor._flat("bench_wood", "#8c6044", surfaces, materials)
		for k in 2:
			var at := c + Vector2.RIGHT.rotated(k * PI + 0.4) * 4.0
			if _clear(at, near_strips, near_rings):
				var d := Vector2.RIGHT.rotated(k * PI + 0.4 + PI * 0.5)
				RealLandmarks._obox(wood, at, d, Vector2(0.9, 0.22), 0.42, 0.5)
				RealLandmarks._obox(wood, at - d.orthogonal() * 0.2, d, Vector2(0.9, 0.04), 0.5, 0.9)


static func _clear(p: Vector2, strips: Array, rings: Array) -> bool:
	for s: Dictionary in strips:
		if RealChunkBuilder._distance_to_lines(p, [s.line]) < float(s.reach) + PARK_TREE_CLEAR:
			return false
	for r: PackedVector2Array in rings:
		if RealChunkBuilder.point_in_ring(p, r) or RealChunkBuilder._distance_to_ring(p, r) < PARK_TREE_CLEAR:
			return false
	return true


## A swing frame, a slide and a roundabout round the middle of the playground.
static func _playground(ring: PackedVector2Array, rng: RandomNumberGenerator, surfaces: Dictionary, materials: Dictionary) -> void:
	var c := RealChunkBuilder.ring_box(ring).get_center()
	if not RealChunkBuilder.point_in_ring(c, ring):
		return
	var steel := RealStreetDecor._flat("play_red", "#c8392f", surfaces, materials)
	var blue := RealStreetDecor._flat("play_blue", "#2b6fb5", surfaces, materials)
	var yellow := RealStreetDecor._flat("play_yellow", "#e0b02a", surfaces, materials)
	var u := Vector2.RIGHT.rotated(rng.randf() * PI)
	var sw := c - u * 4.0
	for s: float in [-1.0, 1.0]:
		RealLandmarks._obox(steel, sw + u * s * 1.6, u, Vector2(0.06, 0.06), 0.0, 2.3)
	RealLandmarks._obox(steel, sw, u, Vector2(1.7, 0.06), 2.25, 2.35)
	for s: float in [-0.7, 0.7]:
		RealLandmarks._obox(RealStreetDecor._flat("wire", RealStreetDecor.WIRE, surfaces, materials), sw + u * s, u, Vector2(0.01, 0.01), 0.45, 2.25)
		RealLandmarks._obox(blue, sw + u * s, u, Vector2(0.25, 0.12), 0.42, 0.47)
	var sl := c + u * 3.0
	var v := u.orthogonal()
	RealLandmarks._obox(yellow, sl, v, Vector2(0.5, 0.45), 0.0, 1.6)
	var top0 := RealChunkBuilder._v(sl + v * 0.5 - u * 0.4, 1.6)
	var top1 := RealChunkBuilder._v(sl + v * 0.5 + u * 0.4, 1.6)
	var bot0 := RealChunkBuilder._v(sl + v * 3.2 - u * 0.4, 0.2)
	var bot1 := RealChunkBuilder._v(sl + v * 3.2 + u * 0.4, 0.2)
	for tri: Array in [[top0, top1, bot1], [top0, bot1, bot0]]:
		RealChunkBuilder._up(blue, tri[0], tri[1], tri[2])
		RealChunkBuilder._facing(blue, tri[0], tri[1], tri[2], Vector3.DOWN)
	RealLandmarks._prism(yellow, c + v * -3.5, 1.2, 12, 0.25, 0.35, true)
	RealLandmarks._prism(steel, c + v * -3.5, 0.08, 6, 0.0, 0.9, true)


## Soccer goals (posts and crossbar) at both short ends of a pitch.
static func _goals(ring: PackedVector2Array, surfaces: Dictionary, materials: Dictionary) -> void:
	var rect := RealChunkBuilder.min_rect(ring)
	var half: Vector2 = rect.half
	if half.x < 12.0:
		return
	var white := RealStreetDecor._flat("goal_white", "#f4f1ea", surfaces, materials)
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var goal_half := 3.66 if half.x > 40.0 else 2.0
	var height := 2.44 if half.x > 40.0 else 2.0
	for su: float in [-1.0, 1.0]:
		var line := (rect.c as Vector2) + u * su * (half.x - 1.0)
		for sv: float in [-1.0, 1.0]:
			RealLandmarks._obox(white, line + v * sv * goal_half, u, Vector2(0.06, 0.06), 0.0, height)
		RealLandmarks._obox(white, line, v, Vector2(goal_half + 0.06, 0.06), height - 0.12, height)


## A bakkie selling snoek off the back: the bakkie, a cooler box on the verge and a hand-painted board.
static func _snoek_bakkie(s: Dictionary, root: Node3D, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array) -> void:
	var at: Vector2 = s.at
	var d: Vector2 = s.dir
	var out: Vector2 = s.out
	var pivot := VehicleLibrary.build(root, "bakkie", Color("#e8e4dc"), Vector3(at.x, 0.0, at.y), atan2(-d.y, d.x))
	for gi in pivot.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).visibility_range_end = 200.0
	var cooler := at - d * 3.0 + out * 0.2
	RealLandmarks._obox(RealStreetDecor._flat("cooler", "#2b6fb5", surfaces, materials), cooler, d, Vector2(0.35, 0.25), 0.0, 0.45)
	RealLandmarks._obox(RealStreetDecor._flat("cooler_lid", "#f4f1ea", surfaces, materials), cooler, d, Vector2(0.37, 0.27), 0.45, 0.5)
	var board := RealChunkBuilder._tool("panel_sign_fish", surfaces, materials, PixelMaterials.panel("sign_fish"))
	var board_at := at - d * 3.4 + out * 0.9
	RealChunkBuilder._panel(board, board_at, d, out, 1.4, 0.3, 0.65)
	RealChunkBuilder._panel(board, board_at, -d, -out, 1.4, 0.3, 0.65)
	var box := RealYards.obstacle_box(at, d, SNOEK_HALF)
	for k in 4:
		var a := RealChunkBuilder._v(box[k], 0.0)
		var b := RealChunkBuilder._v(box[(k + 1) % 4], 0.0)
		collision.append_array([a, a + Vector3.UP * 1.5, b + Vector3.UP * 1.5, a, b + Vector3.UP * 1.5, b])
