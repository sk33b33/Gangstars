class_name RealHomeDecor
extends RefCounted
## What makes a real Westridge home look lived in: a wendy house or a washing line in the back yard,
## a JoJo water tank by the back wall, a satellite dish on the front wall, a front garden (aloes,
## bougainvillea against the fence, the odd lemon tree, pot plants on the stoep), a brick-paved
## driveway with now and then a car on it, and here and there a spaza shop run from the front room.
## Planned from the map data (RealDistrictData.home_decor), so the solid pieces (wendy houses, tanks,
## parked cars) are navigation obstacles too; drawn by the chunk builder. Design: design/gdd/real_world.md ("Homes").

const WENDY_HALF := Vector2(1.5, 1.2)     # 3.0 x 2.4 m
const WENDY_HEIGHT := 2.3
const WENDY_ONE_IN := 4
const TANK_ONE_IN := 5
const TANK_RADIUS := 0.65
const DISH_ONE_IN := 2
const SPAZA_ONE_IN := 30
const BACK_GAP := 0.6                    # between the house's back wall and a wendy house
const YARD_CARS := ["hatch", "sedan", "skoro", "hatch"]   # the ones that fit a 4.6 m driveway space
const PAINTED_CARS := ["#c8392f", "#f1eee8", "#2b6fb5", "#3d3d42", "#b7b9bd", "#2f8a4a", "#e0b02a"]


## The decor of one home: {back: {kind: "wendy"|"washing", at, u}, tank: Vector2, dish: {at, n},
## plants: [{kind, at}], spaza: bool, obstacles: [outline]}. `yard`: the home's RealYards plan or {}.
static func plan(ring: PackedVector2Array, front: Dictionary, yard: Dictionary, rings: Array, strips: Array, lanes: Array, fences: Array, story: bool, seed_value: int) -> Dictionary:
	var out := {"plants": [], "obstacles": [], "items": [], "lawns": []}
	var i: int = front.index
	var p0 := ring[i]
	var p1 := ring[(i + 1) % ring.size()]
	var mid: Vector2 = front.mid
	var n: Vector2 = front.normal
	var t := (p1 - p0).normalized()
	var half := p0.distance_to(p1) * 0.5
	var own_step := mid + n * RealChunkBuilder.DOOR_OUT
	var near_lanes: Array = lanes.filter(func(l): return l[0].distance_squared_to(mid) < 900.0 and l[0].distance_to(own_step) > RealYards.OWN_STEP)
	var near_fences: Array = fences.filter(func(f): return (f[0] as Vector2).distance_squared_to(mid) < 900.0)
	var area := Rect2(mid, Vector2.ZERO).grow(30.0)
	var near_strips: Array = strips.filter(func(s): return (s.box as Rect2).intersects(area))
	var back := 0.0
	for p in ring:
		back = maxf(back, (mid - p).dot(n))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Back yard: a wendy house (or else a washing line) behind the house.
	var want_wendy := rng.randi() % WENDY_ONE_IN == 0
	for off: float in [0.0, half * 0.35, -half * 0.35]:
		if want_wendy:
			var at := mid - n * (back + BACK_GAP + WENDY_HALF.y) + t * off
			var box := RealYards.obstacle_box(at, t, WENDY_HALF)
			if _free(box, ring, rings, near_strips, near_lanes, near_fences):
				out.back = {"kind": "wendy", "at": at, "u": t}
				out.obstacles.append(box)
				break
		else:
			var at := mid - n * (back + 1.6) + t * off
			if _free(RealYards.obstacle_box(at, t, Vector2(1.6, 0.4)), ring, rings, near_strips, near_lanes, near_fences):
				out.back = {"kind": "washing", "at": at, "u": t}
				break
	if rng.randi() % TANK_ONE_IN == 0:
		var sd := 1.0 if rng.randi() % 2 == 0 else -1.0
		var at := mid - n * (back + TANK_RADIUS + 0.15) + t * sd * maxf(0.0, half - 1.0)
		var box := RealYards.obstacle_box(at, t, Vector2(TANK_RADIUS, TANK_RADIUS))
		if _free(box, ring, rings, near_strips, near_lanes, near_fences) and not (out.has("back") and (out.back.at as Vector2).distance_to(at) < 2.4):
			out.tank = at
			out.obstacles.append(box)
	if rng.randi() % DISH_ONE_IN == 0:
		out.dish = {"at": mid + t * (half - 0.6) * (1.0 if rng.randi() % 2 == 0 else -1.0) + n * 0.3, "n": n}
	# Front garden, clear of the path to the gate and of the driveway.
	if not yard.is_empty():
		var depth := float(yard.depth)
		var drive_side := signf(float(yard.drive.get("centre_t", 0.0))) if not (yard.drive as Dictionary).is_empty() else 0.0
		for sd: float in [-1.0, 1.0]:
			if sd == drive_side or half < 2.4:
				continue
			out.plants.append({"kind": "aloe", "at": mid + t * sd * (half - 0.7) + n * minf(1.0, depth * 0.35)})
			if rng.randi() % 3 != 0:   # a bed of flowers by the path, and now and then a shrub or a hedge piece
				out.plants.append({"kind": "flowers", "at": mid + t * sd * (half - 1.5) + n * minf(1.6, depth * 0.5), "variant": rng.randi() % 3})
			if rng.randi() % 3 == 0 and depth >= 2.5:
				out.plants.append({"kind": "bush", "at": mid + t * sd * (half - 2.6) + n * (depth - 0.8), "variant": rng.randi() % 4})
			if rng.randi() % 2 == 0:
				out.plants.append({"kind": "bougainvillea", "at": mid + t * sd * (half - 0.7) + n * (depth - 0.6)})
			elif rng.randi() % 3 == 0 and depth >= 3.0:
				out.plants.append({"kind": "lemon_tree", "at": mid + t * sd * (half - 1.1) + n * (depth - 1.4)})
		if rng.randi() % 2 == 0:
			for sd: float in [-1.0, 1.0]:
				out.plants.append({"kind": "pot", "at": mid + t * sd * 0.95 + n * 0.35})
		# More of the garden: a paved path from the stoep to the gate, lawn patches either side of it, a wheelie bin and a letterbox by the
		# gate, plastic chairs on the stoep, tyre planters along the fence.
		var free_side := -drive_side if drive_side != 0.0 else (1.0 if rng.randi() % 2 == 0 else -1.0)
		if depth >= 2.2:
			out.path = {"a": mid + n * 0.66, "b": mid + n * (depth - 0.05)}
			if rng.randi() % 5 < 3 and half >= 3.0:
				for sd: float in [-1.0, 1.0]:
					if sd != drive_side:
						out.lawns.append({"at": mid + t * sd * (half * 0.5 + 0.55) + n * (depth * 0.5 + 0.3), "w": minf(half - 1.4, 3.2), "l": maxf(depth - 1.1, 1.0)})
			var gate := mid + n * depth
			if rng.randi() % 100 < 60:
				out.items.append({"prop": "wheelie_bin", "at": gate - n * 0.7 + t * free_side * (RealYards.GATE * 0.5 + 0.55), "face": n})
			if rng.randi() % 100 < 70:
				out.items.append({"prop": "letterbox", "at": gate + t * -free_side * (RealYards.GATE * 0.5 + 0.2), "face": n, "y": 1.05})
			if rng.randi() % 100 < 32 and half >= 2.4:
				for k in 2:
					out.items.append({"prop": "plastic_chair", "at": mid + t * (-1.0 if k == 0 else 1.0) * 1.55 + n * 0.85, "face": (n + t * (1.0 if k == 0 else -1.0) * 0.3).normalized()})
			if rng.randi() % 100 < 28 and depth >= 2.6:
				out.items.append({"prop": "tyre_planters", "at": mid + t * free_side * (half - 2.4) + n * (depth - 0.45), "face": t})
	# The back yard: a braai drum, a kennel and now and then a child's bicycle, clear of the other fittings.
	var back_taken: Array = []
	if out.has("back"):
		back_taken.append(out.back.at)
	if out.has("tank"):
		back_taken.append(out.tank)
	for item: Array in [["braai_drum", 25], ["kennel", 16], ["bicycle", 14]]:
		if rng.randi() % 100 >= int(item[1]):
			continue
		for off: float in [-half * 0.5, half * 0.5, 0.0]:
			var at := mid - n * (back + 1.3) + t * off
			if back_taken.any(func(o): return (o as Vector2).distance_to(at) < 2.4):
				continue
			if _free(RealYards.obstacle_box(at, t, Vector2(0.5, 0.5)), ring, rings, near_strips, near_lanes, near_fences):
				out.items.append({"prop": item[0], "at": at, "face": -n if item[0] == "kennel" else t})
				back_taken.append(at)
				break
	out.spaza = not story and rng.randi() % SPAZA_ONE_IN == 0 and half >= 3.2
	return out


## True when the box stands clear of buildings, lanes, doorsteps, fences and the streets.
static func _free(box: PackedVector2Array, own: PackedVector2Array, rings: Array, strips: Array, lanes: Array, fences: Array) -> bool:
	if not RealYards.box_clear(box, own, rings, lanes):
		return false
	for f: Array in fences:
		for k in 4:
			if Geometry2D.segment_intersects_segment(box[k], box[(k + 1) % 4], f[0], f[1]) != null:
				return false
	for p in box:
		for s: Dictionary in strips:
			if RealChunkBuilder._distance_to_lines(p, [s.line]) < float(s.reach) + 0.3:
				return false
	return true


# ------------------------------------------------------------------ drawing

## Draws a home's decor and its yard's driveway. `h`: the house's wall height.
static func draw(decor: Dictionary, yard: Dictionary, front: Dictionary, ring: PackedVector2Array, h: float, seed_value: int, root: Node3D, surfaces: Dictionary, materials: Dictionary, props: Dictionary, collision: PackedVector3Array, house_number := 0) -> void:
	var n: Vector2 = front.normal
	var mid: Vector2 = front.mid
	var t := Vector2(-n.y, n.x)
	draw_number(root, mid, t, n, number_for(house_number, seed_value), surfaces, materials)
	if not yard.is_empty() and not (yard.drive as Dictionary).is_empty():
		_driveway(yard, front, seed_value, root, surfaces, materials, collision)
	if decor.has("back"):
		var b: Dictionary = decor.back
		if b.kind == "wendy":
			_wendy(b.at, b.u, surfaces, materials, collision)
		else:
			RealStreetDecor.add_prop(props, "washing_line", b.at, atan2((b.u as Vector2).x, (b.u as Vector2).y) + PI * 0.5)
	if decor.has("tank"):
		RealStreetDecor.add_prop(props, "jojo_tank", decor.tank, 0.0)
	if decor.has("dish"):
		var dn: Vector2 = decor.dish.n
		RealStreetDecor.add_prop(props, "satellite_dish", decor.dish.at, atan2(dn.x, dn.y), 1.0, maxf(1.8, h - 0.6))
	if decor.has("path"):
		var path_tool := RealChunkBuilder._tool("garden_path", surfaces, materials, PixelMaterials.surface("sidewalk", Vector2(1.5, 1.5), Color("#cdc4ae")))
		RealChunkBuilder.strip(path_tool, PackedVector2Array([decor.path.a, decor.path.b]), 0.9, RealStreetDecor.Y_GROUND_DECAL + 0.001)
	for lawn: Dictionary in decor.get("lawns", []):
		var lawn_tool := RealStreetDecor._decal_tool("grass_patch", surfaces, materials)
		RealStreetDecor.decal(lawn_tool, lawn.at, n, float(lawn.w), float(lawn.l), RealStreetDecor.Y_GROUND_DECAL + 0.002)
	for it: Dictionary in decor.get("items", []):
		var face: Vector2 = it.face
		RealStreetDecor.add_prop(props, str(it.prop), it.at, atan2(face.x, face.y), 1.0, float(it.get("y", 0.0)))
	for plant: Dictionary in decor.get("plants", []):
		var at: Vector2 = plant.at
		match str(plant.kind):
			"aloe":
				RealStreetDecor.add_prop(props, "aloe", at, float(seed_value % 7))
			"lemon_tree":
				RealStreetDecor.add_prop(props, "tree_b", at, float(seed_value % 5), 0.55)
				var fruit := RealStreetDecor._flat("lemons", "#f2d23a", surfaces, materials)
				for k in 5:
					var a := TAU * k / 5.0 + seed_value
					RealLandmarks._obox(fruit, at + Vector2(cos(a), sin(a)) * 0.7, Vector2.RIGHT, Vector2(0.06, 0.06), 1.6 + (k % 2) * 0.3, 1.72 + (k % 2) * 0.3)
			"bougainvillea":
				var leaf := RealStreetDecor._flat("bougain_leaf", "#3f7a3a", surfaces, materials)
				var bloom := RealStreetDecor._flat("bougain_bloom", "#c8327a", surfaces, materials)
				RealLandmarks._obox(leaf, at, t, Vector2(0.55, 0.35), 0.0, 1.5)
				RealLandmarks._obox(bloom, at + n * 0.05, t, Vector2(0.6, 0.38), 1.2, 1.9)
				RealLandmarks._obox(bloom, at - t * 0.3, t, Vector2(0.3, 0.3), 0.7, 1.3)
			"flowers":
				RealStreetDecor.add_prop(props, ["flowers_pink", "flowers_yellow", "flowers_purple"][int(plant.get("variant", 0)) % 3], at, atan2(t.x, t.y) + PI * 0.5)
			"bush":
				RealStreetDecor.add_prop(props, ["bush", "bush_pink", "bush_yellow", "bush_white"][int(plant.get("variant", 0)) % 4], at, float(seed_value % 7), 0.8)
			"pot":
				RealLandmarks._prism(RealStreetDecor._flat("terracotta", "#b8714e", surfaces, materials), at, 0.22, 8, 0.0, 0.42, true)
				RealLandmarks._prism(RealStreetDecor._flat("pot_plant", "#4f8a3c", surfaces, materials), at, 0.26, 8, 0.42, 0.75, true)
	if decor.get("spaza", false):
		var at := mid + t * 1.7
		var sign := RealChunkBuilder._tool("panel_sign_spaza", surfaces, materials, PixelMaterials.panel("sign_spaza"))
		RealChunkBuilder._panel(sign, at, t, n, 2.4, 2.15, 2.75)
		RealChunkBuilder._panel(RealStreetDecor._flat("hatch", "#1d1b24", surfaces, materials), at, t, n, 0.9, 1.0, 1.6)
		RealStreetDecor.add_prop(props, "crate_stack", at + n * 0.9 + t * 0.6, 0.3)
		RealStreetDecor.add_prop(props, "plastic_chair", at + n * 1.0 - t * 0.6, 2.4)
		RealShopDecor.draw_spaza(at, t, n, seed_value, surfaces, materials, props)


## The number on a home: the game's own number for the homes that are in the game's data, else one made from the outline's seed (1 to 98),
## so every home has a number that never changes.
static func number_for(game_number: int, seed_value: int) -> int:
	return game_number if game_number > 0 else 1 + seed_value % 98


## A small white plate on the wall beside the front door, the number in black on it. The number is a Label3D that only shows within
## HOUSE_NUMBER_RANGE metres, so far-off streets cost nothing.
const HOUSE_NUMBER_RANGE := 16.0
const HOUSE_NUMBER_BESIDE := 1.25


static func draw_number(root: Node3D, mid: Vector2, t: Vector2, n: Vector2, number: int, surfaces: Dictionary, materials: Dictionary) -> Label3D:
	var at := mid + t * HOUSE_NUMBER_BESIDE
	RealLandmarks._obox(RealStreetDecor._flat("number_plate", "#f1eee8", surfaces, materials), at + n * 0.02, t, Vector2(0.17, 0.012), 1.5, 1.74)
	var label := Label3D.new()
	label.name = "HouseNumber"
	label.text = str(number)
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color("#1d1b24")
	label.outline_size = 0
	label.double_sided = false
	label.visibility_range_end = HOUSE_NUMBER_RANGE
	label.position = Vector3(at.x + n.x * 0.036, 1.62, at.y + n.y * 0.036)
	label.rotation.y = atan2(n.x, n.y)
	root.add_child(label)
	return label


static func _driveway(yard: Dictionary, front: Dictionary, seed_value: int, root: Node3D, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array) -> void:
	var n: Vector2 = front.normal
	var t := Vector2(-n.y, n.x)
	var drive: Dictionary = yard.drive
	var dc: Vector2 = front.mid + t * float(drive.centre_t)
	var depth := float(yard.depth) + float(drive.get("crossover", 0.0))
	var pave := RealChunkBuilder._tool("driveway", surfaces, materials, PixelMaterials.surface("paving_brick", Vector2(2, 2)))
	RealChunkBuilder.strip(pave, PackedVector2Array([dc + n * 0.05, dc + n * depth]), float(drive.width), RealStreetDecor.Y_GROUND_DECAL + 0.001)
	if drive.has("car"):
		var car: Dictionary = drive.car
		var at: Vector2 = car.at
		var d: Vector2 = car.dir
		var model: String = YARD_CARS[seed_value % YARD_CARS.size()]
		var pivot := VehicleLibrary.build(root, model, Color(PAINTED_CARS[seed_value % PAINTED_CARS.size()]), Vector3(at.x, 0.0, at.y), atan2(-d.y, d.x))
		for gi in pivot.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).visibility_range_end = 160.0
		var box := RealYards.obstacle_box(at, d, Vector2(RealYards.CAR_LENGTH * 0.5, RealYards.CAR_WIDTH * 0.5))
		for k in 4:
			var a := RealChunkBuilder._v(box[k], 0.0)
			var b := RealChunkBuilder._v(box[(k + 1) % 4], 0.0)
			collision.append_array([a, a + Vector3.UP * 1.4, b + Vector3.UP * 1.4, a, b + Vector3.UP * 1.4, b])
		RealStreetDecor.decal(RealStreetDecor._decal_tool("oil_stain", surfaces, materials), at, d, 0.9, 0.9, RealStreetDecor.Y_GROUND_DECAL + 0.002)


## A wendy house: a timber-panelled hut with a sloping iron roof and a door.
static func _wendy(at: Vector2, u: Vector2, surfaces: Dictionary, materials: Dictionary, collision: PackedVector3Array) -> void:
	var walls := RealChunkBuilder._tool("wendy", surfaces, materials, PixelMaterials.surface("wendy_wall", Vector2(2, 2)))
	var box := RealYards.obstacle_box(at, u, WENDY_HALF)
	for k in 4:
		var a := RealChunkBuilder._v(box[k], 0.0)
		var b := RealChunkBuilder._v(box[(k + 1) % 4], 0.0)
		RealChunkBuilder._quad(walls, a, b, WENDY_HEIGHT, RealChunkBuilder._v((box[k] + box[(k + 1) % 4]) * 0.5 - at, 0.0))
		collision.append_array([a, a + Vector3.UP * WENDY_HEIGHT, b + Vector3.UP * WENDY_HEIGHT, a, b + Vector3.UP * WENDY_HEIGHT, b])
	var v := Vector2(-u.y, u.x)
	var roof := RealChunkBuilder._tool("roof_ibr", surfaces, materials, PixelMaterials.surface("roof_ibr", Vector2(2, 2)))
	var r0 := at - u * (WENDY_HALF.x + 0.2) - v * (WENDY_HALF.y + 0.2)
	var r1 := at + u * (WENDY_HALF.x + 0.2) - v * (WENDY_HALF.y + 0.2)
	var r2 := at + u * (WENDY_HALF.x + 0.2) + v * (WENDY_HALF.y + 0.2)
	var r3 := at - u * (WENDY_HALF.x + 0.2) + v * (WENDY_HALF.y + 0.2)
	var low := WENDY_HEIGHT
	var high := WENDY_HEIGHT + 0.35
	for tri: Array in [[RealChunkBuilder._v(r0, low), RealChunkBuilder._v(r1, low), RealChunkBuilder._v(r2, high)], [RealChunkBuilder._v(r0, low), RealChunkBuilder._v(r2, high), RealChunkBuilder._v(r3, high)]]:
		RealChunkBuilder._up(roof, tri[0], tri[1], tri[2])
		RealChunkBuilder._facing(roof, tri[0], tri[1], tri[2], Vector3.DOWN)
	RealChunkBuilder._panel(RealChunkBuilder._tool("panel_door", surfaces, materials, PixelMaterials.panel("door_gate")), at - v * WENDY_HALF.y, u, -v, 0.8, 0.0, 1.9)
