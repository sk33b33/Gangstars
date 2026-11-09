class_name MissionManager
extends Node
## Runs missions: availability (prerequisites), start (auto or by talking to the giver),
## objective progress from player events, time-limit failure, and completion. Rewards are
## granted through ProgressionState.grant("mission:<id>"), so they can never pay out twice.
## World access goes through injected Callables so the manager is unit-testable without scenes:
##   resident_info(npc_id) -> {inside: bool, home_id: String, name: String} or {}
##   occupants_inside(house_id) -> PackedStringArray of npc ids currently at home
##   anchor_position(anchor_id) -> Vector3 or null
##   crew_near(position, radius) -> bool (a player crew member is close)

signal mission_started(mission: MissionData)
signal mission_updated(mission: MissionData)
signal mission_completed(mission: MissionData, rewards_granted: bool)
signal mission_failed(mission: MissionData, reason: String)
signal message(text: String)

var catalog: Dictionary = {}          # id -> MissionData
var order: PackedStringArray = []
var progression: ProgressionState
var clock: SimClock
var active: Dictionary = {}           # id -> {objective: int, count: int, seen: Array, started: float}
var resident_info: Callable
var occupants_inside: Callable
var anchor_position: Callable
var crew_near: Callable
var _last_position_minutes := -1.0


func setup(missions: Array[MissionData], p_progression: ProgressionState, p_clock: SimClock) -> void:
	catalog.clear()
	order.clear()
	for m in missions:
		catalog[m.id] = m
		order.append(m.id)
	progression = p_progression
	clock = p_clock
	progression.changed.connect(_check_stat_objectives)


func get_mission(id: String) -> MissionData:
	return catalog.get(id)


func absolute_minutes() -> float:
	return clock.day * 1440.0 + clock.minutes


func is_completed(id: String) -> bool:
	return progression.completed_mission_ids.has(id)


func prerequisites_met(m: MissionData) -> bool:
	var pre := m.prerequisites
	for dep in pre.get("missions", []):
		if not is_completed(str(dep)):
			return false
	if progression.reputation < int(pre.get("reputation", 0)):
		return false
	if progression.recruited_crew_ids.size() < int(pre.get("crew", 0)):
		return false
	return true


func is_available(id: String) -> bool:
	var m := get_mission(id)
	return m != null and not is_completed(id) and not active.has(id) and prerequisites_met(m)


## Human-readable list of what is still missing for a mission.
func missing_requirements(id: String) -> PackedStringArray:
	var m := get_mission(id)
	var out: PackedStringArray = []
	if m == null:
		return out
	for dep in m.prerequisites.get("missions", []):
		if not is_completed(str(dep)):
			out.append("complete \"%s\"" % get_mission(str(dep)).title if get_mission(str(dep)) else str(dep))
	var rep := int(m.prerequisites.get("reputation", 0))
	if progression.reputation < rep:
		out.append("reach %d reputation (now %d)" % [rep, progression.reputation])
	return out


func available_from(npc_id: String) -> MissionData:
	for id in order:
		var m: MissionData = catalog[id]
		if m.giver == npc_id and is_available(id):
			return m
	return null


func tracked_mission() -> MissionData:
	for id in order:
		if active.has(id):
			return catalog[id]
	return null


func current_objective(id: String) -> Dictionary:
	if not active.has(id):
		return {}
	var m: MissionData = catalog[id]
	var i: int = active[id].objective
	return m.objectives[i] if i < m.objectives.size() else {}


func objective_text(id: String) -> String:
	var o := current_objective(id)
	if o.is_empty():
		return ""
	var text := str(o.get("text", o.type))
	match str(o.type):
		"talk_distinct":
			text += " (%d/%d)" % [active[id].count, int(o.get("count", 1))]
		"reputation":
			text += " (%d/%d)" % [progression.reputation, int(o.get("value", 0))]
		"hold":
			text += " (%d/%d min)" % [int(active[id].count), int(o.get("minutes", 1))]
	var m: MissionData = catalog[id]
	if m.time_limit_minutes > 0.0:
		var left := m.time_limit_minutes - (absolute_minutes() - float(active[id].started))
		text += "  [%dh%02d left]" % [int(left / 60.0), int(left) % 60]
	return text


func start(id: String) -> bool:
	if not is_available(id):
		return false
	active[id] = {"objective": 0, "count": 0, "seen": [], "started": absolute_minutes()}
	var m: MissionData = catalog[id]
	mission_started.emit(m)
	message.emit("Mission started: %s — %s" % [m.title, objective_text(id)])
	_check_stat_objectives()
	return true


## Starts auto-start missions whose prerequisites are now met. Call after load and on changes.
func check_auto_start() -> void:
	for id in order:
		if catalog[id].auto_start and is_available(id):
			start(id)


## Player talked to an NPC ("npc") or knocked on a house ("door"). Returns extra feedback
## (mission intro, objective done) to append to the interaction message.
func on_interaction(kind: String, target: String) -> String:
	var notes: PackedStringArray = []
	var talked: PackedStringArray = []
	if kind == "npc":
		talked.append(target)
	elif kind == "door" and occupants_inside.is_valid():
		talked.append_array(occupants_inside.call(target))
	for npc in talked:
		progression.register_talk(npc, clock.day)
	# Progress active missions first, so a talk that finishes one can't also start the next.
	for id in active.keys():
		var o := current_objective(id)
		var hit := false
		match str(o.get("type", "")):
			"talk_to":
				hit = talked.has(str(o.target)) and (kind == "npc" or bool(o.get("allow_knock", false)))
			"knock":
				hit = kind == "door" and target == str(o.target)
			"talk_distinct":
				for npc in talked:
					if not active[id].seen.has(npc):
						active[id].seen.append(npc)
						active[id].count += 1
				hit = active[id].count >= int(o.get("count", 1))
				if not hit and not talked.is_empty():
					mission_updated.emit(catalog[id])
		if hit:
			notes.append(_advance(id))
	for npc in talked:
		var m := available_from(npc)
		if m != null and start(m.id):
			notes.append(m.intro if not m.intro.is_empty() else "New mission: " + m.title)
	return "\n".join(notes)


func on_player_position(pos: Vector3) -> void:
	var now := absolute_minutes()
	var elapsed := 0.0 if _last_position_minutes < 0.0 else clampf(now - _last_position_minutes, 0.0, 30.0)
	_last_position_minutes = now
	for id in active.keys():
		var o := current_objective(id)
		var kind := str(o.get("type", ""))
		if kind == "hold":
			_update_hold(id, o, pos, elapsed)
			continue
		if kind != "visit" or not anchor_position.is_valid():
			continue
		var target: Variant = anchor_position.call(str(o.target))
		if target == null:
			continue
		if o.has("window"):
			var w: Array = o.window
			if not SimClock.in_window(clock.hour(), float(w[0]), float(w[1])):
				continue
		var flat := Vector2(pos.x - target.x, pos.z - target.z).length()
		if flat <= float(o.get("radius", 3.0)):
			var note := _advance(id)
			if not note.is_empty():
				message.emit(note)


## Hold: accumulate game minutes while in place (and in the time window, with crew if
## required). Stepping away resets the count, so the player has to really stand their ground.
func _update_hold(id: String, o: Dictionary, pos: Vector3, elapsed: float) -> void:
	var target: Variant = anchor_position.call(str(o.target)) if anchor_position.is_valid() else null
	if target == null:
		return
	if o.has("window"):
		var w: Array = o.window
		if not SimClock.in_window(clock.hour(), float(w[0]), float(w[1])):
			return
	var inside := Vector2(pos.x - target.x, pos.z - target.z).length() <= float(o.get("radius", 4.0))
	var crew_ok: bool = not bool(o.get("with_crew", false)) or (crew_near.is_valid() and crew_near.call(pos, 10.0))
	if inside and crew_ok:
		active[id].count += elapsed
		if active[id].count >= float(o.get("minutes", 1)):
			message.emit(_advance(id))
		else:
			mission_updated.emit(catalog[id])
	elif active[id].count > 0.0:
		active[id].count = 0.0
		message.emit("You left the %s. Start again." % str(o.target).trim_prefix("poi_") if not inside
			else "Your crew isn't with you. Start again.")


## Periodic checks: time limits and auto-start.
func tick() -> void:
	for id in active.keys():
		var m: MissionData = catalog[id]
		if m.time_limit_minutes > 0.0 and absolute_minutes() - float(active[id].started) > m.time_limit_minutes:
			fail(id, m.fail_text if not m.fail_text.is_empty() else "Out of time.")
	check_auto_start()


func fail(id: String, reason: String) -> void:
	if not active.has(id):
		return
	active.erase(id)
	progression.failed_mission_counts[id] = int(progression.failed_mission_counts.get(id, 0)) + 1
	var m: MissionData = catalog[id]
	mission_failed.emit(m, reason)
	message.emit("Mission failed: %s. %s Talk to %s to try again." % [m.title, reason,
		_name(m.giver) if not m.giver.is_empty() else "them"])


func _check_stat_objectives() -> void:
	for id in active.keys():
		var o := current_objective(id)
		var t := str(o.get("type", ""))
		var done := (t == "reputation" and progression.reputation >= int(o.get("value", 0))) \
			or (t == "district_unlocked" and progression.unlocked_district_ids.has(str(o.get("target", ""))))
		if done:
			var note := _advance(id)
			if not note.is_empty():
				message.emit(note)


func _advance(id: String) -> String:
	var m: MissionData = catalog[id]
	active[id].objective += 1
	active[id].count = 0
	active[id].seen = []
	if active[id].objective >= m.objectives.size():
		return _complete(id)
	mission_updated.emit(m)
	_check_stat_objectives.call_deferred()
	return "Objective done. Next: " + objective_text(id)


func _complete(id: String) -> String:
	var m: MissionData = catalog[id]
	active.erase(id)
	if not progression.completed_mission_ids.has(id):
		progression.completed_mission_ids.append(id)
	var granted := progression.grant("mission:" + id, m.rewards)
	mission_completed.emit(m, granted)
	var parts: PackedStringArray = []
	if granted:
		if m.rewards.has("cash"):
			parts.append("R%d" % int(m.rewards.cash))
		if m.rewards.has("reputation"):
			parts.append("+%d rep" % int(m.rewards.reputation))
		if m.rewards.has("crew_influence"):
			parts.append("+%d crew influence" % int(m.rewards.crew_influence))
		if m.rewards.has("recruit"):
			parts.append("%s joins your crew" % _name(str(m.rewards.recruit)))
	check_auto_start.call_deferred()
	return "Mission complete: %s! %s" % [m.title, ", ".join(parts)]


func _name(npc_id: String) -> String:
	if resident_info.is_valid():
		var info: Dictionary = resident_info.call(npc_id)
		return str(info.get("name", npc_id))
	return npc_id


func to_dict() -> Dictionary:
	var out := {}
	for id in active:
		out[id] = active[id].duplicate(true)
	return {"active": out}


func load_dict(d: Variant) -> String:
	if not d is Dictionary or not d.get("active") is Dictionary:
		return "missions section missing"
	var loaded := {}
	for id in d.active:
		var a: Variant = d.active[id]
		if not catalog.has(id):
			continue  # mission removed from data: drop it rather than fail the whole save
		if not a is Dictionary or not (a.get("objective") is float or a.get("objective") is int):
			return "mission %s has bad progress data" % id
		var m: MissionData = catalog[id]
		loaded[id] = {"objective": clampi(int(a.objective), 0, m.objectives.size() - 1),
			"count": float(a.get("count", 0)), "seen": Array(a.get("seen", [])),
			"started": float(a.get("started", absolute_minutes()))}
	active = loaded
	return ""
