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
	if args.has("cars") or args.has("sky"):
		# A sky to reflect in the car paint and glass.
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color("#3f7fc4")
		sm.sky_horizon_color = Color("#bcd3e6")
		sm.ground_horizon_color = Color("#bcd3e6")
		sm.ground_bottom_color = Color("#6d675c")
		sky.sky_material = sm
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
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
	var dogs: Array = []
	var looks := [
		[Color("#f1eee8"), Color("#29384a"), Color("#8d5a3b"), Color("#a63a4c"), {"hair_style": "short", "sleeves": "short", "pants_style": "denim", "cap_logo": "vlakte_vipers", "face": "face_stubble"}, "wave", 0.0],
		[Color("#d9534f"), Color("#3b2f4a"), Color("#6b4430"), Color(0, 0, 0, 0), {"hair_style": "doek", "hair_color": Color("#2e8b57"), "figure": 1.0, "heavy": 0.5, "skirt": true, "accessories": ["apron", "glasses"], "apron_color": Color("#f4f1ea")}, "sit", 0.0],
		[Color("#1d1b24"), Color("#2c2c34"), Color("#c58c62"), Color(0, 0, 0, 0), {"hair_style": "short", "hair_color": Color("#b8b4ac"), "accessories": ["collar", "glasses", "beard"]}, "talk", 0.0],
		[Color("#5dade2"), Color("#1d1b24"), Color("#a7754f"), Color(0, 0, 0, 0), {"hair_style": "ponytail", "figure": 0.9, "height": 0.95}, "lean", 0.0],
		[Color("#7d3c98"), Color("#566573"), Color("#4a2f22"), Color(0, 0, 0, 0), {"hair_style": "beanie", "accessories": ["chain", "hood"], "heavy": 0.4, "pants_style": "tracksuit"}, "guard", 0.0],
		[Color("#27ae60"), Color("#784212"), Color("#6b4430"), Color(0, 0, 0, 0), {"hair_style": "afro", "hair_color": Color("#1d1b24"), "pants_style": "tracksuit", "accessories": ["hood"]}, "idle", 1.5],
	]
	if args.has("named"):
		# The named characters, exactly as the game dresses them (resident data + looks.json).
		looks = []
		for f in ["starter", "rooiduin", "kalkbos"]:
			for n in NpcData.load_file("res://data/npcs/%s_residents.json" % f):
				if not n.id.get_slice("_", n.id.get_slice_count("_") - 1).is_valid_int():
					looks.append([n.shirt_color, n.pants_color, n.skin_color, Color(0, 0, 0, 0), n.appearance(), "idle", 0.0, n.display_name])
	if args.has("cars"):
		var paints := [Color("#c0392b"), Color("#2e86c1"), Color("#ecf0f1"), Color.WHITE, Color("#f4f1ea"), Color("#b5651d"), Color("#2f7d6d"), Color.WHITE]
		for i in VehicleLibrary.MODELS.size():
			var m: String = VehicleLibrary.MODELS[i]
			var car := VehicleLibrary.build(world, m, paints[i], Vector3(-6.0 + (i % 3) * 5.6, 0, -3.2 + (i / 3) * 4.6), deg_to_rad(-30.0))
			VehicleLibrary.set_lights(car, m == "police", 0.1)
			VehicleLibrary.add_occupants(car)
	if args.has("dogs"):
		var coats := [[Color("#5a3a22"), Color("#d8c4a0")], [Color("#1d1b20"), Color("#e8e2d6")], [Color("#c9a26b"), Color("#f0e2c4")], [Color("#8a7d70"), Color("#d8d0c4")]]
		for i in coats.size():
			var d := DogModel.new()
			world.add_child(d)
			d.build(coats[i][0], coats[i][1], 1.0 + 0.08 * (i % 2))
			d.position = Vector3(-1.8 + i * 1.2, 0, 1.2)
			d.rotation.y = 0.6
			d.lying = i == 2
			dogs.append([d, [0.0, 1.0, 0.0, 2.6][i]])
	if args.has("cars"):
		looks = []
	if args.has("armed"):
		var cop := {"hair_style": "short", "sleeves": "short", "accessories": ["police_cap", "police_vest", "dutybelt"]}
		var navy := Color("#9db4d6")
		var trousers := Color("#2b3b63")
		looks = [
			[navy, trousers, Color("#6b4430"), Color(0, 0, 0, 0), cop, "aim:pistol", 0.0],
			[navy, trousers, Color("#a7754f"), Color(0, 0, 0, 0), cop.merged({"figure": 0.9, "hair_style": "ponytail"}), "holster:pistol", 0.0],
			[navy, trousers, Color("#4a2f22"), Color(0, 0, 0, 0), cop, "aim:shotgun", 0.0],
			[Color("#7a1f1f"), Color("#1c2833"), Color("#8d5a3b"), Color(0, 0, 0, 0), {"hair_style": "beanie", "accessories": ["sunglasses", "chain"]}, "aim:pistol", 0.0],
			[Color("#2c3e50"), Color("#4a4e6a"), Color("#6b4430"), Color(0, 0, 0, 0), {"hair_style": "bald"}, "holster:shotgun", 1.5],
			[Color("#7a1f1f"), Color("#1c2833"), Color("#a7754f"), Color(0, 0, 0, 0), {"hair_style": "short"}, "down", 0.0],
		]
	if args.has("hair"):
		var styles := ["fade", "cornrows", "braids", "curls", "bun", "short"]
		looks = []
		for i in styles.size():
			var woman: bool = styles[i] in ["braids", "curls", "bun"]
			looks.append([Color("#3f5874"), Color("#29384a"), [Color("#6b4430"), Color("#8d5a3b"), Color("#a7754f")][i % 3], Color(0, 0, 0, 0),
				{"hair_style": styles[i], "figure": 0.95 if woman else 0.0, "face": "face_f" if woman else "face_m", "pants_style": "denim"}, "idle", 0.0, styles[i]])
	if args.has("outfits"):
		looks = [
			[Color("#3f5874"), Color("#29384a"), Color("#8d5a3b"), Color(0, 0, 0, 0), {"height": 0.72, "shirt_override": Color("#f4f4f0"), "pants_override": Color("#5d6066"), "accessories": ["tie", "backpack"], "tie_color": Color("#7a1f2e"), "pack_color": Color("#2f3f6a"), "hair_style": "fade"}, "idle", 0.0, "uniform"],
			[Color("#3f5874"), Color("#29384a"), Color("#6b4430"), Color(0, 0, 0, 0), {"pants_override": Color("#2f4f8a"), "overall_color": Color("#2f4f8a"), "accessories": ["overall"], "hair_style": "short"}, "idle", 0.0, "overall"],
			[Color("#3f5874"), Color("#29384a"), Color("#a7754f"), Color(0, 0, 0, 0), {"shirt_override": Color("#f4f4f0"), "pants_override": Color("#26262e"), "cardigan_color": Color("#2c2c34"), "accessories": ["cardigan", "tie"], "hair_style": "short", "hair_color": Color("#a7a39a"), "stoop": 0.6}, "idle", 0.0, "sunday"],
			[Color("#e84393"), Color("#29384a"), Color("#8d5a3b"), Color(0, 0, 0, 0), {"figure": 0.9, "hair_style": "braids", "face": "face_f"}, "phone", 0.0, "phone"],
			[Color("#27ae60"), Color("#29384a"), Color("#6b4430"), Color(0, 0, 0, 0), {"hair_style": "cornrows", "accessories": ["shopbag"], "pants_style": "denim"}, "idle", 1.4, "shopping"],
			[Color("#e8e2d0"), Color("#3b2f4a"), Color("#a7754f"), Color(0, 0, 0, 0), {"figure": 0.9, "dress": true, "print": "solid", "hair_style": "hijab", "hair_color": Color("#2f3f6a"), "face": "face_f", "accessories": ["handbag"]}, "idle", 0.0, "hijab"],
		]
	if args.has("aunties"):
		# The Mitchells Plain aunty look: prints, doeks, curlers, hoops, handbags, cardigans, slippers.
		var a := {"figure": 1.0, "dress": true, "accessories": ["hoops"]}
		looks = [
			[Color("#e86a8a"), Color("#3b2f4a"), Color("#6b4430"), Color(0, 0, 0, 0), a.merged({"print": "print_rose", "hair_style": "doek", "hair_color": Color("#2f6db8"), "heavy": 0.6, "shoe_color": Color("#f29bbd"), "accessories": ["hoops", "handbag"]}, true), "talk", 0.0],
			[Color("#2f6db8"), Color("#3b2f4a"), Color("#8d5a3b"), Color(0, 0, 0, 0), a.merged({"print": "print_blue", "hair_style": "short", "heavy": 0.3, "shoe_color": Color("#7fc3e8"), "accessories": ["curlers", "handbag"]}, true), "idle", 1.2],
			[Color("#f2b632"), Color("#3b2f4a"), Color("#a7754f"), Color(0, 0, 0, 0), a.merged({"print": "print_sun", "hair_style": "doek", "hair_color": Color("#d9442e"), "heavy": 0.7, "cardigan_color": Color("#d8cbb0"), "shoe_color": Color("#1d1b24"), "accessories": ["hoops", "cardigan"]}, true), "sit", 0.0],
			[Color("#d9442e"), Color("#3b2f4a"), Color("#6b4430"), Color(0, 0, 0, 0), a.merged({"print": "solid", "hair_style": "long", "heavy": 0.2, "shoe_color": Color("#f4f4f0"), "accessories": ["hoops", "handbag"], "bag_color": Color("#1d1b24")}, true), "wave", 0.0],
			[Color("#159a8c"), Color("#3b2f4a"), Color("#4a2f22"), Color(0, 0, 0, 0), a.merged({"print": "print_teal", "hair_style": "doek", "hair_color": Color("#9a6cc4"), "heavy": 0.5, "apron_color": Color("#f4f1ea"), "shoe_color": Color("#c8a27a"), "accessories": ["apron", "glasses", "hoops"]}, true), "guard", 0.0],
			[Color("#9a6cc4"), Color("#3b2f4a"), Color("#8d5a3b"), Color(0, 0, 0, 0), a.merged({"print": "print_lilac", "hair_style": "short", "hair_color": Color("#a7a39a"), "heavy": 0.45, "cardigan_color": Color("#a7c0d6"), "shoe_color": Color("#e2585e"), "accessories": ["cardigan", "curlers", "handbag"]}, true), "idle", 1.0],
		]
	if args.has("stoop"):
		for i in looks.size():
			if i == looks.size() - 1:
				looks[i][4] = (looks[i][4] as Dictionary).merged({"stoop": 1.0}, true)
	var models: Array = []
	var spacing := 0.85 if looks.size() > 6 else 1.0
	for i in looks.size():
		var l: Array = looks[i]
		var m := CharacterModel.new()
		world.add_child(m)
		m.position = Vector3((i - (looks.size() - 1) * 0.5) * spacing, 0, 0)
		if l.size() > 7:
			var tag := Label3D.new()
			tag.text = str(l[7]).replace(" ", "\n")
			tag.font_size = 22
			tag.pixel_size = 0.004
			tag.position = m.position + Vector3(0, 2.05, 0)
			tag.modulate = Color("#1d1b24")
			tag.outline_size = 0
			world.add_child(tag)
		m.build(l[0], l[1], l[2], l[3], l[4])
		if str(l[5]).contains(":"):
			var parts := str(l[5]).split(":")
			m.set_weapon(parts[1])
			m.draw_weapon(parts[0] == "aim")
			m.aiming = parts[0] == "aim"
			if parts[0] == "aim":
				m.rotation.y = -0.5
		match str(l[5]):
			"down":
				m.base_pose = "down"
			"sit", "lean":
				m.base_pose = l[5]
			"wave":
				pass
			_:
				m.mode = l[5]
		if l[5] == "sit":
			var seat := MeshInstance3D.new()
			seat.mesh = PropLibrary.mesh("plastic_chair")
			seat.position = m.position
			world.add_child(seat)
		models.append([m, float(l[6])])
	var cam := Camera3D.new()
	world.add_child(cam)
	if args.has("cars"):
		cam.position = Vector3(0.0, 5.6, 12.5)
		cam.look_at(Vector3(-0.5, 0.6, 1.0))
	elif args.has("dogs"):
		cam.position = Vector3(0.2, 1.1, 3.6)
		cam.look_at(Vector3(-0.3, 0.45, 1.2))
	elif args.has("face"):
		var who: Node3D = models[clampi(int(args.face), 0, models.size() - 1)][0]
		var head := who.global_position + Vector3(0, 1.64 * who.scale.y, 0)
		var dist := float(args.get("dist", "0.62"))
		cam.position = head + Vector3(0.12 * dist / 0.62, 0.02 - (dist - 0.62) * 0.3, dist)
		if args.has("side"):
			cam.position = head + Vector3(dist, 0.02 - (dist - 0.62) * 0.3, 0.05)
		cam.look_at(head)
	elif args.has("close"):
		cam.position = Vector3(-1.0, 1.55, 1.6)
		cam.look_at(Vector3(-1.5, 1.45, 0))
	elif args.has("named"):
		cam.position = Vector3(0, 1.25, 6.6)
		cam.look_at(Vector3(0, 1.1, 0))
	else:
		cam.position = Vector3(0, 1.4, 5.2)
		cam.look_at(Vector3(0, 0.95, 0))
	cam.fov = 30 if args.has("face") else (45 if args.has("close") else 60)
	cam.current = true
	var frames := int(args.get("frames", "40"))
	for f in frames:
		for pair in models:
			if f % 60 == 0 and models.find(pair) == 0:
				(pair[0] as CharacterModel).wave()
			(pair[0] as CharacterModel).animate(1.0 / 60.0, pair[1])
		for dp in dogs:
			if f == frames - 8 and dp == dogs[0]:
				(dp[0] as DogModel).bark()
			(dp[0] as DogModel).animate(1.0 / 60.0, dp[1])
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(str(args.get("out", "res://tests/output/lineup.png"))))
	print("lineup saved")
	quit()
