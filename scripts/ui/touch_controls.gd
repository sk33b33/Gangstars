class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (Android, iOS), shown only on a touchscreen (or with the
## --touch argument for testing on a PC):
##   left stick  - move (and steer/accelerate when driving)
##   right stick - look
##   LOCK        - toggles auto-lock aim (raises the weapon and swings onto the nearest armed stranger)
##   buttons     - Talk/interact, Sprint (tap to toggle), Jump, Aim (hold), Shoot (hold), and a column on
##                 the right edge: Menu, Phone, Map, Whistle, Radio.
## Everything goes through the normal input actions (InputEventAction), so the game code doesn't know
## the difference. Taps on the controls never reach the game world; menus (which switch the player's
## input off) hide the controls and work with plain touch taps.

const STICK_RADIUS := 105.0
const DEAD := 0.15

var player: Player
var enabled := false
var _draw_node: Control
var _touches := {}           # touch index -> "move" | "look" | button id
var _stick_pos := {"move": Vector2.ZERO, "look": Vector2.ZERO}   # knob offsets, pixels
var _sprint_on := false
var _was_visible := false

## id, action, label, hold (true) or tap (false), radius, at: [from the right edge, from the bottom edge],
## or from the top edge for the "top" buttons
var _buttons := [
	{"id": "interact", "action": "interact", "label": "TALK", "hold": false, "r": 58.0, "at": [330.0, 150.0]},
	{"id": "sprint", "action": "sprint", "label": "RUN", "hold": true, "toggle": true, "r": 46.0, "at": [470.0, 70.0]},
	{"id": "jump", "action": "jump", "label": "JUMP", "hold": false, "r": 42.0, "at": [470.0, 200.0]},
	{"id": "aim", "action": "aim", "label": "AIM", "hold": true, "r": 46.0, "at": [215.0, 330.0]},
	{"id": "lock", "action": "", "label": "LOCK", "hold": false, "toggle": true, "r": 46.0, "at": [90.0, 330.0]},
	{"id": "fire", "action": "fire", "label": "FIRE", "hold": true, "r": 56.0, "at": [190.0, 345.0], "left": true},
	{"id": "pause", "action": "pause", "label": "MENU", "hold": false, "r": 30.0, "at": [48.0, 115.0], "top": true},
	{"id": "phone", "action": "phone", "label": "PHONE", "hold": false, "r": 30.0, "at": [48.0, 185.0], "top": true},
	{"id": "turf_map", "action": "turf_map", "label": "MAP", "hold": false, "r": 30.0, "at": [48.0, 255.0], "top": true},
	{"id": "shout", "action": "shout", "label": "HEY", "hold": false, "r": 30.0, "at": [120.0, 255.0], "top": true},
	{"id": "radio", "action": "radio", "label": "RADIO", "hold": false, "r": 30.0, "at": [120.0, 185.0], "top": true},
]


func setup(p_player: Player, force := false) -> void:
	player = p_player
	layer = 8
	enabled = force or DisplayServer.is_touchscreen_available()
	_draw_node = Control.new()
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	player.mouse_look_enabled = not enabled   # touch drags must not turn the camera by themselves
	visible = false


func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _stick_centre(id: String) -> Vector2:
	var s := _size()
	return Vector2(190.0, s.y - 170.0) if id == "move" else Vector2(s.x - 170.0, s.y - 140.0)


## Button centre in screen pixels. "top" buttons hang from the top right (below the health), the
## others from the bottom right.
func _button_centre(b: Dictionary) -> Vector2:
	var s := _size()
	var at: Array = b.at
	if b.get("left", false):   # from the left edge, above the move stick
		return Vector2(float(at[0]), s.y - float(at[1]))
	if b.get("top", false):
		return Vector2(s.x - float(at[0]), float(at[1]))
	return Vector2(s.x - float(at[0]), s.y - float(at[1]))


func _process(_delta: float) -> void:
	var show_now := enabled and player != null and player.input_enabled
	if show_now != _was_visible:
		_was_visible = show_now
		visible = show_now
		if not show_now:
			_release_all()
	if visible:
		_apply_sticks()
		_draw_node.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var hit := _hit(event.position)
			if hit != "":
				_touches[event.index] = hit
				_begin(hit, event.position)
				get_viewport().set_input_as_handled()
		elif _touches.has(event.index):
			_end(str(_touches[event.index]))
			_touches.erase(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var id := str(_touches[event.index])
		if id == "move" or id == "look":
			_stick_pos[id] = _clamped(event.position - _stick_centre(id))
		get_viewport().set_input_as_handled()


func _hit(p: Vector2) -> String:
	for b in _buttons:
		if p.distance_to(_button_centre(b)) <= float(b.r) * 1.15:
			return str(b.id)
	for id in ["move", "look"]:
		if p.distance_to(_stick_centre(id)) <= STICK_RADIUS * 1.5:
			return id
	return ""


func _clamped(v: Vector2) -> Vector2:
	return v.limit_length(STICK_RADIUS)


func _begin(id: String, p: Vector2) -> void:
	if id == "move" or id == "look":
		_stick_pos[id] = _clamped(p - _stick_centre(id))
		return
	var b := _button(id)
	if id == "lock":
		player.auto_lock = not player.auto_lock
		return
	if bool(b.get("toggle", false)):
		_sprint_on = not _sprint_on
		_send(str(b.action), _sprint_on)
	else:
		_send(str(b.action), true)


func _end(id: String) -> void:
	if id == "move" or id == "look":
		_stick_pos[id] = Vector2.ZERO
		return
	var b := _button(id)
	if id != "lock" and not bool(b.get("toggle", false)):
		_send(str(b.action), false)


func _button(id: String) -> Dictionary:
	for b in _buttons:
		if b.id == id:
			return b
	return {}


func _send(action: String, pressed: bool, strength := 1.0) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = strength if pressed else 0.0
	Input.parse_input_event(e)


## Pushes the stick positions into the move_* and look_* actions (analogue strength).
func _apply_sticks() -> void:
	var mv := _axis(_stick_pos.move)
	_set_axis("move_left", "move_right", mv.x)
	_set_axis("move_forward", "move_backward", mv.y)
	var lk := _axis(_stick_pos.look)
	_set_axis("look_left", "look_right", lk.x)
	_set_axis("look_up", "look_down", lk.y)


func _axis(v: Vector2) -> Vector2:
	var a := v / STICK_RADIUS
	if a.length() < DEAD:
		return Vector2.ZERO
	return a


func _set_axis(neg: String, pos: String, value: float) -> void:
	var want_neg := maxf(-value, 0.0)
	var want_pos := maxf(value, 0.0)
	if not is_equal_approx(Input.get_action_strength(neg), want_neg):
		_send(neg, want_neg > 0.0, want_neg)
	if not is_equal_approx(Input.get_action_strength(pos), want_pos):
		_send(pos, want_pos > 0.0, want_pos)


func _release_all() -> void:
	_touches.clear()
	_stick_pos = {"move": Vector2.ZERO, "look": Vector2.ZERO}
	_apply_sticks()
	for b in _buttons:
		if str(b.action) != "" and Input.is_action_pressed(str(b.action)) and b.action != "pause":
			_send(str(b.action), false)
	_sprint_on = false
	if player:
		player.auto_lock = false


func _on_draw() -> void:
	var font := ThemeDB.fallback_font
	for id in ["move", "look"]:
		var c := _stick_centre(id)
		_draw_node.draw_circle(c, STICK_RADIUS, Color(1, 1, 1, 0.10))
		_draw_node.draw_arc(c, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
		_draw_node.draw_circle(c + _stick_pos[id], 44.0, Color(1, 0.85, 0.37, 0.45))
		var name_txt := "MOVE" if id == "move" else "LOOK"
		_draw_node.draw_string(font, c + Vector2(-24, STICK_RADIUS + 24), name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.55))
	for b in _buttons:
		var c2 := _button_centre(b)
		var down: bool = _touches.values().has(b.id) or (b.id == "sprint" and _sprint_on) or (b.id == "lock" and player.auto_lock)
		_draw_node.draw_circle(c2, float(b.r), Color(1.0, 0.85, 0.37, 0.5) if down else Color(0.05, 0.06, 0.09, 0.45))
		_draw_node.draw_arc(c2, float(b.r), 0.0, TAU, 28, Color(1, 1, 1, 0.5), 2.5)
		var w: float = font.get_string_size(str(b.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_draw_node.draw_string(font, c2 + Vector2(-w * 0.5, 6), str(b.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
