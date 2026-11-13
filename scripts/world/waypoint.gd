class_name Waypoint
extends Node3D
## The marker for where to go next: a soft gold beam of light you can see across the street and a
## spinning diamond above it. It fades out when you are close, so it never hides the person or door
## you are walking up to. GameSession decides the target (objective_position); the HUD shows the
## distance and an arrow when the target is off screen.

var target: Variant = null    # Vector3 or null
var _beam: MeshInstance3D
var _gem: MeshInstance3D
var _mat: StandardMaterial3D
var _gem_mat: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	name = "Waypoint"
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_color = Color(1.0, 0.82, 0.3, 0.22)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_fog = true
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.5
	cyl.height = 60.0
	cyl.radial_segments = 12
	_beam = MeshInstance3D.new()
	_beam.mesh = cyl
	_beam.material_override = _mat
	_beam.position = Vector3(0, 30, 0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_gem_mat = StandardMaterial3D.new()
	_gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gem_mat.albedo_color = Color(1.0, 0.85, 0.35)
	_gem_mat.disable_fog = true
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	_gem = MeshInstance3D.new()
	_gem.mesh = box
	_gem.material_override = _gem_mat
	_gem.rotation = Vector3(0.6, 0, 0.6)
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gem)
	visible = false


func set_target(pos: Variant) -> void:
	target = pos
	visible = pos != null
	if pos != null:
		global_position = pos


func _process(delta: float) -> void:
	if target == null:
		return
	_time += delta
	_gem.position = Vector3(0, 3.0 + sin(_time * 2.0) * 0.15, 0)
	_gem.rotation.y += delta * 1.6
	var cam := get_viewport().get_camera_3d()
	var near := 1.0
	if cam:
		near = smoothstep(4.0, 14.0, Vector2(cam.global_position.x - global_position.x, cam.global_position.z - global_position.z).length())
	_mat.albedo_color.a = 0.22 * near
	_gem.visible = near > 0.05
