extends SceneTree
## Dev: renders Remy's van from four sides. xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/godot/van_shot.gd -- --out=res://tests/output/van
var _cams: Array = []
var _i := 0
var _out := "res://tests/output/van"
var _frame := 0
var _van: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	root.size = Vector2i(1280, 720)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#b9d3ea")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#cfd8e6")
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#7d7a74")
	ground.material_override = gm
	root.add_child(ground)
	var stage := Node3D.new()
	root.add_child(stage)
	_van = VehicleLibrary.build(stage, "hiace", Color("#f1eee8"))
	var remy_seat: Vector3 = VehicleLibrary.REMY_SEAT["hiace"]
	var remy: RemyPlayerModel = (load("res://scenes/characters/remy/remy_player_model.tscn") as PackedScene).instantiate()
	remy.position = remy_seat
	(_van.get_meta("tilt") as Node3D).add_child(remy)
	remy.set_seated(true, true)
	if "--ghost" in OS.get_cmdline_user_args():   # see through the paint, to check where the driver sits
		var mi: MeshInstance3D = _van.find_child("Mesh", true, false)
		for si in mi.mesh.get_surface_count():
			var nm := mi.mesh.surface_get_material(si).resource_name
			if nm in ["paint", "glass"]:
				var ghost := StandardMaterial3D.new()
				ghost.albedo_color = Color(0.9, 0.9, 0.9, 0.12)
				ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.set_surface_override_material(si, ghost)
	if "--marks" in OS.get_cmdline_user_args():   # a red ball where the model's steering wheel is (Blender -0.496, -2.0, 1.2), a green one at the driver's seat marker
		var tilt: Node3D = _van.get_meta("tilt")
		for spec in [[Vector3(-0.496, 1.2, 2.0), Color.RED], [Vector3(-0.496, 0.78, 1.38), Color.GREEN]]:
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			ball.mesh = sm
			var bm := StandardMaterial3D.new()
			bm.albedo_color = spec[1]
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.no_depth_test = true
			ball.material_override = bm
			ball.position = spec[0]
			tilt.add_child(ball)
	if "--rain" in OS.get_cmdline_user_args():
		VehicleLibrary.rain = 1.0
	if "--steer=1" in OS.get_cmdline_user_args():
		VehicleLibrary.animate(_van, 3.0, 1.0, 0.0, 0, 0.1, 0.1)
	elif "--steer=-1" in OS.get_cmdline_user_args():
		VehicleLibrary.animate(_van, 3.0, -1.0, 0.0, 0, 0.1, 0.1)
	var cam := Camera3D.new()
	cam.name = "Cam"
	root.add_child(cam)
	cam.current = true
	_cams = [[Vector3(5.0, 1.7, 1.7), Vector3(-0.4, 1.1, 1.7)], [Vector3(-4.5, 1.7, 1.7), Vector3(-0.4, 1.1, 1.7)], [Vector3(-0.4, 4.0, 1.8), Vector3(-0.4, 0.8, 1.7)], [Vector3(-0.4, 1.4, -0.8), Vector3(-0.4, 1.2, 2.2)]]


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	if _frame % 3 != 0:
		return false
	var cam: Camera3D = root.get_node("Cam")
	if _i > 0:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s_%d.png" % [_out, _i - 1]))
	if _i >= _cams.size():
		quit()
		return true
	cam.global_position = _cams[_i][0]
	cam.look_at(_cams[_i][1])
	_i += 1
	return false
