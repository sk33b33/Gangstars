class_name FootDust
extends CPUParticles3D
## Little puffs of sand kicked up behind the player's feet when running (not walking, not driving). Added to the Player; reads its velocity.

const MIN_SPEED := 3.4   # m/s: a jog and faster

var _body: CharacterBody3D


static func should_puff(speed: float, on_floor: bool, driving: bool) -> bool:
	return speed >= MIN_SPEED and on_floor and not driving


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	name = "FootDust"
	amount = 10
	lifetime = 0.7
	local_coords = false
	position = Vector3(0, 0.08, 0)
	direction = Vector3(0, 0.6, 0)
	spread = 35.0
	initial_velocity_min = 0.4
	initial_velocity_max = 1.0
	gravity = Vector3(0, -0.2, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.5))
	scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.76, 0.58, 0.45))
	fade.set_color(1, Color(0.85, 0.76, 0.58, 0.0))
	color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	quad.material = mat
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 25.0
	emitting = false


func _physics_process(_delta: float) -> void:
	if _body == null:
		return
	var flat := Vector2(_body.velocity.x, _body.velocity.z).length()
	emitting = should_puff(flat, _body.is_on_floor(), _body.has_method("is_driving") and _body.is_driving())
