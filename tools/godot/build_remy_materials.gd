extends SceneTree
## Writes the Remy materials as editable .tres files (assets/models/characters/remy/materials/), tuned for phones:
## hair and eyelashes use alpha scissor (no blending, no sorting problems), closed meshes cull back faces, and the
## unused metallic texture and the strength-0 normal map are dropped (two texture reads less per material). Remy_Animations_Mobile.glb.import points
## the glb's materials at these files, so edit them in the editor and the changes stick.
## Run: godot --headless --path . -s tools/godot/build_remy_materials.gd   (reads the glb's own materials, so run it
## BEFORE the .import points at the files, or after deleting the _subresources/materials block).
const GLB := "res://assets/models/characters/Remy_Animations_Mobile.glb"
const OUT := "res://assets/models/characters/remy/materials/"
## material -> {scissor threshold (alpha scissor), cull, rough (roughness), spec (metallic_specular)}.
## Everything is two-sided: with back-face culling the open ends of sleeves, collars and trouser legs let the background
## show through. The glb's Gloss maps are used as roughness there, which makes the clothes shiny, so they are dropped for
## one matte roughness per material and a low specular.
const FIX := {
	"Bodymat": {"cull": BaseMaterial3D.CULL_DISABLED, "rough": 0.85, "spec": 0.12},
	"Topmat": {"cull": BaseMaterial3D.CULL_DISABLED, "rough": 0.95, "spec": 0.1},
	"Bottommat": {"cull": BaseMaterial3D.CULL_DISABLED, "rough": 0.95, "spec": 0.1},
	"Shoesmat": {"cull": BaseMaterial3D.CULL_DISABLED, "rough": 0.85, "spec": 0.15},
	"Hairmat": {"scissor": 0.4, "cull": BaseMaterial3D.CULL_DISABLED, "rough": 0.8, "spec": 0.2},
	"Eyelashmat": {"scissor": 0.5, "cull": BaseMaterial3D.CULL_DISABLED, "rough": 0.8, "spec": 0.1},
}


func _init() -> void:
	var root := (load(GLB) as PackedScene).instantiate()
	var done := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
		if mat == null or done.has(mat.resource_name) or not FIX.has(mat.resource_name):
			continue
		var m := mat.duplicate() as BaseMaterial3D
		var fix: Dictionary = FIX[mat.resource_name]
		m.cull_mode = fix.cull
		if fix.has("scissor"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = fix.scissor
		else:
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		m.roughness_texture = null
		m.roughness = fix.rough
		m.metallic_specular = fix.spec
		m.metallic_texture = null
		m.metallic = 0.0
		m.normal_enabled = false   # the glb imports every normal map with strength 0: it did nothing but cost a texture read
		m.normal_texture = null
		var path: String = OUT + mat.resource_name + ".tres"
		var err := ResourceSaver.save(m, path)
		print("saved ", path, " -> ", error_string(err))
		done[mat.resource_name] = true
	root.free()
	quit()
