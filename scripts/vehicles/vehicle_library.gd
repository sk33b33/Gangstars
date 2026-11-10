class_name VehicleLibrary
extends RefCounted
## Vehicle meshes from tools/blender/build_vehicles.py (vehicles.glb), by model name:
## hatch, sedan, bakkie, taxi, police. build() returns a pivot whose model faces local +X (the
## convention the traffic, parking and driving code already uses). "paint" takes the car's colour,
## "headlight" shares the night-glow lamp material, and police "lightbar" surfaces get their own
## material per vehicle so its lights can flash (see set_lights()).

const SOURCE := "res://assets/models/vehicles/vehicles.glb"
const MODELS := ["hatch", "sedan", "bakkie", "taxi", "police"]
const CIVILIAN := ["hatch", "hatch", "sedan", "bakkie"]   # weighted pick for everyday cars
## Length of each model (m), for colliders and obstacles.
const LENGTH := {"hatch": 4.0, "sedan": 4.5, "bakkie": 4.7, "taxi": 5.3, "police": 5.1}

static var _meshes: Dictionary = {}


static func mesh(model: String) -> Mesh:
	if _meshes.is_empty():
		var root: Node = (load(SOURCE) as PackedScene).instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			_meshes[str(mi.name)] = (mi as MeshInstance3D).mesh
		root.free()
	return _meshes.get(model)


## A civilian model picked deterministically from a seed (e.g. a vehicle id).
static func civilian_for(seed_text: String) -> String:
	return CIVILIAN[absi(seed_text.hash()) % CIVILIAN.size()]


static func build(root: Node3D, model: String, color: Color, center := Vector3.ZERO, rot_y := 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Body_" + model
	pivot.position = center
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	var m := mesh(model)
	if m == null:
		push_warning("Unknown vehicle model: " + model)
		return pivot
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = m
	mi.rotation.y = PI * 0.5   # Blender front (-Y) -> Godot +Z -> rotate to +X
	pivot.add_child(mi)
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		var key := mat.resource_name if mat else ""
		match key:
			"paint":
				var paint := StandardMaterial3D.new()
				paint.albedo_color = Color.WHITE if model == "police" else color
				paint.roughness = 0.35
				paint.metallic_specular = 0.7
				mi.set_surface_override_material(i, paint)
			"headlight":
				mi.set_surface_override_material(i, PixelMaterials.lamp())
			"lightbar":
				var bar := StandardMaterial3D.new()
				bar.albedo_color = Color("#2a6cff")
				bar.emission_enabled = true
				bar.emission = Color("#2a6cff")
				bar.emission_energy_multiplier = 0.0
				mi.set_surface_override_material(i, bar)
				pivot.set_meta("lightbar", bar)
	if model == "police":
		_police_markings(pivot)
	return pivot


## Flashing blue lights (police). on=false switches them off. Call every frame while on.
static func set_lights(pivot: Node3D, on: bool, time: float) -> void:
	if not pivot.has_meta("lightbar"):
		return
	var bar: StandardMaterial3D = pivot.get_meta("lightbar")
	bar.emission_energy_multiplier = (6.0 if fmod(time, 0.5) < 0.25 else 1.0) if on else 0.0


## "POLICE / POLISIE" on the doors and canopy, and the made-up crest (not the real SAPS emblem).
static func _police_markings(pivot: Node3D) -> void:
	for side in [1.0, -1.0]:
		var z: float = side * 0.935
		var door := Label3D.new()
		door.text = "POLICE"
		door.font_size = 64
		door.pixel_size = 0.004
		door.modulate = Color("#123f8c")
		door.outline_size = 0
		door.position = Vector3(0.55, 0.42, z)
		door.rotation.y = 0.0 if side > 0 else PI
		door.double_sided = false
		pivot.add_child(door)
		var back := door.duplicate() as Label3D
		back.text = "POLICE"
		back.position = Vector3(-1.55, 1.72, z)
		back.font_size = 48
		pivot.add_child(back)
		var crest := Geo.quad(pivot, Vector2(0.3, 0.36), Vector3(1.0, 0.82, z + side * 0.002),
			PixelMaterials.panel("police_crest", Color.WHITE, true), 0.0 if side > 0 else PI)
		crest.name = "Crest"
