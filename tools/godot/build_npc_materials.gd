extends SceneTree
## Writes tuned, editable materials for the five Mixamo NPC bodies (assets/models/characters/npc/materials/<Name>_<material>.tres)
## and points each glb's .import at them. Mixamo's own materials use the Gloss map as roughness and metallic 0.5 (shiny clothes)
## and alpha-BLEND on hair (sorting glitches): here every material is matte, two-sided (no see-through gaps), without
## metallic, roughness or normal maps, and hair and eyelashes use alpha scissor.
## Run: godot --headless --path . -s tools/godot/build_npc_materials.gd   (then re-import; run after lighten_mixamo.py)
const NAMES := ["James", "Kate", "Leonard", "Louise", "Meegan"]
const DIR := "res://assets/models/characters/npc/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + "materials"))
	for n in NAMES:
		var root := (load(DIR + n + ".glb") as PackedScene).instantiate()
		var done := {}
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var src := mesh.surface_get_material(s) as BaseMaterial3D
				if src == null or done.has(src.resource_name):
					continue
				done[src.resource_name] = true
				var m := StandardMaterial3D.new()
				m.resource_name = src.resource_name
				m.albedo_texture = src.albedo_texture
				m.roughness = 0.9
				m.metallic_specular = 0.12
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				var low := src.resource_name.to_lower()
				if low.contains("hair") or low.contains("eyelash"):
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					m.alpha_scissor_threshold = 0.5
				var path := "%smaterials/%s_%s.tres" % [DIR, n, src.resource_name]
				print("saved ", path, " ", error_string(ResourceSaver.save(m, path)))
		root.free()
	quit()
