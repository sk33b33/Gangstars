extends Node
## Bootstraps the session: district, player, HUD, debug overlay; wires their signals.
## Optional user args (after `--`) for automated screenshots:
##   --shot=res://tests/output/x.png  --shot-delay=8  --view=player|overview|street
##   --debug  --player=x,z  --yaw=degrees  --pitch=degrees  --interact  --hour=21.5
##   --incident=car_alarm|argument|scuffle (raised at the player 2 s before the shot)

@onready var district: District = $Vleirand
@onready var player: Player = $Player
@onready var hud: Hud = $Hud
@onready var debug_overlay: DebugOverlay = $DebugOverlay

var _args := {}


func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	hud.set_district_name(district.display_name())
	player.interaction_target_changed.connect(hud.set_prompt)
	player.interacted.connect(hud.show_message)
	debug_overlay.setup(district, hud)
	district.director.observer = player
	district.events.message.connect(hud.show_message)
	player.shouted.connect(func(pos: Vector3): district.events.raise("whistle", pos))
	if _args.has("hour"):
		district.director.clock.set_hour(float(_args.hour))
	if not district.is_navigation_ready:
		await district.navigation_ready
	hud.show_message("Welcome to Vleirand. Walk Duif Street and meet the neighbours.")
	if _args.has("shot"):
		_run_screenshot.call_deferred()


func _process(_delta: float) -> void:
	hud.set_clock(district.director.clock)


func _unhandled_input(event: InputEvent) -> void:
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
	if _args.has("yaw"):
		player.pivot.rotation.y = deg_to_rad(float(_args.yaw))
	if _args.has("pitch"):
		player.pitch.rotation.x = deg_to_rad(float(_args.pitch))
	match _args.get("view", "player"):
		"overview":
			_add_camera(Vector3(0, 105, 52), Vector3(0, 0, -30))
		"street":
			_add_camera(Vector3(-36, 9, 12), Vector3(-4, 1, 2))
	if _args.has("debug"):
		debug_overlay.toggle()
	var delay := float(_args.get("shot-delay", "6"))
	if _args.has("incident"):
		await get_tree().create_timer(maxf(delay - 3.0, 0.1)).timeout
		district.events.raise(_args.incident, player.global_position + Vector3(0, 0, -6), "you")
		delay = 3.0
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
