class_name LightPool
extends Node3D
## Real light for streetlights without paying for dozens of lights: a handful of OmniLight3D
## are moved to the lamps nearest the camera every half second, only at night with power.

const POOL := 6
const RANGE := 11.0

var day_night: DayNight
var lamps := PackedVector3Array()
var _lights: Array[OmniLight3D] = []
var _accum := 0.0
var _glow: MultiMeshInstance3D
var _glow_mat: StandardMaterial3D


## Lamp heads are the high (y > 4 m) meshes using the shared lamp material.
static func collect_lamps(root: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	var lamp := PixelMaterials.lamp()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.material_override == lamp and mi.global_position.y > 4.0:
			out.append(mi.global_position)
	return out


func setup(p_day_night: DayNight, p_lamps: PackedVector3Array) -> void:
	day_night = p_day_night
	lamps = p_lamps
	for i in POOL:
		var l := OmniLight3D.new()
		l.light_color = Color("#ffc985")
		l.light_energy = 1.6
		l.omni_range = RANGE
		l.omni_attenuation = 1.3
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)
	_make_glow()


## A soft warm pool painted on the ground under every lamp (one draw call for all of them),
## so far-off streets glow too, not only the few lamps with a real light.
func _make_glow() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.78, 0.5, 0.55))
	g.set_color(1, Color(1.0, 0.78, 0.5, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.albedo_texture = tex
	_glow_mat.albedo_color = Color(1, 1, 1, 0)
	var quad := PlaneMesh.new()
	quad.size = Vector2(9.0, 9.0)
	quad.material = _glow_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = lamps.size()
	for i in lamps.size():
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(lamps[i].x, 0.045, lamps[i].z)))
	_glow = MultiMeshInstance3D.new()
	_glow.name = "LampGlow"
	_glow.multimesh = mm
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	add_child(_glow)


func glow_visible() -> bool:
	return _glow != null and _glow.visible


func active_count() -> int:
	return _lights.filter(func(l): return l.visible).size()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.5:
		return
	_accum = 0.0
	var cam := get_viewport().get_camera_3d()
	if _glow:
		_glow.visible = day_night != null and day_night.is_lit
		_glow_mat.albedo_color.a = 1.0 if _glow.visible else 0.0
	if day_night == null or not day_night.is_lit or cam == null or lamps.is_empty():
		for l in _lights:
			l.visible = false
		return
	var origin := cam.global_position
	var order := Array(lamps)
	order.sort_custom(func(a, b): return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	for i in POOL:
		_lights[i].visible = i < order.size()
		if i < order.size():
			_lights[i].global_position = order[i] - Vector3(0, 0.3, 0)
