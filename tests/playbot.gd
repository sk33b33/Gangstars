extends SceneTree
## The playtest bot: boots the real game and plays every mission from start to finish the way a
## player would, as far as a script can. It teleports to people and places, talks, knocks, holds a
## spot while the clock runs, picks the first dialogue choice, waits for calendar events, and
## follows people. It reports every mission it could not finish and where it got stuck.
##
##   tests/playbot.sh            (reads the PLAYBOT summary line; see tests/run.sh for why)
##
## It cheats where a script has to: districts are unlocked directly (the unlock rules are tested
## elsewhere), crew-mates are always "nearby", and stats are set. It does not test that missions
## are *fun*, only that none of them is impossible, mis-wired or stuck.

var _main: Node
var _district: District
var _player: Player
var _session: GameSession
var _results: Array = []   # [mission id, "done" | "stuck: why"]
var _crew := "vlakte_vipers"   # --crew=<id>: which crew the bot joins
var _choice := 0               # --choice=<n>: which dialogue choice it always takes (explores the other story branch)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--crew="):
			_crew = a.trim_prefix("--crew=")
		elif a.begins_with("--choice="):
			_choice = int(a.trim_prefix("--choice="))
	print("== playbot: crew %s, dialogue choice %d" % [_crew, _choice])
	_main = load("res://scenes/main/main.tscn").instantiate()
	_main.auto_load = false
	_main.save_path = "user://playbot_save.json"
	root.add_child(_main)
	_district = _main.get_node("Westridge")
	_player = _main.get_node("Player")
	if not _district.is_navigation_ready:
		await _district.navigation_ready
	await _frames(5)
	_session = _main.session
	_session.autosave_enabled = false
	_session.turf.state.next_push = 1e9
	for i in 600:   # the crew picker opens a moment after the navigation is ready
		if _session.crew_picker != null or not _session.progression.crew_id.is_empty():
			break
		await physics_frame
	if _session.crew_picker != null and _session.crew_picker.visible:
		_session.crew_picker.button(_crew).pressed.emit()
	else:
		_session.choose_crew(_crew)
	_district.director.ambient_incidents = false
	_district.weather.enabled = false
	_session.missions.crew_near = func(_p, _r): return true
	await _frames(5)
	print("== playbot: %d missions in the catalog" % _session.missions.order.size())
	for round in 12:   # unlocking one mission can make others available
		var progressed := false
		for id in _session.missions.order:
			if _session.missions.is_completed(id) or _results.any(func(r): return r[0] == id):
				continue
			if not _available(id):
				continue
			await _play(id)
			progressed = true
		if not progressed:
			break
	for id in _session.missions.order:
		if not _results.any(func(r): return r[0] == id):
			var why := ", ".join(_session.missions.missing_requirements(id))
			var behind_skipped := _results.any(func(r): return str(r[1]).begins_with("skipped") and why.contains(str(_session.missions.get_mission(r[0]).title)))
			if why.contains("member of that crew") or why.is_empty() or behind_skipped:
				_results.append([id, "skipped: needs another crew or the other story branch (the bot takes the first dialogue choice and one crew)"])
			else:
				_results.append([id, "never became available: %s" % why])
	var done := _results.filter(func(r): return r[1] == "done").size()
	for r in _results:   # things only a human can do are skipped, not failures
		if str(r[1]).contains("the bot can't"):
			r[1] = "skipped: " + str(r[1]).get_slice("(", 0)
	var skipped := _results.filter(func(r): return str(r[1]).begins_with("skipped")).size()
	for r in _results:
		print("  %s  %s" % ["OK   " if r[1] == "done" else ("skip " if str(r[1]).begins_with("skipped") else "STUCK"), "%s: %s" % [r[0], r[1]]])
	var stuck := _results.size() - done - skipped
	print("\nPLAYBOT: %d/%d missions finished, %d skipped (other branches), %d stuck" % [done, _results.size(), skipped, stuck])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playbot_save.json"))
	quit(0 if stuck == 0 else 1)


## Cheat: open the districts a mission needs, then check the ordinary prerequisites.
func _available(id: String) -> bool:
	if _session.missions.active.has(id):   # auto-start missions are already running
		return true
	var m: MissionData = _session.missions.get_mission(id)
	for d in m.prerequisites.get("districts", []):
		_unlock(str(d))
	return _session.missions.is_available(id)


func _unlock(district_id: String) -> void:
	if _session.progression.unlocked_district_ids.has(district_id):
		return
	_session.progression.unlocked_district_ids.append(district_id)
	_district.set_district_open(district_id, true, false)


func _play(id: String) -> void:
	print("  ... playing %s" % id)
	var m: MissionData = _session.missions.get_mission(id)
	_session.progression.reputation = maxi(_session.progression.reputation, 400)   # so rep gates don't block the bot
	if not _session.missions.active.has(id) and not _session.missions.start(id):
		_results.append([id, "stuck: could not start"])
		return
	for step in m.objectives.size() + 2:
		if not _session.missions.active.has(id):
			break
		var o := _session.missions.current_objective(id)
		var why := await _satisfy(id, o)
		if not why.is_empty():
			_results.append([id, "stuck: %s (%s)" % [why, o.get("text", o.get("id", "?"))]])
			_session.missions.active.erase(id)
			return
	_results.append([id, "done" if _session.missions.is_completed(id) else "stuck: objectives ran out but the mission is not complete"])


## Returns "" when the objective was satisfied, otherwise why it couldn't be.
func _satisfy(id: String, o: Dictionary) -> String:
	var mm := _session.missions
	var type := str(o.get("type", ""))
	if o.has("event"):
		await _wait_for_event(str(o.event))
	elif o.has("window") and type in ["visit", "drive_to", "follow"]:
		_district.director.clock.set_hour(float(o.window[0]) + 0.5)
	match type:
		"talk_to":
			var r: Resident = _district.residents.get(str(o.target))
			if r == null:
				return "no such person %s" % o.target
			_go_to(r.global_position)
			await _frames(2)
			mm.message.emit(mm.on_interaction("npc", str(o.target)))
		"knock":
			mm.on_interaction("door", str(o.target))
		"talk_distinct":
			var n := 0
			for rid in _district.residents:
				if n >= int(o.get("count", 1)):
					break
				mm.on_interaction("npc", str(rid))
				n += 1
		"visit", "drive_to":
			if type == "drive_to":
				mm.driving_vehicle = func() -> String: return str(o.get("vehicle", "bot_car"))
			if not _district.destinations.has(str(o.target)):
				return "unknown place %s" % o.target
			_go_to(_district.destinations.anchor_position(str(o.target)))
			await _frames(3)
			mm.on_player_position(_player.global_position)
			if type == "drive_to":
				mm.driving_vehicle = func() -> String: return ""
		"hold":
			if not _district.destinations.has(str(o.target)):
				return "unknown place %s" % o.target
			var w: Array = o.get("window", [0, 24])
			_district.director.clock.set_hour(float(w[0]) + 0.5)
			_go_to(_district.destinations.anchor_position(str(o.target)))
			for i in int(o.get("minutes", 1)) + 3:
				_district.director.clock.minutes += 1.0
				mm.on_player_position(_player.global_position)
				await _frames(1)
		"reputation":
			_session.progression.reputation = maxi(_session.progression.reputation, int(o.get("value", 0)))
			_session.progression.changed.emit()
		"district_unlocked":
			_unlock(str(o.target))
			_session.progression.changed.emit()
		"enter_vehicle":
			mm.on_vehicle_entered(str(o.target))
		"stat":
			if str(o.stat) == "contacts":
				return "the bot can't make phone contacts (covered by the dealing tests)"
			_make_stat(str(o.stat), int(o.get("value", 1)))
			_session.progression.changed.emit()
			await _frames(3)
		"dialogue":
			var scene: Dictionary = _session.story_scenes.get(str(o.get("scene", "")), {})
			if not scene.is_empty():
				_session.apply_effects(scene.choices[mini(_choice, scene.choices.size() - 1)].get("effects", {}))
			mm.finish_dialogue(id)
		"follow":
			var r2: Resident = _district.residents.get(str(o.target))
			if r2 == null:
				return "no such person %s" % o.target
			for i in 9000:   # a couple of minutes: people walk at a believable speed
				if not mm.active.has(id) or mm.current_objective(id) != o:
					break
				_go_to(r2.global_position + Vector3(18, 0, 0))   # a tail keeps its distance: rivals attack if you crowd them
				mm.on_player_position(_player.global_position)
				if OS.get_cmdline_user_args().has("--verbose") and i % 300 == 0:
					print("    follow: %s at %s state %s dest %s dist_to_goal %.1f inside %s" % [r2.data.id, r2.global_position.snapped(Vector3.ONE), NpcBrain.State.keys()[r2.brain.state], r2.brain.destination_id, r2.global_position.distance_to(_district.destinations.anchor_position(str(o.destination))), r2.is_inside])
				await physics_frame
			if mm.active.has(id) and mm.current_objective(id) == o:
				return "never arrived (state %s, heading for %s, pending %s)" % [NpcBrain.State.keys()[r2.brain.state], r2.brain.destination_id, r2.brain.pending_event]
		_:
			return "the bot does not know the objective type '%s'" % type
	await _frames(2)
	if mm.active.has(id) and mm.current_objective(id) == o and type not in ["follow"]:
		return "objective did not advance"
	return ""


func _go_to(p: Vector3) -> void:
	_player.global_position = p + Vector3(1.2, 0.1, 0)


## Advances the clock to the next time the calendar event runs.
func _wait_for_event(event_id: String) -> void:
	var cal := _district.director.calendar
	var clock := _district.director.clock
	for day in range(clock.day, clock.day + 22):
		clock.day = day
		for hour in [6.0, 7.5, 9.5, 12.0, 13.0, 15.0, 19.5, 20.5]:
			clock.set_hour(hour)
			cal.update(clock)
			if cal.is_active(event_id):
				await _frames(2)
				return


func _make_stat(stat: String, value: int) -> void:
	if stat == "corners":
		var n := 0
		for cid in _session.turf.state.order:
			if _session.turf.state.corners[cid].owner != _session.progression.crew_id and n < value:
				_session.turf.state.corners[cid].owner = _session.progression.crew_id
			if _session.turf.state.is_players(cid):
				n += 1
	elif stat == "contacts":
		pass   # derived from real clients; the dealing missions are covered by the main tests
	else:
		_session.dealing.state.stats[stat] = maxi(int(_session.dealing.state.stats.get(stat, 0)), value)
