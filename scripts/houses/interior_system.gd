class_name InteriorSystem
extends Node
## Lets the player go inside: their safehouse, Aunty Mavis' smokkie (opening hours) and any
## house where someone answers the door (knock first, then "Go inside"). The interior is built
## only on entry (InteriorBuilder), DEPTH metres under its own plot so the street simulation
## around it keeps running, and freed on the way out. Residents who are at home show up inside
## (sitting on the couch, in the kitchen) and can be talked to like outside. Police can't see
## you indoors, so heat cools off. Owned by the GameSession.

signal entered(place_id: String)
signal left(place_id: String)

const DEPTH := -40.0
const SHEBEEN := "shebeen"
const SHEBEEN_HOURS := Vector2(10, 23)
## How long a "come in" lasts after a knock (game minutes).
const WELCOME_MINUTES := 20.0

var session: GameSession
var district: District
var player: Player
var current := ""
var room: Node3D
var spots := {}
var shebeen_door: Interactable

var _exit_pos := Vector3.ZERO
var _exit_yaw := 0.0
var _stand_ins: Array = []          # [{model, resident, interactable}]
var _welcomes := {}                 # house id -> game minute the welcome runs out
var _fade: ColorRect
var _tick := 0.0


func setup(p_session: GameSession, p_district: District, p_player: Player, overlay_parent: Node) -> void:
	session = p_session
	district = p_district
	player = p_player
	var layer := CanvasLayer.new()
	layer.layer = 20
	overlay_parent.add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	if district.destinations.has("shebeen:door"):
		shebeen_door = Interactable.new()
		shebeen_door.name = "ShebeenDoor"
		shebeen_door.kind = "door"
		shebeen_door.target = SHEBEEN
		shebeen_door.radius = 1.3
		shebeen_door.prompt = "Go into Aunty Mavis' smokkie"
		shebeen_door.on_interact = func(): return ""
		district.add_child(shebeen_door)
		shebeen_door.global_position = district.destinations.anchor_position("shebeen:door") + Vector3(0, 1.0, 0)


func is_inside() -> bool:
	return not current.is_empty()


func minutes() -> float:
	return district.director.clock.day * 1440.0 + district.director.clock.minutes


# ------------------------------------------------------------------ who may go in

## "" if the player may go in now, else the reason.
func why_not(place_id: String) -> String:
	if is_inside():
		return "You're already inside."
	if player.is_driving():
		return "Park first."
	if place_id == GameSession.SAFEHOUSE_ID:
		return ""
	if place_id == SHEBEEN:
		var h := district.director.clock.minutes / 60.0
		if h < SHEBEEN_HOURS.x or h >= SHEBEEN_HOURS.y:
			return "Aunty Mavis' smokkie is closed. It opens at %02d:00." % int(SHEBEEN_HOURS.x)
		return ""
	var house := district.registry.get_house(place_id)
	if house == null:
		return "There's no way in."
	if float(_welcomes.get(place_id, -1.0)) < minutes():
		return "Knock first."
	return ""


## Called after someone answers a knock: the door stays open and the prompt says "Go inside".
func welcome(house_id: String) -> void:
	_welcomes[house_id] = minutes() + WELCOME_MINUTES
	var plot: HousePlot = district.plots.get(house_id)
	if plot:
		plot.door_interactable.prompt = "Go inside %s" % plot.data.address()


func is_welcome(house_id: String) -> bool:
	return float(_welcomes.get(house_id, -1.0)) >= minutes()


# ------------------------------------------------------------------ in and out

## Goes inside. Returns "" or why not.
func enter(place_id: String) -> String:
	var why := why_not(place_id)
	if not why.is_empty():
		return why
	var kind := "home"
	var origin := Vector3.ZERO
	if place_id == SHEBEEN:
		kind = "shebeen"
		var door := district.destinations.anchor_position("shebeen:door")
		var out := (district.destinations.anchor_position("poi_shebeen") - door)
		out.y = 0.0
		out = out.normalized() if out.length() > 0.1 else Vector3.BACK
		_exit_pos = door + out * 1.4
		_exit_yaw = atan2(-out.x, -out.z) + PI
		origin = door
	else:
		var plot: HousePlot = district.plots.get(place_id)
		if plot == null:
			return "There's no way in."
		kind = "safehouse" if place_id == GameSession.SAFEHOUSE_ID else "home"
		var out := plot.global_basis.z
		_exit_pos = plot.door_position() + out * 0.6
		_exit_yaw = atan2(-out.x, -out.z) + PI
		origin = plot.door_position()
		plot.open_door(1.5)
		district.door_opened.emit(plot.door_position())
	room = Node3D.new()
	room.name = "Interior_" + place_id
	district.add_child(room)
	room.global_position = Vector3(origin.x, DEPTH, origin.z)
	spots = InteriorBuilder.build(room, kind, absi(place_id.hash()))
	current = place_id
	_add_people(place_id, kind)
	_add_fittings(kind)
	_update_daylight()
	_move_player(room.to_global(spots.spawn), room.global_rotation.y)
	_flash()
	entered.emit(place_id)
	return ""


## Back out to the street at the door.
func leave() -> void:
	if not is_inside():
		return
	var was := current
	_move_player(_exit_pos + Vector3(0, 0.1, 0), _exit_yaw)
	_cleanup()
	var plot: HousePlot = district.plots.get(was)
	if plot:
		plot.open_door(1.2)
		district.door_opened.emit(plot.door_position())
	_flash()
	left.emit(was)


## Where the player stands outside (for saving while indoors).
func outside_position() -> Vector3:
	return _exit_pos


## Drops the interior without moving the player (load, knockout wake-up, debug teleport).
func discard() -> void:
	if is_inside():
		var was := current
		_cleanup()
		left.emit(was)


func _cleanup() -> void:
	for s in _stand_ins:
		if is_instance_valid(s.model):
			s.model.queue_free()
	_stand_ins.clear()
	if room:
		room.queue_free()
	room = null
	spots = {}
	current = ""


func _move_player(pos: Vector3, yaw: float) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = pos
	player.pivot.rotation.y = yaw
	var fwd := -Basis(Vector3.UP, yaw).z
	player.model.rotation.y = atan2(fwd.x, fwd.z)   # face where the camera looks
	player.reset_physics_interpolation()
	player.snap_camera()


func _flash() -> void:
	if _fade == null:
		return
	_fade.color.a = 1.0
	var t := _fade.create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.45)


# ------------------------------------------------------------------ inside

func _add_fittings(kind: String) -> void:
	var exit := _interactable("Exit", "Go outside", spots.exit, func():
		leave.call_deferred()
		return "")
	exit.kind = "exit"
	exit.target = current
	if kind == "safehouse":
		_interactable("Stash", "Open your stash (safehouse)", spots.stash, func():
			session.open_safehouse_menu()
			return "")
		_interactable("Bed", "Rest (safehouse)", spots.bed, func():
			session.open_safehouse_menu()
			return "")
	if kind == "shebeen" and session.dealing:
		var counter := _interactable("Counter", "Serve at Aunty Mavis' counter", spots.counter, session.dealing.serve_counter)
		counter.kind = "counter"
		counter.target = SHEBEEN


func _interactable(n: String, prompt: String, at: Vector3, fn: Callable) -> Interactable:
	var it := Interactable.new()
	it.name = n
	it.prompt = prompt
	it.radius = 1.1
	it.on_interact = fn
	room.add_child(it)
	it.position = at
	return it


## Residents who are at home, inside: on the couch, in the kitchen. Mavis behind her bar, and a
## few regulars on smokkie nights.
func _add_people(place_id: String, kind: String) -> void:
	var seats: Array = spots.seats.duplicate()
	var stands: Array = spots.stands.duplicate()
	if kind == "shebeen":
		var mavis: Resident = district.residents.get("npc_mavis")
		if mavis and not mavis.is_down():
			_stand_in(mavis, spots.host, false)
		var h := district.director.clock.minutes / 60.0
		if h >= 17.0:
			var regulars := district.residents.values().filter(func(r): return r.data.role == "resident" and r.data.id != "npc_mavis" \
					and not r.is_down() and r.global_position.distance_to(district.destinations.anchor_position("poi_shebeen")) < 12.0)
			for r: Resident in regulars.slice(0, seats.size() + stands.size()):
				var sitting := not seats.is_empty()
				_stand_in(r, seats.pop_front() if sitting else stands.pop_front(), sitting)
		return
	var house := district.registry.get_house(place_id)
	if house == null:
		return
	for id in house.occupant_ids:
		var r: Resident = district.residents.get(id)
		if r == null or not r.is_inside or r.is_down():
			continue
		if not seats.is_empty():
			_stand_in(r, seats.pop_front(), true)
		elif not stands.is_empty():
			_stand_in(r, stands.pop_front(), false)


func _stand_in(r: Resident, spot: Dictionary, sitting: bool) -> void:
	var m := CharacterModel.new()
	m.name = "StandIn_" + r.data.id
	room.add_child(m)
	m.build(r.data.shirt_color, r.data.pants_color, r.data.skin_color, Color(0, 0, 0, 0), r.data.appearance())
	m.position = spot.pos
	m.rotation.y = spot.yaw
	if sitting:
		m.base_pose = "sit"
	var it := Interactable.new()
	it.name = "Talk"
	it.kind = "npc"
	it.target = r.data.id
	it.prompt = r.interactable.prompt
	it.radius = 1.0
	it.on_interact = r.interactable.on_interact
	m.add_child(it)
	it.position = Vector3(0, 1.0, 0)
	_stand_ins.append({"model": m, "resident": r, "interactable": it})


func _process(delta: float) -> void:
	if not is_inside():
		return
	for s in _stand_ins:
		if is_instance_valid(s.model):
			s.model.mode = "talk" if player.global_position.distance_to(s.model.global_position) < 2.5 else "idle"
			s.model.look_at_point(player.global_position + Vector3(0, 1.5, 0))
			s.model.animate(delta, 0.0)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	# The player was moved out some other way (knocked out, loaded a save, a test): drop the room.
	if room == null or player.global_position.distance_to(room.global_position) > 30.0:
		discard()
		return
	_update_daylight()
	# Someone who heads out leaves the room (only home occupants; Mavis stays at her bar).
	for s in _stand_ins.duplicate():
		var r: Resident = s.resident
		if current != SHEBEEN and (not r.is_inside or r.is_down()):
			s.model.queue_free()
			_stand_ins.erase(s)


func _update_daylight() -> void:
	var h := district.director.clock.minutes / 60.0
	var day := clampf(minf(h - 5.5, 19.5 - h) / 1.5, 0.0, 1.0)
	for w: MeshInstance3D in spots.get("windows", []):
		var m := w.material_override as StandardMaterial3D
		if m:
			m.emission_energy_multiplier = lerpf(0.05, 1.1, day)
			m.albedo_color = Color.WHITE.lerp(Color("#30384a"), 1.0 - day)


func stand_in_count() -> int:
	return _stand_ins.size()


func _physics_process(_delta: float) -> void:
	# Welcomes run out: the door goes back to "Knock".
	for id in _welcomes.keys():
		if float(_welcomes[id]) < minutes():
			_welcomes.erase(id)
			var plot: HousePlot = district.plots.get(id)
			if plot:
				plot.door_interactable.prompt = "Knock on %s" % plot.data.address()
