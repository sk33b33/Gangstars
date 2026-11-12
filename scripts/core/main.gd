extends Node
## Bootstraps the session: district, player, HUD, debug overlay; wires their signals.
## Optional user args (after `--`) for automated screenshots:
##   --shot=res://tests/output/x.png  --shot-delay=8  --view=player|overview|street
##   --debug  --player=x,z  --yaw=degrees  --pitch=degrees  --interact  --hour=21.5
##   --incident=car_alarm|argument|scuffle (raised at the player 2 s before the shot)
##   --safehouse-menu (open the safehouse menu)  --turf-map (open the turf map)
##   --load=user://file.json (start from that save; goes through normal save validation)
##   --profile (print rendering/frame stats after the delay and quit)  --no-lod
##   --day=N  --weather=clear|cloudy|windy|rain  --drive=<vehicle id>  --pause-menu
##   --cam=x,y,z,tx,ty,tz (fixed camera at x,y,z looking at tx,ty,tz)

@onready var district: District = $Westridge
@onready var player: Player = $Player
@onready var hud: Hud = $Hud
@onready var debug_overlay: DebugOverlay = $DebugOverlay

## Load the save on start (if one exists). Tests turn this off; `--new-game` also skips it.
@export var auto_load := true
@export var save_path := "user://savegame.json"

var session: GameSession
var settings := SettingsStore.new()
var pause_menu: PauseMenu

var _args := {}


func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	if _args.has("no-lod"):
		district.use_lod = false
	hud.set_district_name(district.display_name())
	player.interaction_target_changed.connect(hud.set_prompt)
	player.interacted.connect(hud.show_message)
	debug_overlay.setup(district, hud)
	district.director.observer = player
	session = GameSession.new()
	session.name = "Session"
	session.save_path = _args.get("load", save_path)
	add_child(session)
	settings.load_settings()
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	hud.add_child(pause_menu)
	pause_menu.setup(settings)
	pause_menu.quit_requested.connect(func(): get_tree().quit())
	pause_menu.resumed.connect(func():
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	settings.changed.connect(apply_settings)
	district.events.message.connect(hud.show_message)
	player.shouted.connect(func(pos: Vector3): district.events.raise("whistle", pos))
	if not district.is_navigation_ready:
		await district.navigation_ready
	session.setup(district, player, hud)
	apply_settings()
	hud.show_message("Welcome to Westridge. You've just moved into 13 AZ Berman Drive.")
	session.begin(_args.has("load") or (auto_load and not _args.has("new-game") and not _args.has("shot")))
	if session.progression.crew_id.is_empty():
		if _args.has("crew"):
			session.choose_crew(str(_args.crew))
		elif (_args.has("shot") or _args.has("profile")) and not _args.has("crew-picker"):
			session.choose_crew("vlakte_vipers")   # screenshots: skip the choice
		else:
			session.open_crew_picker()
	if _args.has("hour"):
		district.director.clock.set_hour(float(_args.hour))  # after loading, so it wins over the save
	if _args.has("shot"):
		_run_screenshot.call_deferred()
	elif _args.has("profile"):
		_run_profile.call_deferred()


func _process(_delta: float) -> void:
	hud.set_clock(district.director.clock)
	if session.police:
		hud.set_combat(player.health.fraction(), session.police.heat.level(), player.aiming)


## Pushes settings into the engine and game objects (called at start and on every change).
func apply_settings() -> void:
	settings.apply_engine()
	player.mouse_sensitivity = float(settings.get_value("controls/mouse_sensitivity"))
	player.invert_y = bool(settings.get_value("controls/invert_y"))
	player.stick_sensitivity = float(settings.get_value("controls/stick_sensitivity"))
	player.vibration = bool(settings.get_value("controls/vibration"))
	player.camera.fov = float(settings.get_value("video/fov"))
	var vp := get_viewport()
	vp.msaa_3d = int(settings.get_value("video/msaa")) as Viewport.MSAA
	vp.scaling_3d_scale = float(settings.get_value("video/render_scale"))
	var env: Environment = district.get_node("WorldEnvironment").environment
	env.fog_enabled = bool(settings.get_value("video/fog"))
	RenderQuality.apply(env, district.get_node("Sun"), bool(settings.get_value("video/effects")))
	district.day_night.shadows_allowed = bool(settings.get_value("video/shadows"))
	hud.set_fps_visible(bool(settings.get_value("video/show_fps")))
	if district.traffic:
		district.traffic.set_enabled(bool(settings.get_value("gameplay/traffic")))
	if district.weather:
		district.weather.enabled = bool(settings.get_value("gameplay/weather"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not pause_menu.visible and not hud.is_menu_open() \
			and not session.turf_map.visible:
		pause_menu.open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("debug_incident"):
		district.events.raise("argument", player.global_position + Vector3(2, 0, 0), "you")
	elif event.is_action_pressed("debug_danger"):
		district.events.raise("scuffle", player.global_position + Vector3(2, 0, 0), "you")
	elif event.is_action_pressed("debug_time"):
		var clock := district.director.clock
		clock.set_hour(clock.hour() + 1.0)
	elif event.is_action_pressed("toggle_debug"):
		debug_overlay.toggle()
	elif event.is_action_pressed("debug_reachability"):
		var text := debug_overlay.run_reachability()
		print(text)
		hud.show_message(text)


func _run_screenshot() -> void:
	if _args.has("player"):
		var p: PackedStringArray = _args.player.split(",")
		player.global_position = Vector3(float(p[0]), 0.1, float(p[1]))
		player.snap_camera()
	if _args.has("yaw"):
		player.pivot.rotation.y = deg_to_rad(float(_args.yaw))
	if _args.has("pitch"):
		player.pitch.rotation.x = deg_to_rad(float(_args.pitch))
	if _args.has("cam"):
		var c: PackedStringArray = _args.cam.split(",")
		_add_camera(Vector3(float(c[0]), float(c[1]), float(c[2])), Vector3(float(c[3]), float(c[4]), float(c[5])))
	match _args.get("view", "player"):
		"overview":
			_add_camera(Vector3(0, 105, 52), Vector3(0, 0, -30))
		"street":
			_add_camera(Vector3(-36, 9, 12), Vector3(-4, 1, 2))
	if _args.has("debug"):
		debug_overlay.toggle()
	if _args.has("day"):
		district.director.clock.day = int(_args.day)
	if _args.has("weather"):
		district.weather.hold(_args.weather)
		district.weather.rain = float(Weather.KINDS[_args.weather][0])
		district.weather.overcast = float(Weather.KINDS[_args.weather][1])
		district.weather.wind = float(Weather.KINDS[_args.weather][2])
		if _args.weather == "rain" or _args.has("wet"):
			district.weather.wet = 1.0
	if _args.has("drive") and district.vehicles.has(_args.drive):
		player.enter_vehicle(district.vehicles[_args.drive])
	if _args.has("pause-menu"):
		pause_menu.open()
	if _args.has("safehouse-menu"):
		session.open_safehouse_menu()
	if _args.has("turf-map"):
		session.open_turf_map()
	var delay := float(_args.get("shot-delay", "6"))
	if _args.has("incident"):
		await get_tree().create_timer(maxf(delay - 3.0, 0.1)).timeout
		district.events.raise(_args.incident, player.global_position + Vector3(0, 0, -6), "you")
		delay = 3.0
	if _args.has("hustle"):
		await get_tree().create_timer(maxf(delay - 2.0, 0.1)).timeout
		_stage_hustle()
		delay = 1.5
	if _args.has("interior"):
		await get_tree().create_timer(maxf(delay - 1.0, 0.1)).timeout
		var id := str(_args.interior)
		if id != GameSession.SAFEHOUSE_ID and not session.dealing.is_venue(id):
			session.interiors.welcome(id)
		var why := session.interiors.enter(id)
		if not why.is_empty():
			print("interior: ", why)
		if _args.has("yaw"):
			player.pivot.rotation.y = deg_to_rad(float(_args.yaw))
			player.snap_camera()
		delay = 0.6
	if _args.has("tag"):
		await get_tree().create_timer(maxf(delay - 1.0, 0.1)).timeout
		session.turf._refresh_tags()
		for id in session.turf.tags:
			var d: Decal = session.turf.tags[id].decal
			if d and absf(d.global_basis.y.y) < 0.5:
				var n := d.global_basis.y
				_add_camera(d.global_position + n * 4.5 + Vector3(0, 0.4, 0) + d.global_basis.x * 1.5, d.global_position)
				break
		delay = 0.4
	if _args.has("aunty"):
		await get_tree().create_timer(maxf(delay - 1.0, 0.1)).timeout
		_stage_aunty_shot()
		delay = 0.3
	if _args.has("firefight") or _args.has("follow"):
		await get_tree().create_timer(maxf(delay - 3.0, 0.1)).timeout
		await _stage_police_shot(_args.has("firefight"))
		delay = 2.5 if _args.has("firefight") else 0.2
	await get_tree().create_timer(delay).timeout
	if _args.has("interact") and player.current_target:
		hud.show_message(player.current_target.interact(player))
		await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path: String = _args.shot
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("screenshot %s -> %s" % [path, error_string(err)])
	get_tree().quit()


## Screenshot staging: some stock, a few clients near the player (different moods), one ringing,
## and the phone open (unless --hustle=street, which shows the mood faces in the world).
func _stage_hustle() -> void:
	var d := session.dealing
	d.state.add_stock("weed", 6)
	d.state.add_stock("drink", 10)
	if not session.progression.completed_mission_ids.has("the_smokkie"):
		session.progression.completed_mission_ids.append("the_smokkie")
	session.missions.active["bankies"] = {"objective": 0, "count": 0.0, "seen": [], "started": d.minutes()}
	var near: Array = district.residents.values().filter(func(r): return not r.is_inside and d._could_be_client(r))
	near.sort_custom(func(a, b): return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	var moods := [90.0, 62.0, 40.0, 28.0]
	for i in mini(4, near.size()):
		d.on_chat(near[i].data.id)
		d.state.clients[near[i].data.id].mood = moods[i]
	if near.size() > 4:
		d.on_chat(near[4].data.id)
		d.state.clients[near[4].data.id].status = "lost"
		d.state.clients[near[4].data.id].rival = "Dune Cruisers"
	if not near.is_empty():
		var c: Dictionary = d.state.clients[near[0].data.id]
		d.state.call = {"npc": near[0].data.id, "product": c.product, "qty": 1, "place": str(c.home) + ":gate", "rings_until": d.minutes() + 30.0}
	if str(_args.hustle) != "street":
		session.toggle_phone()
	elif near.size() >= 2:
		var c0: Vector3 = near[0].global_position
		player.global_position = c0 + Vector3(2.0, 0.1, 1.5)
		_add_camera(c0 + Vector3(3.0, 2.4, 4.0), c0 + Vector3(0, 1.8, 0))


## Screenshot staging: frames the outdoor resident in a house dress with the most others nearby.
func _stage_aunty_shot() -> void:
	var outside := district.residents.values().filter(func(r): return not r.is_inside and not r.is_down() \
			and r.data.appearance().get("dress", false))
	var best: Resident = null
	var best_n := -1
	for r: Resident in outside:
		var n := outside.filter(func(o): return o.global_position.distance_to(r.global_position) < 10.0).size()
		if n > best_n:
			best_n = n
			best = r
	if best == null:
		return
	var f := best.global_basis.z
	_add_camera(best.global_position + f * 4.2 + best.global_basis.x * 1.4 + Vector3(0, 1.6, 0), best.global_position + Vector3(0, 1.0, 0))


## Screenshot staging: frames the officer nearest the player. With firefight, the player stands
## off against them at heat 3 (both aiming) and the camera looks across the two.
func _stage_police_shot(firefight: bool) -> void:
	var cop: Resident = null
	var best := INF
	for r: Resident in district.residents.values():
		if r.data.role == "police" and not r.is_inside and not r.is_down():
			var d := r.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				cop = r
	if cop == null:
		return
	var side := cop.global_basis.x
	if firefight:
		player.global_position = cop.global_position + cop.global_basis.z * 8.0 + Vector3(0, 0.1, 0)
		player.snap_camera()
		var to := cop.global_position - player.global_position
		player.pivot.rotation.y = atan2(-to.x, -to.z)
		session.police.heat.add(3.0)
		cop.start_fight(player)
		player.model.set_weapon("pistol")
		player.model.draw_weapon(true)
		player.model.aiming = true
		var mid := (cop.global_position + player.global_position) * 0.5
		_add_camera(mid + side * 7.5 + Vector3(0, 2.4, 0), mid + Vector3(0, 1.0, 0))
	else:
		_add_camera(cop.global_position + cop.global_basis.z * 5.5 + side * 2.0 + Vector3(0, 1.8, 0), cop.global_position + Vector3(0, 1.1, 0))


## Prints frame/render statistics after the world has settled (windowed run needed for
## draw-call numbers; headless reports zeros for rendering).
func _run_profile() -> void:
	if _args.has("player"):
		var p: PackedStringArray = _args.player.split(",")
		player.global_position = Vector3(float(p[0]), 0.1, float(p[1]))
		player.snap_camera()
	if _args.has("yaw"):
		player.pivot.rotation.y = deg_to_rad(float(_args.yaw))
	if _args.has("hour"):
		district.director.clock.set_hour(float(_args.hour))
	await get_tree().create_timer(float(_args.get("shot-delay", "8"))).timeout
	var frames := 120
	var draw := 0
	var objs := 0
	var prims := 0
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
		draw += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var frame_ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("PROFILE merge=%s" % district.merge_stats)
	print("PROFILE lod=%s lod_instances=%d nodes=%d draw_calls=%d objects=%d primitives=%d frame_ms=%.2f process_ms=%.3f physics_ms=%.3f" % [
		district.use_lod, district.lod_count, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		draw / frames, objs / frames, prims / frames, frame_ms,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	get_tree().quit()


func _add_camera(pos: Vector3, look_at_point: Vector3) -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = pos
	cam.look_at(look_at_point)
	cam.current = true


static func _parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out
