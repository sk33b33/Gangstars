extends SceneTree
## Renders a line-up of CharacterModels (different looks, poses and speeds) to a PNG.
## xvfb-run -a godot --path . -s tools/godot/lineup.gd -- --out=res://tests/output/lineup.png [--close]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9cb4cc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	RenderQuality.apply(env, sun, true)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	ground.material_override = PixelMaterials.flat(Color("#b9b2a2"))
	world.add_child(ground)
	var looks := [
		[Color("#f1eee8"), Color("#29384a"), Color("#8d5a3b"), Color("#a63a4c"), {"hair_style": "short", "sleeves": "short"}, "idle", 0.0],
		[Color("#d9534f"), Color("#3b2f4a"), Color("#6b4430"), Color(0, 0, 0, 0), {"hair_style": "doek", "hair_color": Color("#2e8b57"), "figure": 1.0, "skirt": true}, "talk", 0.0],
		[Color("#f0c419"), Color("#2c3e50"), Color("#c58c62"), Color(0, 0, 0, 0), {"hair_style": "beanie", "hair_color": Color("#34495e"), "heavy": 0.6}, "guard", 0.0],
		[Color("#5dade2"), Color("#1d1b24"), Color("#a7754f"), Color(0, 0, 0, 0), {"hair_style": "long", "figure": 0.9, "height": 0.95}, "idle", 1.5],
		[Color("#7d3c98"), Color("#566573"), Color("#4a2f22"), Color(0, 0, 0, 0), {"hair_style": "bald", "height": 1.08, "sleeves": "short"}, "idle", 4.5],
		[Color("#27ae60"), Color("#784212"), Color("#e0ac80"), Color(0, 0, 0, 0), {"hair_style": "short", "hair_color": Color("#6e2c00"), "heavy": 0.35, "figure": 0.0}, "talk", 0.0],
	]
	var models: Array = []
	for i in looks.size():
		var l: Array = looks[i]
		var m := CharacterModel.new()
		world.add_child(m)
		m.position = Vector3((i - (looks.size() - 1) * 0.5) * 1.0, 0, 0)
		m.build(l[0], l[1], l[2], l[3], l[4])
		m.mode = l[5]
		models.append([m, float(l[6])])
	var cam := Camera3D.new()
	world.add_child(cam)
	if args.has("close"):
		cam.position = Vector3(-1.0, 1.55, 1.6)
		cam.look_at(Vector3(-1.5, 1.45, 0))
	else:
		cam.position = Vector3(0, 1.4, 5.2)
		cam.look_at(Vector3(0, 0.95, 0))
	cam.fov = 45 if args.has("close") else 60
	cam.current = true
	var frames := int(args.get("frames", "40"))
	for f in frames:
		for pair in models:
			(pair[0] as CharacterModel).animate(1.0 / 60.0, pair[1])
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(str(args.get("out", "res://tests/output/lineup.png"))))
	print("lineup saved")
	quit()
