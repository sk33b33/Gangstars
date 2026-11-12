class_name HousePlot
extends Node3D
## Reusable house plot built from HouseData. Local frame: the street fence is along z = 0,
## the front of the plot faces +Z, the plot extends to z = -depth. Kits (from the reference
## photos) only change proportions, roof, garage and openings; colours come from data.

const SETBACK := 4.0
const FENCE_HEIGHT := 1.5
const FENCE_THICKNESS := 0.12
const GATE_WIDTH := 1.8
const STOREY := 2.8

const KITS := {
	"single_hip": {"w": 8.5, "d": 7.0, "x": -0.75, "storeys": 1, "door_x": 0.6, "roof": "hip", "roof_h": 1.6,
		"windows": [[-3.0, 1.0], [2.5, 1.0]]},
	"single_gable": {"w": 6.5, "d": 6.5, "x": -2.25, "storeys": 1, "door_x": -0.4, "roof": "gable", "roof_h": 1.4,
		"windows": [[-4.3, 1.0], [-2.3, 1.0]], "garage": {"x": 2.9, "w": 3.6, "d": 6.0}},
	"double_semi": {"w": 5.5, "d": 7.0, "x": -2.25, "storeys": 2, "door_x": -1.0, "roof": "gable_side", "roof_h": 1.2,
		"windows": [[-3.6, 1.0], [-3.6, 3.7], [-1.2, 3.7]]},
	"double_garage": {"w": 6.0, "d": 7.0, "x": -2.5, "storeys": 2, "door_x": -1.0, "roof": "gable", "roof_h": 1.0,
		"windows": [[-4.0, 1.0], [-4.0, 3.7], [-1.6, 3.7]], "garage": {"x": 2.6, "w": 3.8, "d": 6.5}},
	# Lentegeur: 3-storey walk-up flats (external stair tower, balconies) and narrow row houses.
	"flats": {"w": 16.0, "d": 8.0, "x": -1.2, "storeys": 3, "door_x": 8.0, "roof": "flat", "roof_h": 0.0,
		"windows": [[-7.0, 1.0], [-3.5, 1.0], [0.0, 1.0], [3.5, 1.0], [-7.0, 3.8], [-3.5, 3.8], [0.0, 3.8], [3.5, 3.8],
			[-7.0, 6.6], [-3.5, 6.6], [0.0, 6.6], [3.5, 6.6]],
		"stair": {"x": 8.0, "w": 2.6}, "balconies": true},
	# Rocklands: whitewashed limestone cottage, steep gable, chimney, low dry-stone wall.
	"cottage": {"w": 7.0, "d": 6.0, "x": -0.5, "storeys": 1, "door_x": -1.2, "roof": "gable", "roof_h": 1.9,
		"windows": [[-3.0, 1.1], [1.6, 1.1]], "wall_texture": "limestone_wall", "chimney": {"x": 2.7}},
	"row_house": {"w": 7.4, "d": 7.0, "x": 0.0, "storeys": 1, "door_x": -2.0, "roof": "gable_side", "roof_h": 1.1,
		"windows": [[1.2, 1.0]]},
}

var data: HouseData
var door_interactable: Interactable
var _door_local := Vector3.ZERO
var _door_hinge: Node3D
var _door_tween: Tween


func build(house: HouseData, closing_fence := false) -> void:
	data = house
	name = house.id
	transform = house.plot_transform()
	var kit: Dictionary = KITS[house.kit]
	var front_z := -SETBACK
	var h: float = STOREY * int(kit.storeys)
	var center := Vector3(kit.x, h * 0.5, front_z - kit.d * 0.5)
	var wall := PixelMaterials.surface(str(kit.get("wall_texture", "wall_plaster")), Vector2(2, 2), house.wall_color)

	# Body and splash-back grime band.
	Geo.box(self, Vector3(kit.w, h, kit.d), center, wall)
	Geo.box(self, Vector3(kit.w + 0.04, 0.5, kit.d + 0.04), Vector3(kit.x, 0.25, center.z),
		PixelMaterials.surface("wall_grime", Vector2(2, 0.5), house.wall_color), false)
	_build_roof(kit, h, center)

	# Openings on the street facade.
	var face := front_z + 0.03
	for win in kit.windows:
		Geo.quad(self, Vector2(1.5, 1.25), Vector3(win[0], win[1] + 0.62, face), PixelMaterials.panel("window_bars"))
	_build_facade_details(kit, h, front_z, face, center)
	_door_local = Vector3(kit.door_x, 0.0, front_z + 0.9)
	# Door on a hinge in front of a dark doorway, so it can swing open.
	Geo.quad(self, Vector2(1.0, 2.0), Vector3(kit.door_x, 1.0, face - 0.01), PixelMaterials.flat(Color("#141218")))
	_door_hinge = Node3D.new()
	_door_hinge.name = "DoorHinge"
	_door_hinge.position = Vector3(kit.door_x - 0.5, 0.0, face + 0.01)
	add_child(_door_hinge)
	Geo.quad(_door_hinge, Vector2(1.0, 2.0), Vector3(0.5, 1.0, 0.0), PixelMaterials.panel("door_gate"))
	Geo.box(self, Vector3(2.2, 0.1, 1.4), Vector3(kit.door_x, 0.05, front_z + 0.7),
		PixelMaterials.surface("sidewalk", Vector2(2, 2)), false)
	Geo.label(self, str(house.number), Vector3(kit.door_x + 0.85, 2.1, face + 0.01), 72, Color("#1d1b24"))

	# Garden path from the gate to the stoep.
	Geo.patch(self, Rect2(kit.door_x - 0.6, front_z, 1.2, -front_z), 0.012,
		PixelMaterials.surface("sidewalk", Vector2(2, 2)))

	var gaps: Array = [[kit.door_x, GATE_WIDTH]]
	if kit.has("garage"):
		_build_garage(kit.garage, front_z)
		gaps.append([kit.garage.x, kit.garage.w - 0.4])
	_build_fences(gaps, closing_fence)
	if kit.has("stair"):
		_build_flats_extras(kit, h, front_z)
	if kit.has("chimney"):
		var ch: float = float(kit.roof_h) + 0.9
		Geo.box(self, Vector3(0.7, ch, 0.7), Vector3(float(kit.x) + float(kit.chimney.x), h + ch * 0.5 - 0.3, front_z - float(kit.d) * 0.5),
			PixelMaterials.surface("limestone_wall", Vector2(2, 2), house.wall_color), false)
		Geo.box(self, Vector3(0.85, 0.12, 0.85), Vector3(float(kit.x) + float(kit.chimney.x), h + ch - 0.24, front_z - float(kit.d) * 0.5),
			PixelMaterials.flat(Color("#3d3d42")), false)
	_build_props(kit, h, front_z)
	_build_owner_additions(kit, h, front_z, face)
	if data.occupancy != "vacant":   # lamplight on the yard from the front windows and the door
		for win in kit.windows:
			if float(win[1]) < 2.0:
				NightGlow.add(self, Vector3(win[0], 0.04, face + 1.7), Vector2(3.4, 2.6))
		NightGlow.add(self, Vector3(kit.door_x, 0.045, face + 1.1), Vector2(2.4, 2.0))

	door_interactable = Interactable.new()
	door_interactable.name = "Door"
	door_interactable.position = _door_local + Vector3(0, 1.0, 0)
	door_interactable.prompt = "Knock on %s" % house.address()
	door_interactable.kind = "door"
	door_interactable.target = house.id
	if house.ownership == "player":
		door_interactable.prompt = "Enter safehouse (%s)" % house.address()
	add_child(door_interactable)


## Lived-in facade: gutter and downpipe, window sills, a meter box by the door, some cracks
## and rust stains, and (by plot) a stoep canopy, a TV aerial or a solar geyser on the roof.
## Plain shared-material meshes, so the static batcher merges them.
func _build_facade_details(kit: Dictionary, h: float, front_z: float, face: float, center: Vector3) -> void:
	var roll := absi(hash(data.id + ":facade"))
	var side := 1.0 if roll % 2 else -1.0
	var grey := PixelMaterials.flat(Color("#8a8f99"))
	var trim := PixelMaterials.flat(Color("#e8e4da"))
	var flat_roof: bool = str(kit.roof) == "flat"
	if not flat_roof:
		Geo.box(self, Vector3(float(kit.w) + 0.3, 0.12, 0.14), Vector3(kit.x, h - 0.04, face + 0.1), grey, false)   # gutter
	Geo.box(self, Vector3(0.09, h, 0.09), Vector3(float(kit.x) + side * (float(kit.w) * 0.5 - 0.15), h * 0.5, face + 0.07), grey, false)   # downpipe
	for win in kit.windows:
		Geo.box(self, Vector3(1.62, 0.06, 0.16), Vector3(win[0], float(win[1]) - 0.03, face + 0.08), trim, false)   # sill
	var door_x: float = kit.door_x
	Geo.box(self, Vector3(0.36, 0.5, 0.14), Vector3(door_x - side * 0.95, 1.55, face + 0.07), PixelMaterials.flat(Color("#c9c9c4")), false)   # meter box
	# Weathering: a crack from a window corner, a rust streak under a sill.
	if roll / 3 % 2 == 0 and not kit.windows.is_empty():
		var w0: Array = kit.windows[roll / 5 % kit.windows.size()]
		Geo.quad(self, Vector2(0.9, 0.9), Vector3(float(w0[0]) + 0.85, float(w0[1]) + 1.4, face + 0.012), PixelMaterials.panel("crack_a", Color.WHITE, true))
	if roll / 7 % 3 == 0 and not kit.windows.is_empty():
		var w1: Array = kit.windows[0]
		Geo.quad(self, Vector2(0.45, 0.9), Vector3(float(w1[0]), float(w1[1]) - 0.5, face + 0.011), PixelMaterials.panel("stain_rust", Color.WHITE, true))
	# Stoep canopy over the door (single-storey homes).
	if int(kit.storeys) == 1 and roll / 11 % 5 < 2:
		var roof := PixelMaterials.surface("roof_ibr", Vector2(2, 2), Color("#9aa3ab"))
		Geo.box(self, Vector3(2.4, 0.06, 1.5), Vector3(door_x, 2.42, face + 0.75), roof, false)
		for px in [-1.1, 1.1]:
			Geo.box(self, Vector3(0.07, 2.42, 0.07), Vector3(door_x + px, 1.21, face + 1.42), PixelMaterials.flat(Color("#f4f1ea")), false)
	if flat_roof:
		return
	var roof_h: float = kit.get("roof_h", 1.2)
	if roll / 13 % 5 < 2:   # TV aerial on the ridge
		var ax: float = float(kit.x) + side * 1.2
		var ay := h + roof_h
		Geo.box(self, Vector3(0.04, 1.6, 0.04), Vector3(ax, ay + 0.7, center.z), grey, false)
		for k in 3:
			Geo.box(self, Vector3(0.9 - k * 0.2, 0.03, 0.03), Vector3(ax, ay + 1.0 + k * 0.22, center.z), grey, false)
	elif roll / 13 % 5 == 2:   # solar geyser on the front slope
		var slope := atan2(roof_h, float(kit.d) * 0.5)
		var panel := Geo.box(self, Vector3(1.7, 0.06, 1.1), Vector3(float(kit.x) - side * 1.6, h + roof_h * 0.45 - 0.12, front_z - float(kit.d) * 0.24),
			PixelMaterials.flat(Color("#1f2f45")), false)
		panel.rotation.x = slope
		Geo.box(self, Vector3(1.6, 0.4, 0.4), Vector3(float(kit.x) - side * 1.6, h + roof_h * 0.8 + 0.3, front_z - float(kit.d) * 0.4),
			PixelMaterials.flat(Color("#d8dadf")), false)


## What owners add to the plain council house over the years (docs/MITCHELLS_PLAIN_REFERENCE.md):
## a front hedge or flower bed, a satellite dish, a lean-to room at the side, a corrugated-iron
## room or a Wendy house in the back yard, and a mural on the flats' blank wall. All visual only
## (no colliders), so paths and reachability never change.
func _build_owner_additions(kit: Dictionary, h: float, front_z: float, face: float) -> void:
	var roll := absi(hash(data.id + ":owner"))
	var half_w := data.plot_size.x * 0.5
	var depth := data.plot_size.y
	var body_x: float = kit.x
	var body_w: float = kit.w
	var door_x: float = kit.door_x
	var back_z: float = front_z - float(kit.d)
	if str(data.kit) == "flats":
		if roll % 3 == 0:
			Geo.quad(self, Vector2(6.0, 2.5), Vector3(body_x - 4.2, 1.75, face + 0.014), PixelMaterials.panel("mural_plain"))
		return
	var single := int(kit.storeys) == 1
	var pick := roll % 100
	# Front hedge (or a flowering shrub) beside the stoep, below the window sills.
	if single and pick < 35:
		var dir := 1.0 if door_x + 3.6 < body_x + body_w * 0.5 else -1.0
		var hx := door_x + dir * 2.4
		if absf(hx - body_x) < body_w * 0.5 - 1.0:
			var leaf := PixelMaterials.flat(Color("#4d7a3c") if roll / 7 % 2 == 0 else Color("#5f8a3a"))
			Geo.box(self, Vector3(2.2, 0.55, 0.65), Vector3(hx, 0.28, face + 0.5), leaf, false)
			if roll / 11 % 2 == 0:   # roses in bloom
				var bloom := PixelMaterials.flat(Color("#d6403e") if roll / 13 % 2 == 0 else Color("#f0a8c0"))
				for k in 4:
					Geo.box(self, Vector3(0.12, 0.12, 0.12), Vector3(hx - 0.8 + k * 0.5, 0.6, face + 0.82), bloom, false)
	# Satellite dish on the front wall.
	if roll / 3 % 100 < 30:
		var dx := body_x + (body_w * 0.5 - 0.7) * (1.0 if roll % 2 else -1.0)
		var dy := h - 0.75
		var dish := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.34
		cone.bottom_radius = 0.04
		cone.height = 0.16
		cone.radial_segments = 10
		dish.mesh = cone
		dish.material_override = PixelMaterials.flat(Color("#d8dadf"))
		dish.position = Vector3(dx, dy, face + 0.34)
		dish.rotation.x = PI * 0.5
		dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dish)
		Geo.box(self, Vector3(0.05, 0.05, 0.32), Vector3(dx, dy, face + 0.16), PixelMaterials.flat(Color("#8a8f99")), false)
	if not single or kit.has("garage"):
		return
	var back_ok := back_z - 3.4 > -depth + 0.3
	var kind := (roll / 5) % 100
	if kind < 26:   # a lean-to room added at the side, on the side with space
		var room_w := 2.6
		var left := body_x - body_w * 0.5 - room_w * 0.5
		var right := body_x + body_w * 0.5 + room_w * 0.5
		var ex := right if half_w - absf(right) > half_w - absf(left) else left
		if absf(ex) + room_w * 0.5 < half_w - 0.3:
			var paint: Color = [Color("#e9d7b8"), Color("#cfe0d0"), Color("#d9c4d8"), Color("#f2e4b8")][roll / 17 % 4]
			var ez := front_z - float(kit.d) * 0.68
			Geo.box(self, Vector3(room_w, 2.3, float(kit.d) * 0.55), Vector3(ex, 1.15, ez),
				PixelMaterials.surface("wall_plaster", Vector2(2, 2), paint), false)
			var lean := Geo.box(self, Vector3(room_w + 0.3, 0.08, float(kit.d) * 0.55 + 0.3), Vector3(ex, 2.42, ez),
				PixelMaterials.surface("roof_ibr", Vector2(2, 2), Color("#9aa3ab")), false)
			lean.rotation.z = 0.08 * (1.0 if ex > body_x else -1.0)
	elif kind < 52 and back_ok:   # a corrugated-iron room in the back yard (shared yards are common)
		var bx := (half_w - 1.9) * (1.0 if roll % 2 else -1.0)
		var bz := back_z - 2.2
		var iron := PixelMaterials.surface("roof_ibr", Vector2(1, 1), Color("#b7bcc2") if roll / 19 % 2 == 0 else Color("#c9b9a0"))
		Geo.box(self, Vector3(2.5, 2.1, 2.6), Vector3(bx, 1.05, bz), iron, false)
		var tin := Geo.box(self, Vector3(2.8, 0.07, 3.0), Vector3(bx, 2.2, bz), PixelMaterials.flat(Color("#7d828c")), false)
		tin.rotation.z = 0.1
		Geo.box(self, Vector3(0.8, 1.7, 0.06), Vector3(bx, 0.85, bz + 1.32), PixelMaterials.flat(Color("#3a4a5a")), false)
	elif kind < 64 and back_ok:   # a timber Wendy house, painted
		var wx := (half_w - 1.8) * (-1.0 if roll % 2 else 1.0)
		var wz := back_z - 2.0
		var paint: Color = [Color("#8fb8d8"), Color("#f2e4b8"), Color("#9fd8b8"), Color("#e8967a")][roll / 23 % 4]
		Geo.box(self, Vector3(2.0, 1.9, 2.0), Vector3(wx, 0.95, wz), PixelMaterials.flat(paint), false)
		Geo.box(self, Vector3(2.3, 0.08, 2.3), Vector3(wx, 1.98, wz), PixelMaterials.flat(Color("#6b4630")), false)
		Geo.box(self, Vector3(0.6, 1.2, 0.05), Vector3(wx, 0.62, wz + 1.03), PixelMaterials.flat(Color("#f4f1ea")), false)


## Front yard side that is free of the garden path and the garage/driveway.
func _free_side(kit: Dictionary) -> float:
	return -1.0 if kit.has("garage") or kit.door_x > 0.0 else 1.0


## Deterministic dressing from data. Solid props only go where no path runs (yard corners,
## back yard); thin decorative ones stay visual so they never cut off navigation.
func _build_props(kit: Dictionary, h: float, front_z: float) -> void:
	var p := data.props
	var half_w := data.plot_size.x * 0.5
	var depth := data.plot_size.y
	var side := _free_side(kit)
	var back_z: float = front_z - float(kit.d)
	match str(p.get("yard", "sand")):
		"paved":
			Geo.patch(self, Rect2(-half_w + 0.1, front_z, half_w * 2 - 0.2, -front_z - 0.1), 0.008,
				PixelMaterials.surface("paving_brick", Vector2(2, 2), Color(0.92, 0.88, 0.84)))
		"lawn":
			var lawn_x := side * (half_w - 2.1)
			Geo.patch(self, Rect2(lawn_x - 1.8, front_z + 0.3, 3.6, -front_z - 0.8), 0.009, PixelMaterials.flat(Color("#7fae55")))
	var roll := absi(hash(data.id))  # deterministic extras for data that predates them
	if p.get("bin", false):
		var bx := side * (half_w - 0.75)
		PropLibrary.place(self, "wheelie_bin", Vector3(bx, 0, -0.9), PI, Color("#2f6e3a") if roll % 4 else Color("#2a2d34"))
		Geo.collider(self, Vector3(0.6, 1.0, 0.75), Vector3(bx, 0.5, -0.9))
	var tx := side * (half_w - 2.2)
	if p.get("tree", false):
		PropLibrary.place(self, "tree_b" if roll % 2 else "tree_a", Vector3(tx, 0, -2.3), float(roll % 628) / 100.0)
		Geo.collider(self, Vector3(0.24, 2.0, 0.24), Vector3(tx, 1.0, -2.3))
	elif roll / 3 % 5 < 3:
		PropLibrary.place(self, "aloe", Vector3(tx, 0, -2.3), float(roll % 300) / 100.0)
	if str(p.get("yard", "sand")) != "paved" and roll / 7 % 20 < 9:
		var tyre_paint: Color = [Color("#f4f1ea"), Color("#e2585e"), Color("#3d6e8f"), Color("#f1c40f")][roll / 13 % 4]
		PropLibrary.place(self, "tyre_planters", Vector3(side * (half_w - 2.1), 0, -0.45), 0.0, tyre_paint)
	var stoep_z := front_z + 0.55
	if roll / 17 % 2 == 0:
		var chair := PropLibrary.place(self, "plastic_chair", Vector3(float(kit.door_x) + 1.15 * side, 0, stoep_z), 0.3 * side)
		SpotRegistry.marker(self, "sit", chair.position, chair.rotation.y)
	if roll / 19 % 20 < 7:
		PropLibrary.place(self, "gas_bottle", Vector3(float(kit.door_x) + 1.7 * side, 0, front_z + 0.3))
	if p.get("gate", false):
		# Steel gate leaf standing open inside the yard, beside the garden path.
		var gx: float = kit.door_x + GATE_WIDTH * 0.5
		Geo.quad(self, Vector2(1.2, 1.3), Vector3(gx + 0.05, 0.7, -0.62), PixelMaterials.surface("fence_palisade", Vector2(2, 1.5), Color("#56606e"), true), PI * 0.5)
	if p.get("dish", false):
		# On the front wall under the eaves, at the corner away from the door, aimed at the sky.
		var dx: float = float(kit.x) - side * (float(kit.w) * 0.5 - 0.6)
		PropLibrary.place(self, "satellite_dish", Vector3(dx, h - 0.45, front_z + 0.02), 0.35 * side)
	var back_space := back_z + depth  # metres between house back and rear fence
	if p.get("wendy", false) and back_space > 2.6:
		var wz := -depth + 1.3
		var wx := side * (half_w - 1.8)
		Geo.box(self, Vector3(3.0, 2.3, 2.3), Vector3(wx, 1.15, wz),
			PixelMaterials.surface("wendy_wall", Vector2(2, 2), Color("#cfe0e8") if side > 0 else Color("#f0d7c0")))
		Geo.box(self, Vector3(3.3, 0.08, 2.6), Vector3(wx, 2.35, wz), PixelMaterials.surface("roof_ibr", Vector2(2, 2)), false)
		Geo.quad(self, Vector2(0.8, 1.8), Vector3(wx - side * 0.6, 0.9, wz + 1.16), PixelMaterials.flat(Color("#6b4630")))
	elif p.get("washing", false) and back_space > 1.6:
		PropLibrary.place(self, "washing_line", Vector3(float(kit.x), 0, -depth + back_space * 0.5))
	# A JoJo tank in the back corner away from the wendy house / washing line.
	if back_space > 2.2 and roll / 23 % 10 < 3:
		var tank := Vector3(-side * (half_w - 1.0), 0, back_z - 1.0)
		PropLibrary.place(self, "jojo_tank", tank, 0.0, Color("#2f5d3a") if roll % 3 else Color("#24323f"))
		Geo.collider(self, Vector3(1.5, 2.0, 1.5), tank + Vector3(0, 1.0, 0))


## The open front yard between the fence and the house, in plot-local space (+Z = street side),
## kept clear of the fences. Yard dogs live here.
func front_yard() -> Rect2:
	var half_w := data.plot_size.x * 0.5
	return Rect2(-half_w + 0.5, -SETBACK + 0.6, data.plot_size.x - 1.0, SETBACK - 1.1)


## Swings the front door open and closed again (someone entering, leaving or answering).
func open_door(hold := 1.4) -> void:
	if _door_hinge == null or not is_inside_tree():
		return
	if _door_tween and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(_door_hinge, "rotation:y", 1.35, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_door_tween.tween_interval(hold)
	_door_tween.tween_property(_door_hinge, "rotation:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_door_open() -> bool:
	return _door_hinge != null and _door_hinge.rotation.y > 0.1


## Visible safehouse upgrades (props on the plot). Idempotent.
func show_upgrade(upgrade_id: String) -> void:
	if has_node("upgrade_" + upgrade_id):
		return
	var root := Node3D.new()
	root.name = "upgrade_" + upgrade_id
	add_child(root)
	var kit: Dictionary = KITS[data.kit]
	var front_z := -SETBACK
	match upgrade_id:
		"security_light":
			Geo.box(root, Vector3(0.5, 0.25, 0.25), Vector3(kit.door_x, 2.45, front_z + 0.15), PixelMaterials.lamp(), false)
		"mural":
			var mural := PixelMaterials.flat(Color("#e2585e"))
			Geo.box(root, Vector3(2.2, 1.6, 0.04), Vector3(kit.door_x - 2.6, 1.3, front_z + 0.03), mural, false)
			Geo.box(root, Vector3(1.4, 0.9, 0.05), Vector3(kit.door_x - 2.6, 1.3, front_z + 0.05), PixelMaterials.flat(Color("#f1d36b")), false)
			Geo.box(root, Vector3(0.6, 0.4, 0.06), Vector3(kit.door_x - 2.6, 1.3, front_z + 0.07), PixelMaterials.flat(Color("#2f6e3a")), false)
		"stash":
			Geo.box(root, Vector3(0.7, 0.5, 0.5), Vector3(kit.door_x + 2.4, 0.25, front_z + 1.6), PixelMaterials.flat(Color("#6b4630")), false)
		"crew_lounge":
			for dx in [-1.1, 1.1]:
				Geo.box(root, Vector3(0.5, 0.45, 0.5), Vector3(kit.door_x + dx, 0.32, front_z + 0.9), PixelMaterials.flat(Color("#2e86c1")), false)
				Geo.box(root, Vector3(0.5, 0.5, 0.08), Vector3(kit.door_x + dx, 0.75, front_z + 0.66), PixelMaterials.flat(Color("#2e86c1")), false)


func door_position() -> Vector3:
	return to_global(_door_local)


## Point on the sidewalk just outside the garden gate (crew guard spot, meeting point).
func gate_position() -> Vector3:
	return to_global(Vector3(_door_local.x, 0.0, 1.0))


func _build_roof(kit: Dictionary, h: float, center: Vector3) -> void:
	var overhang := 0.4
	var w: float = kit.w + overhang * 2
	var d: float = kit.d + overhang * 2
	var mi := MeshInstance3D.new()
	match kit.roof:
		"hip":
			mi.mesh = Geo.roof_mesh(w, d, kit.roof_h, minf(w, d) * 0.5)
		"gable_side":
			mi.mesh = Geo.roof_mesh(d, w, kit.roof_h, 0.0)
			mi.rotation.y = PI * 0.5
		"flat":
			Geo.box(self, Vector3(kit.w + 0.3, 0.35, kit.d + 0.3), Vector3(center.x, h + 0.175, center.z),
				PixelMaterials.flat(Color("#8a8f96")), false)
			return
		_:
			mi.mesh = Geo.roof_mesh(w, d, kit.roof_h, 0.0)
	var tex := "roof_tiles" if data.roof == "tiles" else "roof_ibr"
	mi.material_override = PixelMaterials.surface(tex, Vector2(2, 2))
	mi.position = Vector3(center.x, h, center.z)
	add_child(mi)


## Flats: external stair tower, a balcony with a steel railing on every upper floor, and
## laundry on some railings (data props "washing").
func _build_flats_extras(kit: Dictionary, h: float, front_z: float) -> void:
	var st: Dictionary = kit.stair
	var wall := PixelMaterials.surface("wall_plaster", Vector2(2, 2), data.wall_color.darkened(0.12))
	Geo.box(self, Vector3(st.w, h + 0.6, 2.6), Vector3(st.x, (h + 0.6) * 0.5, front_z - 1.3), wall)
	var slab := PixelMaterials.flat(Color("#a7acb4"))
	var rail := PixelMaterials.surface("fence_palisade", Vector2(2, 1.0), Color("#56606e"), true)
	var cloth := PixelMaterials.panel("washing", Color.WHITE, true)
	for s in range(1, int(kit.storeys)):
		var y: float = s * STOREY
		Geo.box(self, Vector3(kit.w, 0.15, 1.1), Vector3(kit.x, y, front_z + 0.55), slab, false)
		Geo.box(self, Vector3(kit.w, 1.0, 0.04), Vector3(kit.x, y + 0.55, front_z + 1.08), rail, false)
		if data.props.get("washing", false) and s % 2 == 1:
			Geo.quad(self, Vector2(2.0, 1.0), Vector3(float(kit.x) - 4.0, y + 0.6, front_z + 1.12), cloth)
		elif data.props.get("washing", false):
			Geo.quad(self, Vector2(2.0, 1.0), Vector3(float(kit.x) + 2.5, y + 0.6, front_z + 1.12), cloth)


func _build_garage(g: Dictionary, front_z: float) -> void:
	var gh := 2.7
	var wall := PixelMaterials.surface("wall_plaster", Vector2(2, 2), data.wall_color)
	Geo.box(self, Vector3(g.w, gh, g.d), Vector3(g.x, gh * 0.5, front_z - g.d * 0.5), wall)
	Geo.box(self, Vector3(g.w + 0.3, 0.15, g.d + 0.3), Vector3(g.x, gh + 0.075, front_z - g.d * 0.5),
		PixelMaterials.flat(Color("#6d7177")), false)
	Geo.quad(self, Vector2(2.5, 2.0), Vector3(g.x, 1.0, front_z + 0.03), PixelMaterials.panel("garage_door"))
	Geo.patch(self, Rect2(g.x - g.w * 0.5 + 0.2, front_z, g.w - 0.4, -front_z), 0.011,
		PixelMaterials.surface("paving_brick", Vector2(2, 2)))


## Low dry-stone walls (Rocklands) are shorter but still solid (above the nav obstacle height).
func _fence_height() -> float:
	return 1.0 if data.fence == "stone" else FENCE_HEIGHT


func _fence_material() -> Material:
	if data.fence == "stone":
		return PixelMaterials.surface("limestone_wall", Vector2(2, 1.0), data.fence_color)
	if data.fence == "palisade":
		return PixelMaterials.surface("fence_palisade", Vector2(2, FENCE_HEIGHT), data.fence_color, true)
	return PixelMaterials.surface("fence_precast", Vector2(2, FENCE_HEIGHT), data.fence_color, true)


## Front fence with gaps, plus the local -X side fence and rear fence. Neighbouring plots
## supply the other side; the last plot in a row sets `closing_fence` to close its +X side.
func _build_fences(gaps: Array, closing_fence: bool) -> void:
	var half_w := data.plot_size.x * 0.5
	var depth := data.plot_size.y
	var mat := _fence_material()
	var spans: Array = [[-half_w, half_w]]
	for gap in gaps:
		var g0: float = gap[0] - gap[1] * 0.5
		var g1: float = gap[0] + gap[1] * 0.5
		var next: Array = []
		for s in spans:
			if g1 <= s[0] or g0 >= s[1]:
				next.append(s)
				continue
			if g0 > s[0]:
				next.append([s[0], g0])
			if g1 < s[1]:
				next.append([g1, s[1]])
		spans = next
	for s in spans:
		var length: float = s[1] - s[0]
		if length > 0.05:
			_fence(Vector3((s[0] + s[1]) * 0.5, 0, 0), length, 0.0, mat)
	_fence(Vector3(-half_w, 0, -depth * 0.5), depth, PI * 0.5, mat)
	_fence(Vector3(0, 0, -depth), half_w * 2, 0.0, mat)
	if closing_fence:
		_fence(Vector3(half_w, 0, -depth * 0.5), depth, PI * 0.5, mat)


func _fence(center: Vector3, length: float, rot_y: float, mat: Material) -> void:
	var fh := _fence_height()
	var thick := 0.35 if data.fence == "stone" else FENCE_THICKNESS
	Geo.box(self, Vector3(length, fh, thick), center + Vector3(0, fh * 0.5, 0), mat, true, rot_y)
