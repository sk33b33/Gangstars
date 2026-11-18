class_name AmbientFx
extends RefCounted
## Small moving things that make a street feel lived in. Each is a short-range CPUParticles3D (switched off beyond `visibility_range_end`),
## so the cost is only near the player.

const SMOKE_RANGE := 30.0


## A thin plume of braai smoke rising from `at` (parent-local), drifting a little with the wind.
static func smoke(parent: Node3D, at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "BraaiSmoke"
	p.position = at
	p.amount = 8
	p.lifetime = 2.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3(0, 1, 0)
	p.spread = 10.0
	p.initial_velocity_min = 0.45
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.3, 0.12, 0.1)   # the south-easter leans it over
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.9))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.7, 0.7, 0.7, 0.4))
	fade.set_color(1, Color(0.75, 0.75, 0.75, 0.0))
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = SMOKE_RANGE
	parent.add_child(p)
	return p
