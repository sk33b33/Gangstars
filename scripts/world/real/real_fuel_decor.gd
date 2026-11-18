class_name RealFuelDecor
extends RefCounted
## What makes a petrol station read as one: a "DUIN GARAGE" sign over the kiosk window, a price pylon with a board of fuel prices
## by the road, an air and water machine, bollards at the kiosk door, a litter bin, and stacks of tyres and oil drums along the
## kiosk wall. (The pump islands and canopy are RealLandmarks._forecourt.) `n` is the kiosk front's outward normal, `t` its tangent.

const CLUTTER_MIN_LENGTH := 10.0   # kiosk front at least this wide for the air machine, tyres and drums
const PYLON_MIN_ROOM := 3.5      # metres between the kiosk front and the road needed for the pylon
const PYLON_BOARD := Vector2(2.1, 1.5)
const PYLON_BOARD_Y := 4.9


static func draw(mid: Vector2, t: Vector2, n: Vector2, length: float, room: float, seed_value: int, surfaces: Dictionary, materials: Dictionary, props: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 31
	var yaw := atan2(n.x, n.y)
	var sign := RealChunkBuilder._tool("panel_sign_garage", surfaces, materials, PixelMaterials.panel("sign_garage"))
	RealChunkBuilder._panel(sign, mid + n * 0.04, t, n, minf(5.0, length - 1.0), 2.5, 3.2)
	var half := length * 0.5
	for k in 3:   # bollards across the kiosk door
		RealStreetDecor.add_prop(props, "bollard", mid + n * 0.9 + t * (k - 1) * 0.9, 0.0)
	RealStreetDecor.add_prop(props, "litter_bin", mid + n * 0.7 + t * minf(half - 0.9, 2.0), yaw)
	var side := 1.0 if rng.randi() % 2 == 0 else -1.0
	if length >= CLUTTER_MIN_LENGTH:   # a narrow front would put these against the neighbouring wall
		RealStreetDecor.add_prop(props, "air_machine", mid + n * 1.0 - t * side * (half - 1.0), yaw)
		RealStreetDecor.add_prop(props, "tyre_stack", mid + n * 0.7 + t * side * (half - 1.0), rng.randf() * TAU)
		RealStreetDecor.add_prop(props, "oil_drums", mid + n * 0.8 + t * side * (half - 2.4), rng.randf() * TAU)
	if room >= PYLON_MIN_ROOM:
		var at := mid + n * clampf(room * 0.7, 2.5, 9.0) + t * side * (half + 2.0)
		RealStreetDecor.add_prop(props, "price_pylon", at, 0.0)
		var board := RealChunkBuilder._tool("panel_sign_fuel_prices", surfaces, materials, PixelMaterials.panel("sign_fuel_prices"))
		var road_dir := t   # the board faces both ways along the road that runs past the front
		for s: float in [1.0, -1.0]:
			RealStreetDecor.face_quad(board, at, road_dir * s, PYLON_BOARD.x, PYLON_BOARD_Y, PYLON_BOARD_Y + PYLON_BOARD.y, 0.12)
