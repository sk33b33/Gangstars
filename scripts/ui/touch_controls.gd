class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (Android, iOS), shown only on a touchscreen (or with the
## --touch argument for testing on a PC):
##   left stick  - move (and steer/accelerate when driving)
##   right stick - look
##   LOCK        - toggles auto-lock aim (raises the weapon and swings onto the nearest armed stranger)
##   buttons     - Talk/interact, Sprint (tap to toggle), Jump, Aim (hold), Shoot (hold), and a column on
##                 the right edge: Menu, Phone, Map, Whistle, Radio. The player can move, remove and add
##                 buttons (Menu > Edit touch controls): see TouchLayout and the edit mode below.
## Everything goes through the normal input actions (InputEventAction), so the game code doesn't know
## the difference. Taps on the controls never reach the game world; menus (which switch the player's
## input off) hide the controls and work with plain touch taps.

signal edit_finished(layout: Dictionary)

const STICK_RADIUS := 105.0
const DEAD := 0.15
const DRAG_SLOP := 10.0          # a touch that moves less than this is a tap (edit mode)
const BADGE_RADIUS := 15.0       # the small x that appears on a selected button

var player: Player
var enabled := false
var _draw_node: Control
var _touches := {}           # touch index -> "move" | "look" | button id
var _stick_pos := {"move": Vector2.ZERO, "look": Vector2.ZERO}   # knob offsets, pixels
var _sprint_on := false
var _was_visible := false

## The buttons now on screen (from `layout`): id, action, label, hold, radius, ...
var _buttons: Array = []
var layout := TouchLayout.new()

# Edit mode (Menu > Edit touch controls): drag to move, tap once to select (a small x appears), tap the x to remove.
var editing := false
var _selected := ""
var _drag := {}                  # {id, index, from, grab, moved} while a button is being dragged
var _edit_ui: Control
var _toolbar: PanelContainer
var _picker: PanelContainer
var _picker_list: VBoxContainer


func setup(p_player: Player, force := false) -> void:
	player = p_player
	layer = 8
	enabled = force or DisplayServer.is_touchscreen_available()
	_draw_node = Control.new()
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	_rebuild()
	player.mouse_look_enabled = not enabled   # touch drags must not turn the camera by themselves
	if enabled:
		strip_mouse_bindings()
	visible = false


## A touch also arrives as an emulated left-click (that's how menus work with taps), and left-click is
## bound to "fire": every tap on AIM or LOCK would shoot. So on a touchscreen the mouse buttons are
## taken off the combat actions; the FIRE button sends "fire" itself. Returns what it removed.
func strip_mouse_bindings() -> Array:
	var removed: Array = []
	for action in ["fire", "aim"]:
		for e in InputMap.action_get_events(action):
			if e is InputEventMouseButton:
				removed.append([action, e])
				InputMap.action_erase_event(action, e)
	return removed


func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _stick_centre(id: String) -> Vector2:
	var s := _size()
	return Vector2(190.0, s.y - 170.0) if id == "move" else Vector2(s.x - 170.0, s.y - 140.0)


## Button centre in screen pixels (from the layout: the default place, or where the player put it).
func _button_centre(b: Dictionary) -> Vector2:
	return layout.centre(b, _size())


## Loads a saved layout (settings `touch/layout`) and puts the buttons where it says.
func apply_layout(saved: Variant) -> void:
	layout.load_dict(saved)
	_rebuild()


func _rebuild() -> void:
	_buttons = layout.active()


func _process(_delta: float) -> void:
	if editing:
		visible = true
		_draw_node.queue_redraw()
		return
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
	if editing:
		_edit_input(event)
		return
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
	if editing:
		_draw_node.draw_rect(Rect2(Vector2.ZERO, _size()), Color(0, 0, 0, 0.38))
	for id in ["move", "look"]:
		var c := _stick_centre(id)
		var fade := 0.45 if editing else 1.0
		_draw_node.draw_circle(c, STICK_RADIUS, Color(1, 1, 1, 0.10 * fade))
		_draw_node.draw_arc(c, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.35 * fade), 3.0)
		if not editing:
			_draw_node.draw_circle(c + _stick_pos[id], 44.0, Color(1, 0.85, 0.37, 0.45))
		var name_txt := "MOVE" if id == "move" else "LOOK"
		_draw_node.draw_string(font, c + Vector2(-24, STICK_RADIUS + 24), name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.55 * fade))
	for b in _buttons:
		var c2 := _button_centre(b)
		var chosen := editing and str(b.id) == _selected
		var down: bool = not editing and (_touches.values().has(b.id) or (b.id == "sprint" and _sprint_on) or (b.id == "lock" and player.auto_lock))
		var fill := Color(1.0, 0.85, 0.37, 0.5) if down else Color(0.05, 0.06, 0.09, 0.55 if editing else 0.45)
		_draw_node.draw_circle(c2, float(b.r), fill)
		_draw_node.draw_arc(c2, float(b.r), 0.0, TAU, 28, Color("#ffd75e") if chosen else Color(1, 1, 1, 0.5), 5.0 if chosen else 2.5)
		var w: float = font.get_string_size(str(b.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_draw_node.draw_string(font, c2 + Vector2(-w * 0.5, 6), str(b.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
		if chosen and layout.can_remove(str(b.id)):   # the small x that removes it
			var badge := _badge_centre(b)
			_draw_node.draw_circle(badge, BADGE_RADIUS, Color("#d6403e"))
			_draw_node.draw_arc(badge, BADGE_RADIUS, 0.0, TAU, 20, Color.WHITE, 2.0)
			_draw_node.draw_line(badge + Vector2(-5, -5), badge + Vector2(5, 5), Color.WHITE, 3.0)
			_draw_node.draw_line(badge + Vector2(-5, 5), badge + Vector2(5, -5), Color.WHITE, 3.0)
		elif chosen:
			var note := "stays: it opens the menu"
			var nw: float = font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_draw_node.draw_string(font, c2 + Vector2(-nw * 0.5, float(b.r) + 20), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffd75e"))


# ------------------------------------------------------------------ edit mode

## Where the small x sits on a button: its top right.
func _badge_centre(b: Dictionary) -> Vector2:
	return _button_centre(b) + Vector2(1.0, -1.0) * float(b.r) * 0.78


## Starts editing: the game stays paused, every button can be dragged, tapped (to select) and removed.
func begin_edit() -> void:
	_release_all()
	editing = true
	_selected = ""
	_drag = {}
	process_mode = Node.PROCESS_MODE_ALWAYS   # the game is paused behind the editor
	if _edit_ui == null:
		_build_edit_ui()
	_edit_ui.visible = true
	_picker.visible = false
	visible = true


## Done: saves nothing itself (the caller stores `layout.to_dict()` from the signal), hides the editor.
func end_edit() -> void:
	if not editing:
		return
	editing = false
	_selected = ""
	_drag = {}
	_edit_ui.visible = false
	_picker.visible = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_was_visible = false   # _process works out again whether the controls show
	edit_finished.emit(layout.to_dict())


func _build_edit_ui() -> void:
	_edit_ui = Control.new()
	_edit_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edit_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edit_ui)
	_toolbar = PanelContainer.new()
	_toolbar.name = "EditToolbar"
	_toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toolbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toolbar.offset_top = 10
	_style(_toolbar)
	_edit_ui.add_child(_toolbar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_toolbar.add_child(col)
	var hint := Label.new()
	hint.text = "EDIT CONTROLS: drag a button to move it. Tap it once to select it, then tap the red x to remove it."
	hint.add_theme_font_size_override("font_size", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for spec in [["AddButton", "+ Add button", _open_picker], ["ResetLayout", "Reset to default", reset_layout], ["DoneEditing", "Done", end_edit]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.custom_minimum_size = Vector2(170, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(spec[2])
		PauseMenu._outline(b)
		row.add_child(b)
	_picker = PanelContainer.new()
	_picker.name = "AddPicker"
	_picker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_picker.offset_left = -260
	_picker.offset_right = 260
	_picker.offset_top = -190
	_picker.offset_bottom = 190
	_style(_picker)
	_edit_ui.add_child(_picker)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 6)
	_picker.add_child(pcol)
	var title := Label.new()
	title.text = "Add a button (tap one)"
	title.add_theme_font_size_override("font_size", 20)
	pcol.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pcol.add_child(scroll)
	_picker_list = VBoxContainer.new()
	_picker_list.custom_minimum_size = Vector2(480, 0)
	_picker_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_picker_list)
	var cancel := Button.new()
	cancel.name = "CancelAdd"
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 52)
	cancel.pressed.connect(func(): _picker.visible = false)
	PauseMenu._outline(cancel)
	pcol.add_child(cancel)
	_picker.visible = false


func _style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.border_color = Color("#ffd75e")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)


## Lists the buttons that are not on screen; tapping one puts it there.
func _open_picker() -> void:
	for c in _picker_list.get_children():
		c.queue_free()
	var left := layout.available()
	if left.is_empty():
		var none := Label.new()
		none.text = "Every button is already on the screen."
		_picker_list.add_child(none)
	for b: Dictionary in left:
		var btn := Button.new()
		btn.name = "Add_" + str(b.id)
		btn.text = "%s  -  %s" % [b.label, b.name]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 54)
		btn.add_theme_font_size_override("font_size", 19)
		btn.pressed.connect(add_button.bind(str(b.id)))
		PauseMenu._outline(btn)
		_picker_list.add_child(btn)
	_picker.visible = true


## Puts a button on screen (an extra one appears near the top middle, ready to be dragged) and selects it.
func add_button(id: String) -> void:
	if layout.add(id):
		_rebuild()
		_selected = id
	_picker.visible = false


func remove_button(id: String) -> bool:
	if not layout.remove(id):
		return false
	_rebuild()
	if _selected == id:
		_selected = ""
	return true


func reset_layout() -> void:
	layout.reset()
	_rebuild()
	_selected = ""


## The topmost button under `p` ("" when none).
func _button_at(p: Vector2) -> String:
	for i in range(_buttons.size() - 1, -1, -1):
		var b: Dictionary = _buttons[i]
		if p.distance_to(_button_centre(b)) <= float(b.r) * 1.15:
			return str(b.id)
	return ""


func _over_editor_ui(p: Vector2) -> bool:
	if _picker.visible:
		return true   # the picker is modal: touches outside it do nothing
	return _toolbar.get_global_rect().has_point(p)


## Touches in edit mode: a touchscreen sends touch events; on a PC the mouse does (a phone's emulated
## mouse events are ignored so one tap is not handled twice).
func _edit_input(event: InputEvent) -> void:
	var kind := ""
	var index := 0
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		kind = "down" if event.pressed else "up"
		index = event.index
		pos = event.position
	elif event is InputEventScreenDrag:
		kind = "move"
		index = event.index
		pos = event.position
	elif not DisplayServer.is_touchscreen_available() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		kind = "down" if event.pressed else "up"
		index = -1
		pos = event.position
	elif not DisplayServer.is_touchscreen_available() and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		kind = "move"
		index = -1
		pos = event.position
	if kind == "":
		return
	if _over_editor_ui(pos) and _drag.is_empty():
		return   # the toolbar's and the picker's own buttons take it
	match kind:
		"down":
			_edit_press(index, pos)
		"move":
			_edit_move(index, pos)
		"up":
			_edit_release(index, pos)
	get_viewport().set_input_as_handled()


func _edit_press(index: int, p: Vector2) -> void:
	if not _drag.is_empty():
		return
	if _selected != "" and layout.can_remove(_selected):
		var chosen := _button(_selected)
		if not chosen.is_empty() and p.distance_to(_badge_centre(chosen)) <= BADGE_RADIUS * 1.7:
			remove_button(_selected)
			return
	var hit := _button_at(p)
	if hit == "":
		_selected = ""
		return
	_drag = {"id": hit, "index": index, "from": p, "grab": _button_centre(_button(hit)) - p, "moved": false}


func _edit_move(index: int, p: Vector2) -> void:
	if _drag.is_empty() or int(_drag.index) != index:
		return
	if not bool(_drag.moved) and p.distance_to(_drag.from) > DRAG_SLOP:
		_drag.moved = true
	if bool(_drag.moved):
		layout.move(str(_drag.id), p + (_drag.grab as Vector2), _size())


func _edit_release(index: int, _p: Vector2) -> void:
	if _drag.is_empty() or int(_drag.index) != index:
		return
	if not bool(_drag.moved):
		_selected = str(_drag.id)   # a tap: highlight it, the small x appears
	_drag = {}
