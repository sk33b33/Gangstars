class_name NightGlow
extends RefCounted
## Warm light spilling out of windows and doorways onto the yard at night: one shared additive
## material, so every house's glow batches and DayNight just changes its strength. The
## streetlights use a sodium-orange variant of the same trick (see LightPool).

static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.72, 0.38, 0.6))
		g.set_color(1, Color(1.0, 0.72, 0.38, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 48
		tex.height = 48
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.albedo_texture = tex
		_mat.albedo_color = Color(1, 1, 1, 0)
		_mat.disable_receive_shadows = true
	return _mat


## 0 = off (day, or load-shedding), 1 = full night.
static func set_level(level: float) -> void:
	material().albedo_color.a = clampf(level, 0.0, 1.0)


static func level() -> float:
	return material().albedo_color.a


## A pool of light on the ground in front of a window or door at `pos` (parent-local).
static func add(parent: Node3D, pos: Vector3, size: Vector2) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.name = "WindowGlow"
	mi.mesh = pm
	mi.material_override = material()
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
