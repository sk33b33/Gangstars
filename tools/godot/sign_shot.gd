extends SceneTree
## Dev picture of the road signs: builds one real chunk, finds a street name slab and a stop sign and photographs them.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/godot/sign_shot.gd -- --out=res://tests/output/signs
var _step := 0
var _cams: Array = []
var _out := "res://tests/output/signs"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	var data := RealDistrictData.new()
	data.load_meta()
	var node: Node3D = null
	var chosen := Vector2i(-1, -1)
	for key: Vector2i in [Vector2i(-1, -1), Vector2i(-1, -2), Vector2i(0, -1), Vector2i(-2, -1), Vector2i(0, -2), Vector2i(-2, -2), Vector2i(0, 0), Vector2i(-1, 0)]:
		node = RealChunkBuilder.build(key, data.load_chunk(key), {}, data.around(key, "road_lines"), {}, data.around(key, "outlines"), data.yards(key), data.home_fronts(key), {"street": data.street_context(key), "decor": data.home_decor(key), "schools": data.school_fences(key), "stalls": data.stalls(key), "strips": data.around(key, "road_strips")})
		var has_stop := node.get_children().any(func(c): return str(c.name).contains("sign_stop"))
		if has_stop:
			chosen = key
			break
		node.free()
	root.add_child(node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#b9d3ea")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#cfd8e6")
	root.add_child(env)
	var slab: Label3D = null
	for c in node.get_children():
		if c is Label3D and c.has_meta("street_slab"):
			slab = c
			break
	if slab:
		var p := slab.position
		var cam_pos := p + slab.basis.z * 2.2 + Vector3(0, 0.6, 0)
		_cams.append([cam_pos, p])
		print("SLAB ", slab.text.replace("\n", " / "), " at ", p)
	for c in node.get_children():
		if c is MeshInstance3D and str(c.name).contains("sign_stop"):
			var sv: PackedVector3Array = (c.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var mid := (sv[0] + sv[2]) * 0.5   # the first plate's centre
			_cams.append([mid + Vector3(2.2, 0.2, 2.2), mid])
			_cams.append([mid + Vector3(-2.2, 0.2, -2.2), mid])
			_cams.append([mid + Vector3(2.2, 0.2, -2.2), mid])
			_cams.append([mid + Vector3(-2.2, 0.2, 2.2), mid])
			print("STOP sign mesh around ", mid)
			break
	# The painted STOP and a speed hump, from a driver's seat: 7 m back along the road, 1.3 m up, looking at the first marking.
	for c in node.get_children():
		if c is MeshInstance3D and str(c.name).contains("decal_stop_text"):
			var v: PackedVector3Array = (c.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var mid := (v[0] + v[1] + v[2] + v[5]) * 0.25
			var d := Vector3(v[0].x - v[2].x, 0, v[0].z - v[2].z).normalized()   # front minus back: the way the driver goes
			_cams.append([mid - d * 6.0 + Vector3(0, 1.3, 0), mid + d * 1.0])
			_cams.append([mid + Vector3(0, 4.5, 0), mid, d])   # straight above, the way the driver goes is up the picture
			print("STOPTEXT at ", mid, " driving ", d)
			break
	for c in node.get_children():
		if c is MeshInstance3D and str(c.name).contains("hump"):
			var v: PackedVector3Array = (c.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var mid := (v[0] + v[2]) * 0.5
			_cams.append([mid + Vector3(3, 2.2, 3), mid])
			print("HUMP at ", mid)
			break
	# Three ordinary houses from the street, for the walls and roofs.
	var picked := 0
	for key2: Vector2i in [chosen]:
		for b in data.load_chunk(key2).get("buildings", []):
			if picked >= 4:
				break
			if b.has("k") or b.p.size() < 4:
				continue
			var ring := RealChunkBuilder._line(b.p)
			var area := absf(RealChunkBuilder._signed_area(ring))
			if area < 60.0 or area > 200.0:
				continue
			var cen := Vector2.ZERO
			for q in ring:
				cen += q
			cen /= ring.size()
			picked += 1
			_cams.append([Vector3(cen.x + 11.0, 4.0, cen.y + 11.0), Vector3(cen.x, 2.0, cen.y)])
			_cams.append([Vector3(cen.x - 9.0, 2.2, cen.y + 9.0), Vector3(cen.x, 1.8, cen.y)])
			if RealChunkBuilder.seed_of(ring) % 2 == 0:   # a gable house, seen from its short end (the gable end must have no board)
				var rect := RealChunkBuilder.min_rect(ring)
				var end_at: Vector2 = cen + (rect.u as Vector2) * (float((rect.half as Vector2).x) + 7.0)
				_cams.append([Vector3(end_at.x, 2.6, end_at.y), Vector3(cen.x, 3.0, cen.y)])
	for c in node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_solar_geyser":
			var xf: Transform3D = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0)
			_cams.append([xf.origin + xf.basis.y * 3.0 + xf.basis.z * 5.0, xf.origin])
			_cams.append([xf.origin + xf.basis.y * 5.0 + xf.basis.z * 9.0 + xf.basis.x * 6.0, xf.origin])
			print("GEYSER at ", xf.origin)
			break
	for c in node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_braai_drum":
			var xf2: Transform3D = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0)
			_cams.append([xf2.origin + Vector3(4, 5, 4), xf2.origin])
			_cams.append([xf2.origin + Vector3(-3, 7, 6), xf2.origin + Vector3(0, 0, 2)])
			break
	var park_key := Vector2i(-4, -3)   # two parks of about 47 m
	var park_node := RealChunkBuilder.build(park_key, data.load_chunk(park_key), {}, data.around(park_key, "road_lines"), {}, data.around(park_key, "outlines"), data.yards(park_key), data.home_fronts(park_key), {"street": data.street_context(park_key), "decor": data.home_decor(park_key), "schools": data.school_fences(park_key), "stalls": data.stalls(park_key), "strips": data.around(park_key, "road_strips")})
	root.add_child(park_node)
	for c in park_node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_park_bench":
			var pb: Vector3 = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0).origin
			_cams.append([pb + Vector3(0, 14, 12), pb])
			_cams.append([pb + Vector3(5, 2.0, 5), pb + Vector3(0, 0.6, 0)])
			print("PARK BENCH at ", pb)
			break
	var cam := Camera3D.new()
	cam.name = "Cam"
	root.add_child(cam)
	cam.current = true


func _process(_delta: float) -> bool:
	_step += 1
	var cam := root.get_node("Cam") as Camera3D
	var shot := _step / 20
	if _step % 20 == 1 and shot < _cams.size():
		cam.global_position = _cams[shot][0]
		if _cams[shot].size() > 2:
			cam.look_at(_cams[shot][1], _cams[shot][2])
		else:
			cam.look_at(_cams[shot][1])
	if _step % 20 == 15 and shot < _cams.size():
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s_%d.png" % [_out, shot]))
	if shot >= _cams.size() or _cams.is_empty():
		quit()
	return false
