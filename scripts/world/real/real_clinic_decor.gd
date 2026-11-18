class_name RealClinicDecor
extends RefCounted
## What makes a clinic or crèche read as one: a green-cross "WESTRIDGE CLINIC" sign over the door (a colourful "CRECHE" board for a
## kindergarten), an opening-hours board beside the door, benches for people waiting and a litter bin under the canopy, bollards
## at the kerb, a signpost by the road with a two-sided clinic board, and the ambulance bay painted in front of a clinic. A crèche gets
## spring riders and a sandpit out front instead of the bay. `n` is the front's outward normal, `t` its tangent.

const SIGN_Y := Vector2(3.3, 3.95)         # above the entrance canopy (its top is at 3.2 m)
const HOURS_SIZE := Vector2(0.6, 0.8)
const SIGNPOST_HEIGHT := 2.4
const SIGNPOST_BOARD := Vector2(1.4, 0.35)
const BAY_SIZE := Vector2(3.0, 6.0)         # across x along the road
const BAY_TEXT := Vector2(2.4, 1.2)
const MIN_FRONT := 6.0


static func draw(kind: String, mid: Vector2, t: Vector2, n: Vector2, length: float, seed_value: int, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var creche := kind == "kindergarten"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 53
	var yaw := atan2(n.x, n.y)
	var sign_tex := "sign_creche" if creche else "sign_clinic"
	var sign := RealChunkBuilder._tool("panel_" + sign_tex, surfaces, materials, PixelMaterials.panel(sign_tex))
	RealChunkBuilder._panel(sign, mid + n * 0.04, t, n, minf(4.0, maxf(length - 1.0, 1.0)), SIGN_Y.x, SIGN_Y.y)
	if length < MIN_FRONT:
		return
	if not creche:
		var hours := RealChunkBuilder._tool("panel_sign_clinic_hours", surfaces, materials, PixelMaterials.panel("sign_clinic_hours"))
		RealChunkBuilder._panel(hours, mid + t * 2.6 + n * 0.04, t, n, HOURS_SIZE.x, 1.2, 1.2 + HOURS_SIZE.y)
	for s: float in [-1.0, 1.0]:
		RealStreetDecor.add_prop(props, "park_bench", mid + n * 1.2 + t * s * 2.2, yaw)
	RealStreetDecor.add_prop(props, "litter_bin", mid + n * 1.0 + t * 3.8, yaw)
	for k in 3:
		RealStreetDecor.add_prop(props, "bollard", mid + n * 3.6 + t * (k - 1) * 1.6, 0.0)
	if creche:
		RealStreetDecor.add_prop(props, "spring_rider", mid + n * 3.0 - t * 4.5, rng.randf() * TAU)
		RealStreetDecor.add_prop(props, "spring_rider", mid + n * 3.4 - t * 6.0, rng.randf() * TAU)
		RealStreetDecor.add_prop(props, "seesaw", mid + n * 5.0 + t * 5.0, atan2(-t.y, t.x))
		var sand := RealStreetDecor._flat("play_sand", "#d9c49a", surfaces, materials)
		RealLandmarks._obox(sand, mid + n * 6.0 - t * 3.0, t, Vector2(1.6, 1.6), 0.0, 0.1)
		return
	var bay := mid + n * 5.0 - t * 3.0
	var paint := RealStreetDecor._flat("bay_paint", "#e6c12e", surfaces, materials)
	for e: Array in [[bay + t * BAY_SIZE.x * 0.5, n, Vector2(BAY_SIZE.y * 0.5, 0.06)], [bay - t * BAY_SIZE.x * 0.5, n, Vector2(BAY_SIZE.y * 0.5, 0.06)], [bay + n * BAY_SIZE.y * 0.5, t, Vector2(BAY_SIZE.x * 0.5, 0.06)], [bay - n * BAY_SIZE.y * 0.5, t, Vector2(BAY_SIZE.x * 0.5, 0.06)]]:
		RealLandmarks._obox(paint, e[0], e[1], e[2], RealStreetDecor.Y_GROUND_DECAL, RealStreetDecor.Y_GROUND_DECAL + 0.012)
	RealStreetDecor.decal(RealStreetDecor._decal_tool("bay_ambulance", surfaces, materials), bay, -n, BAY_TEXT.x, BAY_TEXT.y, RealStreetDecor.Y_GROUND_DECAL + 0.015)
	var post := mid + n * 7.5 + t * 7.0
	RealLandmarks._obox(RealStreetDecor._flat("steel", RealLandmarks.STEEL, surfaces, materials), post, t, Vector2(0.05, 0.05), 0.0, SIGNPOST_HEIGHT)
	var board := RealChunkBuilder._tool("panel_sign_clinic", surfaces, materials, PixelMaterials.panel("sign_clinic"))
	for s: float in [1.0, -1.0]:
		RealStreetDecor.face_quad(board, post, n * s, SIGNPOST_BOARD.x, SIGNPOST_HEIGHT - SIGNPOST_BOARD.y, SIGNPOST_HEIGHT, 0.08)
