class_name PropLibrary
extends RefCounted
## Meshes from the Blender-built prop set (tools/blender/build_props.py -> props.glb), by name.
## Each mesh has its origin at the prop's base centre and faces +Z. The glb scene is opened once.
## "paint" surfaces can be recoloured; leaf surfaces get the wind-sway shader.

const SOURCE := "res://assets/models/props/props.glb"
const WIND := preload("res://assets/shaders/foliage_wind.gdshader")

static var _meshes: Dictionary = {}
static var _wind_mats: Dictionary = {}


static func mesh(prop: String) -> Mesh:
	if _meshes.is_empty():
		var root: Node = (load(SOURCE) as PackedScene).instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			_meshes[str(mi.name)] = (mi as MeshInstance3D).mesh
		root.free()
	return _meshes.get(prop)


## Adds a prop to `parent`. paint: recolours "paint" surfaces (null keeps the default green).
static func place(parent: Node3D, prop: String, pos: Vector3, rot_y := 0.0, paint: Variant = null) -> MeshInstance3D:
	var m := mesh(prop)
	if m == null:
		push_warning("Unknown prop: " + prop)
		return null
	var mi := MeshInstance3D.new()
	mi.name = prop
	mi.mesh = m
	mi.position = pos
	mi.rotation.y = rot_y
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		var key := mat.resource_name if mat else ""
		if key == "paint" and paint != null:
			mi.set_surface_override_material(i, PixelMaterials.flat(paint))
		elif key.begins_with("leaf"):
			mi.set_surface_override_material(i, _wind(mat as BaseMaterial3D))
	parent.add_child(mi)
	return mi


static func _wind(src: BaseMaterial3D) -> ShaderMaterial:
	var key := src.resource_name
	if not _wind_mats.has(key):
		var sm := ShaderMaterial.new()
		sm.shader = WIND
		sm.set_shader_parameter("albedo", src.albedo_color)
		_wind_mats[key] = sm
	return _wind_mats[key]
