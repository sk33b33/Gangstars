class_name CharacterModel
extends Node3D
## Low-poly person with a jointed rig: hips -> legs (with shoes), torso -> arms (with hands),
## head (eyes, hair style). Faces +Z. A procedural walk cycle is driven by distance travelled
## (stride-matched, so feet don't slide) and blends smoothly into an idle breathing pose.
## Meshes are shared between all characters (built once) to keep memory and setup cheap.
## Swap for a rigged model later without touching movement or AI code.

const STRIDE := 0.85          # metres per full step cycle (two steps)
const LEG_SWING := 0.55       # radians at full walking amplitude
const ARM_SWING := 0.45
const BLEND_RATE := 6.0       # how fast the gait blends in/out
const HAIR_STYLES: PackedStringArray = ["short", "doek", "beanie", "bald", "long"]

static var _meshes: Dictionary = {}

var _phase := 0.0
var _amp := 0.0
var _breath := 0.0
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hair: Node3D


## opts: {hair_style, hair_color: Color, height: float (1.0 = 1.75 m), sleeves: "long"/"short"}
func build(shirt: Color, pants: Color, skin: Color, hat: Color = Color(0, 0, 0, 0), opts: Dictionary = {}) -> void:
	for c in get_children():
		c.queue_free()
	var height: float = clampf(float(opts.get("height", 1.0)), 0.85, 1.12)
	scale = Vector3(lerpf(1.0, height, 0.5), height, lerpf(1.0, height, 0.5))
	var long_sleeves: bool = opts.get("sleeves", "long") == "long"
	var shoe := Color("#1d1b24")

	_hips = _pivot(self, "Hips", Vector3(0, 0.9, 0))
	_leg_l = _pivot(_hips, "LegL", Vector3(-0.1, 0, 0))
	_leg_r = _pivot(_hips, "LegR", Vector3(0.1, 0, 0))
	for leg in [_leg_l, _leg_r]:
		_part(leg, "leg", Vector3(0, -0.42, 0), pants)
		_part(leg, "shoe", Vector3(0, -0.86, 0.04), shoe)
	_part(_hips, "pelvis", Vector3(0, 0.02, 0), pants)

	_torso = _pivot(_hips, "Torso", Vector3(0, 0.05, 0))
	_part(_torso, "chest", Vector3(0, 0.3, 0), shirt)
	_arm_l = _pivot(_torso, "ArmL", Vector3(-0.27, 0.55, 0))
	_arm_r = _pivot(_torso, "ArmR", Vector3(0.27, 0.55, 0))
	for arm in [_arm_l, _arm_r]:
		_part(arm, "upper_arm", Vector3(0, -0.15, 0), shirt)
		_part(arm, "lower_arm", Vector3(0, -0.43, 0), shirt if long_sleeves else skin)
		_part(arm, "hand", Vector3(0, -0.62, 0.01), skin)

	_head = _pivot(_torso, "Head", Vector3(0, 0.74, 0))
	_part(_head, "neck", Vector3(0, -0.08, 0), skin)
	_part(_head, "head", Vector3(0, 0.06, 0), skin)
	_part(_head, "eyes", Vector3(0, 0.09, 0.135), Color("#1d1b24"))
	_build_hair(str(opts.get("hair_style", "short")), opts.get("hair_color", Color("#1d1b24")))
	if hat.a > 0.0:
		set_hat(hat)


## Adds (or recolours) a cap, e.g. when someone joins the player's crew. Hides the hair.
func set_hat(color: Color) -> void:
	if _head == null:
		return
	var cap := _head.get_node_or_null("Cap")
	if cap == null:
		cap = _pivot(_head, "Cap", Vector3.ZERO)
		_part(cap, "cap", Vector3(0, 0.17, 0), color)
		_part(cap, "brim", Vector3(0, 0.13, 0.15), color)
	else:
		for mi: MeshInstance3D in cap.get_children():
			mi.material_override = PixelMaterials.flat(color)
	if _hair:
		_hair.visible = false


## Call every frame with horizontal speed (m/s). Drives the gait and idle breathing.
func animate(delta: float, speed: float) -> void:
	if _hips == null:
		return
	var target_amp := clampf(speed / 1.4, 0.0, 1.3)
	_amp = lerpf(_amp, target_amp, clampf(delta * BLEND_RATE, 0.0, 1.0))
	_phase = fmod(_phase + speed * delta / STRIDE * TAU, TAU)
	var s := sin(_phase)
	_leg_l.rotation.x = s * LEG_SWING * _amp
	_leg_r.rotation.x = -s * LEG_SWING * _amp
	_arm_l.rotation.x = -s * ARM_SWING * _amp
	_arm_r.rotation.x = s * ARM_SWING * _amp
	_hips.position.y = 0.9 + absf(cos(_phase)) * 0.035 * _amp
	_torso.rotation.y = s * 0.06 * _amp
	_torso.rotation.x = 0.05 * minf(_amp, 1.0)
	# Idle breathing fades in as the gait fades out.
	_breath = fmod(_breath + delta * 1.6, TAU)
	var idle := 1.0 - minf(_amp, 1.0)
	_torso.scale = Vector3(1.0, 1.0 + sin(_breath) * 0.012 * idle, 1.0)
	_arm_l.rotation.z = -0.06 * idle
	_arm_r.rotation.z = 0.06 * idle


func walk_amplitude() -> float:
	return _amp


func _build_hair(style: String, color: Color) -> void:
	_hair = _pivot(_head, "Hair", Vector3.ZERO)
	match style:
		"short":
			_part(_hair, "hair_short", Vector3(0, 0.12, -0.015), color)
		"long":
			_part(_hair, "hair_short", Vector3(0, 0.12, -0.015), color)
			_part(_hair, "hair_back", Vector3(0, -0.02, -0.11), color)
		"doek":
			_part(_hair, "doek", Vector3(0, 0.13, -0.01), color)
			_part(_hair, "doek_knot", Vector3(0, 0.2, -0.12), color)
		"beanie":
			_part(_hair, "beanie", Vector3(0, 0.15, 0), color)
		_:
			pass


func _pivot(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh_name: String, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(mesh_name)
	mi.position = pos
	mi.material_override = PixelMaterials.flat(color)
	parent.add_child(mi)
	return mi


static func _mesh(mesh_name: String) -> Mesh:
	if _meshes.has(mesh_name):
		return _meshes[mesh_name]
	var m: Mesh
	match mesh_name:
		"leg": m = _box(Vector3(0.15, 0.82, 0.17))
		"shoe": m = _box(Vector3(0.15, 0.08, 0.26))
		"pelvis": m = _box(Vector3(0.38, 0.16, 0.2))
		"chest": m = _capsule(0.2, 0.62)
		"upper_arm": m = _box(Vector3(0.11, 0.32, 0.12))
		"lower_arm": m = _box(Vector3(0.1, 0.26, 0.11))
		"hand": m = _box(Vector3(0.09, 0.1, 0.1))
		"neck": m = _box(Vector3(0.09, 0.1, 0.09))
		"head": m = _sphere(0.14, 0.3)
		"eyes": m = _box(Vector3(0.15, 0.035, 0.03))
		"hair_short": m = _sphere(0.148, 0.2)
		"hair_back": m = _box(Vector3(0.24, 0.26, 0.06))
		"doek": m = _sphere(0.165, 0.24)
		"doek_knot": m = _sphere(0.06, 0.1)
		"beanie": m = _cylinder(0.15, 0.15, 0.14)
		"cap": m = _cylinder(0.15, 0.155, 0.08)
		"brim": m = _box(Vector3(0.24, 0.025, 0.14))
	_meshes[mesh_name] = m
	return m


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 4
	return c


static func _sphere(radius: float, height: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = 12
	s.rings = 6
	return s


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 12
	return c
