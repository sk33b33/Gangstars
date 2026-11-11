class_name PixelMaterials
extends RefCounted
## Cached materials for the pxl-generated pixel textures (assets/textures/pxl).
## `surface()` is world-triplanar so tiles keep a constant 16 px/metre density on any mesh.
## `panel()` maps the texture once across a QuadMesh (windows, doors, signs).

const TEX_DIR := "res://assets/textures/pxl/"

static var _cache: Dictionary = {}


static func surface(tex_name: String, tile_size: Vector2, tint: Color = Color.WHITE, alpha: bool = false) -> StandardMaterial3D:
	var key := "s|%s|%s|%s|%s" % [tex_name, tile_size, tint.to_html(), alpha]
	if _cache.has(key):
		return _cache[key]
	var mat := _base(tex_name, tint, alpha)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	# x/z use tile_size.x, vertical uses tile_size.y (metres per texture repeat).
	mat.uv1_scale = Vector3(1.0 / tile_size.x, 1.0 / tile_size.y, 1.0 / tile_size.x)
	_cache[key] = mat
	return mat


static func panel(tex_name: String, tint: Color = Color.WHITE, alpha: bool = false) -> StandardMaterial3D:
	var key := "p|%s|%s|%s" % [tex_name, tint.to_html(), alpha]
	if _cache.has(key):
		return _cache[key]
	var mat := _base(tex_name, tint, alpha)
	_cache[key] = mat
	return mat


static func flat(color: Color) -> StandardMaterial3D:
	var key := "f|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	_cache[key] = mat
	return mat


## Cloth print for clothes. The character model's cloth has cylindrical UVs (one repeat per
## 0.2 m of height, 8 round the body), so the print follows the body as it moves.
static func fabric(tex_name: String) -> StandardMaterial3D:
	var key := "c|%s" % tex_name
	if _cache.has(key):
		return _cache[key]
	var mat := _base(tex_name, Color.WHITE, false)
	mat.roughness = 0.9
	_cache[key] = mat
	return mat


## Shared streetlight/window glow material; DayNight drives its emission energy.
static func lamp() -> StandardMaterial3D:
	if _cache.has("lamp"):
		return _cache["lamp"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#fff0a8")
	mat.emission_enabled = true
	mat.emission = Color("#ffc85e")
	mat.emission_energy_multiplier = 0.3
	_cache["lamp"] = mat
	return mat


static func _base(tex_name: String, tint: Color, alpha: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var path := TEX_DIR + tex_name + ".png"
	if ResourceLoader.exists(path):
		mat.albedo_texture = load(path)
	else:
		push_warning("Missing texture %s; using flat colour." % path)
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.95
	if alpha:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
