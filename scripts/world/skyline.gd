class_name Skyline
extends Node3D
## The far horizon, drawn like a skybox: it follows the camera so it never gets closer.
## From Mitchells Plain (see docs/MITCHELLS_PLAIN_REFERENCE.md):
## - Table Mountain to the north-west, seen *side on* from the Flats: a long, pale-blue plateau
##   with Devil's Peak at one end, Lion's Head at the other, and, in the south-easter, its cloud
##   "tablecloth" spilling over the edge;
## - the Hottentots-Holland range, jagged and blue, to the east;
## - the low Peninsula ridge to the west;
## - False Bay to the south, a flat band of sea.
## Bearings are compass degrees (0 = north = -Z, 90 = east = +X). Heights are metres at RADIUS,
## exaggerated on purpose so the shapes read at game scale. The materials ignore fog and are
## tinted by set_atmosphere() so the mountains turn violet at dusk and go dark at night.

const RADIUS := 900.0
const BOTTOM := -140.0
## Real ranges are only a few degrees high from the Flats; here they're stretched so they read on screen.
const HEIGHT_SCALE := 2.5
const MOUNTAIN_BLUE := Color(0.33, 0.42, 0.58)
const NIGHT_BLUE := Color(0.045, 0.06, 0.12)
const SEA_BLUE := Color(0.3, 0.5, 0.66)

## [bearing, height] control points, interpolated smoothly between them.
const TABLE_MOUNTAIN := [
	[300.0, 0.0], [306.0, 14.0], [311.0, 26.0], [314.0, 22.0], [317.0, 40.0], [318.5, 52.0], [320.0, 38.0],   # the Peninsula end, Lion's Head
	[322.0, 60.0], [323.0, 78.0], [325.0, 80.0], [333.0, 81.0], [339.0, 80.0], [343.0, 82.0],                 # the long flat plateau
	[345.0, 78.0], [347.0, 86.0], [348.5, 97.0], [350.0, 88.0], [352.0, 60.0], [355.0, 34.0], [360.0, 14.0],  # Devil's Peak
	[366.0, 6.0], [372.0, 0.0]]
const HOTTENTOTS_HOLLAND := [
	[55.0, 0.0], [66.0, 18.0], [74.0, 30.0], [79.0, 52.0], [83.0, 38.0], [88.0, 62.0], [93.0, 46.0], [98.0, 70.0],
	[102.0, 44.0], [108.0, 56.0], [114.0, 30.0], [122.0, 22.0], [132.0, 0.0]]
const PENINSULA := [
	[230.0, 0.0], [240.0, 14.0], [252.0, 22.0], [264.0, 18.0], [276.0, 30.0], [288.0, 22.0], [298.0, 6.0], [304.0, 0.0]]
const SEA := [[138.0, 0.0], [222.0, 0.0]]

var _layers: Array = []     # [MeshInstance3D, StandardMaterial3D, haze: float]
var _cloud: MeshInstance3D
var _cloud_mat: StandardMaterial3D
var _sea_mat: StandardMaterial3D
var _built := false


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	name = "Skyline"
	_add_layer("HottentotsHolland", HOTTENTOTS_HOLLAND, 0.55, 0.0, 91)
	_add_layer("Peninsula", PENINSULA, 0.6, 0.0, 92)
	_add_layer("TableMountain", TABLE_MOUNTAIN, 0.38, 0.0, 93)
	_add_sea()
	_add_tablecloth()
	set_atmosphere(Color(0.78, 0.84, 0.9), 0.0, 0.0, 0.0, 0.0)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = Vector3(cam.global_position.x, 0.0, cam.global_position.z)


## Heights along the ridge, smooth between control points (cosine ease) plus a little craggy noise.
static func profile(points: Array, bearing: float, seed_value: float = 0.0) -> float:
	if bearing <= float(points[0][0]) or bearing >= float(points[points.size() - 1][0]):
		return 0.0
	for i in points.size() - 1:
		var a: Array = points[i]
		var b: Array = points[i + 1]
		if bearing <= float(b[0]):
			var t := (bearing - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			t = 0.5 - 0.5 * cos(t * PI)
			var h := lerpf(float(a[1]), float(b[1]), t)
			return maxf(0.0, (h + sin(bearing * 2.3 + seed_value) * h * 0.012) * HEIGHT_SCALE)
	return 0.0


static func point_at(bearing: float, y: float, radius: float = RADIUS) -> Vector3:
	var r := deg_to_rad(bearing)
	return Vector3(sin(r) * radius, y, -cos(r) * radius)


func _add_layer(layer_name: String, points: Array, haze: float, _unused: float, priority: int) -> void:
	var first := float(points[0][0])
	var last := float(points[points.size() - 1][0])
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var step := 0.5
	var b := first
	var n := 0
	while b <= last + 0.001:
		var h := profile(points, b, first)
		verts.append(point_at(b, BOTTOM))
		verts.append(point_at(b, h))
		# Base is paler (haze at the foot), the crest slightly deeper.
		cols.append(Color(1, 1, 1, 1).lerp(Color(0.9, 0.93, 1.0), 0.5))
		cols.append(Color(0.86, 0.9, 1.0) if h > 1.0 else Color(1, 1, 1))
		if n > 0:
			var k := (n - 1) * 2
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 2, k + 1, k + 3]))
		n += 1
		b += step
	_commit(layer_name, verts, cols, idx, haze, priority)


func _commit(layer_name: String, verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, haze: float, priority: int) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = priority - 100
	var mi := MeshInstance3D.new()
	mi.name = layer_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2000.0
	add_child(mi)
	_layers.append([mi, mat, haze])


func _add_sea() -> void:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var cols := PackedColorArray()
	var b := float(SEA[0][0])
	var n := 0
	while b <= float(SEA[1][0]) + 0.001:
		verts.append(point_at(b, BOTTOM))
		verts.append(point_at(b, 1.5))
		cols.append(Color.WHITE)
		cols.append(Color(1.1, 1.1, 1.1))
		if n > 0:
			var k := (n - 1) * 2
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 2, k + 1, k + 3]))
		n += 1
		b += 2.0
	_commit("FalseBay", verts, cols, idx, 0.5, 90)
	_sea_mat = _layers[_layers.size() - 1][1]


## The "tablecloth": cloud pouring over the plateau when the south-easter blows.
func _add_tablecloth() -> void:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var cols := PackedColorArray()
	var b := 322.0
	var n := 0
	while b <= 346.001:
		var top := profile(TABLE_MOUNTAIN, b, 322.0)
		var wave := sin(b * 1.7) * 3.0 + sin(b * 4.1) * 1.4
		verts.append(point_at(b, top - 10.0 + wave * 0.5, RADIUS - 6.0))
		verts.append(point_at(b, top + 8.0 + wave, RADIUS - 6.0))
		cols.append(Color(1, 1, 1, 0.0))
		cols.append(Color(1, 1, 1, 0.9))
		if n > 0:
			var k := (n - 1) * 2
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 2, k + 1, k + 3]))
		n += 1
		b += 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.vertex_color_use_as_albedo = true
	_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat.disable_fog = true
	_cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloud_mat.albedo_color = Color(1, 1, 1, 0.0)
	_cloud_mat.render_priority = -90
	_cloud = MeshInstance3D.new()
	_cloud.name = "Tablecloth"
	_cloud.mesh = mesh
	_cloud.material_override = _cloud_mat
	_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud.extra_cull_margin = 2000.0
	add_child(_cloud)


## horizon: the sky's horizon colour (so dusk tints the mountains), night 0..1, overcast 0..1,
## dust 0..1 (thick haze hides the far ranges), wind 0..1 (the tablecloth).
func set_atmosphere(horizon: Color, night: float, overcast: float, dust: float, wind: float) -> void:
	var base := MOUNTAIN_BLUE.lerp(NIGHT_BLUE, night)
	for l in _layers:
		var mat: StandardMaterial3D = l[1]
		var haze := clampf(float(l[2]) + overcast * 0.25 + dust * 0.45, 0.0, 0.95) * (1.0 - night * 0.6)
		var tint := base.lerp(horizon, haze)
		if mat == _sea_mat:
			tint = SEA_BLUE.lerp(NIGHT_BLUE, night).lerp(horizon, 0.35 + dust * 0.4)
		mat.albedo_color = tint
	if _cloud_mat:
		var shown := smoothstep(0.35, 0.8, wind) * (1.0 - night * 0.85) * (1.0 - dust * 0.6)
		_cloud_mat.albedo_color = Color(horizon.lerp(Color.WHITE, 0.7), shown)
		_cloud.visible = shown > 0.02


func layer_count() -> int:
	return _layers.size()


func tablecloth_alpha() -> float:
	return _cloud_mat.albedo_color.a if _cloud_mat else 0.0
