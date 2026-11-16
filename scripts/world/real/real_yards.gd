class_name RealYards
extends RefCounted
## Front yards of the real homes: a fence or wall along the street side of the house with a gate
## opening in line with the front door, and side walls back to the house corners. Worked out from
## the map data alone (the same answer for the builder, which draws it, and the navigation bake,
## which walks round it). Design: design/gdd/real_world.md ("Yards").

## Fence styles, picked from the house's outline: the list repeats the common ones; "none" is an open yard.
const KINDS := ["precast", "palisade", "low_wall", "wall_palisade", "precast", "palisade", "low_wall", "none"]
const HEIGHTS := {"precast": 1.5, "palisade": 1.6, "low_wall": 1.0, "wall_palisade": 1.8}
## The gate opening in the front fence (people keep 0.6 m from fences, so 0.8 m of it is walkable).
const GATE := 2.0
## Shortest front wall that gets a yard, and how deep a yard may be (wall to fence).
const MIN_WALL := 4.0
const MIN_DEPTH := 2.2   # doorstep 1.2 m out + 0.6 m clearance + half the fence + slack
const MAX_DEPTH := 4.5
## The game's own homes: their gate spot is 5 m out and their yard dog runs up to 3.5 m out,
## 3 m either side of the door, so the fence stands between those and spans the dog's run.
const STORY_MIN_DEPTH := 3.8
const STORY_MAX_DEPTH := 4.4
const STORY_HALF := 3.4
## Gap kept between a fence and the pavement (or a footpath's edge); of a wider pavement only this much
## is kept clear in front of a fence (the rest becomes part of the yard).
const PAVE_GAP := 0.3
const PAVE_KEEP := 1.5
## No fence within this of another home's doorstep, so every door stays reachable.
const DOOR_KEEP := 1.0
## Each home's walk-out lane: from its doorstep this far straight out; no other home's fence may cross it.
const LANE := 4.0
## A lane starting this close to the house's own doorstep is its own.
const OWN_STEP := 0.1
## Fence thickness used for the navigation obstacle.
const THICK := 0.2
const DEPTH_STEP := 0.2


## The yard of a home, or {} for an open yard / no room. `front`: RealChunkBuilder.home_front.
## `strips`: [{line, reach, box: Rect2 round the line}] street and footpath centre lines with their half width (pavement included).
## `rings`: outlines near the house (its own included). `lanes`: every home's walk-out lane
## (PackedVector2Array [doorstep, point LANE metres straight out]); its own is recognised and ignored.
## Returns {kind, height, depth, segments: [[a, b], ...], posts: [Vector2], gate: Vector2 (middle of the opening)}.
static func plan(ring: PackedVector2Array, front: Dictionary, strips: Array, rings: Array, lanes: Array, story: bool, seed_value: int) -> Dictionary:
	var kind: String = KINDS[(seed_value / 13) % KINDS.size()]
	if kind == "none" or front.is_empty():
		return {}
	var i: int = front.index
	var p0 := ring[i]
	var p1 := ring[(i + 1) % ring.size()]
	var mid: Vector2 = front.mid
	var n: Vector2 = front.normal
	var t := (p1 - p0).normalized()
	var half := p0.distance_to(p1) * 0.5
	if half * 2.0 < MIN_WALL and not story:
		return {}
	var w0 := -half
	var w1 := half
	if story:
		w0 = minf(w0, -STORY_HALF)
		w1 = maxf(w1, STORY_HALF)
	var reach := MAX_DEPTH + maxf(half, STORY_HALF) + 4.0
	var area := Rect2(mid, Vector2.ZERO).grow(reach + 12.0)
	var near_strips := strips.filter(func(s): return s.box.intersects(area) and RealChunkBuilder._distance_to_lines(mid, [s.line]) < float(s.reach) + reach)
	var own_step := mid + n * RealChunkBuilder.DOOR_OUT
	var near_lanes: Array = lanes.filter(func(l): return l[0].distance_squared_to(mid) < (reach + LANE) * (reach + LANE) and l[0].distance_to(own_step) > OWN_STEP)
	var lo := STORY_MIN_DEPTH if story else MIN_DEPTH
	var depth := STORY_MAX_DEPTH if story else MAX_DEPTH
	while depth >= lo and not _clear_of_streets(mid + t * w0 + n * depth, mid + t * w1 + n * depth, near_strips):
		depth -= DEPTH_STEP
	if depth < lo:
		return {}
	var a := mid + t * w0 + n * depth
	var b := mid + t * w1 + n * depth
	var g0 := mid + n * depth - t * GATE * 0.5
	var g1 := mid + n * depth + t * GATE * 0.5
	var yard := PackedVector2Array([mid + t * w0, mid + t * w1, b, a])
	for lane: PackedVector2Array in near_lanes:
		if RealChunkBuilder.point_in_ring(lane[0], yard):
			return {}   # another home's door opens into this yard: leave it open
	var candidates: Array = [[a, g0], [g1, b]]
	if not story:   # story yards stay open at the sides (their dog runs wider than some houses)
		candidates.append([mid + t * w0, a])
		candidates.append([mid + t * w1, b])
	var segments: Array = []
	var posts: Array = []
	for seg: Array in candidates:
		if _segment_ok(seg[0], seg[1], ring, rings, near_lanes):
			segments.append(seg)
			for p: Vector2 in seg:
				if not posts.any(func(q): return q.distance_to(p) < 0.05):
					posts.append(p)
	if segments.is_empty():
		return {}
	return {"kind": kind, "height": float(HEIGHTS[kind]), "depth": depth, "segments": segments, "posts": posts, "gate": mid + n * depth}


## True when the fence line a-b keeps PAVE_GAP clear of every street's pavement and every footpath.
static func _clear_of_streets(a: Vector2, b: Vector2, strips: Array) -> bool:
	for s: Dictionary in strips:
		var line: PackedVector2Array = s.line
		var keep := float(s.reach) + PAVE_GAP
		for k in line.size() - 1:
			var pts := Geometry2D.get_closest_points_between_segments(a, b, line[k], line[k + 1])
			if pts[0].distance_to(pts[1]) < keep:
				return false
	return true


## A fence piece may not cross a building (its own house only at its ends), pass close to another
## home's doorstep, or cross another home's walk-out lane.
static func _segment_ok(a: Vector2, b: Vector2, own: PackedVector2Array, rings: Array, lanes: Array) -> bool:
	if a.distance_to(b) < 0.3:
		return false
	var dir := (b - a).normalized()
	var a_in := a + dir * 0.15   # a side wall starts at the house corner: only its inner part is tested
	var b_in := b - dir * 0.15
	for ring: PackedVector2Array in rings:
		var mine := ring == own
		for k in ring.size():
			var q0 := ring[k]
			var q1 := ring[(k + 1) % ring.size()]
			if Geometry2D.segment_intersects_segment(a_in if mine else a, b_in if mine else b, q0, q1) != null:
				return false
		if not mine and (RealChunkBuilder.point_in_ring(a, ring) or RealChunkBuilder.point_in_ring(b, ring)):
			return false
	for lane: PackedVector2Array in lanes:
		if lane[0].distance_to(Geometry2D.get_closest_point_to_segment(lane[0], a, b)) < DOOR_KEEP \
				or Geometry2D.segment_intersects_segment(a, b, lane[0], lane[1]) != null:
			return false
	return true


## The navigation obstacle for a fence piece: a thin rectangle along it.
static func obstacle(a: Vector2, b: Vector2) -> PackedVector2Array:
	var t := (b - a).normalized()
	var side := Vector2(-t.y, t.x) * THICK * 0.5
	return PackedVector2Array([a + side, b + side, b - side, a - side])
