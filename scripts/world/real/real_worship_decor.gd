class_name RealWorshipDecor
extends RefCounted
## What makes a church or mosque more than a shape: a church gets stained-glass windows between buttresses on its long walls, a pair of
## wooden doors up two steps at the front gable, a rose window in the gable, a notice board by the street and a few plants and a
## bench in front. A mosque gets arched windows (RealLandmarks._window_rows), a crescent on the dome and the minaret with loudspeakers
## under its balcony, a shoe rack and an ablution trough beside the entrance, a notice board and palms. `rect` is the building's
## RealChunkBuilder.min_rect: `u` along its long side, `half.x` the half length.

const CHURCH_WALL := 5.0
const WINDOW_SPACING := 3.6
const WINDOW_SIZE := Vector2(1.0, 2.6)
const WINDOW_Y := 1.3
const BUTTRESS := Vector2(0.22, 0.2)
const ROSE_MIN_RISE := 4.5          # the gable must rise this far for a rose window to fit in it
const BOARD_SIZE := Vector2(1.6, 0.6)
const BOARD_HEIGHT := 1.6
const LOUDSPEAKERS := 4


## `su` is the end (+1 or -1 along u) of the front gable, `rise` the roof's rise above CHURCH_WALL.
static func draw_church(rect: Dictionary, su: float, rise: float, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var u: Vector2 = rect.u
	var v: Vector2 = rect.v
	var c: Vector2 = rect.c
	var half: Vector2 = rect.half
	var stained := RealChunkBuilder._tool("panel_window_stained", surfaces, materials, PixelMaterials.panel("window_stained"))
	var stone := RealStreetDecor._flat("buttress", "#cfc9bd", surfaces, materials)
	var count := int((half.x * 2.0 - 4.0) / WINDOW_SPACING)
	for k in count:
		var along := -((count - 1) * WINDOW_SPACING) * 0.5 + k * WINDOW_SPACING
		for s: float in [-1.0, 1.0]:
			var wall_at := c + u * along + v * s * half.y
			RealChunkBuilder._panel(stained, wall_at, u, v * s, WINDOW_SIZE.x, WINDOW_Y, WINDOW_Y + WINDOW_SIZE.y)
			RealLandmarks._obox(stone, c + u * (along + WINDOW_SPACING * 0.5) + v * s * (half.y + BUTTRESS.y), u, BUTTRESS, 0.0, CHURCH_WALL * 0.85)
	var n := u * su
	var end := c + n * half.x
	var door := RealChunkBuilder._tool("panel_door_church", surfaces, materials, PixelMaterials.panel("door_church"))
	RealChunkBuilder._panel(door, end, v, n, 1.8, 0.0, 2.7)
	RealLandmarks._obox(stone, end + n * 0.3, v, Vector2(1.5, 0.3), 0.0, 0.3)
	RealLandmarks._obox(stone, end + n * 0.75, v, Vector2(1.3, 0.15), 0.0, 0.15)
	if rise >= ROSE_MIN_RISE:
		var rose := RealChunkBuilder._tool("panel_rose_window", surfaces, materials, PixelMaterials.panel("rose_window"))
		RealChunkBuilder._panel(rose, end, v, n, 2.0, CHURCH_WALL + 0.9, CHURCH_WALL + 2.9)
	var yaw := atan2(n.x, n.y)
	_notice_board("sign_church", end + n * 7.0 + v * (half.y * 0.5 + 2.0), v, n, surfaces, materials)
	for s: float in [-1.0, 1.0]:
		RealStreetDecor.add_prop(props, "flowers_pink" if s > 0.0 else "flowers_yellow", end + n * 1.4 + v * s * 2.7, atan2(v.x, v.y))
	RealStreetDecor.add_prop(props, "park_bench", end + n * 3.0 + v * 3.6, yaw)
	RealStreetDecor.add_prop(props, "litter_bin", end + n * 3.0 + v * 5.0, yaw)
	RealStreetDecor.add_prop(props, "palm", end + n * 5.0 - v * (half.y + 1.5), 0.0)
	RealStreetDecor.add_prop(props, "tree_a", end + n * 6.0 + v * (half.y + 2.5), 1.0)


## `dome_top` and `minaret_top` are the heights where the dome and the minaret's little dome end.
static func draw_mosque(rect: Dictionary, front: Dictionary, c: Vector2, dome_top: float, minaret: Vector2, minaret_top: float, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	RealStreetDecor.add_prop(props, "crescent_finial", c, 0.0, 1.0, dome_top - 0.05)
	RealStreetDecor.add_prop(props, "crescent_finial", minaret, 0.0, 0.6, minaret_top - 0.05)
	var trim := RealStreetDecor._flat("speaker", "#6d7177", surfaces, materials)
	for k in LOUDSPEAKERS:
		var a := TAU * k / LOUDSPEAKERS + 0.4
		RealLandmarks._obox(trim, minaret + Vector2.RIGHT.rotated(a) * 1.2, Vector2.RIGHT.rotated(a), Vector2(0.15, 0.2), RealLandmarks.MINARET_HEIGHT - 3.4, RealLandmarks.MINARET_HEIGHT - 2.9)
	if front.is_empty():
		return
	var n: Vector2 = front.normal
	var t := Vector2(-n.y, n.x)
	var mid: Vector2 = front.mid
	var steel := RealStreetDecor._flat("steel", RealLandmarks.STEEL, surfaces, materials)
	var rack := RealStreetDecor._flat("bench_wood", "#8c6044", surfaces, materials)
	RealLandmarks._obox(rack, mid + t * 3.0 + n * 0.5, t, Vector2(1.0, 0.2), 0.05, 0.12)
	RealLandmarks._obox(rack, mid + t * 3.0 + n * 0.5, t, Vector2(1.0, 0.2), 0.45, 0.52)
	RealLandmarks._obox(rack, mid + t * 3.0 + n * 0.5, t, Vector2(1.0, 0.2), 0.85, 0.92)
	for s: float in [-1.0, 1.0]:
		RealLandmarks._obox(rack, mid + t * (3.0 + s * 1.0) + n * 0.5, t, Vector2(0.04, 0.2), 0.0, 0.92)
	RealLandmarks._obox(RealStreetDecor._flat("wudu", "#b9b4a8", surfaces, materials), mid - t * 3.2 + n * 1.0, t, Vector2(1.4, 0.3), 0.0, 0.4)
	for k in 3:
		RealLandmarks._obox(steel, mid - t * (2.2 + k * 0.9) + n * 0.8, t, Vector2(0.03, 0.03), 0.4, 0.8)
	_notice_board("sign_mosque", mid + n * 5.5 - t * 4.0, t, n, surfaces, materials)
	RealStreetDecor.add_prop(props, "palm", mid + n * 4.0 + t * 6.0, 0.0)
	RealStreetDecor.add_prop(props, "palm", mid + n * 4.0 - t * 7.0, 1.7)
	RealStreetDecor.add_prop(props, "flowers_purple", mid + n * 1.8 + t * 1.2, atan2(t.x, t.y))


## A notice board on two posts at `at`, its writing facing along `n` and the other way (`t` runs along the board).
static func _notice_board(tex: String, at: Vector2, t: Vector2, n: Vector2, surfaces: Dictionary, materials: Dictionary) -> void:
	var steel := RealStreetDecor._flat("steel", RealLandmarks.STEEL, surfaces, materials)
	for s: float in [-1.0, 1.0]:
		RealLandmarks._obox(steel, at + t * s * (BOARD_SIZE.x * 0.5 - 0.1), t, Vector2(0.04, 0.04), 0.0, BOARD_HEIGHT + BOARD_SIZE.y)
	var board := RealChunkBuilder._tool("panel_" + tex, surfaces, materials, PixelMaterials.panel(tex))
	for s: float in [1.0, -1.0]:
		RealStreetDecor.face_quad(board, at, n * s, BOARD_SIZE.x, BOARD_HEIGHT, BOARD_HEIGHT + BOARD_SIZE.y, 0.08)
