class_name StreetDetail
extends RefCounted
## The shared puddle material (the weather fades its alpha in with how wet the ground is).
## Street litter, potholes, drains and bins for the real streets are on the ROADMAP.

static var _puddle_mat: StandardMaterial3D


## Dark mirror-like water; Weather fades its alpha in with the wetness of the ground.
static func puddle_material() -> StandardMaterial3D:
	if _puddle_mat == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var r := Vector2(x - 15.5, y - 15.5).length() / 15.5
				var wob := 0.85 + 0.12 * sin(atan2(y - 15.5, x - 15.5) * 3.0 + 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(wob - 0.18, wob, r)))
		_puddle_mat = StandardMaterial3D.new()
		_puddle_mat.albedo_texture = ImageTexture.create_from_image(img)
		_puddle_mat.albedo_color = Color(0.08, 0.1, 0.14, 0.0)
		_puddle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puddle_mat.metallic = 0.9
		_puddle_mat.metallic_specular = 1.0
		_puddle_mat.roughness = 0.04
		_puddle_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _puddle_mat
