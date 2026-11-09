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


func active_count() -> int:
	return _lights.filter(func(l): return l.visible).size()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.5:
		return
	_accum = 0.0
	var cam := get_viewport().get_camera_3d()
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
