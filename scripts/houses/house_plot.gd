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
}

var data: HouseData
var door_interactable: Interactable
var _door_local := Vector3.ZERO


func build(house: HouseData, closing_fence := false) -> void:
	data = house
	name = house.id
	transform = house.plot_transform()
	var kit: Dictionary = KITS[house.kit]
	var front_z := -SETBACK
	var h: float = STOREY * int(kit.storeys)
	var center := Vector3(kit.x, h * 0.5, front_z - kit.d * 0.5)
	var wall := PixelMaterials.surface("wall_plaster", Vector2(2, 2), house.wall_color)

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
	Geo.quad(self, Vector2(1.0, 2.0), Vector3(kit.door_x, 1.0, face), PixelMaterials.panel("door_gate"))
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

	door_interactable = Interactable.new()
	door_interactable.name = "Door"
	door_interactable.position = _door_local + Vector3(0, 1.0, 0)
	door_interactable.prompt = "Knock on %s" % house.address()
	if house.ownership == "player":
		door_interactable.prompt = "Enter safehouse (%s)" % house.address()
	add_child(door_interactable)


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
		_:
			mi.mesh = Geo.roof_mesh(w, d, kit.roof_h, 0.0)
	var tex := "roof_tiles" if data.roof == "tiles" else "roof_ibr"
	mi.material_override = PixelMaterials.surface(tex, Vector2(2, 2))
	mi.position = Vector3(center.x, h, center.z)
	add_child(mi)


func _build_garage(g: Dictionary, front_z: float) -> void:
	var gh := 2.7
	var wall := PixelMaterials.surface("wall_plaster", Vector2(2, 2), data.wall_color)
	Geo.box(self, Vector3(g.w, gh, g.d), Vector3(g.x, gh * 0.5, front_z - g.d * 0.5), wall)
	Geo.box(self, Vector3(g.w + 0.3, 0.15, g.d + 0.3), Vector3(g.x, gh + 0.075, front_z - g.d * 0.5),
		PixelMaterials.flat(Color("#6d7177")), false)
	Geo.quad(self, Vector2(2.5, 2.0), Vector3(g.x, 1.0, front_z + 0.03), PixelMaterials.panel("garage_door"))
	Geo.patch(self, Rect2(g.x - g.w * 0.5 + 0.2, front_z, g.w - 0.4, -front_z), 0.011,
		PixelMaterials.surface("paving_brick", Vector2(2, 2)))


func _fence_material() -> Material:
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
	Geo.box(self, Vector3(length, FENCE_HEIGHT, FENCE_THICKNESS), center + Vector3(0, FENCE_HEIGHT * 0.5, 0), mat, true, rot_y)
