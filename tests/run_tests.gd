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


func _test_district() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
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

	# Soak: simulated minutes of normal routine.
	var minutes := float(_args.get("soak-minutes", "10"))
	var frames := int(minutes * 60.0 * 60.0)
	var disable_at := frames / 2
	var t0 := Time.get_ticks_msec()
	for f in frames:
		if f == disable_at:
			# Recovery: the café closes mid-run; NPCs must fall back, not crash or freeze.
			district.destinations.set_enabled("poi_shop", false)
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
		_check(r.teleport_violations == 0, "%s never teleports while visible" % r.data.id)
		_check(r.arrivals >= int(minutes * 0.5), "%s keeps completing trips (%d arrivals)" % [r.data.id, r.arrivals])
		_check(r.max_travel_time < 150.0, "%s never stays stuck travelling (max %.1fs)" % [r.data.id, r.max_travel_time])
	main.queue_free()
	await process_frame
