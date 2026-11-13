class_name PauseMenu
extends Control
## Esc menu: pauses the game; audio, controls, video and gameplay settings (saved on change).

signal resumed
signal quit_requested
signal replay_tutorial

var settings: SettingsStore
var _rows: VBoxContainer


func setup(p_settings: SettingsStore) -> void:
	settings = p_settings
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -320
	panel.offset_bottom = 320
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_color = Color("#ffd75e")
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(620, 0)
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)
	_build()
	visible = false


func _build() -> void:
	_heading("PAUSED", 28)
	var resume := Button.new()
	resume.name = "Resume"
	resume.text = "Resume (Esc / Menu)"
	resume.pressed.connect(close)
	_rows.add_child(resume)
	_heading("Audio", 20)
	_slider("Master volume", "audio/master", 0.0, 1.0, 0.05)
	_slider("Effects", "audio/sfx", 0.0, 1.0, 0.05)
	_slider("Ambience", "audio/ambient", 0.0, 1.0, 0.05)
	_slider("Interface", "audio/ui", 0.0, 1.0, 0.05)
	_slider("Music & radio", "audio/music", 0.0, 1.0, 0.05)
	_heading("Controls", 20)
	_slider("Mouse sensitivity", "controls/mouse_sensitivity", 0.0005, 0.008, 0.0005)
	_slider("Stick sensitivity", "controls/stick_sensitivity", 1.0, 6.0, 0.2)
	_check("Controller vibration", "controls/vibration")
	_check("Invert camera Y", "controls/invert_y")
	_heading("Keys (click one, then press the new key; Esc cancels)", 16)
	for a in InputRebinder.ACTIONS:
		_bind_row(str(a[0]), str(a[1]))
	var reset := Button.new()
	reset.name = "ResetKeys"
	reset.text = "Reset keys to default"
	reset.pressed.connect(func():
		settings.reset_bindings()
		_refresh_binds())
	_rows.add_child(reset)
	_heading("Accessibility", 20)
	_check("Sound captions (e.g. [Gunshot], [Taxi hooter])", "access/captions")
	_check("Speech bubbles over people who talk", "access/speech_bubbles")
	_heading("Video", 20)
	_slider("Field of view", "video/fov", 55.0, 95.0, 1.0)
	_slider("Render scale", "video/render_scale", 0.5, 1.0, 0.05)
	_slider("Anti-aliasing (MSAA 0-3)", "video/msaa", 0, 3, 1)
	_slider("Crowd simulation range (0 near, 1 wide, 2 everywhere)", "video/crowd_range", 0, 2, 1)
	_check("Shadows", "video/shadows")
	_check("Lighting effects (ambient occlusion, bloom)", "video/effects")
	_check("Distance fog", "video/fog")
	_check("Fullscreen", "video/fullscreen")
	_check("VSync", "video/vsync")
	_check("Show FPS", "video/show_fps")
	_heading("Gameplay", 20)
	_check("Weather (rain and wind)", "gameplay/weather")
	_check("Traffic", "gameplay/traffic")
	_check("Autosave (after missions and each new day)", "gameplay/autosave")
	_check("Gold waypoint marker for the current mission", "gameplay/waypoint")
	_check("Show tips for new players", "gameplay/tips")
	var replay := Button.new()
	replay.name = "ReplayTutorial"
	replay.text = "Replay the tutorial"
	replay.pressed.connect(func(): replay_tutorial.emit())
	_rows.add_child(replay)
	var quit := Button.new()
	quit.text = "Quit to desktop"
	quit.pressed.connect(func(): quit_requested.emit())
	_rows.add_child(quit)


var _capturing := ""
var _bind_buttons: Dictionary = {}   # action -> Button


func _bind_row(action: String, label: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var b := Button.new()
	b.name = "bind_" + action
	b.custom_minimum_size = Vector2(300, 0)
	b.text = InputRebinder.label(action)
	b.pressed.connect(func():
		_capturing = action
		b.text = "Press a key…")
	row.add_child(b)
	_bind_buttons[action] = b
	_rows.add_child(row)


func _refresh_binds() -> void:
	_capturing = ""
	for action in _bind_buttons:
		(_bind_buttons[action] as Button).text = InputRebinder.label(action)


## While a key button waits for input, the next key or mouse button is taken before anything else sees it.
func _input(event: InputEvent) -> void:
	if _capturing.is_empty() or not visible:
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_refresh_binds()
		return
	settings.note_bindings(InputRebinder.bind(_capturing, event))
	_refresh_binds()


func _heading(text: String, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#ffd75e"))
	_rows.add_child(l)


func _slider(label: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.name = key.replace("/", "_")
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(settings.get_value(key))
	s.custom_minimum_size = Vector2(300, 24)
	s.value_changed.connect(func(v: float): _store(key, v))
	row.add_child(s)
	_rows.add_child(row)


func _check(label: String, key: String) -> void:
	var c := CheckBox.new()
	c.name = key.replace("/", "_")
	c.text = label
	c.button_pressed = bool(settings.get_value(key))
	c.toggled.connect(func(on: bool): _store(key, on))
	_rows.add_child(c)


func _store(key: String, value: Variant) -> void:
	settings.set_value(key, value)
	settings.save_settings()


func control_for(key: String) -> Control:
	return find_child(key.replace("/", "_"), true, false) as Control


func open() -> void:
	visible = true
	get_tree().paused = true
	var resume := find_child("Resume", true, false) as Button
	if resume:
		resume.grab_focus.call_deferred()


func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# B (ui_cancel on a pad) backs out too; Esc is both pause and ui_cancel, so it only counts once.
	if visible and (event.is_action_pressed("pause") or (event.is_action_pressed("ui_cancel") and event is InputEventJoypadButton)):
		close()
		get_viewport().set_input_as_handled()
