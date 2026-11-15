extends Node
## Walk-around preview of the real Westridge (work in progress: no missions or residents yet).
## Open from the pause menu ("Real Westridge preview") or run scenes/real/real_westridge.tscn.
## Desktop builds the whole suburb; a touchscreen loads only what is near you.
##   -- --shot=<png> --shot-delay=<s> --cam=x,y,z,tx,ty,tz --at=x,z --radius=<m> --touch --top-down
## Design: design/gdd/real_world.md.

const PLAYER_SCENE := "res://scenes/characters/player.tscn"
const MAIN_SCENE := "res://scenes/main/main.tscn"
const START := Vector3(-150.0, 0.2, -128.0)   # Excelsior Street
const PHONE_RADIUS := 320.0

var world: RealWorld
var data: RealDistrictData
var player: Player
var touch: TouchControls
var _label: Label
var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	data = RealDistrictData.new()
	if not data.load_meta():
		push_error("real Westridge data missing")
		return
	_build_sky()
	player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	player.global_position = START
	if _args.has("at"):
		var p: PackedStringArray = str(_args.at).split(",")
		player.global_position = Vector3(float(p[0]), 0.2, float(p[1]))
	player.snap_camera()
	player.camera.far = 1500.0
	world = RealWorld.new()
	world.name = "RealWestridge"
	add_child(world)
	world.setup(data, player)
	touch = TouchControls.new()
	add_child(touch)
	touch.setup(player, _args.has("touch"))
	InputHints.touch = touch.enabled
	world.load_radius = PHONE_RADIUS if touch.enabled else INF
	world.builds_per_frame = 1 if touch.enabled else 2
	if _args.has("radius"):
		world.load_radius = float(_args.radius)
	if _args.has("top-down"):
		player.top_down = true
	_build_hud()
	if DisplayServer.get_name() != "headless" and not touch.enabled and not _args.has("shot"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _args.has("shot"):
		_shoot.call_deferred()


func _build_sky() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#5b8fd0")
	sky_material.sky_horizon_color = Color("#cfd9e6")
	sky_material.ground_horizon_color = Color("#d8c9a4")
	sky_material.ground_bottom_color = Color("#bfae88")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("#d7dde6")
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = not DisplayServer.is_touchscreen_available()
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	var credit := Label.new()
	credit.text = data.credit
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credit.position += Vector2(12, -26)
	credit.add_theme_font_size_override("font_size", 12)
	credit.add_theme_color_override("font_outline_color", Color.BLACK)
	credit.add_theme_constant_override("outline_size", 4)
	layer.add_child(credit)


func status_text() -> String:
	var look := -player.pivot.global_basis.z
	var heading := fposmod(rad_to_deg(atan2(look.x, -look.z)), 360.0)
	var points := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var street := world.street_near(player.global_position)
	return "WESTRIDGE, real map (preview)   %s\n%s   ·   facing %s   ·   %d of %d pieces loaded, %d buildings%s   ·   %d fps\n%s" % [
		"" if data.is_inside(player.global_position) else "(outside Westridge)",
		street if not street.is_empty() else "open ground", points[int(round(heading / 45.0)) % 8],
		world.loaded.size(), data.chunk_keys.size(), world.buildings_loaded,
		("  (loading %d)" % world.pending()) if world.pending() > 0 else "", Engine.get_frames_per_second(),
		"MENU: back to the game" if touch.enabled else "Esc: back to the game   ·   V: top-down view"]


func _process(_delta: float) -> void:
	if _label and Engine.get_process_frames() % 10 == 0:
		_label.text = status_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(MAIN_SCENE)


func _shoot() -> void:
	world.load_all_now() if is_inf(world.load_radius) else world.scan(player.global_position)
	while world.pending() > 0:
		await get_tree().process_frame
	if _args.has("cam"):
		var c: PackedStringArray = str(_args.cam).split(",")
		var cam := Camera3D.new()
		add_child(cam)
		cam.far = 4000.0
		cam.global_position = Vector3(float(c[0]), float(c[1]), float(c[2]))
		cam.look_at(Vector3(float(c[3]), float(c[4]), float(c[5])))
		cam.current = true
	await get_tree().create_timer(float(_args.get("shot-delay", "2"))).timeout
	_label.text = status_text()
	await RenderingServer.frame_post_draw
	var path := str(_args.shot)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	print("screenshot %s -> %s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
	get_tree().quit()
