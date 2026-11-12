class_name PixelMaterials
extends RefCounted
## Cached materials for the pxl-generated pixel textures (assets/textures/pxl).
## `surface()` is world-triplanar so tiles keep a constant 16 px/metre density on any mesh.
## `panel()` maps the texture once across a QuadMesh (windows, doors, signs).

const TEX_DIR := "res://assets/textures/pxl/"

static var _cache: Dictionary = {}
## 0..1: after rain the outdoor surfaces (triplanar ground, walls, roads) go darker and glossy.
static var wetness := 0.0


static func surface(tex_name: String, tile_size: Vector2, tint: Color = Color.WHITE, alpha: bool = false) -> StandardMaterial3D:
	var key := "s|%s|%s|%s|%s" % [tex_name, tile_size, tint.to_html(), alpha]
	if _cache.has(key):
		return _cache[key]
	var mat := _base(tex_name, tint, alpha)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	# x/z use tile_size.x, vertical uses tile_size.y (metres per texture repeat).
	mat.uv1_scale = Vector3(1.0 / tile_size.x, 1.0 / tile_size.y, 1.0 / tile_size.x)
	if wetness > 0.0:
		_wet(mat)
	_cache[key] = mat
	return mat


## Wet look for every world surface material: darker albedo and a glossy finish. New surface
## materials pick it up as they're made.
static func set_wetness(w: float) -> void:
	wetness = clampf(w, 0.0, 1.0)
	for key: String in _cache:
		if key.begins_with("s|"):
			_wet(_cache[key])


static func _wet(mat: StandardMaterial3D) -> void:
	if not mat.has_meta("dry_tint"):
		mat.set_meta("dry_tint", mat.albedo_color)
	mat.albedo_color = (mat.get_meta("dry_tint") as Color).darkened(0.28 * wetness)
	mat.roughness = lerpf(0.95, 0.3, wetness)
	mat.metallic_specular = lerpf(0.5, 0.8, wetness)


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


## Skin: softer highlights and (Forward+) a little subsurface scattering.
static func skin(color: Color) -> StandardMaterial3D:
	var key := "k|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic_specular = 0.35
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_strength = 0.25
	_cache[key] = mat
	return mat


## Plain cloth: matte with a faint sheen at grazing angles.
static func cloth(color: Color) -> StandardMaterial3D:
	var key := "t|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.metallic_specular = 0.3
	mat.rim_enabled = true
	mat.rim = 0.2
	mat.rim_tint = 0.7
	_cache[key] = mat
	return mat


## Denim twill in the trouser colour (character cloth UVs, four repeats round each leg).
static func denim(color: Color) -> StandardMaterial3D:
	var key := "d|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := _base("denim", color, false)
	mat.uv1_scale = Vector3(4, 1, 1)
	mat.roughness = 0.95
	_cache[key] = mat
	return mat


## Tracksuit trousers: the trouser colour with two white stripes down the outside of each leg.
static func tracksuit(color: Color) -> StandardMaterial3D:
	var key := "r|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := cloth(color).duplicate() as StandardMaterial3D
	var stripes: Texture2D = load(TEX_DIR + "tracksuit_stripes.png")
	mat.detail_enabled = true
	mat.detail_mask = stripes
	mat.detail_albedo = stripes
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.6   # shiny polyester
	_cache[key] = mat
	return mat


## Painted face overlay (eyelids, lips, wrinkles), multiplied by the skin colour.
static func face(tex_name: String, skin_color: Color) -> StandardMaterial3D:
	var key := "a|%s|%s" % [tex_name, skin_color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var mat := _base(tex_name, skin_color, true)
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.roughness = 0.55
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
