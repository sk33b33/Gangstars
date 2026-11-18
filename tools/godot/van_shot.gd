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
	VehicleLibrary.set_driver(_van, true)
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
	_cams = [[Vector3(7, 2.4, 6), Vector3(0, 1.0, 0)], [Vector3(-6.5, 2.4, -6.5), Vector3(0, 1.0, 0)], [Vector3(4.2, 2.0, -4.2), Vector3(0.3, 0.6, -1.5)], [Vector3(-2.2, 1.6, -5.2), Vector3(0, 1.4, -2.0)], [Vector3(0.0, 1.5, -5.0), Vector3(0, 1.3, 0)], [Vector3(5.0, 3.5, 1.0), Vector3(0, 2.0, 0)]]


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
