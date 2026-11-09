class_name GameSession
extends Node
## Gameplay services for one play session: progression, missions, safehouse, save/load.
## Wires them to the district (world queries, recruits, upgrade props), the player
## (interactions, position) and the HUD (stats, tracker, menus, markers).

const MISSIONS_FILE := "res://data/missions/intro.json"
const UPGRADES_FILE := "res://data/progression/safehouse_upgrades.json"
const SAFEHOUSE_ID := "starter_h05"
const TRACK_INTERVAL := 0.25

@export var save_path := "user://savegame.json"

var progression := ProgressionState.new()
var missions: MissionManager
var safehouse: Safehouse
var district: District
var player: Player
var hud: Hud
var districts: DistrictManager
var turf_map: TurfMap
var audio: AudioDirector
var last_save_error := ""

var _track_accum := 0.0
var _reckless_cooldown := 0.0
var current_area := "starter"
var _beacon: MeshInstance3D


## Missions from every district in the catalog (`missions` field), starter first.
static func _load_all_missions() -> Array[MissionData]:
	var out: Array[MissionData] = []
	var catalog: Variant = DataFiles.load_json("res://data/districts/districts.json")
	var files: PackedStringArray = [MISSIONS_FILE]
	if catalog is Dictionary:
		for d in catalog.get("districts", []):
			var f := str(d.get("missions", ""))
			if not f.is_empty() and not files.has(f):
				files.append(f)
	for f in files:
		out.append_array(MissionData.load_file(f))
	return out


func setup(p_district: District, p_player: Player, p_hud: Hud) -> void:
	district = p_district
	player = p_player
	hud = p_hud
	district.player = player
	safehouse = Safehouse.load_file(UPGRADES_FILE)
	missions = MissionManager.new()
	missions.name = "Missions"
	add_child(missions)
	missions.setup(_load_all_missions(), progression, district.director.clock)
	missions.resident_info = district.resident_info
	missions.occupants_inside = district.occupants_inside
	missions.anchor_position = district.anchor_or_null
	missions.crew_near = district.crew_near
	missions.driving_vehicle = func() -> String: return player.vehicle.vehicle_id if player.is_driving() else ""
	missions.event_active = func(id: String) -> bool: return district.director.calendar.is_active(id)
	districts = DistrictManager.load_file("res://data/districts/districts.json", progression, district.registry)
	for id in missions.order:
		districts.mission_titles[id] = missions.get_mission(id).title
	districts.district_unlocked.connect(_on_district_unlocked)
	districts.became_unlockable.connect(func(id: String):
		hud.show_message("%s can now be unlocked. Open the turf map (%s)." % [districts.display_name(id), InputHints.key("turf_map")]))
	progression.changed.connect(districts.check_unlockable)
	turf_map = TurfMap.new()
	turf_map.name = "TurfMap"
	hud.add_child(turf_map)
	turf_map.setup(district, districts, player)
	turf_map.unlock_requested.connect(request_unlock)
	turf_map.closed.connect(_on_map_closed)
	_setup_audio()
	missions.message.connect(hud.show_message)
	progression.changed.connect(func(): hud.set_stats(progression))
	progression.recruited.connect(func(npc_id: String): district.apply_recruit(npc_id, SAFEHOUSE_ID))
	district.director.clock.day_changed.connect(_on_new_day)
	player.interacted_with.connect(_on_interacted)
	player.honked.connect(func(pos: Vector3): district.events.raise("car_horn", pos))
	player.vehicle_changed.connect(_on_vehicle_changed)
	_build_beacon()
	hud.set_stats(progression)


## Call once the district's navigation and residents are ready.
func begin(load_save: bool) -> void:
	if load_save and SaveSystem.exists(save_path):
		var err := load_game()
		if not err.is_empty():
			hud.show_message("Couldn't load your save (%s). Starting a new game." % err)
	missions.check_auto_start()
	sync_gates()
	_refresh()


func _physics_process(delta: float) -> void:
	if missions == null or player == null:
		return
	_track_accum += delta
	if _track_accum >= TRACK_INTERVAL:
		_track_accum = 0.0
		missions.on_player_position(player.global_position)
		missions.tick()
		_check_reckless(TRACK_INTERVAL)
		_check_area()
		_call_crew_if_needed()
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var pad_back := event is InputEventJoypadButton and event.is_action_pressed("ui_cancel")
	if hud.is_menu_open() and (event.is_action_pressed("pause") or pad_back):
		_close_menu()
		get_viewport().set_input_as_handled()
	elif turf_map.visible and (event.is_action_pressed("pause") or event.is_action_pressed("turf_map") or pad_back):
		turf_map.close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("turf_map") and not hud.is_menu_open():
		open_turf_map()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- turf

func open_turf_map() -> void:
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	turf_map.open()


func _on_map_closed() -> void:
	player.input_enabled = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## UI asks; the DistrictManager decides.
func request_unlock(district_id: String) -> bool:
	var ok := districts.unlock_district(district_id)
	if not ok:
		hud.show_message("%s is still locked." % districts.display_name(district_id))
	if turf_map.visible:
		turf_map.refresh()
	return ok


func _on_district_unlocked(district_id: String) -> void:
	if district.set_district_open(district_id, true, true):
		district.rebake_navigation()
	hud.show_banner("%s UNLOCKED" % districts.display_name(district_id).to_upper())
	hud.show_message("The boom gates to %s are up. New turf lies beyond." % districts.display_name(district_id))


## Gates always mirror the saved unlock state (used on start and after loading).
func sync_gates(animate := false) -> void:
	var changed := false
	for d in districts.neighbours():
		changed = district.set_district_open(str(d.id), districts.is_unlocked(str(d.id)), animate) or changed
	if changed:
		district.rebake_navigation()


func _on_interacted(target: Interactable, base_message: String) -> void:
	if target == null:
		return
	var extra := missions.on_interaction(target.kind, target.target)
	if target.kind == "npc":
		var rel := progression.relationship(target.target)
		if rel != 0:
			base_message += "  (%s %+d)" % [_relationship_word(rel), rel]
	var text := base_message if extra.is_empty() else base_message + "\n" + extra
	hud.show_message(text)
	if target.kind == "vehicle" and district.vehicles.has(target.target):
		player.enter_vehicle(district.vehicles[target.target])
	if target.kind == "door" and target.target == SAFEHOUSE_ID:
		open_safehouse_menu()


func _setup_audio() -> void:
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	audio.clock = district.director.clock
	audio.weather = district.weather
	audio.listener_node = player
	district.weather.follow = player
	district.weather.changed.connect(func(k: String):
		if k == "rain":
			hud.show_message("It starts to rain. People hurry indoors."))
	district.door_opened.connect(func(pos: Vector3): audio.play_at("door", pos + Vector3(0, 1, 0), -4.0))
	district.vehicle_horn.connect(func(pos: Vector3): audio.play_at("horn", pos + Vector3(0, 1, 0)))
	player.honked.connect(func(pos: Vector3): audio.play_at("horn", pos + Vector3(0, 1, 0), 2.0))
	player.shouted.connect(func(pos: Vector3): audio.play_at("whistle", pos + Vector3(0, 1.7, 0)))
	district.events.incident_started.connect(func(e: Dictionary):
		if e.kind == "car_alarm":
			audio.play_at("alarm", e.position + Vector3(0, 1, 0), -2.0))
	districts.district_unlocked.connect(func(_id): audio.play_ui("jingle"))
	missions.mission_completed.connect(func(_m, _g): audio.play_ui("jingle", -6.0))
	for car in district.vehicles.values():
		audio.attach_engine(car, -8.0)
	if district.traffic:
		for car in district.traffic.cars:
			audio.attach_engine(car)


## When the tracked objective needs the crew beside the player (a crew hold), every recruit
## who isn't already following is called over (a pending follow entry; recruits at home come out).
func _call_crew_if_needed() -> void:
	var m := missions.tracked_mission()
	if m == null:
		return
	var o := missions.current_objective(m.id)
	if str(o.get("type", "")) != "hold" or not bool(o.get("with_crew", false)):
		return
	for npc_id in progression.recruited_crew_ids:
		var r: Resident = district.residents.get(npc_id)
		if r == null or r.brain.state == NpcBrain.State.FOLLOWING:
			continue
		if r.brain.pending_event.is_empty():
			r.brain.pending_event = {"activity": "follow", "destination": "@leader:player", "duration": 120.0, "event": "crew_call"}
		elif str(r.brain.pending_event.get("event", "")) != "crew_call":
			continue
		# Nudge every check, so a recruit who got home after the call comes straight back out.
		if r.brain.state == NpcBrain.State.AT_HOME:
			r.brain.timer = minf(r.brain.timer, 1.0)
		elif r.brain.state in [NpcBrain.State.AT_DESTINATION, NpcBrain.State.SOCIALIZING, NpcBrain.State.GUARDING]:
			r.brain.timer = 0.0


## Announces district changes as the player crosses into another area.
func _check_area() -> void:
	var a := district.area_at(player.global_position)
	if a.is_empty() or a == current_area:
		return
	current_area = a
	var name_text := districts.display_name(a) if a != "starter" else "Vleirand"
	hud.show_banner(name_text.to_upper(), 3.0)
	hud.set_district_name("%s · %s" % [name_text, districts.state(a)])


func _on_vehicle_changed(car: DrivableCar) -> void:
	if car:
		hud.show_message("You get into %s. W/S drive, A/D steer, Q hoot, E get out." % car.display_name)
		missions.on_vehicle_entered(car.vehicle_id)
	else:
		hud.show_message("You get out.")


## Speeding past people on foot makes them scatter (a severity-2 incident), with a cooldown.
func _check_reckless(dt: float) -> void:
	_reckless_cooldown = maxf(0.0, _reckless_cooldown - dt)
	if not player.is_driving() or _reckless_cooldown > 0.0 or absf(player.vehicle.speed) < 9.0:
		return
	for r: Resident in district.residents.values():
		if not r.is_inside and r.global_position.distance_to(player.vehicle.global_position) < 7.0:
			district.events.raise("reckless_driving", player.vehicle.global_position)
			_reckless_cooldown = 6.0
			return


static func _relationship_word(rel: int) -> String:
	if rel >= 40:
		return "Close friend"
	if rel >= 15:
		return "Friendly"
	if rel >= 0:
		return "Acquaintance"
	return "Wary"


func _on_new_day(day: int) -> void:
	var income := safehouse.daily_income(progression)
	if income > 0:
		progression.add_cash(income)
		hud.show_message("Day %d. Your stash pays out R%d." % [day, income])


# ---------------------------------------------------------------- safehouse menu

func open_safehouse_menu() -> void:
	if audio:
		audio.play_ui("click")
	var items: Array = []
	for u in safehouse.upgrades:
		var id := str(u.id)
		var why := safehouse.why_not(id, progression)
		var label := "%s  —  R%d\n   %s" % [u.name, int(u.cost), u.get("description", "")]
		if progression.safehouse_upgrades.has(id):
			label = "✓ %s (built)" % u.name
		elif not why.is_empty():
			label += "  [%s]" % why
		items.append({"text": label, "disabled": not why.is_empty(), "action": buy_upgrade.bind(id)})
	items.append({"text": "Rest until morning (07:00)", "action": _rest})
	items.append({"text": "Save game", "action": func(): _menu_feedback(save_game())})
	items.append({"text": "Load last save", "disabled": not SaveSystem.exists(save_path),
		"action": _load_from_menu})
	items.append({"text": "Leave", "action": _close_menu})
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.open_menu("SAFEHOUSE — 13 Duif Street   (R%d)" % progression.cash, items)


func buy_upgrade(id: String) -> bool:
	var ok := safehouse.buy(id, progression)
	if ok:
		_show_upgrade(id)
		hud.show_message("Built: %s." % safehouse.by_id[id].name)
	if hud.is_menu_open():
		open_safehouse_menu()
	return ok


func _rest() -> void:
	district.director.clock.skip_to(7.0)
	_close_menu()
	hud.show_message("You sleep until morning. Day %d." % district.director.clock.day)


func _menu_feedback(err: String) -> void:
	hud.show_message("Game saved." if err.is_empty() else "Save failed: " + err)
	open_safehouse_menu()


func _load_from_menu() -> void:
	_close_menu()
	_report_load(load_game())


func _report_load(err: String) -> void:
	hud.show_message("Game loaded." if err.is_empty() else "Load failed: " + err)


func _close_menu() -> void:
	hud.close_menu()
	player.input_enabled = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_upgrade(id: String) -> void:
	var plot: HousePlot = district.plots.get(SAFEHOUSE_ID)
	if plot:
		plot.show_upgrade(id)


# ---------------------------------------------------------------- save / load

func snapshot() -> Dictionary:
	var clock := district.director.clock
	return {
		"clock": {"minutes": clock.minutes, "day": clock.day},
		"player": {"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"yaw": player.pivot.rotation.y},
		"progression": progression.to_dict(),
		"missions": missions.to_dict(),
		"vehicles": _vehicles_snapshot(),
	}


func _vehicles_snapshot() -> Dictionary:
	var out := {}
	for id in district.vehicles:
		var car: DrivableCar = district.vehicles[id]
		out[id] = {"position": [car.global_position.x, car.global_position.y, car.global_position.z], "yaw": car.rotation.y}
	return out


## Returns "" on success, otherwise the error.
func save_game() -> String:
	var err := SaveSystem.write(save_path, snapshot())
	last_save_error = "" if err == OK else error_string(err)
	return last_save_error


## Validates everything before applying anything; on failure the current game is untouched.
func load_game() -> String:
	var res := SaveSystem.read(save_path)
	if not res.ok:
		return res.error
	return apply_snapshot(res.data)


func apply_snapshot(data: Dictionary) -> String:
	var c: Variant = data.get("clock")
	var pl: Variant = data.get("player")
	if not c is Dictionary or not (c.get("minutes") is float or c.get("minutes") is int):
		return "clock section missing"
	if not pl is Dictionary or not pl.get("position") is Array or pl.position.size() != 3:
		return "player section missing"
	var test_progress := ProgressionState.new()
	var err := test_progress.load_dict(data.get("progression"))
	if not err.is_empty():
		return err
	var test_missions := MissionManager.new()
	var catalog: Array[MissionData] = []
	catalog.assign(missions.catalog.values())
	test_missions.setup(catalog, test_progress, district.director.clock)
	err = test_missions.load_dict(data.get("missions"))
	test_missions.free()
	if not err.is_empty():
		return err
	# Everything validated: apply.
	if player.is_driving():
		player.exit_vehicle()
	var vehicles: Variant = data.get("vehicles", {})
	if vehicles is Dictionary:
		for id in vehicles:
			var car: DrivableCar = district.vehicles.get(id)
			var v: Variant = vehicles[id]
			if car and v is Dictionary and v.get("position") is Array and v.position.size() == 3:
				car.global_position = Vector3(float(v.position[0]), float(v.position[1]) + 0.05, float(v.position[2]))
				car.rotation.y = float(v.get("yaw", 0.0))
				car.speed = 0.0
				car.reset_physics_interpolation()
	progression.load_dict(data.progression)
	missions.load_dict(data.missions)
	var clock := district.director.clock
	clock.minutes = clampf(float(c.minutes), 0.0, 1439.9)
	clock.day = maxi(1, int(c.get("day", 1)))
	var p: Array = pl.position
	player.global_position = Vector3(float(p[0]), float(p[1]) + 0.05, float(p[2]))
	player.velocity = Vector3.ZERO
	player.pivot.rotation.y = float(pl.get("yaw", 0.0))
	player.snap_camera()
	for npc_id in progression.recruited_crew_ids:
		district.apply_recruit(npc_id, SAFEHOUSE_ID)
	for id in progression.safehouse_upgrades:
		_show_upgrade(id)
	sync_gates()
	hud.set_stats(progression)
	_refresh()
	return ""


# ---------------------------------------------------------------- markers & tracker

func _build_beacon() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.35
	mesh.bottom_radius = 0.35
	mesh.height = 30.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.84, 0.37, 0.35)
	_beacon = MeshInstance3D.new()
	_beacon.mesh = mesh
	_beacon.material_override = mat
	_beacon.visible = false
	district.add_child(_beacon)


## Objective target position (for the beacon and distance), or null for non-spatial objectives.
func objective_target(mission_id: String) -> Variant:
	var o := missions.current_objective(mission_id)
	match str(o.get("type", "")):
		"talk_to":
			var r: Resident = district.residents.get(str(o.target))
			if r == null:
				return null
			if r.is_inside:
				return district.destinations.anchor_position(r.data.home_id + ":door")
			return r.global_position
		"knock":
			return district.anchor_or_null(str(o.target) + ":door")
		"visit":
			return district.anchor_or_null(str(o.target))
	return null


func _refresh() -> void:
	# Givers with something for you get "!"; the current talk target gets "▼".
	var tracked := missions.tracked_mission()
	var target_npc := ""
	if tracked:
		var o := missions.current_objective(tracked.id)
		if str(o.get("type", "")) == "talk_to":
			target_npc = str(o.target)
	for r: Resident in district.residents.values():
		if r.data.id == target_npc:
			r.set_marker("▼")
		elif missions.available_from(r.data.id) != null:
			r.set_marker("!")
		else:
			r.set_marker("")
	if tracked == null:
		_beacon.visible = false
		hud.set_tracker(_next_hint())
		return
	var target: Variant = objective_target(tracked.id)
	var dist := ""
	if target != null:
		dist = "  (%d m)" % int(Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length())
	var npc_target: bool = not target_npc.is_empty() and district.residents.has(target_npc) and not district.residents[target_npc].is_inside
	_beacon.visible = target != null and not npc_target
	if _beacon.visible:
		_beacon.global_position = Vector3(target.x, 15.0, target.z)
	hud.set_tracker("▶ %s\n   %s%s" % [tracked.title.to_upper(), missions.objective_text(tracked.id), dist])


func _next_hint() -> String:
	for id in missions.order:
		if missions.is_available(id):
			var m := missions.get_mission(id)
			var info := district.resident_info(m.giver)
			return "Next: %s has a job for you (look for \"!\")" % info.get("name", m.giver)
	for id in missions.order:
		if not missions.is_completed(id):
			return "Next: %s — %s" % [missions.get_mission(id).title, ", ".join(missions.missing_requirements(id))]
	return "All missions done. More turf arrives in Phase 7."
