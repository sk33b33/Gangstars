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

	door_interactable = Interactable.new()
	door_interactable.name = "Door"
	door_interactable.position = _door_local + Vector3(0, 1.0, 0)
	door_interactable.prompt = "Knock on %s" % house.address()
	door_interactable.kind = "door"
	door_interactable.target = house.id
	if house.ownership == "player":
		door_interactable.prompt = "Enter safehouse (%s)" % house.address()
	add_child(door_interactable)


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
