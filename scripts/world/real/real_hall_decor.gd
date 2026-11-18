class_name RealHallDecor
extends RefCounted
## What makes a community hall read as one. The civic centre: a "WESTRIDGE CIVIC CENTRE" sign over the entrance, steel double doors, barred
## windows along the walls and a row of high windows in the raised hall, an events board by the street, benches and bins, bollards, a
## bicycle rack, a community vegetable garden of raised beds, a water tank and trees. The sports hall: its own sign, doors, high windows,
## a basketball post and two tall floodlights, benches and a bicycle rack. `n` is the front's outward normal, `t` its tangent.

const SIGN_Y := Vector2(3.5, 4.4)
const SIGN_WIDTH := 5.0
const DOOR_SIZE := Vector2(2.4, 2.5)
const HIGH_WINDOW_Y := Vector2(6.3, 7.5)    # in the raised civic hall (walls 5.0 to 8.5 m)
const HIGH_WINDOW_SPACING := 3.2
const BOARD_SIZE := Vector2(1.5, 1.1)
const BOARD_HEIGHT := 1.2
const BED_SIZE := Vector2(1.2, 0.6)
const MIN_FRONT := 8.0


static func draw_civic(mid: Vector2, t: Vector2, n: Vector2, length: float, rect: Dictionary, seed_value: int, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 71
	var yaw := atan2(n.x, n.y)
	_front(mid, t, n, length, "sign_civic", surfaces, materials)
	var half: Vector2 = rect.half
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var c: Vector2 = rect.c
	var high := RealChunkBuilder._tool("panel_window", surfaces, materials, PixelMaterials.panel("window_bars"))
	var count := int(half.x * 0.7 / HIGH_WINDOW_SPACING)
	for k in count:
		var along := -((count - 1) * HIGH_WINDOW_SPACING) * 0.5 + k * HIGH_WINDOW_SPACING
		for s: float in [-1.0, 1.0]:
			RealChunkBuilder._panel(high, c + u * along + v * s * half.y * 0.8, u, v * s, 1.6, HIGH_WINDOW_Y.x, HIGH_WINDOW_Y.y)
	if length < MIN_FRONT:
		return
	_notice_board("sign_events", mid + n * 6.0 - t * (length * 0.5 + 1.5), t, n, surfaces, materials)
	for s: float in [-1.0, 1.0]:
		RealStreetDecor.add_prop(props, "park_bench", mid + n * 1.8 + t * s * 4.0, yaw)
		RealStreetDecor.add_prop(props, "litter_bin", mid + n * 1.6 + t * s * 6.0, yaw)
		RealStreetDecor.add_prop(props, "tree_a" if s > 0.0 else "tree_c", mid + n * 8.0 + t * s * 9.0, rng.randf() * TAU)
	for k in 5:
		RealStreetDecor.add_prop(props, "bollard", mid + n * 4.0 + t * (k - 2) * 1.5, 0.0)
	RealStreetDecor.add_prop(props, "bike_rack", mid + n * 2.4 + t * (length * 0.5 - 2.0), atan2(-t.y, t.x))
	RealStreetDecor.add_prop(props, "jojo_tank", mid - n * (half.y * 2.0 + 2.0) + t * 4.0, 0.0)
	var soil := RealStreetDecor._flat("garden_soil", "#6b5a45", surfaces, materials)
	var beds := RealStreetDecor._flat("garden_veg", "#4f8a3c", surfaces, materials)
	var timber := RealStreetDecor._flat("bench_wood", "#8c6044", surfaces, materials)
	var garden := mid + n * 9.0 + t * (length * 0.5 + 6.0)
	for k in 3:
		var at := garden + n * k * 2.0
		RealLandmarks._obox(timber, at, t, BED_SIZE, 0.0, 0.35)
		RealLandmarks._obox(soil, at, t, BED_SIZE - Vector2(0.08, 0.08), 0.34, 0.37)
		RealLandmarks._obox(beds, at, t, BED_SIZE - Vector2(0.2, 0.2), 0.37, 0.6 + 0.1 * (k % 2))


static func draw_sports_hall(mid: Vector2, t: Vector2, n: Vector2, length: float, rect: Dictionary, seed_value: int, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var yaw := atan2(n.x, n.y)
	_front(mid, t, n, length, "sign_sports_hall", surfaces, materials)
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var high := RealChunkBuilder._tool("panel_window", surfaces, materials, PixelMaterials.panel("window_bars"))
	var count := maxi(1, int(half.x * 1.6 / HIGH_WINDOW_SPACING))
	for k in count:
		var along := -((count - 1) * HIGH_WINDOW_SPACING) * 0.5 + k * HIGH_WINDOW_SPACING
		for s: float in [-1.0, 1.0]:
			RealChunkBuilder._panel(high, c + u * along + v * s * half.y, u, v * s, 1.6, 4.6, 5.8)
	if length < MIN_FRONT:
		return
	RealStreetDecor.add_prop(props, "netball_post", mid + n * 4.0 + t * (length * 0.5 + 3.0), atan2(-t.x, -t.y))
	for s: float in [-1.0, 1.0]:
		RealStreetDecor.add_prop(props, "park_lamp", mid + n * 5.0 + t * s * (length * 0.5 + 1.0), 0.0)
		RealStreetDecor.add_prop(props, "park_bench", mid + n * 1.8 + t * s * 3.0, yaw)
	RealStreetDecor.add_prop(props, "litter_bin", mid + n * 1.6 + t * 5.0, yaw)
	RealStreetDecor.add_prop(props, "bike_rack", mid + n * 2.4 - t * (length * 0.5 - 2.0), atan2(-t.y, t.x))


## The sign over the door and the steel double doors under it.
static func _front(mid: Vector2, t: Vector2, n: Vector2, length: float, sign_tex: String, surfaces: Dictionary, materials: Dictionary) -> void:
	var sign := RealChunkBuilder._tool("panel_" + sign_tex, surfaces, materials, PixelMaterials.panel(sign_tex))
	RealChunkBuilder._panel(sign, mid + n * 0.04, t, n, minf(SIGN_WIDTH, maxf(length - 1.0, 1.0)), SIGN_Y.x, SIGN_Y.y)
	var door := RealChunkBuilder._tool("panel_door_hall", surfaces, materials, PixelMaterials.panel("door_hall"))
	RealChunkBuilder._panel(door, mid + n * 0.04, t, n, DOOR_SIZE.x, 0.0, DOOR_SIZE.y)


static func _notice_board(tex: String, at: Vector2, t: Vector2, n: Vector2, surfaces: Dictionary, materials: Dictionary) -> void:
	var steel := RealStreetDecor._flat("steel", RealLandmarks.STEEL, surfaces, materials)
	for s: float in [-1.0, 1.0]:
		RealLandmarks._obox(steel, at + t * s * (BOARD_SIZE.x * 0.5 - 0.1), t, Vector2(0.04, 0.04), 0.0, BOARD_HEIGHT + BOARD_SIZE.y)
	var board := RealChunkBuilder._tool("panel_" + tex, surfaces, materials, PixelMaterials.panel(tex))
	for s: float in [1.0, -1.0]:
		RealStreetDecor.face_quad(board, at, n * s, BOARD_SIZE.x, BOARD_HEIGHT, BOARD_HEIGHT + BOARD_SIZE.y, 0.08)
