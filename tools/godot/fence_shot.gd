extends SceneTree
## Dev: renders a precast fence with razor wire, an electric fence and none, side by side.
var _frame := 0
var _i := 0
var _cams: Array = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_color = Color("#b9d3ea")
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#cfd8e6")
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var kinds := ["precast", "palisade", "low_wall", "wall_palisade"]
	for row in 3:
		for col in kinds.size():
			var surfaces := {}
			var materials := {}
			var plan := {"kind": kinds[col], "height": float(RealYards.HEIGHTS[kinds[col]]), "segments": [[Vector2(col * 8, row * 5), Vector2(col * 8 + 6, row * 5)]], "posts": [Vector2(col * 8, row * 5), Vector2(col * 8 + 6, row * 5)]}
			RealChunkBuilder._yard(plan, [5, 15, 50][row], surfaces, materials, PackedVector3Array())
			for k in surfaces:
				var st: SurfaceTool = surfaces[k]
				var mi := MeshInstance3D.new()
				st.generate_normals()
				mi.mesh = st.commit()
				mi.material_override = materials[k]
				root.add_child(mi)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#d9c9a0")
	ground.material_override = gm
	root.add_child(ground)
	var cam := Camera3D.new()
	cam.name = "Cam"
	root.add_child(cam)
	cam.current = true
	_cams = [[Vector3(14, 3.5, 14), Vector3(14, 1.2, 5)], [Vector3(4, 2.2, 3), Vector3(5, 1.6, 0)]]


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame % 3 != 0:
		return false
	var cam: Camera3D = root.get_node("Cam")
	if _i > 0:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/output/fence_%d.png" % (_i - 1)))
	if _i >= _cams.size():
		quit()
		return true
	cam.global_position = _cams[_i][0]
	cam.look_at(_cams[_i][1])
	_i += 1
	return false
