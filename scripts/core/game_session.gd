class_name GameSession
extends Node
## Gameplay services for one play session: progression, missions, safehouse, save/load.
## Wires them to the district (world queries, recruits, upgrade props), the player
## (interactions, position) and the HUD (stats, tracker, menus, markers).

const MISSIONS_FILE := "res://data/missions/intro.json"
const CREW_MISSIONS_FILE := "res://data/missions/crews.json"
const DEALING_MISSIONS_FILE := "res://data/missions/dealing.json"
const STORY_MISSIONS_FILE := "res://data/missions/story.json"
const LIFE_MISSIONS_FILE := "res://data/missions/life.json"
const STORY_SCENES_FILE := "res://data/story/scenes.json"
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
var police: PoliceDispatch
var crew_picker: CrewPicker
var dealing: DealingController
var phone: Phone
var interiors: InteriorSystem
var turf: TurfWar
var story_scenes: Dictionary = {}
var last_save_error := ""

var _track_accum := 0.0
var _reckless_cooldown := 0.0
var current_area := "starter"
var _beacon: MeshInstance3D


## Missions from every district in the catalog (`missions` field), starter first.
static func _load_all_missions() -> Array[MissionData]:
	var out: Array[MissionData] = []
	var catalog: Variant = DataFiles.load_json("res://data/districts/districts.json")
	var files: PackedStringArray = [MISSIONS_FILE, CREW_MISSIONS_FILE, DEALING_MISSIONS_FILE, STORY_MISSIONS_FILE, LIFE_MISSIONS_FILE]
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
	missions.npc_position = func(id: String) -> Variant:
		var r: Resident = district.residents.get(id)
		return r.global_position if r and is_instance_valid(r) else null
	missions.objective_started.connect(_on_objective_started)
	Resident.standing = func(npc_id: String) -> Dictionary:
		return {"rep": progression.reputation, "rel": progression.relationship(npc_id), "heat": police.heat.level() if police else 0}
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
	police = PoliceDispatch.new()
	police.name = "PoliceDispatch"
	add_child(police)
	police.setup(district, player, progression, SAFEHOUSE_ID)
	police.audio = audio
	police.player_knocked_out.connect(func(): hud.show_banner("KNOCKED OUT", 4.0))
	police.player_woke.connect(func(): hud.show_message("You come round at the safehouse. Someone fined you R%d." % PoliceDispatch.FINE))
	dealing = DealingController.new()
	dealing.name = "Dealing"
	add_child(dealing)
	dealing.setup(district, player, progression, missions, police)
	interiors = InteriorSystem.new()
	interiors.name = "Interiors"
	add_child(interiors)
	interiors.setup(self, district, player, self)
	district.interiors = interiors
	interiors.entered.connect(func(_id): if audio: audio.play_ui("click"))
	turf = TurfWar.new()
	turf.name = "TurfWar"
	add_child(turf)
	turf.setup(district, player, progression, police, dealing, interiors)
	turf.message.connect(_on_turf_message)
	# Story: "corners" counts for stat objectives too; dialogue scenes with choices.
	missions.stat_value = func(name: String) -> int:
		return turf.state.players_corners().size() if name == "corners" else dealing.state.stat(name)
	var raw: Variant = DataFiles.load_json(STORY_SCENES_FILE)
	story_scenes = raw.get("scenes", {}) if raw is Dictionary else {}
	missions.dialogue_requested.connect(open_dialogue)
	_apply_story_state()
	_setup_street_sound()
	turf_map.turf = turf
	dealing.turf = turf
	dealing.message.connect(hud.show_message)
	phone = Phone.new()
	phone.name = "Phone"
	hud.add_child(phone)
	phone.setup(dealing)
	phone.closed.connect(func():
		player.input_enabled = true
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	dealing.ringing.connect(func(c: Dictionary):
		if audio:
			audio.play_at("ring", player.global_position + Vector3(0, 1.2, 0), 0.0)
		player.rumble(0.3, 0.0, 0.4))
	dealing.state.order_changed.connect(phone.refresh)
	dealing.state.client_changed.connect(func(_id: String): phone.refresh())
	police.heat.changed.connect(func(level: int):
		if level > 0:
			hud.show_message("Police heat %s" % "★".repeat(level)))
	hud.set_stats(progression)


## Joins a crew (new game) or re-applies the crew after loading. One-off perk rewards are granted
## once (ProgressionState.grant); ongoing perks are re-applied every time.
func choose_crew(crew_id: String) -> bool:
	var crews := district.crews
	if not crews.has(crew_id):
		return false
	var first := progression.crew_id.is_empty()
	progression.crew_id = crew_id
	district.set_player_crew(crew_id)
	districts.crew_home = crews.home(crew_id)
	player.wear_colours(crews.colour(crew_id), crews.colour(crew_id).darkened(0.3), crew_id)
	# Ongoing perks start from neutral, so only the chosen crew's applies.
	police.heat.gain_mult = 1.0
	progression.cash_bonus = 1.0
	if crews.perk(crew_id) != "stone_hard" and player.weapons.has("shotgun"):
		player.weapons.remove_at(player.weapons.find("shotgun"))
		if player.weapon == "shotgun":
			player.weapon = "pistol"
			player.model.set_weapon("pistol")
	match crews.perk(crew_id):
		"home_turf":
			progression.grant("crew_perk:home_turf", {"cash": 150, "influence": {"starter": 15}})
		"low_profile":
			police.heat.gain_mult = 0.6
		"quick_hands":
			progression.cash_bonus = 1.25
		"stone_hard":
			player.add_weapon("shotgun")
	if first:
		hud.show_banner(crews.display_name(crew_id).to_upper(), 4.0)
		hud.show_message("You run with the %s now. %s" % [crews.display_name(crew_id), str(crews.get_crew(crew_id).get("perk_text", ""))])
	progression.changed.emit()
	missions.check_auto_start()
	if turf:
		turf.state.player_crew = crew_id
		turf._refresh_tags()
		turf._refresh_flags()
	_refresh()
	return true


## Opens the crew choice (new game, or a save from before crews existed).
func open_crew_picker() -> void:
	if crew_picker == null:
		crew_picker = CrewPicker.new()
		crew_picker.name = "CrewPicker"
		hud.add_child(crew_picker)
		crew_picker.chosen.connect(func(id: String):
			crew_picker.close()
			player.input_enabled = true
			if DisplayServer.get_name() != "headless":
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			choose_crew(id))
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crew_picker.open(district.crews, district)


## Call once the district's navigation and residents are ready.
func begin(load_save: bool) -> void:
	if load_save and SaveSystem.exists(save_path):
		var err := load_game()
		if not err.is_empty():
			hud.show_message("Couldn't load your save (%s). Starting a new game." % err)
	missions.check_auto_start()
	sync_gates()
	if not progression.crew_id.is_empty():
		choose_crew(progression.crew_id)
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


func toggle_phone() -> void:
	if phone.is_open():
		phone.close()
		return
	if hud.is_menu_open() or turf_map.visible or (crew_picker and crew_picker.visible) or player.is_down():
		return
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	phone.open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radio") and player.is_driving():
		hud.show_message(audio.next_station())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("phone"):
		toggle_phone()
		get_viewport().set_input_as_handled()
		return
	if phone and phone.is_open() and (event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"))):
		phone.close()
		get_viewport().set_input_as_handled()
		return
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
	if target.kind == "npc" and dealing.handles(target.target):
		hud.show_message(dealing.try_sell(target.target))
		return
	var extra := missions.on_interaction(target.kind, target.target)
	if target.kind == "npc":
		var contact := dealing.on_chat(target.target)
		if not contact.is_empty():
			extra = contact if extra.is_empty() else extra + "\n" + contact
	if target.kind == "npc":
		var rel := progression.relationship(target.target)
		if rel != 0:
			base_message += "  (%s %+d)" % [_relationship_word(rel), rel]
	var text := base_message if extra.is_empty() else base_message + "\n" + extra
	hud.show_message(text)
	if target.kind == "vehicle" and district.vehicles.has(target.target):
		player.enter_vehicle(district.vehicles[target.target])
	if target.kind == "door" and (target.target == SAFEHOUSE_ID or dealing.is_venue(target.target) or interiors.is_landmark(target.target) \
			or district.enter_request == target.target):
		district.enter_request = ""
		var why := interiors.enter(target.target)
		if not why.is_empty():
			hud.show_message(why)


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
	district.combat.shot_fired.connect(func(_s: Node3D, origin: Vector3, weapon: String):
		audio.play_at("gunshot", origin, 2.0, float(WeaponLibrary.stats(weapon).get("sound_pitch", 1.0))))
	district.dog_barked.connect(func(pos: Vector3, pitch: float): audio.play_at("bark", pos, -2.0, pitch))
	player.honked.connect(func(pos: Vector3): audio.play_at("horn", pos + Vector3(0, 1, 0), 2.0))
	player.shouted.connect(func(pos: Vector3): audio.play_at("whistle", pos + Vector3(0, 1.7, 0)))
	district.events.incident_started.connect(func(e: Dictionary):
		if e.kind == "car_alarm":
			audio.play_at("alarm", e.position + Vector3(0, 1, 0), -2.0))
	districts.district_unlocked.connect(func(_id): audio.play_ui("jingle"))
	missions.mission_completed.connect(func(_m, _g):
		audio.play_ui("jingle", -6.0)
		autosave.call_deferred("mission done"))
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
	var name_text := districts.display_name(a) if a != "starter" else "Westridge"
	hud.show_banner(name_text.to_upper(), 3.0)
	hud.set_district_name("%s · %s" % [name_text, districts.state(a)])


func _on_vehicle_changed(car: DrivableCar) -> void:
	audio.set_driving(car != null)
	if car:
		hud.show_message("You get into %s. W/S drive, A/D steer, Q hoot, E get out, %s radio." % [car.display_name, InputHints.key("radio")])
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
	autosave.call_deferred("new day")
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
	var rc: Dictionary = dealing.state.cfg.get("runner", {})
	items.append({"text": "Hire a runner — R%d  (you have %d; they take phone orders for a cut)" % [int(rc.get("hire_cost", 200)), dealing.state.runners],
		"action": func():
			var why := dealing.hire_runner()
			hud.show_message(why if not why.is_empty() else "You've got a runner now. Send them from your phone's Orders.")
			open_safehouse_menu()})
	for r in dealing.restock_items():
		var idx: int = r.index
		items.append({"text": "%s   (have %d bankies, %d drinks)" % [r.label, int(dealing.state.stock.weed), int(dealing.state.stock.drink)],
			"disabled": progression.cash < int(r.cost),
			"action": func():
				hud.show_message(("Ordered. Pick it up at %s in about %d minutes." % [district.destinations.display_name(dealing.drop_anchor()),
					int(dealing.state.cfg.get("drops", {}).get("ready_minutes", 20))]) if dealing.buy_stock(idx) else "You can't afford that.")
				open_safehouse_menu()})
	items.append({"text": "Rest until morning (07:00)", "action": _rest})
	items.append({"text": "Save game", "action": func(): _menu_feedback(save_game())})
	items.append({"text": "Load last save", "disabled": not SaveSystem.exists(save_path),
		"action": _load_from_menu})
	items.append({"text": "Leave", "action": _close_menu})
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.open_menu("SAFEHOUSE — 13 AZ Berman Drive   (R%d)" % progression.cash, items)


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

# ---------------------------------------------------------------- story dialogue

## Shows a story scene: who's talking, what they say, and the choices. Picking one applies its
## effects (cash, reputation, relationships, influence, flags, turf) and finishes the objective.
func open_dialogue(mission_id: String, scene_id: String, _npc_id := "") -> void:
	var scene: Dictionary = story_scenes.get(scene_id, {})
	if scene.is_empty():
		missions.finish_dialogue(mission_id)
		return
	var lines: Array = scene.get("lines", [])
	var title := "%s:\n%s" % [str(scene.get("speaker", "")), "\n".join(lines.map(func(l): return "\"%s\"" % l))]
	var items: Array = []
	for c in scene.get("choices", []):
		var choice: Dictionary = c
		items.append({"text": str(choice.text), "action": func(): choose(mission_id, choice)})
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.open_menu(title, items)


func choose(mission_id: String, choice: Dictionary) -> void:
	_close_menu()
	apply_effects(choice.get("effects", {}))
	if choice.has("reply"):
		hud.show_message(str(choice.reply))
	missions.finish_dialogue(mission_id)


## A "follow" objective: the person sets off for their destination now.
func _on_objective_started(_mission_id: String, o: Dictionary) -> void:
	if str(o.get("type", "")) != "follow":
		return
	var r: Resident = district.residents.get(str(o.target))
	if r == null or not district.destinations.has(str(o.destination)):
		return
	r.brain.pending_event = {"activity": str(o.get("activity", "waiting")), "destination": str(o.destination),
		"duration": float(o.get("stay", 25.0)), "event": "mission"}
	if r.brain.state == NpcBrain.State.AT_HOME:
		r.brain.timer = minf(r.brain.timer, 1.0)
	elif r.brain.state in [NpcBrain.State.AT_DESTINATION, NpcBrain.State.SOCIALIZING, NpcBrain.State.GUARDING]:
		r.brain.timer = 0.0


func apply_effects(e: Dictionary) -> void:
	progression.add_cash(int(e.get("cash", 0)))
	progression.add_reputation(int(e.get("reputation", 0)))
	progression.add_crew_influence(int(e.get("crew_influence", 0)))
	var rel: Dictionary = e.get("relationship", {})
	for npc in rel:
		progression.add_relationship(str(npc), int(rel[npc]))
	var infl: Dictionary = e.get("influence", {})
	for d in infl:
		progression.add_district_influence(str(d), int(infl[d]))
	for f in e.get("flags", []):
		progression.flags[str(f)] = true
	var give: Dictionary = e.get("turf_give", {})
	for corner in give:
		if turf.state.corners.has(corner):
			var to := progression.crew_id if str(give[corner]) == "player" else str(give[corner])
			turf.state.corners[corner].owner = to
			turf.state.corners[corner].control = 60.0
	if e.has("turf_ally"):
		progression.flags["ally:" + str(e.turf_ally)] = true
		progression.flags.erase("retaliate:" + str(e.turf_ally))   # allies don't hold grudges
	for crew in e.get("turf_allies", []):
		progression.flags["ally:" + str(crew)] = true
		progression.flags.erase("retaliate:" + str(crew))
	if bool(e.get("turf_release", false)):   # walk away: every corner you hold goes back to nobody
		for id in turf.state.players_corners():
			turf.state.corners[id].owner = ""
			turf.state.corners[id].control = 50.0
	if e.has("banner"):
		hud.show_banner(str(e.banner), 6.0)
	var grudge: Dictionary = e.get("retaliation", {})
	if not grudge.is_empty() and not turf.allies.has(str(grudge.get("crew", ""))):
		progression.flags["retaliate:" + str(grudge.crew)] = turf.minutes() + float(grudge.get("minutes", 300))
	_apply_story_state()
	turf._refresh_tags()
	turf._refresh_flags()
	progression.changed.emit()
	missions.check_auto_start()


## Story choices that keep shaping the world: allied crews never push on your corners.
func _apply_story_state() -> void:
	turf.allies = []
	for f in progression.flags:
		if str(f).begins_with("ally:"):
			turf.allies.append(str(f).trim_prefix("ally:"))


## Where the town makes noise: ranks (hooters), the market (callers), church halls (bells),
## the smokkies (music on smokkie nights); voices for whoever talks; music inside smokkies.
func _setup_street_sound() -> void:
	var dest := district.destinations
	for id in ["rooi_taxi", "tc_taxi", "taf_taxi"]:
		if dest.has(id):
			audio.ranks.append(dest.anchor_position(id))
	if dest.has("tc_market"):
		audio.markets.append(dest.anchor_position("tc_market"))
	if dest.has("kalk_hall"):
		audio.churches.append(dest.anchor_position("kalk_hall"))
	for id in dealing.venues:
		var crowd := str(dealing.venues[id].get("crowd", ""))
		if dest.has(crowd):
			audio.add_venue(dest.anchor_position(crowd), Vector2(17, 23))
	audio.calendar = district.director.calendar
	if dest.has("poi_park"):   # the Tweede Nuwe Jaar parade: ghoema drum and brass at the park
		audio.add_venue(dest.anchor_position("poi_park"), Vector2(0, 24), "music_ghoema", "klopse_parade")
	Resident.on_say = func(pos: Vector3, seed: int, female: bool): audio.voice(pos, seed, female)
	interiors.entered.connect(func(id): audio.set_inside_music(dealing.is_venue(id)))
	interiors.left.connect(func(_id): audio.set_inside_music(false))


func _on_turf_message(text: String) -> void:
	if text.begins_with("CORNER TAKEN") or text.begins_with("LOST"):
		hud.show_banner(text.get_slice(":", 0) if text.begins_with("CORNER") else "CORNER LOST", 3.0)
	elif text.contains("moving on"):
		hud.show_banner("TURF UNDER PRESSURE", 3.0)
		if audio:
			audio.play_ui("ring")
	hud.show_message(text)
	missions._check_stat_objectives()


## Indoors, the save puts you back outside the door.
func _saved_player_position() -> Array:
	var p := interiors.outside_position() if interiors and interiors.is_inside() else player.global_position
	return [p.x, p.y, p.z]


func snapshot() -> Dictionary:
	var clock := district.director.clock
	return {
		"clock": {"minutes": clock.minutes, "day": clock.day},
		"player": {"position": _saved_player_position(),
			"yaw": player.pivot.rotation.y},
		"progression": progression.to_dict(),
		"missions": missions.to_dict(),
		"vehicles": _vehicles_snapshot(),
		"dealing": dealing.state.to_dict(),
		"turf": turf.state.to_dict(),
	}


func _vehicles_snapshot() -> Dictionary:
	var out := {}
	for id in district.vehicles:
		var car: DrivableCar = district.vehicles[id]
		out[id] = {"position": [car.global_position.x, car.global_position.y, car.global_position.z], "yaw": car.rotation.y}
	return out


## Autosave after a mission and at each new day. The settings switch it off; tests turn it off
## so a save they made on purpose is never overwritten behind their back.
var autosave_enabled := true
var autosave_user := true   # the player's setting (Main copies it here)
var autosaves := 0


func autosave(reason: String) -> void:
	if not autosave_enabled or not autosave_user or player == null or player.is_down() or crew_picker != null and crew_picker.visible:
		return
	if progression.crew_id.is_empty():
		return
	if save_game().is_empty():
		autosaves += 1
		hud.show_message("Autosaved (%s)." % reason)


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
	var current_crew := progression.crew_id
	var err := apply_snapshot(res.data)
	if err.is_empty():
		# Saves from before crews existed keep the crew you're in (or ask, if you have none yet).
		if progression.crew_id.is_empty():
			progression.crew_id = current_crew
		if not progression.crew_id.is_empty():
			choose_crew(progression.crew_id)
		elif missions != null and police != null and is_inside_tree() and crew_picker == null:
			open_crew_picker.call_deferred()
	return err


func apply_snapshot(data: Dictionary) -> String:
	if interiors:
		interiors.discard()
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
	if data.get("dealing") is Dictionary:
		dealing.state.load_dict(data.dealing)
	if data.get("turf") is Dictionary:
		turf.state.load_dict(data.turf)
		turf._refresh_tags()
		turf._refresh_flags()
	_apply_story_state()
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
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 30.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.84, 0.37, 0.35)
	# Readable from across the neighbourhood, but it fades away up close instead of filling the screen.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 6.0
	mat.distance_fade_max_distance = 28.0
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
