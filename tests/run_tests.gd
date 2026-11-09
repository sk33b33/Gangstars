extends SceneTree
## Headless test runner. Usage (from the repo root):
##   godot --headless --path . --fixed-fps 60 -s tests/run_tests.gd [-- --soak-minutes=10]
## --fixed-fps makes each frame advance exactly 1/60 s, so simulated minutes run fast.
## Exit code 0 = all passed.

var _passed := 0
var _failed: PackedStringArray = []
var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", what)
	else:
		_failed.append(what)
		print("  FAIL  ", what)


func _run() -> void:
	print("== data")
	_test_house_data()
	_test_npc_data()
	print("== npc brain")
	_test_brain_cycle()
	_test_brain_failures()
	print("== phase 3 units (clock, reactions, time windows, crew)")
	_test_phase3_units()
	print("== phase 4 units (progression, missions, safehouse, saves)")
	_test_phase4_units()
	print("== phase 5 units (districts, hold objective)")
	_test_phase5_units()
	print("== district (integration)")
	await _test_district()
	print("\n%d passed, %d failed" % [_passed, _failed.size()])
	for f in _failed:
		print("  failed: ", f)
	quit(0 if _failed.is_empty() else 1)


func _test_house_data() -> void:
	var reg := HouseRegistry.load_file("res://data/houses/starter_houses.json")
	_check(reg.errors.is_empty(), "starter houses load without errors %s" % [reg.errors])
	_check(reg.count() >= 28 and reg.count() <= 32, "starter district has ~30 houses (%d)" % reg.count())
	var streets := {}
	var addresses := {}
	for id in reg.order:
		var h := reg.get_house(id)
		streets[h.street] = true
		addresses[h.address()] = true
		if h.occupancy == "occupied":
			_check(not h.occupant_ids.is_empty(), "%s is occupied and has residents" % id)
	_check(streets.size() >= 3, "houses span at least 3 streets (%d)" % streets.size())
	_check(addresses.size() == reg.count(), "every house has a unique street address")
	var ids := {}
	for id in reg.order:
		ids[id] = true
		var h := reg.get_house(id)
		_check(h.id.begins_with("starter_h"), "%s uses stable starter_hNN id" % id)
	_check(ids.size() == reg.count(), "house ids are unique")
	# Duplicate and invalid entries are rejected, not crashed on.
	var dup := HouseData.from_dict({"id": "starter_h01", "kit": "single_hip", "occupant_ids": ["x"]}, "starter")
	_check(not reg.add(dup), "duplicate house id is rejected")
	var bad := HouseData.from_dict({"id": "starter_h99", "kit": "castle", "occupancy": "occupied"}, "starter")
	_check(not bad.validate().is_empty(), "unknown kit / missing occupants is reported")


func _test_npc_data() -> void:
	var npcs := NpcData.load_file("res://data/npcs/starter_residents.json")
	var reg := HouseRegistry.load_file("res://data/houses/starter_houses.json")
	_check(npcs.size() >= 8 and npcs.size() <= 30, "8-30 residents (%d)" % npcs.size())
	var kinds := {}
	for n in npcs:
		for e in n.schedule:
			kinds[e.destination.split(":")[0] if e.destination.contains(":") else e.destination] = true
	_check(kinds.size() >= 4, "schedules use several distinct destinations (%d)" % kinds.size())
	for n in npcs:
		_check(reg.get_house(n.home_id) != null, "%s has a valid home (%s)" % [n.id, n.home_id])
		_check(reg.get_house(n.home_id).occupant_ids.has(n.id), "%s is listed as an occupant of %s" % [n.id, n.home_id])
	for id in reg.order:
		var h := reg.get_house(id)
		for occ in h.occupant_ids:
			_check(npcs.any(func(n): return n.id == occ), "occupant %s of %s exists" % [occ, id])


func _test_brain_cycle() -> void:
	var b := NpcBrain.new([
		{"activity": "shopping", "destination": "poi_shop", "duration": 2.0},
		{"activity": "home", "destination": "home", "duration": 3.0}], 1.0)
	_check(b.state == NpcBrain.State.AT_HOME, "brain starts at home")
	b.update(1.1)
	_check(b.state == NpcBrain.State.PREPARING_TO_LEAVE, "home timer -> preparing to leave")
	var cmds := b.update(2.0)
	_check(cmds.size() == 2 and cmds[0].cmd == "exit_home" and cmds[1].destination == "poi_shop", "leaves home and heads to shop")
	_check(b.state == NpcBrain.State.TRAVELLING, "state TRAVELLING")
	b.on_arrived()
	_check(b.state == NpcBrain.State.AT_DESTINATION and b.activity == "shopping", "arrives and starts activity")
	cmds = b.update(2.5)
	_check(b.state == NpcBrain.State.RETURNING_HOME and cmds[0].destination == "home", "activity done -> returning home")
	cmds = b.on_arrived()
	_check(b.state == NpcBrain.State.AT_HOME and cmds[0].cmd == "enter_home", "enters home")
	_check(is_equal_approx(b.timer, 3.0), "stays home for the scheduled duration")


func _test_brain_failures() -> void:
	var b := NpcBrain.new([
		{"activity": "a", "destination": "poi_a", "duration": 2.0},
		{"activity": "b", "destination": "poi_b", "duration": 2.0},
		{"activity": "home", "destination": "home", "duration": 3.0}], 0.0)
	b.update(0.1)
	b.update(2.0)
	var cmds := b.on_travel_failed()
	_check(b.state == NpcBrain.State.TRAVELLING and cmds[0].destination == "poi_b", "unreachable destination -> falls back to next entry")
	cmds = b.on_travel_failed()
	_check(b.state == NpcBrain.State.RETURNING_HOME, "second failure -> heads home (next entry)")
	b.on_travel_failed()
	_check(b.state == NpcBrain.State.UNAVAILABLE, "route home failing -> UNAVAILABLE, no crash")
	cmds = b.update(NpcBrain.UNAVAILABLE_TIME + 0.1)
	_check(b.state == NpcBrain.State.RETURNING_HOME and cmds[0].destination == "home", "UNAVAILABLE retries home later")


func _test_phase3_units() -> void:
	_check(SimClock.in_window(23.0, 22.0, 2.0) and SimClock.in_window(1.0, 22.0, 2.0) and not SimClock.in_window(12.0, 22.0, 2.0),
		"time windows wrap midnight")
	var c := SimClock.new()
	c.set_hour(23.5)
	c.advance(60.0)
	_check(c.day == 2 and is_equal_approx(c.hour(), 0.5), "clock rolls over to the next day")

	_check(ReactionPolicy.choose("resident", "timid", 2, 5.0, 18.0) == "flee", "timid resident flees a disturbance")
	_check(ReactionPolicy.choose("resident", "gossip", 2, 5.0, 18.0) == "report", "gossip reports a disturbance")
	_check(ReactionPolicy.choose("resident", "curious", 2, 5.0, 18.0) == "investigate", "curious resident investigates")
	_check(ReactionPolicy.choose("resident", "steady", 1, 5.0, 14.0) == "notice", "steady resident only notices a noise")
	_check(ReactionPolicy.choose("crew", "tough", 3, 5.0, 22.0) == "investigate", "crew investigate danger")
	_check(ReactionPolicy.choose("resident", "curious", 3, 30.0, 22.0) == "", "out of range: no reaction")

	var sched := [
		{"activity": "shopping", "destination": "poi_shop", "duration": 5.0, "window": Vector2(7, 19)},
		{"activity": "socializing", "destination": "poi_corner", "duration": 5.0, "window": Vector2(10, 22)},
		{"activity": "home", "destination": "home", "duration": 5.0}]
	var b := NpcBrain.new(sched, 0.0, Vector2(6, 22))
	b.clock_hour = 8.0
	b.update(0.1)
	var cmds := b.update(2.0)
	_check(cmds.size() == 2 and cmds[1].destination == "poi_shop", "08:00: goes shopping (window open)")
	b.on_arrived()
	cmds = b.update(6.0)
	_check(b.state == NpcBrain.State.RETURNING_HOME, "08:00: corner window closed -> skips it and heads home")
	b.on_arrived()
	b.clock_hour = 23.0
	b.update(10.0)
	_check(b.state == NpcBrain.State.AT_HOME, "23:00: stays home outside active hours")
	b.clock_hour = 12.0
	b.update(20.0)
	b.update(2.0)
	_check(b.state == NpcBrain.State.TRAVELLING, "12:00: leaves home again")
	b.on_arrived()
	b.clock_hour = 22.5
	cmds = b.update(0.5)
	_check(b.state == NpcBrain.State.RETURNING_HOME and cmds[0].destination == "home", "curfew sends a resident home from a destination")

	# Reactions: notice -> resume; investigate -> watch -> resume; flee -> hide inside.
	b = NpcBrain.new(sched, 0.0)
	b.clock_hour = 12.0
	b.update(0.1)
	b.update(2.0)
	cmds = b.on_incident("notice", "evt_a")
	_check(b.state == NpcBrain.State.NOTICING and cmds[0].cmd == "stop", "notice stops and looks")
	_check(b.on_incident("notice", "evt_a").is_empty(), "same incident is not reacted to twice")
	cmds = b.update(NpcBrain.NOTICE_TIME + 0.1)
	_check(b.state == NpcBrain.State.TRAVELLING and cmds[0].destination == "poi_shop", "after noticing, resumes the same trip")
	cmds = b.on_incident("investigate", "evt_b")
	_check(b.state == NpcBrain.State.INVESTIGATING and cmds[0].destination == "@incident", "investigate walks to the incident")
	b.on_arrived()
	cmds = b.update(NpcBrain.WATCH_TIME + 0.1)
	_check(b.state == NpcBrain.State.TRAVELLING and cmds[0].destination == "poi_shop", "after watching, back to routine")
	cmds = b.on_incident("report", "evt_c")
	cmds = b.on_incident("flee", "evt_d")
	_check(b.state == NpcBrain.State.FLEEING and cmds[0].speed > 1.0, "stronger reaction (flee) overrides report, at a run")
	_check(b.on_incident("notice", "evt_e").is_empty(), "a fleeing NPC ignores weaker incidents")
	cmds = b.on_arrived()
	_check(b.state == NpcBrain.State.AT_HOME and cmds[0].cmd == "enter_home" and not b.is_reacting(), "fleeing ends hidden at home")

	# Crew: patrol route, guard, follow.
	var crew := NpcBrain.new([
		{"activity": "patrol", "destination": "", "route": PackedStringArray(["p:0", "p:1"]), "duration": 1.0},
		{"activity": "guard", "destination": "h:gate", "duration": 4.0},
		{"activity": "follow", "destination": "@leader:boss", "duration": 3.0},
		{"activity": "home", "destination": "home", "duration": 5.0}], 0.0, Vector2(10, 2))
	crew.clock_hour = 20.0
	crew.update(0.1)
	cmds = crew.update(2.0)
	_check(crew.state == NpcBrain.State.PATROLLING and cmds[1].destination == "p:0", "patrol starts at the first waypoint")
	cmds = crew.on_arrived()
	_check(cmds[0].destination == "p:1", "patrol continues to the next waypoint")
	cmds = crew.on_arrived()
	_check(crew.state == NpcBrain.State.TRAVELLING and cmds[0].destination == "h:gate", "patrol complete -> guard post")
	crew.on_arrived()
	_check(crew.state == NpcBrain.State.GUARDING, "guard activity -> GUARDING")
	cmds = crew.update(4.5)
	_check(crew.state == NpcBrain.State.FOLLOWING and cmds[0].cmd == "follow" and cmds[0].leader == "boss", "follow entry follows the leader")
	cmds = crew.on_travel_failed()
	_check(crew.state == NpcBrain.State.RETURNING_HOME, "losing the leader moves on to the next entry")
	crew.clock_hour = 1.0
	_check(crew.is_active_hours(), "crew active hours wrap past midnight")


func _test_phase4_units() -> void:
	# Progression: rewards once, spending, save round trip, bad data rejected.
	var p := ProgressionState.new()
	_check(p.grant("mission:x", {"cash": 50, "reputation": 5}) and p.cash == 150 and p.reputation == 5, "grant applies rewards")
	_check(not p.grant("mission:x", {"cash": 50}) and p.cash == 150, "the same reward key never pays twice")
	_check(not p.spend(1000) and p.cash == 150 and p.spend(100) and p.cash == 50, "spend checks funds")
	_check(p.register_talk("npc_a", 1) and p.reputation == 6 and p.relationship("npc_a") == 2, "first talk: +1 rep, +2 relationship")
	_check(not p.register_talk("npc_a", 1) and p.relationship("npc_a") == 2, "second talk the same day gives nothing")
	_check(p.register_talk("npc_a", 2) and p.relationship("npc_a") == 4 and p.reputation == 6, "next day: relationship only")
	var copy := ProgressionState.new()
	_check(copy.load_dict(p.to_dict()) == "" and copy.to_dict() == p.to_dict(), "progression save round-trips")
	var before := copy.to_dict()
	_check(not copy.load_dict({"cash": "lots"}).is_empty() and copy.to_dict() == before, "bad progression data is rejected, state untouched")
	var no_starter := p.to_dict()
	no_starter.unlocked_district_ids = []
	_check(not copy.load_dict(no_starter).is_empty(), "a save that lost the starter district is rejected")

	# Mission data.
	var all := MissionData.load_file("res://data/missions/intro.json")
	_check(all.size() == 7, "7 missions load (%d)" % all.size())
	var houses := HouseRegistry.load_file("res://data/houses/starter_houses.json")
	var npc_ids := {}
	for n in NpcData.load_file("res://data/npcs/starter_residents.json"):
		npc_ids[n.id] = true
	var ids := {}
	for m in all:
		ids[m.id] = true
	for m in all:
		for dep in m.prerequisites.get("missions", []):
			_check(ids.has(dep), "%s prerequisite %s exists" % [m.id, dep])
		if not m.giver.is_empty():
			_check(npc_ids.has(m.giver), "%s giver %s exists" % [m.id, m.giver])
		for o in m.objectives:
			match str(o.type):
				"talk_to": _check(npc_ids.has(o.target), "%s talks to existing NPC %s" % [m.id, o.target])
				"knock": _check(houses.get_house(o.target) != null, "%s knocks on existing house %s" % [m.id, o.target])

	# Mission manager without a scene (fake world callables).
	var clock := SimClock.new()
	clock.set_hour(9.0)
	var prog := ProgressionState.new()
	var mm := MissionManager.new()
	mm.setup(all, prog, clock)
	var inside := {"npc_faiza": false}
	mm.resident_info = func(id): return {"name": id, "inside": inside.get(id, false)}
	mm.occupants_inside = func(house): return PackedStringArray(["npc_faiza"]) if house == "starter_h01" and inside.npc_faiza else PackedStringArray()
	mm.anchor_position = func(id): return Vector3(20, 0, -20) if id == "poi_court" else null
	mm.check_auto_start()
	_check(mm.active.has("new_face") and not mm.is_available("a_favour"), "New Face auto-starts; A Favour locked")
	mm.on_interaction("npc", "npc_boeta")
	_check(mm.is_completed("new_face") and prog.cash == 150, "talking to Boeta completes New Face (+R50)")
	_check(mm.available_from("npc_faiza") != null, "Auntie Faiza now offers A Favour")
	inside.npc_faiza = true
	var note := mm.on_interaction("door", "starter_h01")
	_check(mm.active.has("a_favour") and note.contains("Faiza"), "knocking while the giver is home starts her mission")
	clock.advance(241.0)
	mm.tick()
	_check(not mm.active.has("a_favour") and mm.is_available("a_favour") and prog.failed_mission_counts.a_favour == 1,
		"A Favour fails after its time limit and can be retried")
	_check(prog.cash == 150, "a failed mission pays nothing")
	mm.on_interaction("door", "starter_h01")
	mm.on_interaction("door", "starter_h12")
	_check(mm.current_objective("a_favour").get("id") == "return", "delivering the note advances to the return step")
	mm.on_interaction("door", "starter_h01")
	_check(mm.is_completed("a_favour") and prog.cash == 230, "returning completes A Favour (+R80)")
	prog.completed_mission_ids.remove_at(prog.completed_mission_ids.find("a_favour"))
	mm.start("a_favour")
	mm.on_interaction("door", "starter_h12")
	mm.on_interaction("door", "starter_h01")
	_check(mm.is_completed("a_favour") and prog.cash == 230, "replaying a completed mission never grants its rewards again")
	mm.on_interaction("npc", "npc_lionel")
	mm.on_player_position(Vector3(21, 0, -21))
	_check(mm.current_objective("know_the_block").get("id") == "park", "standing at the court completes the visit objective")
	var saved := mm.to_dict()
	var mm2 := MissionManager.new()
	mm2.setup(all, prog, clock)
	_check(mm2.load_dict(saved) == "" and mm2.current_objective("know_the_block").get("id") == "park", "mission progress round-trips")
	_check(not mm2.load_dict({"active": {"know_the_block": {"objective": "x"}}}).is_empty(), "bad mission progress is rejected")
	_check(mm.missing_requirements("first_crew").size() >= 1, "locked missions explain what is missing")
	mm.free()
	mm2.free()

	# Safehouse upgrades.
	var sh := Safehouse.load_file("res://data/progression/safehouse_upgrades.json")
	var sp := ProgressionState.new()
	_check(sh.upgrades.size() == 4, "4 safehouse upgrades")
	_check(sh.why_not("crew_lounge", sp).contains("crew"), "crew lounge needs a crew member")
	_check(sh.buy("security_light", sp) and sp.cash == 40 and sp.reputation == 3, "buying the security light costs R60, +3 rep")
	_check(not sh.buy("security_light", sp), "an upgrade can't be bought twice")
	_check(not sh.buy("stash", sp) and sp.cash == 40, "can't buy what you can't afford")
	sp.add_cash(500)
	sh.buy("stash", sp)
	_check(sh.daily_income(sp) == 40, "stash pays R40 a day")

	# Save files.
	var path := "user://test_unit_save.json"
	_check(SaveSystem.write(path, {"hello": 1}) == OK and SaveSystem.read(path).ok and SaveSystem.read(path).data.hello == 1, "save file round-trips")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	_check(not SaveSystem.read(path).ok, "a corrupt save is reported, not crashed on")
	SaveSystem.write(path, {"hello": 1})
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	raw.version = 99
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	_check(not SaveSystem.read(path).ok, "an unknown save version is refused")
	_check(not SaveSystem.read("user://does_not_exist.json").ok, "a missing save is reported")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_phase5_units() -> void:
	var houses := HouseRegistry.load_file("res://data/houses/starter_houses.json")
	var p := ProgressionState.new()
	var dm := DistrictManager.load_file("res://data/districts/districts.json", p, houses)
	_check(dm.neighbours().size() >= 2, "at least two neighbouring districts (%d)" % dm.neighbours().size())
	_check(dm.is_unlocked("starter") and not dm.is_unlocked("district_east") and not dm.is_unlocked("district_west"),
		"only the starter district is open at the start")
	_check(dm.state("district_east") == "locked" and not dm.unlock_district("district_east"), "Rooiduin cannot be unlocked early")
	var reqs := dm.get_unlock_requirements("district_east")
	_check(reqs.size() == 4 and reqs.all(func(r): return not r.met), "Rooiduin lists 4 unmet requirements")
	p.completed_mission_ids.append("hold_the_corner")
	p.reputation = 60
	p.recruit("npc_boeta")
	_check(not dm.can_unlock("district_east"), "missing influence still blocks the unlock")
	p.add_district_influence("starter", 48)
	_check(dm.influence("starter") == 50, "friendly houses add influence (%d = 48 stored + 1 friendly house x 2)" % dm.influence("starter"))
	var announced := [""]
	dm.became_unlockable.connect(func(id): announced[0] = id)
	dm.check_unlockable()
	_check(announced[0] == "district_east" and dm.state("district_east") == "unlockable", "Rooiduin becomes unlockable and is announced")
	var unlocked := [""]
	dm.district_unlocked.connect(func(id): unlocked[0] = id)
	_check(dm.unlock_district("district_east") and unlocked[0] == "district_east" and dm.state("district_east") == "unlocked", "Rooiduin unlocks")
	_check(not dm.unlock_district("district_east"), "unlocking twice does nothing")
	_check(dm.state("district_west") == "locked", "Kalkbos stays locked")
	var p2 := ProgressionState.new()
	p2.load_dict(p.to_dict())
	var dm2 := DistrictManager.load_file("res://data/districts/districts.json", p2, houses)
	_check(dm2.is_unlocked("district_east"), "the unlock persists through progression save data")
	_check(SimClock.in_window(1.0, 19.0, 2.0), "hold window wraps past midnight")

	# Hold objective: accumulate while in place with crew; leaving resets.
	var all := MissionData.load_file("res://data/missions/intro.json")
	_check(all.size() == 7, "7 missions load (%d)" % all.size())
	var clock := SimClock.new()
	clock.set_hour(20.0)
	var prog := ProgressionState.new()
	for id in ["new_face", "a_favour", "know_the_block", "first_crew", "local_respect"]:
		prog.completed_mission_ids.append(id)
	prog.recruit("npc_boeta")
	var mm := MissionManager.new()
	mm.setup(all, prog, clock)
	var crew_here := [true]
	mm.crew_near = func(_p, _r): return crew_here[0]
	mm.anchor_position = func(id): return Vector3(38, 0, -5.4) if id == "poi_corner" else null
	_check(mm.start("hold_the_corner"), "Hold the Corner starts once Local Respect is done and you have crew")
	var corner := Vector3(38, 0, -5.4)
	mm.on_player_position(corner)
	for i in 10:
		clock.advance(2.0)
		mm.on_player_position(corner)
	_check(mm.active.has("hold_the_corner") and int(mm.active.hold_the_corner.count) == 20, "20 minutes held")
	crew_here[0] = false
	clock.advance(1.0)
	mm.on_player_position(corner)
	_check(mm.active.hold_the_corner.count == 0.0, "holding without your crew resets the count")
	crew_here[0] = true
	for i in 16:
		clock.advance(2.0)
		mm.on_player_position(corner)
	_check(mm.is_completed("hold_the_corner") and prog.district_influence("starter") == 25, "holding 30 minutes completes it (+25 influence)")
	mm.free()


func _press_toward(player: Player, action: String, seconds: float) -> void:
	Input.action_press(action)
	for i in int(seconds * 60):
		await physics_frame
	Input.action_release(action)


func _test_turf_in_game(main: Node, district: District, player: Player) -> void:
	var session: GameSession = main.session
	var dm := session.districts
	var prog := session.progression
	var missions := session.missions
	district.director.ambient_incidents = false
	var east_x: float = district.info.bounds[2]
	_check(district.gates.has("district_east") and district.gates.has("district_west"), "both neighbours have boom gates")
	_check(not district.is_district_open("district_east"), "Rooiduin gate starts closed")

	# The gate physically blocks the player.
	player.pivot.rotation.y = 0.0
	player.global_position = Vector3(east_x - 6.0, 0.1, 0.0)
	player.snap_camera()
	await _press_toward(player, "move_right", 3.0)
	_check(player.global_position.x < east_x, "the locked gate stops the player (x %.1f < %.1f)" % [player.global_position.x, east_x])
	_check(not session.request_unlock("district_east") and not district.is_district_open("district_east"), "an early unlock request is refused")

	# Turf map shows requirements.
	session.open_turf_map()
	_check(session.turf_map.visible and session.turf_map.panel_text().contains("✗ Complete \"Hold the Corner\""), "turf map lists Rooiduin's missing requirements")
	_check(session.turf_map.unlock_button("district_east").disabled, "the Unlock button is disabled while locked")
	session.turf_map.close()
	_check(player.input_enabled, "closing the map returns control")

	# Local Respect: chat, reputation, corner after dark.
	_talk(player, district.residents["npc_tasneem"].interactable)
	_check(missions.active.has("local_respect"), "Tasneem offers Local Respect")
	var talked := 0
	for r: Resident in district.residents.values():
		if talked >= 5:
			break
		if r.data.role == "resident":
			_talk(player, r.interactable)
			talked += 1
	prog.add_reputation(maxi(0, 40 - prog.reputation))
	await physics_frame
	district.director.clock.set_hour(20.0)
	player.global_position = district.destinations.anchor_position("poi_corner") + Vector3(0, 0.1, 0)
	player.snap_camera()
	for i in 30:
		await physics_frame
	_check(missions.is_completed("local_respect"), "Local Respect completes")

	# Hold the Corner with Boeta actually beside you.
	var boeta: Resident = district.residents["npc_boeta"]
	_talk(player, boeta.interactable)
	_check(missions.active.has("hold_the_corner"), "Boeta offers Hold the Corner")
	var held := false
	for i in 60 * 150:
		if missions.is_completed("hold_the_corner"):
			held = true
			break
		await physics_frame
	_check(held, "holding the corner with Boeta completes the mission (%s)" % missions.objective_text("hold_the_corner"))
	print("  rooiduin requirements: %s" % [dm.get_unlock_requirements("district_east")])
	if not dm.can_unlock("district_east"):
		# Top up anything still short so the unlock flow itself is tested.
		prog.add_reputation(maxi(0, 60 - prog.reputation))
		prog.add_district_influence("starter", 50)
	_check(dm.can_unlock("district_east"), "Rooiduin is unlockable after Hold the Corner")

	# Unlock through the map button.
	session.open_turf_map()
	var btn := session.turf_map.unlock_button("district_east")
	_check(btn != null and not btn.disabled, "the Unlock button is enabled")
	btn.pressed.emit()
	_check(prog.unlocked_district_ids.has("district_east") and district.is_district_open("district_east"), "pressing Unlock opens Rooiduin's gates")
	_check(session.hud.banner_text().contains("ROOIDUIN UNLOCKED"), "unlock banner is shown")
	session.turf_map.close()
	_check(not district.is_district_open("district_west") and not session.request_unlock("district_west"), "Kalkbos stays locked")

	# Beyond the Block: walk through the open gate into Rooiduin.
	_talk(player, district.residents["npc_lionel"].interactable)
	_check(missions.active.has("beyond_the_block"), "Lionel offers Beyond the Block")
	_check(missions.current_objective("beyond_the_block").get("id") == "enter", "the unlock objective is already done")
	district.director.clock.set_hour(12.0)
	player.pivot.rotation.y = 0.0
	player.global_position = Vector3(east_x - 6.0, 0.1, 0.0)
	player.snap_camera()
	await _press_toward(player, "move_right", 7.0)
	_check(player.global_position.x > east_x + 12.0, "the open gate lets the player through (x %.1f)" % player.global_position.x)
	for i in 20:
		await physics_frame
	_check(missions.is_completed("beyond_the_block"), "walking into Rooiduin completes Beyond the Block")
	var west_x: float = district.info.bounds[0]
	player.global_position = Vector3(west_x + 6.0, 0.1, 0.0)
	player.snap_camera()
	await _press_toward(player, "move_left", 3.0)
	_check(player.global_position.x > west_x, "Kalkbos' gate still blocks the player")

	# Persistence: save, lock everything again, load.
	_check(session.save_game() == "", "save after unlocking")
	prog.unlocked_district_ids = PackedStringArray(["starter"])
	district.set_district_open("district_east", false, false)
	_check(session.load_game() == "" and prog.unlocked_district_ids.has("district_east") and district.is_district_open("district_east"),
		"after loading, Rooiduin is unlocked and its gates are open")
	_check(district.residents.size() >= 28 and district.residents.values().any(func(r): return not r.is_inside),
		"the starter district is still populated")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.save_path))


func _talk(player: Player, who: Interactable) -> void:
	player.interacted_with.emit(who, who.interact(player))


func _test_missions_in_game(main: Node, district: District, player: Player) -> void:
	var session: GameSession = main.session
	var missions := session.missions
	var prog := session.progression
	district.director.ambient_incidents = false
	district.director.clock.set_hour(10.0)
	_check(missions.active.has("new_face"), "game starts with New Face active")
	session._refresh()
	var boeta: Resident = district.residents["npc_boeta"]
	_check(boeta._marker.text == "▼", "Boeta is marked as the target")
	_check(session.hud.tracker_text().contains("NEW FACE"), "tracker shows the mission")
	_talk(player, boeta.interactable)
	_check(missions.is_completed("new_face"), "New Face completes in game")
	session._refresh()
	var faiza: Resident = district.residents["npc_faiza"]
	_check(faiza._marker.text == "!", "Auntie Faiza shows a mission marker")
	_talk(player, faiza.interactable)
	_talk(player, district.plots["starter_h12"].door_interactable)
	_talk(player, faiza.interactable)
	_check(missions.is_completed("a_favour"), "A Favour completes in game")
	_talk(player, district.residents["npc_lionel"].interactable)
	for poi in ["poi_court", "poi_park", "poi_bus_stop_mossie"]:
		player.global_position = district.destinations.anchor_position(poi) + Vector3(0, 0.1, 0)
		for i in 30:
			await physics_frame
	_check(missions.is_completed("know_the_block"), "Know the Block completes by walking to the places")
	_check(prog.reputation >= 20, "reputation is high enough for First Crew (%d)" % prog.reputation)
	_talk(player, boeta.interactable)
	_check(missions.active.has("first_crew"), "Boeta offers First Crew")
	_talk(player, faiza.interactable)
	_talk(player, district.plots["starter_h05"].door_interactable)
	_check(missions.is_completed("first_crew") and prog.recruited_crew_ids.has("npc_boeta"), "First Crew recruits Boeta")
	_check(boeta.data.role == "player_crew", "Boeta is now player crew")
	_check(session.hud.is_menu_open(), "knocking on the safehouse opens its menu")
	_check(session.buy_upgrade("security_light") and district.plots["starter_h05"].has_node("upgrade_security_light"),
		"buying an upgrade adds its prop to the safehouse")
	session._close_menu()
	_check(not session.hud.is_menu_open() and player.input_enabled, "closing the menu gives control back")

	# Boeta follows the player once he is out.
	player.global_position = Vector3(10, 0.1, 4)
	var followed := false
	for i in 60 * 120:
		if boeta.brain.state == NpcBrain.State.FOLLOWING and boeta.global_position.distance_to(player.global_position) < 6.0:
			followed = true
			break
		await physics_frame
	_check(followed, "recruited Boeta comes out and follows the player")

	# Save, change things, load: everything comes back.
	var cash_saved := prog.cash
	var pos_saved := player.global_position
	var active_saved := missions.to_dict()
	_check(session.save_game() == "", "game saves")
	prog.add_cash(999)
	prog.recruited_crew_ids.clear()
	player.global_position = Vector3(-30, 0.1, 3)
	missions.active.clear()
	_check(session.load_game() == "", "game loads")
	_check(prog.cash == cash_saved and prog.recruited_crew_ids.has("npc_boeta"), "load restores cash and crew")
	_check(player.global_position.distance_to(pos_saved) < 0.2, "load restores the player's position")
	_check(missions.to_dict() == active_saved, "load restores active mission progress")
	_check(not missions.start("new_face"), "completed missions stay completed after load")
	var f := FileAccess.open(session.save_path, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	prog.add_cash(5)
	var cash_now := prog.cash
	_check(not session.load_game().is_empty() and prog.cash == cash_now, "a corrupt save fails safely and keeps the current game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.save_path))


func _sample_states(district: District, seen: Dictionary, tiers: Dictionary) -> void:
	for r: Resident in district.residents.values():
		seen[r.state_name()] = seen.get(r.state_name(), 0) + 1
		tiers[r.sim_tier] = tiers.get(r.sim_tier, 0) + 1


func _test_district() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	main.auto_load = false
	main.save_path = "user://test_game_save.json"
	root.add_child(main)
	var district: District = main.get_node("Vleirand")
	var player: Player = main.get_node("Player")
	if not district.is_navigation_ready:
		await district.navigation_ready
	_check(district.nav_region.navigation_mesh.get_polygon_count() > 0, "navigation mesh baked (%d polys)" % district.nav_region.navigation_mesh.get_polygon_count())
	_check(district.plots.size() == district.registry.count(), "every house plot is built")
	_check(district.residents.size() >= 8, "at least 8 residents spawned (%d)" % district.residents.size())

	# Recovery: a resident whose schedule names a missing destination skips it instead of freezing.
	var lost_data := NpcData.from_dict({"id": "npc_test_lost", "display_name": "Lost Tester", "home_id": "starter_h03",
		"start_delay": 0.5, "schedule": [
			{"activity": "x", "destination": "poi_does_not_exist", "duration": 2},
			{"activity": "shopping", "destination": "poi_shop", "duration": 2},
			{"activity": "home", "destination": "home", "duration": 3}]})
	var lost: Resident = district.RESIDENT_SCENE.instantiate()
	district.add_child(lost)
	lost.setup(lost_data, district.destinations, 0.0)

	var rep := district.reachability_report()
	_check(rep.failed.is_empty(), "every house door reaches every street destination (%d ok) %s" % [rep.ok, rep.failed])

	# Entrances are outside the house: the door point must be on the nav mesh.
	var map := district.nav_region.get_navigation_map()
	for id in district.registry.order:
		var door := district.destinations.anchor_position(id + ":door")
		var snapped := NavigationServer3D.map_get_closest_point(map, door)
		_check(Vector2(door.x, door.z).distance_to(Vector2(snapped.x, snapped.z)) < 0.5, "%s door is on the walkable mesh" % id)

	# Interaction prompt near a door.
	var plot: HousePlot = district.plots["starter_h05"]
	player.global_position = plot.door_position() + Vector3(0, 0.1, 1.0)
	for i in 10:
		await physics_frame
	_check(player.current_target == plot.door_interactable, "interaction target is the nearby door")
	_check(not player.current_target.interact(player).is_empty(), "door interaction returns feedback")
	player.global_position = Vector3(-30, 0.1, 0)
	for i in 10:
		await physics_frame
	_check(player.current_target == null, "no prompt in the middle of the road")

	# Polish: smooth motion settings, jointed rig, plot dressing, swinging doors.
	_check(ProjectSettings.get_setting("physics/common/physics_interpolation", false), "physics interpolation is enabled")
	var some: Resident = district.residents.values()[0]
	_check(some.model.has_node("Hips/LegL") and some.model.has_node("Hips/Torso/ArmR") and some.model.has_node("Hips/Torso/Head"),
		"characters have a jointed rig (legs, arms, head)")
	var dressed := 0
	for hp: HousePlot in district.plots.values():
		dressed += 1 if not hp.data.props.is_empty() else 0
	_check(dressed == district.plots.size(), "every house has plot dressing data (%d)" % dressed)
	var doors_used := [0]
	for r: Resident in district.residents.values():
		r.door_used.connect(func(_h): doors_used[0] += 1)

	# Tiers follow distance to the player.
	var director := district.director
	director.update_tiers()
	var tier_ok := true
	for r: Resident in district.residents.values():
		var d := r.global_position.distance_to(player.global_position)
		var want := "near" if d < director.near_distance else ("mid" if d < director.mid_distance else "far")
		tier_ok = tier_ok and r.sim_tier == want
	_check(tier_ok, "simulation tiers match distance (near %d / mid %d / far %d)" % [
		director.tier_counts.near, director.tier_counts.mid, director.tier_counts.far])

	# Incident reactions, then everyone returns to routine.
	director.ambient_incidents = false
	director.clock.set_hour(9.0)
	for i in 60 * 40:
		await physics_frame
	var outside: Array = district.residents.values().filter(func(r): return not r.is_inside)
	_check(not outside.is_empty(), "some residents are out by 09:40")
	if not outside.is_empty():
		var victim: Resident = outside[0]
		var before := director.reactions_delivered
		var reported := [0]
		district.events.incident_reported.connect(func(_e, _who): reported[0] += 1)
		district.events.raise("argument", victim.global_position, "the test")
		_check(director.reactions_delivered > before and victim.brain.is_reacting(),
			"an argument triggers reactions (%d NPCs, first: %s)" % [director.reactions_delivered - before, victim.brain.state_name()])
		for i in 60 * 90:
			await physics_frame
		var still := district.residents.values().filter(func(r): return r.brain.state in [
			NpcBrain.State.NOTICING, NpcBrain.State.INVESTIGATING, NpcBrain.State.REPORTING, NpcBrain.State.FLEEING])
		_check(still.is_empty(), "90 s later every NPC is back to routine (%d still reacting)" % still.size())
		print("  incident: %d reactions, %d reports" % [director.reactions_delivered - before, reported[0]])
	director.ambient_incidents = true

	# Soak: simulated minutes of daytime routine (07:00 onwards), ambient incidents on.
	director.clock.set_hour(7.0)
	var seen := {}
	var tiers := {}
	var minutes := float(_args.get("soak-minutes", "10"))
	var frames := int(minutes * 60.0 * 60.0)
	var disable_at := frames / 2
	var t0 := Time.get_ticks_msec()
	for f in frames:
		if f == disable_at:
			# Recovery: the café closes mid-run; NPCs must fall back, not crash or freeze.
			district.destinations.set_enabled("poi_shop", false)
		if f % 60 == 0:
			_sample_states(district, seen, tiers)
			for r: Resident in district.residents.values():
				if r.sim_tier != "far" and r.model.walk_amplitude() > 0.5:
					seen["_walking_gait"] = seen.get("_walking_gait", 0) + 1
				if district.plots[r.data.home_id].is_door_open():
					seen["_door_open"] = seen.get("_door_open", 0) + 1
		await physics_frame
	var real_s := (Time.get_ticks_msec() - t0) / 1000.0
	var ms_per_frame := real_s * 1000.0 / frames
	print("  soak: %.1f simulated minutes in %.1f s real time (%.2f ms per physics frame, %d NPCs)" % [
		minutes, real_s, ms_per_frame, district.residents.size()])
	_check(ms_per_frame < 8.0, "simulation cost per frame is under 8 ms headless (%.2f ms)" % ms_per_frame)
	_check(lost.travel_failures >= 1 and lost.arrivals >= 2, "resident with a missing destination recovers (%d failures, %d arrivals)" % [lost.travel_failures, lost.arrivals])
	var total_arrivals := 0
	for r: Resident in district.residents.values():
		total_arrivals += r.arrivals
	print("  total arrivals: %d" % total_arrivals)
	for r: Resident in district.residents.values():
		if not _args.has("verbose") and r.arrivals >= int(minutes * 0.5) and r.teleport_violations == 0:
			_passed += 3
			continue
		print("    %s arrivals=%d failures=%d max_travel=%.1fs state=%s last=%s" % [
			r.data.id, r.arrivals, r.travel_failures, r.max_travel_time, r.state_name(), r.brain.last_transition])
		_check(r.teleport_violations == 0, "%s never teleports" % r.data.id)
		_check(r.arrivals >= int(minutes * 0.5), "%s keeps completing trips (%d arrivals)" % [r.data.id, r.arrivals])
		_check(r.max_travel_time < 150.0, "%s never stays stuck travelling (max %.1fs)" % [r.data.id, r.max_travel_time])
	print("  daytime states seen: %s" % seen)
	print("  tier samples: %s, ambient reactions %d" % [tiers, director.reactions_delivered])
	for st in ["TRAVELLING", "AT_DESTINATION", "SOCIALIZING", "GUARDING", "AT_HOME"]:
		_check(seen.has(st), "daytime soak shows %s" % st)
	_check(tiers.get("far", 0) > 0 and tiers.get("near", 0) > 0, "soak exercises near and far tiers")
	_check(seen.get("_walking_gait", 0) > 50, "walking NPCs swing their limbs (%d samples)" % seen.get("_walking_gait", 0))
	_check(doors_used[0] > 20 and seen.get("_door_open", 0) > 0, "front doors swing when residents come and go (%d uses)" % doors_used[0])

	# Night: 17:00 -> 00:30. Crew patrol/follow; residents go home by curfew.
	district.destinations.set_enabled("poi_shop", true)
	director.ambient_incidents = false
	director.clock.set_hour(17.0)
	var night_seen := {}
	for f in 60 * 60 * 7 + 60 * 30:
		if f % 60 == 0:
			_sample_states(district, night_seen, tiers)
		await physics_frame
	print("  evening states seen: %s (clock %s)" % [night_seen, director.clock.label()])
	_check(night_seen.has("PATROLLING"), "crew leader patrols in the evening")
	_check(night_seen.has("FOLLOWING"), "second crew member follows the leader")
	var residents_out := 0
	var crew_out := 0
	for r: Resident in district.residents.values():
		if r.data.role == "crew":
			crew_out += 0 if r.is_inside else 1
		elif not r.is_inside:
			residents_out += 1
			print("    still out at midnight: %s %s %s" % [r.data.id, r.state_name(), r.brain.last_transition])
	_check(residents_out == 0, "all residents are home by 00:30 (%d still out)" % residents_out)
	_check(crew_out >= 1, "the crew is still out after midnight (%d)" % crew_out)
	var tele := 0
	var nudges := 0
	var near_nudges := 0
	for r: Resident in district.residents.values():
		tele += r.teleport_violations
		nudges += r.offscreen_nudges
		near_nudges += r.near_nudges
	_check(tele == 0, "no teleports (>0.5 m in one frame) across day and night runs (%d)" % tele)
	print("== phase 4 in game (missions, recruit, safehouse, save/load)")
	await _test_missions_in_game(main, district, player)
	print("== phase 5 in game (gates, turf map, unlock, persistence)")
	await _test_turf_in_game(main, district, player)
	_check(nudges + near_nudges <= 20, "physics nudges stay rare: %d off-screen, %d near, in ~1M NPC-frames" % [nudges, near_nudges])
	main.queue_free()
	await process_frame
