class_name RealTransitDecor
extends RefCounted
## What makes a bus or taxi stop read as one: a yellow painted kerb along the bay, BUS or TAXI painted on the tarmac, a timetable on the
## shelter's back wall, a litter bin beside it, and now and then a hawker's crates and chairs. The same pieces dress the small
## "bus station" building (a taxi rank sign, bench and bollards). `d` is the road's direction, `left` the way to the stop's side.

const BAY_LENGTH := 14.0
const BAY_PAINT := "#e6c12e"
const KERB_LINE_WIDTH := 0.16
const BAY_TEXT_SIZE := Vector2(2.6, 2.2)    # across x along the road
const TIMETABLE_SIZE := Vector2(0.7, 0.85)
const HAWKER_ONE_IN := 3


## The extras for a shelter at `at` (the road's centre line at the shelter), on the `left` side of a road `width` wide, a `taxi` stop or a bus stop.
static func draw_stop(line: PackedVector2Array, at_dist: float, width: float, left_side: Vector2, d: Vector2, back: Vector2, taxi: bool, rng: RandomNumberGenerator, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var here: Array = RealStreetDecor.at_distance(line, at_dist)
	var centre: Vector2 = here[0]
	var start: Array = RealStreetDecor.at_distance(line, maxf(0.0, at_dist - BAY_LENGTH * 0.5))
	var end: Array = RealStreetDecor.at_distance(line, at_dist + BAY_LENGTH * 0.5)
	var kerb_off := width * 0.5 - KERB_LINE_WIDTH * 0.5 - 0.02
	var kerb_line := PackedVector2Array([(start[0] as Vector2) + left_side * kerb_off, centre + left_side * kerb_off, (end[0] as Vector2) + left_side * kerb_off])
	RealChunkBuilder.strip(RealStreetDecor._flat("bay_paint", BAY_PAINT, surfaces, materials), kerb_line, KERB_LINE_WIDTH, RealStreetDecor.Y_ROAD_DECAL + 0.001)
	var words := RealStreetDecor._decal_tool("bay_taxi" if taxi else "bay_bus", surfaces, materials)
	RealStreetDecor.decal(words, centre + left_side * (width * 0.5 - 1.5), d, BAY_TEXT_SIZE.x, BAY_TEXT_SIZE.y, RealStreetDecor.Y_ROAD_DECAL + 0.002)
	var table := RealChunkBuilder._tool("panel_sign_timetable", surfaces, materials, PixelMaterials.panel("sign_timetable"))
	var wall_at: Vector2 = centre + left_side * (width * 0.5 + RealChunkBuilder.KERB_WIDTH + 0.4 + 1.6)
	RealChunkBuilder._panel(table, wall_at - left_side * 0.02, d, -left_side, TIMETABLE_SIZE.x, 1.0, 1.0 + TIMETABLE_SIZE.y)
	RealStreetDecor.add_prop(props, "litter_bin", centre + left_side * (width * 0.5 + RealChunkBuilder.KERB_WIDTH + 0.7) + d * 2.4, rng.randf() * TAU)
	_ad_board(centre + left_side * (width * 0.5 + RealChunkBuilder.KERB_WIDTH + 1.4) - d * 2.6, d, -left_side, rng, surfaces, materials)
	if rng.randi() % HAWKER_ONE_IN == 0:
		var spot := centre + left_side * (width * 0.5 + RealChunkBuilder.KERB_WIDTH + 0.9) - d * 3.4
		RealStreetDecor.add_prop(props, "crate_stack", spot, rng.randf() * TAU)
		RealStreetDecor.add_prop(props, "plastic_chair", spot + d * 0.9, rng.randf() * TAU)
		RealStreetDecor.add_prop(props, "plastic_chair", spot - d * 0.8, rng.randf() * TAU)


## An advert board on two steel posts beside the shelter, with a poster on each face (one facing each way along the pavement).
const ADS := ["ad_soap", "ad_airtime"]
const AD_SIZE := Vector2(0.8, 1.1)


static func _ad_board(at: Vector2, d: Vector2, to_road: Vector2, rng: RandomNumberGenerator, surfaces: Dictionary, materials: Dictionary) -> void:
	var steel := RealStreetDecor._flat("steel", RealLandmarks.STEEL, surfaces, materials)
	for s: float in [-1.0, 1.0]:
		RealLandmarks._obox(steel, at + d * s * (AD_SIZE.x * 0.5 - 0.05), d, Vector2(0.04, 0.04), 0.0, 1.9)
	var tex: String = ADS[rng.randi() % ADS.size()]
	var tool := RealChunkBuilder._tool("panel_" + tex, surfaces, materials, PixelMaterials.panel(tex))
	for s: float in [1.0, -1.0]:
		RealStreetDecor.face_quad(tool, at, to_road * s, AD_SIZE.x, 0.7, 0.7 + AD_SIZE.y, 0.05)


## The small "bus station" building: a taxi rank sign over its front, a bench and a litter bin, and bollards along the kerb side.
static func draw_station(mid: Vector2, t: Vector2, n: Vector2, length: float, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var sign := RealChunkBuilder._tool("panel_sign_taxi_rank", surfaces, materials, PixelMaterials.panel("sign_taxi_rank"))
	RealChunkBuilder._panel(sign, mid + n * 0.04, t, n, minf(3.2, length - 0.4), 2.2, 2.9)
	var yaw := atan2(n.x, n.y)
	RealStreetDecor.add_prop(props, "park_bench", mid + n * 1.3, yaw)
	RealStreetDecor.add_prop(props, "litter_bin", mid + n * 1.1 + t * (length * 0.5 + 0.4), yaw)
	for k in 3:
		RealStreetDecor.add_prop(props, "bollard", mid + n * 3.2 + t * (k - 1) * 1.4, 0.0)
