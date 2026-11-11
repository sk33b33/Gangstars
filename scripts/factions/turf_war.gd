class_name TurfWar
extends Node
## Turf wars on street corners (TurfState holds the numbers). Owned by the GameSession.
## - Take a corner: stand on it with no owner crew standing there (fight them off first; they
##   come at you). Crew-mates along make it faster. Reward: cash, reputation, influence.
## - Rival pushes: once you've made a name, rival crews move on your corners now and then: a
##   few members walk over and post up. Go and see them off (they fight), or lose the corner.
##   Your clients in that suburb take it badly.
## - Tags: rivals spray their tag on a wall at corners they hold or push on. Paint over it.
## Game-like and abstract on purpose (see CLAUDE.md).

signal message(text: String)

const TICK := 0.5
const PROVOKE_RANGE := 9.0
const TAGS := {"tortel_crew": "tag_tortel", "vlakte_vipers": "tag_vlakte", "duin_boys": "tag_duin", "klipspringers": "tag_klip"}

var state := TurfState.load_default()
var district: District
var player: Player
var progression: ProgressionState
var police: PoliceDispatch
var dealing: DealingController
var interiors: InteriorSystem
var pushers: Dictionary = {}     # corner id -> Array[Resident]
var allies: Array = []           # crews that never push on your corners (story choices)
var tags: Dictionary = {}        # corner id -> {decal, interactable, crew}

var _rng := RandomNumberGenerator.new()
var _tick := 0.0
var _last := -1.0
var _dt := 0.0


func setup(p_district: District, p_player: Player, p_progression: ProgressionState, p_police: PoliceDispatch,
		p_dealing: DealingController, p_interiors: InteriorSystem) -> void:
	district = p_district
	player = p_player
	progression = p_progression
	police = p_police
	dealing = p_dealing
	interiors = p_interiors
	_rng.seed = 4242
	# Corners whose anchor isn't in this world (district not built) are dropped.
	for id in Array(state.order):
		if not district.destinations.has(str(state.corners[id].anchor)):
			state.corners.erase(id)
			state.order.remove_at(state.order.find(id))
	state.flipped.connect(_on_flipped)
	state.push_started.connect(_on_push_started)
	state.push_ended.connect(_on_push_ended)
	state.next_push = 360.0   # played minutes until the first push
	_refresh_tags.call_deferred()


func minutes() -> float:
	return district.director.clock.day * 1440.0 + district.director.clock.minutes


func anchor(id: String) -> Vector3:
	return district.destinations.anchor_position(str(state.corners[id].anchor))


func area_of(id: String) -> String:
	return district.area_at(anchor(id))


func corner_name(id: String) -> String:
	return str(state.corners[id].name)


func crew_name(crew: String) -> String:
	return district.crews.display_name(crew) if not crew.is_empty() else "nobody"


func _physics_process(delta: float) -> void:
	if district == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	state.player_crew = progression.crew_id
	var now := minutes()
	var dt := clampf(now - _last, 0.0, 30.0) if _last >= 0.0 else 0.0
	_last = now
	_dt = dt
	state.tick(now, dt, presence)
	_provoke_pushers()
	_maybe_push(now)


## Who's standing on a corner (on foot, not indoors, not knocked down).
func presence(id: String) -> Dictionary:
	var at := anchor(id)
	var r2 := float(state.cfg.get("presence_radius", 12.0))
	var out := {"player": false, "crew": 0, "owners": 0, "pushers": 0}
	out.player = not player.is_down() and not player.is_driving() and not (interiors and interiors.is_inside()) \
		and _flat(player.global_position, at) < r2
	var owner := state.owner(id)
	var pusher := str(state.corners[id].push_crew)
	for r: Resident in district.residents.values():
		if r.is_inside or r.is_down() or _flat(r.global_position, at) > r2:
			continue
		if r.data.role == "player_crew" or (r.data.role == "crew" and r.data.faction_id == progression.crew_id):
			out.crew += 1
		elif r.data.role == "crew" and not owner.is_empty() and r.data.faction_id == owner and owner != progression.crew_id:
			out.owners += 1
		if r.data.role == "crew" and not pusher.is_empty() and r.data.faction_id == pusher:
			out.pushers += 1
	return out


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ------------------------------------------------------------------ rival pushes

func _maybe_push(now: float) -> void:
	# A countdown of played minutes (time skips and clock jumps count for at most 30 per tick).
	state.next_push -= _dt
	if state.next_push > 0.0 or progression.crew_id.is_empty():
		return
	state.next_push = _rng.randf_range(float(state.cfg.push_every_minutes[0]), float(state.cfg.push_every_minutes[1]))
	if progression.reputation < int(state.cfg.get("push_after_reputation", 10)):
		return
	var mine := state.players_corners().filter(func(id): return not state.pushed(id))
	if mine.is_empty() or Array(state.order).any(func(id): return state.pushed(id)):
		return
	start_push(mine[_rng.randi() % mine.size()])


## A rival crew from the corner's suburb moves on it. Returns the crew, or "" if none can.
func start_push(id: String, crew := "") -> String:
	var area := area_of(id)
	var members := {}
	for r: Resident in district.residents.values():
		if r.data.role == "crew" and r.data.faction_id != progression.crew_id and not r.data.faction_id.is_empty() and not allies.has(r.data.faction_id) \
				and not r.is_down() and district.resident_district(r) == area:
			if not members.has(r.data.faction_id):
				members[r.data.faction_id] = []
			members[r.data.faction_id].append(r)
	if crew.is_empty():
		for c in members:
			if crew.is_empty() or members[c].size() > members[crew].size():
				crew = c
	if crew.is_empty() or not members.has(crew):
		return ""
	var squad: Array = members[crew].slice(0, 3)
	for r: Resident in squad:
		r.brain.pending_event = {"activity": "guard", "destination": str(state.corners[id].anchor),
			"duration": float(state.cfg.get("push_minutes", 120)), "event": "turf"}
		if r.brain.state == NpcBrain.State.AT_HOME:
			r.brain.timer = minf(r.brain.timer, 1.0)
		elif r.brain.state in [NpcBrain.State.AT_DESTINATION, NpcBrain.State.SOCIALIZING, NpcBrain.State.GUARDING]:
			r.brain.timer = 0.0
	pushers[id] = squad
	state.start_push(id, crew, minutes())
	return crew


## Pushers on your corner square up to you when you come close.
func _provoke_pushers() -> void:
	for id in pushers:
		for r: Resident in pushers[id]:
			if is_instance_valid(r) and r.fight_target == null and r.can_fight() and not r.is_inside \
					and r.global_position.distance_to(player.global_position) < PROVOKE_RANGE and not player.is_down():
				police._provoke(r, "This corner's ours now, bru.")


func _on_push_started(id: String, crew: String) -> void:
	_refresh_tags()
	var text := "The %s are moving on %s! Get there or lose it." % [crew_name(crew), corner_name(id)]
	message.emit(text)


func _on_push_ended(id: String, held: bool) -> void:
	for r: Resident in pushers.get(id, []):
		if is_instance_valid(r) and str(r.brain.pending_event.get("event", "")) == "turf":
			r.brain.pending_event = {}
	pushers.erase(id)
	if held:
		progression.add_reputation(3)
		message.emit("You held %s." % corner_name(id))
	_refresh_tags()


func _on_flipped(id: String, old_owner: String, new_owner: String) -> void:
	var area := area_of(id)
	if new_owner == progression.crew_id:
		progression.add_cash(100)
		progression.add_reputation(4)
		progression.add_district_influence(area, 10)
		message.emit("CORNER TAKEN: %s is %s turf now (+R100)." % [corner_name(id).capitalize(), crew_name(new_owner)])
	elif old_owner == progression.crew_id:
		progression.add_district_influence(area, -10)
		var hit := 0
		if dealing:
			for npc in dealing.state.clients:
				var r: Resident = district.residents.get(npc)
				if r and district.resident_district(r) == area:
					dealing.state.change_mood(npc, -8.0, crew_name(new_owner))
					hit += 1
		message.emit("LOST %s to the %s.%s" % [corner_name(id), crew_name(new_owner), "  Your clients round there aren't happy." if hit > 0 else ""])
	_refresh_tags()


# ------------------------------------------------------------------ tags

## Rivals' tags on a wall at corners they hold or push on; paint over them.
func _refresh_tags() -> void:
	for id in state.order:
		var crew := str(state.corners[id].push_crew)
		if crew.is_empty() and state.owner(id) != progression.crew_id:
			crew = state.owner(id)
		var have: Dictionary = tags.get(id, {})
		if not have.is_empty() and have.crew == crew:
			continue
		_remove_tag(id)
		if not crew.is_empty() and TAGS.has(crew) and crew != progression.crew_id:
			_spray(id, crew)


func _spray(id: String, crew: String) -> void:
	var at := anchor(id) + Vector3(0, 1.3, 0)
	var space := district.get_world_3d().direct_space_state
	var best := {}
	for k in 12:
		var dir := Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0))
		var q := PhysicsRayQueryParameters3D.create(at, at + dir * 14.0, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and absf(hit.normal.y) < 0.3 and (best.is_empty() or at.distance_to(hit.position) < at.distance_to(best.position)):
			best = hit
	if best.is_empty():   # open ground: spray it on the tarmac
		best = {"position": anchor(id) + Vector3(1.5, 0.02, 1.5), "normal": Vector3.UP}
	var decal := Decal.new()
	decal.name = "Tag_" + id
	decal.texture_albedo = load(PixelMaterials.TEX_DIR + str(TAGS[crew]) + ".png")
	decal.size = Vector3(2.2, 0.6, 0.92)
	decal.cull_mask = 1
	district.add_child(decal)
	var n: Vector3 = best.normal
	var x := Vector3.UP.cross(n).normalized() if absf(n.y) < 0.9 else Vector3.RIGHT
	var at_wall: Vector3 = best.position + (x * 1.6 if absf(n.y) < 0.9 else Vector3.ZERO)   # beside any painted-on tag
	decal.global_transform = Transform3D(Basis(x, n, x.cross(n)), at_wall)
	var it := Interactable.new()
	it.name = "PaintOver_" + id
	it.kind = "tag"
	it.target = id
	it.radius = 1.4
	it.prompt = "Paint over the %s tag" % crew_name(crew)
	it.on_interact = paint_over.bind(id)
	district.add_child(it)
	it.global_position = at_wall + n * 0.8
	tags[id] = {"decal": decal, "interactable": it, "crew": crew}


func paint_over(id: String) -> String:
	var t: Dictionary = tags.get(id, {})
	if t.is_empty():
		return ""
	var crew := str(t.crew)
	state.paint_over(id)
	_remove_tag(id)
	tags[id] = {"decal": null, "interactable": null, "crew": crew}   # stays clean until the next change
	return "You paint over the %s tag at %s." % [crew_name(crew), corner_name(id)]


func _remove_tag(id: String) -> void:
	var t: Dictionary = tags.get(id, {})
	for key in ["decal", "interactable"]:
		if t.get(key) != null and is_instance_valid(t[key]):
			t[key].queue_free()
	tags.erase(id)


func tag_count() -> int:
	return tags.values().filter(func(t): return t.decal != null).size()
