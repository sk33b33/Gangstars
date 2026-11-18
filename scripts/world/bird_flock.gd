class_name BirdFlock
extends Node3D
## Gulls and pigeons wheeling over the neighbourhood by day: ten small birds on slow circles round wherever the camera is, one MultiMesh
## updated each frame (ten transforms, nothing else). They go home at night and in a storm. Wing beats scale the V-shaped body up and down.

const COUNT := 10
const RADIUS := 26.0
const HEIGHT := 18.0
const FLAP_RATE := 9.0

var day_night: DayNight
var _mm: MultiMesh
var _node: MultiMeshInstance3D
var _t := 0.0


func setup(p_day_night: DayNight) -> void:
	day_night = p_day_night
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = _bird_mesh()
	_mm.instance_count = COUNT
	_node = MultiMeshInstance3D.new()
	_node.name = "Birds"
	_node.multimesh = _mm
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_node)


## Where bird `i` is at time `t` for a flock circling `centre`: its own slow circle, radius and height.
static func position_at(i: int, t: float, centre: Vector3) -> Vector3:
	var a := t * (0.16 + 0.02 * (i % 3)) + i * TAU / COUNT
	var r := RADIUS * (0.55 + 0.45 * fmod(i * 0.37, 1.0))
	return centre + Vector3(cos(a) * r, HEIGHT + 3.0 * sin(t * 0.5 + i), sin(a) * r)


## True when the birds are out: daylight, and not in rain or a hard blow.
static func out(night: float, rain_amount: float, wind: float) -> bool:
	return night < 0.5 and rain_amount < 0.4 and wind < 0.85


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var flying := cam != null and day_night != null and out(day_night.night_amount(), VehicleLibrary.rain, day_night.wind)
	_node.visible = flying
	if not flying:
		return
	for i in COUNT:
		var p := position_at(i, _t, cam.global_position)
		var ahead := position_at(i, _t + 0.1, cam.global_position) - p
		var yaw := atan2(ahead.x, ahead.z)
		var flap := 0.35 + 0.65 * absf(sin(_t * FLAP_RATE + i * 1.7))
		_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(1.0, flap, 1.0)), p))


static func _bird_mesh() -> ArrayMesh:
	var verts := PackedVector3Array([Vector3(0, 0, 0.3), Vector3(0, 0, -0.25), Vector3(-0.6, 0.18, -0.05), Vector3(0, 0, 0.3), Vector3(0.6, 0.18, -0.05), Vector3(0, 0, -0.25)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#e8e9ec")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh
