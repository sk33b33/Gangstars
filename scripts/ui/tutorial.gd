class_name Tutorial
extends Node
## First-time tips for a new game: a short card at the top of the screen that asks for one thing at
## a time (move, look, sprint, talk to someone, open the map, the phone, whistle) and ticks over
## when you do it. Tab (or D-pad left) skips it all. It never blocks anything. It runs once per
## save (progression flag "tutorial_done"); the pause menu can switch tips off or replay them.

signal finished(skipped: bool)

const STEPS := [
	{"id": "move", "text": "Move around with %s.", "keys": ["move"]},
	{"id": "look", "text": "Look around with the %s.", "keys": ["look"]},
	{"id": "sprint", "text": "Hold %s while you move to sprint.", "keys": ["sprint"]},
	{"id": "talk", "text": "Follow the gold marker and press %s to talk to someone. That's how missions start.", "keys": ["interact"]},
	{"id": "map", "text": "Press %s to open the turf map. Corners you hold show your colour.", "keys": ["turf_map"]},
	{"id": "phone", "text": "Press %s to open your phone.", "keys": ["phone"]},
	{"id": "whistle", "text": "Press %s to whistle. People nearby look round.", "keys": ["shout"]},
]
const END_TEXT := "That's the basics. Missions are in the top left, the gold marker shows where to go, and Esc opens the menu (you can re-bind keys there)."

var hud: Hud
var player: Player
var session: GameSession
var enabled := true            # the "tips" setting
var active := false
var index := 0

var _checked := false
var _start_pos := Vector3.ZERO
var _yaw := 0.0
var _yaw_moved := 0.0
var _seen := {}
var _end_timer := 0.0


func setup(p_hud: Hud, p_player: Player, p_session: GameSession) -> void:
	hud = p_hud
	player = p_player
	session = p_session
	player.interacted.connect(func(_m): _seen["talk"] = true)
	player.shouted.connect(func(_p): _seen["whistle"] = true)


## Starts the tips if this save hasn't had them and tips are on.
func maybe_start() -> void:
	_checked = true
	if not enabled or session.progression.flags.has("tutorial_done") or not session.progression.completed_mission_ids.is_empty():
		return
	begin()


func begin() -> void:
	active = true
	index = 0
	_seen.clear()
	_end_timer = 0.0
	_start_pos = player.global_position
	_yaw = player.pivot.rotation.y
	_yaw_moved = 0.0
	_show()


func restart() -> void:
	session.progression.flags.erase("tutorial_done")
	begin()


func skip() -> void:
	if active:
		_finish(true)


func current_id() -> String:
	return "end" if index >= STEPS.size() else str(STEPS[index].id)


func _process(delta: float) -> void:
	if hud == null or player == null:
		return
	if not _checked:   # wait for the crew choice (input is off while the picker is open)
		if player.input_enabled and session.progression.crew_id != "":
			maybe_start()
		return
	if not active:
		return
	var yaw := player.pivot.rotation.y
	_yaw_moved += absf(angle_difference(_yaw, yaw))
	_yaw = yaw
	if index >= STEPS.size():
		_end_timer -= delta
		if _end_timer <= 0.0:
			_finish(false)
		return
	if player.input_enabled and _step_done(current_id()):
		index += 1
		if index >= STEPS.size():
			_end_timer = 9.0
		_show()


func _step_done(id: String) -> bool:
	match id:
		"move":
			return player.global_position.distance_to(_start_pos) > 4.0
		"look":
			return _yaw_moved > 0.9
		"sprint":
			return Input.is_action_pressed("sprint") and player.velocity.length() > 3.0
		"talk":
			return _seen.has("talk")
		"map":
			return session.turf_map != null and session.turf_map.visible
		"phone":
			return session.phone != null and session.phone.visible
		"whistle":
			return _seen.has("whistle")
	return false


func _show() -> void:
	if index >= STEPS.size():
		hud.show_tip("TIPS", END_TEXT, "")
		return
	var step: Dictionary = STEPS[index]
	var keys: Array = step.keys.map(func(k): return "[%s]" % InputHints.key(k))
	hud.show_tip("HOW TO PLAY  %d/%d" % [index + 1, STEPS.size()], str(step.text) % keys[0], "Skip tips: [%s]" % InputHints.key("skip_tips"))


## The device changed (keyboard <-> pad): show the same step with the new key names.
func refresh() -> void:
	if active:
		_show()


func _finish(skipped: bool) -> void:
	active = false
	session.progression.flags["tutorial_done"] = true
	hud.hide_tip()
	finished.emit(skipped)


func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("skip_tips"):
		skip()
		get_viewport().set_input_as_handled()
