extends Node3D
## A small test world for the Remy character: open scenes/dev/remy_playground.tscn and press F6 (Run Current Scene).
## WASD / left stick move, mouse / right stick look, Shift sprint, Space jump, right mouse (or LT) aim.
## On a phone the on-screen controls appear by themselves (on a PC add `-- --touch` to try them).
## A row of NPCs shows the gaits and outfits. Screenshot flags: --shot=<png> --shot-delay=<s> --cam=x,y,z,tx,ty,tz
## --hold=<action,action> (keys held down, for example move_forward,sprint) --hold-after=<s> --touch

const PLAYER_SCENE := preload("res://scenes/characters/remy/remy_player.tscn")
const MODEL_SCENE := preload("res://scenes/characters/remy/remy_model.tscn")
const TOUCH_AFTER := 0.0

var player: RemyPlayer
var touch: TouchControls
var npcs: Array = []             # [{model, speed, sprint}]
var _args := {}
var _time := 0.0
var _shot_done := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_build_world()
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.position = Vector3(0, 0.05, 4)
	player.snap_camera()
	_build_npcs()
	touch = TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.setup(player, _args.has("touch"))
	var hud := CanvasLayer.new()
	add_child(hud)
	var label := Label.new()
	label.text = "REMY PLAYGROUND   WASD move · mouse look · Shift sprint · Space jump · right mouse aim · Esc free the mouse"
	label.position = Vector2(12, 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	hud.add_child(label)
	if _args.has("cam"):
		var c: PackedStringArray = str(_args.cam).split(",")
		var cam := Camera3D.new()
		add_child(cam)
		cam.global_position = Vector3(float(c[0]), float(c[1]), float(c[2]))
		cam.look_at(Vector3(float(c[3]), float(c[4]), float(c[5])))
		cam.current = true
		cam.fov = 45.0
	elif DisplayServer.get_name() != "headless" and not _args.has("touch") and not _args.has("shot"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


var _dbg_next := 0.0


func _process(delta: float) -> void:
	_time += delta
	if _args.has("trace") and _time > _dbg_next and not npcs.is_empty():
		_dbg_next = _time + 0.25
		var mdl: RemyModel = npcs[4].model
		var hp: Vector3 = mdl.skeleton.global_transform * mdl.skeleton.get_bone_global_pose(mdl.skeleton.find_bone("mixamorig_RightHand")).origin - mdl.global_position
		print("TRACE t=%.1f dt=%.3f hand=(%.2f,%.2f,%.2f) aim=%.2f" % [_time, delta, hp.x, hp.y, hp.z, float(mdl.tree.get("parameters/aim/blend_amount"))])
	if _args.has("hold") and _time > float(_args.get("hold-after", "0.5")):
		for action in str(_args.hold).split(","):
			Input.action_press(action)
	if _args.has("shot") and not _shot_done and _time > float(_args.get("shot-delay", "3")):
		_shot_done = true
		if _args.has("debug"):
			for n: Dictionary in npcs:
				var mdl: RemyModel = n.model
				print("DBG npc aim_target=", mdl.is_aiming(), " param=", mdl.tree.get("parameters/aim/blend_amount"), " gait=", mdl.gait, " active=", mdl.tree.active, " state=", mdl.state_name(), " rhand=", mdl.skeleton.global_transform * mdl.skeleton.get_bone_global_pose(mdl.skeleton.find_bone("mixamorig_RightHand")).origin, " pos=", mdl.global_position)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(str(_args.shot)))
		get_tree().quit()


func _physics_process(delta: float) -> void:
	for n: Dictionary in npcs:
		(n.model as RemyModel).update_locomotion(float(n.speed), bool(n.sprint), true, delta)


func _build_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	shape.position.y = -0.5
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	mesh.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("#8f9a74")
	ground.roughness = 1.0
	mesh.material_override = ground
	floor_body.add_child(mesh)
	add_child(floor_body)
	# A tape-measure of 1 m marks along the walking line, steps and boxes to jump on.
	var mark := StandardMaterial3D.new()
	mark.albedo_color = Color("#2b2d33")
	for i in range(-10, 11):
		var m := MeshInstance3D.new()
		var q := BoxMesh.new()
		q.size = Vector3(0.6 if i % 5 == 0 else 0.3, 0.01, 0.04)
		m.mesh = q
		m.material_override = mark
		m.position = Vector3(-3.0, 0.006, float(i))
		add_child(m)
	for spec in [[Vector3(4, 0.25, 4), Vector3(2, 0.25, 0)], [Vector3(2, 0.5, 2), Vector3(5.5, 0.5, 0)], [Vector3(4, 1.0, 1), Vector3(2, 1.0, -3)]]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[0]
		cs.shape = bs
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[0]
		mi.mesh = bm
		mi.material_override = mark
		body.add_child(mi)
		body.position = Vector3(spec[1].x, spec[0].y * 0.5, spec[1].z + 6.0)
		add_child(body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = not DisplayServer.is_touchscreen_available()
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#b9d3ea")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#cfd8e6")
	e.ambient_light_energy = 0.35
	env.environment = e
	add_child(env)


## Five NPCs in a row: standing, walking, running, sprinting and aiming, each in a different outfit.
func _build_npcs() -> void:
	var looks := [
		{"skin": Color("#c89b7b"), "top": Color("#d6403e"), "bottom": Color("#3a3d46"), "shoes": Color("#f1eee8"), "hair": Color("#6b4a33")},
		{"skin": Color("#8d5a3b"), "top": Color("#2b6fb5"), "bottom": Color("#7d8a63"), "shoes": Color("#1d1b24"), "hair": Color("#1d1b24")},
		{"skin": Color("#e2b894"), "top": Color("#e0b02a"), "bottom": Color("#2f3b4a"), "shoes": Color("#a63a4c"), "hair": Color("#c9a14a")},
		{"skin": Color("#6b4430"), "top": Color("#3f8f6a"), "bottom": Color("#d9d4c8"), "shoes": Color("#2b2d33"), "hair": Color("#1d1b24")},
		{"skin": Color("#a7754f"), "top": Color("#c8327a"), "bottom": Color("#1d1b24"), "shoes": Color("#e0b02a"), "hair": Color("#4a2f22")},
	]
	var gaits := [[0.0, false], [1.7, false], [4.0, false], [6.0, true], [0.0, false]]
	var bodies := ["james", "kate", "leonard", "louise", "meegan"]
	for i in 5:
		var m: RemyModel = MODEL_SCENE.instantiate()
		if _args.has("bodies"):   # --bodies: the five Mixamo NPC bodies instead of Remy in five outfits
			m = (load("res://scenes/characters/npc/%s_model.tscn" % bodies[i]) as PackedScene).instantiate()
		add_child(m)
		m.position = Vector3(-4.0 + i * 2.0, 0.0, -6.0)
		m.rotation.y = 0.0   # faces -Z; the player starts south of them, looking north
		var look: Dictionary = looks[i]
		var outfit := RemyOutfit.new()
		outfit.skin_tint = look.skin
		outfit.tops_tint = look.top
		outfit.bottoms_tint = look.bottom
		outfit.shoes_tint = look.shoes
		outfit.hair_tint = look.hair
		if not _args.has("bodies"):
			m.apply_outfit(outfit)
		if i == 4:
			m.set_aiming(true)
		npcs.append({"model": m, "speed": gaits[i][0], "sprint": gaits[i][1]})
