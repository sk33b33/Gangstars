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
	var play_key := Vector2i(-3, 0)   # a playground of 45 x 48 m
	var play_node := RealChunkBuilder.build(play_key, data.load_chunk(play_key), {}, data.around(play_key, "road_lines"), {}, data.around(play_key, "outlines"), data.yards(play_key), data.home_fronts(play_key), {"street": data.street_context(play_key), "decor": data.home_decor(play_key), "schools": data.school_fences(play_key), "stalls": data.stalls(play_key), "strips": data.around(play_key, "road_strips")})
	root.add_child(play_node)
	for c in play_node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_spring_rider":
			var sr: Vector3 = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0).origin
			_cams.append([sr + Vector3(0, 16, 14), sr + Vector3(5, 0, -4)])
			_cams.append([sr + Vector3(4, 2.5, 6), sr + Vector3(4, 0.6, 0)])
			print("PLAYGROUND at ", sr)
			break
	for c in play_node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_netball_post":
			var np: Vector3 = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0).origin
			_cams.append([np + Vector3(0, 30, 24), np + Vector3(0, 0, -8)])
			_cams.append([np + Vector3(6, 2.5, 8), np + Vector3(0, 1.5, 0)])
			print("NETBALL at ", np)
			break
	for c in play_node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_flagpole":
			var fp: Vector3 = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0).origin
			_cams.append([fp + Vector3(5, 3, 9), fp + Vector3(0, 3, 0)])
			print("FLAG at ", fp)
			break
	for c in node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_fire_hydrant":
			var hy: Vector3 = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0).origin
			_cams.append([hy + Vector3(6, 2.2, 7), hy + Vector3(0, 0.6, 0)])
			_cams.append([hy + Vector3(0, 12, 14), hy])
			print("HYDRANT at ", hy)
			break
	var shop_key := Vector2i(-1, 0)
	var shop_node := RealChunkBuilder.build(shop_key, data.load_chunk(shop_key), {}, data.around(shop_key, "road_lines"), {}, data.around(shop_key, "outlines"), data.yards(shop_key), data.home_fronts(shop_key), {"street": data.street_context(shop_key), "decor": data.home_decor(shop_key), "schools": data.school_fences(shop_key), "stalls": data.stalls(shop_key), "strips": data.around(shop_key, "road_strips")})
	root.add_child(shop_node)
	for c in shop_node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_drinks_fridge":
			var df: Vector3 = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0).origin
			var dfb: Basis = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0).basis
			_cams.append([df + dfb.z * 7.0 + Vector3(0, 2.5, 0), df + Vector3(0, 1.8, 0)])
			_cams.append([df + dfb.z * 3.0 + dfb.x * 3.0 + Vector3(0, 1.6, 0), df + Vector3(0, 1.0, 0)])
			print("SHOP FRIDGE at ", df)
			break
	var fuel_key := Vector2i(1, 3)
	var fuel_node := RealChunkBuilder.build(fuel_key, data.load_chunk(fuel_key), {}, data.around(fuel_key, "road_lines"), {}, data.around(fuel_key, "outlines"), data.yards(fuel_key), data.home_fronts(fuel_key), {"street": data.street_context(fuel_key), "decor": data.home_decor(fuel_key), "schools": data.school_fences(fuel_key), "stalls": data.stalls(fuel_key), "strips": data.around(fuel_key, "road_strips")})
	root.add_child(fuel_node)
	for c in fuel_node.get_children():
		if c is MultiMeshInstance3D and str(c.name) == "Props_bollard":
			var bo: Vector3 = (c as MultiMeshInstance3D).multimesh.get_instance_transform(1).origin
			_cams.append([bo + Vector3(0, 14, 16), bo])
			_cams.append([bo + Vector3(7, 2.4, 9), bo + Vector3(0, 2.0, 0)])
			print("FUEL at ", bo)
			break
	var stop_found := false
	for sk: Vector2i in [Vector2i(3, 6), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(-2, 1), Vector2i(2, 2), Vector2i(1, 1)]:
		var sn := RealChunkBuilder.build(sk, data.load_chunk(sk), {}, data.around(sk, "road_lines"), {}, data.around(sk, "outlines"), data.yards(sk), data.home_fronts(sk), {"street": data.street_context(sk), "decor": data.home_decor(sk), "schools": data.school_fences(sk), "stalls": data.stalls(sk), "strips": data.around(sk, "road_strips")})
		for c in sn.get_children():
			if c is MeshInstance3D and str(c.name) == "Mesh_panel_sign_timetable" and not stop_found:
				var tv: PackedVector3Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var tp := tv[0]
				root.add_child(sn)
				_cams.append([tp + Vector3(5, 4, 9), tp])
				_cams.append([tp + Vector3(0, 1.6, 4.5), tp])
				print("TIMETABLE at ", tp, " chunk ", sk)
				stop_found = true
				for c2 in sn.get_children():
					if c2 is MeshInstance3D and str(c2.name).begins_with("Mesh_decal_bay_"):
						var bv: PackedVector3Array = (c2 as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
						var bmid := (bv[0] + bv[2]) * 0.5
						var bd := Vector3(bv[0].x - bv[2].x, 0, bv[0].z - bv[2].z).normalized()
						_cams.append([bmid + Vector3(0, 4.5, 0), bmid, bd])
						print("BAY TEXT ", c2.name, " at ", bmid, " driving ", bd)
						break
		if not stop_found:
			sn.free()
	var clinic_key := Vector2i(0, -1)
	var clinic_node := RealChunkBuilder.build(clinic_key, data.load_chunk(clinic_key), {}, data.around(clinic_key, "road_lines"), {}, data.around(clinic_key, "outlines"), data.yards(clinic_key), data.home_fronts(clinic_key), {"street": data.street_context(clinic_key), "decor": data.home_decor(clinic_key), "schools": data.school_fences(clinic_key), "stalls": data.stalls(clinic_key), "strips": data.around(clinic_key, "road_strips")})
	root.add_child(clinic_node)
	for c in clinic_node.get_children():
		if c is MeshInstance3D and str(c.name) == "Mesh_panel_sign_clinic_hours":
			var cv: PackedVector3Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var cn: Vector3 = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
			var cp := cv[0]
			_cams.append([cp + cn * 9.0 + Vector3(0, 3.0, 0), cp + Vector3(0, 1.5, 0)])
			_cams.append([cp + cn * 18.0 + Vector3(0, 12.0, 0), cp])
			print("CLINIC at ", cp, " normal ", cn)
			break
	for wk: Vector2i in [Vector2i(-1, 2), Vector2i(2, 6)]:
		var wn := RealChunkBuilder.build(wk, data.load_chunk(wk), {}, data.around(wk, "road_lines"), {}, data.around(wk, "outlines"), data.yards(wk), data.home_fronts(wk), {"street": data.street_context(wk), "decor": data.home_decor(wk), "schools": data.school_fences(wk), "stalls": data.stalls(wk), "strips": data.around(wk, "road_strips")})
		root.add_child(wn)
		for c in wn.get_children():
			if c is MeshInstance3D and str(c.name) == "Mesh_panel_door_church":
				var dv: PackedVector3Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var dn: Vector3 = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
				var dp := dv[0]
				_cams.append([dp + dn * 14.0 + Vector3(0, 3.5, 0), dp + Vector3(0, 3.5, 0)])
				_cams.append([dp + dn * 8.0 + Vector3(5, 2.0, 0), dp + Vector3(0, 2.0, 0)])
				print("CHURCH at ", dp)
			if c is MeshInstance3D and str(c.name) == "Mesh_panel_sign_church":
				var nv: PackedVector3Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var nn: PackedVector3Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
				var nmid := (nv[0] + nv[2]) * 0.5
				for q in [0, 6]:   # the quad facing along its normal, then the other side
					var qmid := (nv[q] + nv[q + 2]) * 0.5
					_cams.append([qmid + nn[q] * 3.5 + Vector3(0, 0.2, 0), qmid])
				print("BOARD at ", nmid)
			if c is MultiMeshInstance3D and str(c.name) == "Props_crescent_finial":
				var cf: Vector3 = (c as MultiMeshInstance3D).multimesh.get_instance_transform(0).origin
				_cams.append([cf + Vector3(14, 3, 14), cf + Vector3(0, -4, 0)])
				_cams.append([cf + Vector3(25, 6, 25), cf + Vector3(0, -6, 0)])
				print("MOSQUE at ", cf)
	for hk: Vector2i in [Vector2i(0, -1), Vector2i(-2, -2)]:
		var hn := RealChunkBuilder.build(hk, data.load_chunk(hk), {}, data.around(hk, "road_lines"), {}, data.around(hk, "outlines"), data.yards(hk), data.home_fronts(hk), {"street": data.street_context(hk), "decor": data.home_decor(hk), "schools": data.school_fences(hk), "stalls": data.stalls(hk), "strips": data.around(hk, "road_strips")})
		root.add_child(hn)
		for c in hn.get_children():
			if c is MeshInstance3D and (str(c.name) == "Mesh_panel_sign_civic" or str(c.name) == "Mesh_panel_sign_sports_hall"):
				var hv: PackedVector3Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var hnn: Vector3 = (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
				var hp := (hv[0] + hv[2]) * 0.5
				_cams.append([hp + hnn * 16.0 + Vector3(0, 2.5, 0), hp + Vector3(0, -0.5, 0)])
				_cams.append([hp + hnn * 30.0 + Vector3(0, 20, 0), hp + Vector3(0, -3, 0)])
				print("HALL ", c.name, " at ", hp)
	for c in node.get_children():
		if c is Label3D and str(c.name).begins_with("HouseNumber"):
			var hl := c as Label3D
			var hn := Basis(Vector3.UP, hl.rotation.y).z
			_cams.append([hl.position + hn * 4.0 + Vector3(0, 0.2, 0), hl.position])
			_cams.append([hl.position + hn * 9.0 + Vector3(3, 1.0, 0), hl.position - Vector3(0, 0.5, 0)])
			print("HOUSE NUMBER ", hl.text, " at ", hl.global_position, " local ", hl.position, " in tree ", hl.is_inside_tree(), " parent ", hl.get_parent().name)
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
