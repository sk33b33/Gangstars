class_name WindLitter
extends Node3D
## Paper, plastic bags and chip packets tumbling along the road in the south-easter: a small particle emitter that follows the camera and
## only runs while the wind is up, blowing the way the wind does (towards the north-west). Particles stay low and light.

const START := 0.3             # no litter blows below this wind
const SPREAD := 24.0           # half the width of the area round the camera it blows through (m)

var day_night: DayNight
var _p: CPUParticles3D


static func blowing(wind: float) -> bool:
	return wind >= START


func setup(p_day_night: DayNight) -> void:
	day_night = p_day_night
	_p = CPUParticles3D.new()
	_p.name = "Litter"
	_p.amount = 16
	_p.lifetime = 6.0
	_p.local_coords = false
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_p.emission_box_extents = Vector3(SPREAD, 0.2, SPREAD)
	_p.direction = Vector3(-0.8, 0.06, -0.6)   # the south-easter blows towards the north-west
	_p.spread = 14.0
	_p.initial_velocity_min = 2.0
	_p.initial_velocity_max = 5.0
	_p.gravity = Vector3(0, -0.15, 0)
	_p.angular_velocity_min = -240.0
	_p.angular_velocity_max = 240.0
	var tones := Gradient.new()
	tones.colors = PackedColorArray([Color("#f1eee8"), Color("#c9c4b8"), Color("#3b6fb5"), Color("#d6403e")])
	tones.offsets = PackedFloat32Array([0.0, 0.5, 0.75, 1.0])
	_p.color_initial_ramp = tones
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	_p.mesh = quad
	_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p.emitting = false
	add_child(_p)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or day_night == null:
		return
	global_position = Vector3(cam.global_position.x, 0.25, cam.global_position.z)
	_p.emitting = blowing(day_night.wind)
	_p.speed_scale = clampf(day_night.wind * 1.4, 0.4, 1.6)
