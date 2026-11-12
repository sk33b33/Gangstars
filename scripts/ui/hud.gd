class_name Hud
extends CanvasLayer
## HUD: title/help, interaction prompt, feedback messages, and the debug text panel.
## Observes gameplay through signals; owns no gameplay rules.

const MESSAGE_TIME := 5.0

var _title: Label
var _prompt: Label
var _message: Label
var _debug: Label
var _clock: Label
var _stats: Label
var _combat: Label
var _crosshair: Label
var _tracker: Label
var _menu: PanelContainer
var _menu_list: VBoxContainer
var _menu_title: Label
var _menu_note: Label
var _banner: Label
var _fps: Label
var _banner_timer := 0.0
var _district := ""
var _prompt_target: Interactable
var _message_timer := 0.0
var _help_timer := 40.0   # the controls line fades away after a while; a key/pad switch brings it back


func _ready() -> void:
	_title = _label(Vector2(16, 12), 18)
	_title.text = "GANGSTARS\n" + InputHints.help_line()
	_clock = _label(Vector2(16, 70), 26)
	_stats = _label(Vector2(16, 104), 22)
	_tracker = _label(Vector2(16, 140), 20)
	_combat = _label(Vector2.ZERO, 24)
	_combat.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_combat.offset_left = -260
	_combat.offset_right = -16
	_combat.offset_top = 12
	_combat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_crosshair = _label(Vector2.ZERO, 30)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -20
	_crosshair.offset_right = 20
	_crosshair.offset_top = -22
	_crosshair.offset_bottom = 22
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.text = "+"
	_crosshair.visible = false
	_tracker.add_theme_color_override("font_color", Color("#ffd75e"))
	# Panels behind the info labels (the label's own background), a compass and a vignette.
	_title.add_theme_stylebox_override("normal", panel_style(Color("#9fd8b8")))
	_clock.add_theme_stylebox_override("normal", panel_style(Color("#5dade2")))
	_stats.add_theme_stylebox_override("normal", panel_style(Color("#27ae60")))
	_tracker.add_theme_stylebox_override("normal", panel_style(Color("#ffd75e"), 0.62))
	_title.position = Vector2(12, 8)
	_clock.position = Vector2(12, 78)
	_stats.position = Vector2(12, 120)
	_tracker.position = Vector2(12, 164)
	_build_compass()
	_build_vignette()
	_build_menu()
	_fps = _label(Vector2.ZERO, 16)
	_fps.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps.offset_left = -120
	_fps.offset_top = -30
	_fps.visible = false
	_banner = _label(Vector2.ZERO, 44)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = 150
	_banner.add_theme_color_override("font_color", Color("#9fd8b8"))
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	_prompt = _label(Vector2.ZERO, 22)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_top = -80
	_prompt.offset_bottom = -50
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_message = _label(Vector2.ZERO, 20)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.offset_top = -170
	_message.offset_bottom = -90
	_message.offset_left = -480
	_message.offset_right = 480
	_debug = _label(Vector2.ZERO, 14)
	_debug.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_debug.offset_left = -560
	_debug.offset_top = 12
	_debug.offset_right = -12
	_debug.visible = false


func set_district_name(text: String) -> void:
	_district = text
	_show_title()


func set_clock(clock: SimClock) -> void:
	_clock.text = "%s  ·  Day %d%s" % [clock.label(), clock.day, "  ·  night" if clock.is_night() else ""]


## Health, police heat stars and the aiming crosshair (top right / centre).
func set_combat(health_fraction: float, heat_level: int, aiming: bool) -> void:
	var hp := int(round(health_fraction * 100.0))
	var stars := ("★".repeat(heat_level) + "☆".repeat(5 - heat_level)) if heat_level > 0 else ""
	_combat.text = "♥ %d%s" % [hp, ("\n" + stars) if not stars.is_empty() else ""]
	_combat.add_theme_color_override("font_color", Color("#ff6b6b") if hp < 35 else Color.WHITE)
	_crosshair.visible = aiming


func combat_text() -> String:
	return _combat.text


func set_stats(p: ProgressionState) -> void:
	_stats.text = "R%d   ·   Rep %d   ·   Crew %d (influence %d)" % [p.cash, p.reputation, p.recruited_crew_ids.size(), p.crew_influence]


func set_tracker(text: String) -> void:
	_tracker.text = text


func tracker_text() -> String:
	return _tracker.text


func is_menu_open() -> bool:
	return _menu.visible


## Opens a simple menu. items: [{text, disabled?: bool, action: Callable}]. Keyboard,
## mouse and controller (ui_up/ui_down/ui_accept) all work through Godot's focus system.
func open_menu(title: String, items: Array) -> void:
	_menu_title.text = title
	for c in _menu_list.get_children():
		c.queue_free()
	var first: Button = null
	for item in items:
		var b := Button.new()
		b.text = item.text
		b.disabled = bool(item.get("disabled", false))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(620, 0)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(item.action)
		_menu_list.add_child(b)
		if first == null and not b.disabled:
			first = b
	_menu.visible = true
	move_child(_menu, -1)
	if first:
		var target := first
		(func(): if is_instance_valid(target) and target.is_inside_tree(): target.grab_focus()).call_deferred()


func close_menu() -> void:
	_menu.visible = false
	_menu_note.text = ""


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.offset_left = -330
	_menu.offset_right = 330
	_menu.offset_top = -300
	_menu.offset_bottom = 300
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_color = Color("#ffd75e")
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	_menu.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_menu.add_child(box)
	_menu_title = Label.new()
	_menu_title.add_theme_font_size_override("font_size", 26)
	_menu_title.add_theme_color_override("font_color", Color("#ffd75e"))
	box.add_child(_menu_title)
	_menu_list = VBoxContainer.new()
	_menu_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_list.add_theme_constant_override("separation", 6)
	# Long menus (the safehouse has a dozen entries) scroll instead of running off the screen.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 420)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_menu_list)
	box.add_child(scroll)
	_menu_note = Label.new()
	_menu_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_note.custom_minimum_size = Vector2(620, 0)
	_menu_note.add_theme_font_size_override("font_size", 16)
	_menu_note.add_theme_color_override("font_color", Color("#9fd8b8"))
	box.add_child(_menu_note)
	_menu.visible = false
	add_child(_menu)


func set_prompt(target: Interactable) -> void:
	_prompt_target = target
	_prompt.text = "[%s]  %s" % [InputHints.key("interact"), target.prompt] if target else ""


## Switches every on-screen button name when the player changes between keyboard and pad.
func _input(event: InputEvent) -> void:
	if InputHints.note_event(event):
		refresh_hints()


func refresh_hints() -> void:
	_help_timer = 40.0 if _help_timer > 0.0 else 10.0
	_show_title()
	set_prompt(_prompt_target if is_instance_valid(_prompt_target) else null)


func _show_title() -> void:
	var name_text := _district.to_upper() if not _district.is_empty() else "GANGSTARS"
	_title.text = "%s\n%s" % [name_text, InputHints.help_line()] if _help_timer > 0.0 else name_text


func show_message(text: String) -> void:
	if text.is_empty():
		return
	_message.text = text
	_message.modulate.a = 1.0
	if _menu.visible:
		_menu_note.text = text
	_message_timer = MESSAGE_TIME


func set_debug_text(text: String) -> void:
	_debug.text = text


func set_debug_visible(v: bool) -> void:
	_debug.visible = v


func prompt_text() -> String:
	return _prompt.text


## Big centred announcement (district unlocked, etc.), fades after a few seconds.
func show_banner(text: String, seconds := 4.0) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_timer = seconds


func banner_text() -> String:
	return _banner.text if _banner.visible else ""


func set_fps_visible(v: bool) -> void:
	_fps.visible = v


func _process(delta: float) -> void:
	if _caption and _caption_timer > 0.0:
		_caption_timer -= delta
		if _caption_timer <= 0.0:
			_caption.visible = false
	for l: Label in [_tracker, _stats]:   # no empty glass panels
		l.visible = not l.text.is_empty()
	if _help_timer > 0.0:
		_help_timer -= delta
		if _help_timer <= 0.0:
			_show_title()
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _banner_timer > 0.0:
		_banner_timer -= delta
		_banner.modulate.a = clampf(_banner_timer, 0.0, 1.0)
		if _banner_timer <= 0.0:
			_banner.visible = false
	if _message_timer > 0.0:
		_message_timer -= delta
		_message.modulate.a = clampf(_message_timer, 0.0, 1.0)


## One look for every on-screen panel: dark glass, rounded corners, a thin gold edge on the left.
static func panel_style(accent := Color("#ffd75e"), alpha := 0.55) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, alpha)
	sb.set_corner_radius_all(8)
	sb.border_width_left = 4
	sb.border_color = accent
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


const POINTS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
var _compass: Label
var _vignette: ColorRect


func _build_compass() -> void:
	_compass = _label(Vector2.ZERO, 20)
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.offset_left = -190
	_compass.offset_right = 190
	_compass.offset_top = 76
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass.add_theme_stylebox_override("normal", panel_style(Color("#d9c49a"), 0.5))
	_compass.add_theme_color_override("font_color", Color("#f4efe2"))


## heading: compass degrees, 0 = north, 90 = east. Shows the eight points around you with yours
## in the middle. (Table Mountain is to the north-west: look for it at about 330 degrees.)
func set_heading(heading: float) -> void:
	if _compass == null:
		return
	var i := int(round(fposmod(heading, 360.0) / 45.0)) % 8
	var parts: PackedStringArray = []
	for k in range(-2, 3):
		var p: String = POINTS[(i + k + 16) % 8]
		parts.append("[ %s ]" % p if k == 0 else p)
	_compass.text = "   ".join(parts)


## A soft dark edge to the screen (stronger at night), so the middle of the picture reads first.
func _build_vignette() -> void:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.25;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = dot(uv, uv) * 2.4;
	COLOR = vec4(0.0, 0.0, 0.02, clamp(d * d * strength * 2.6, 0.0, 0.8));
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.material = mat
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vignette)
	move_child(_vignette, 0)


var _caption: Label
var _caption_timer := 0.0


## A sound caption near the bottom left: "◀ [Gunshot]" if it came from the left, "[Gunshot] ▶" from the right.
## side: -1 left .. 1 right (relative to where you look), 0 ahead or behind.
func show_caption(text: String, side: float) -> void:
	if _caption == null:
		_caption = _label(Vector2.ZERO, 22)
		_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_caption.offset_left = 16
		_caption.offset_top = -120
		_caption.offset_bottom = -80
		_caption.add_theme_stylebox_override("normal", panel_style(Color("#d9c49a"), 0.7))
	_caption.text = ("◀ [%s]" if side < -0.3 else ("[%s] ▶" if side > 0.3 else "[%s]")) % text
	_caption.visible = true
	_caption_timer = 2.5


func caption_text() -> String:
	return _caption.text if _caption and _caption.visible else ""


var _rain_fx: ColorRect
var _heat_fx: ColorRect


func _screen_effect(code: String) -> ColorRect:
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var r := ColorRect.new()
	r.material = mat
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.visible = false
	add_child(r)
	move_child(r, 1)
	return r


## Drops running down the "lens" in heavy rain, and a shimmer over the horizon on a hot still day.
func _build_weather_fx() -> void:
	_rain_fx = _screen_effect("""shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 grid = vec2(16.0, 9.0);
	vec2 id = floor(uv * grid);
	float h = hash(id);
	vec2 cell = fract(uv * grid);
	float fall = fract(TIME * (0.12 + h * 0.1) + h * 7.0);
	vec2 centre = vec2(0.15 + h * 0.7, 1.0 - fall);
	float d = length((cell - centre) * vec2(1.0, 0.55));
	float drop = smoothstep(0.1, 0.03, d) * step(h, amount * 0.55);
	vec2 off = (cell - centre) * drop * 0.05;
	COLOR = vec4(texture(screen_tex, uv + off).rgb * 1.08, drop);
}""")
	_heat_fx = _screen_effect("""shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float band = smoothstep(0.3, 0.46, uv.y) * smoothstep(0.66, 0.5, uv.y);
	float wob = sin(uv.y * 160.0 + TIME * 2.6) * 0.0016 * band * strength;
	COLOR = vec4(texture(screen_tex, uv + vec2(wob, 0.0)).rgb, 1.0);
}""")


func set_weather(rain: float, heat: float) -> void:
	if _rain_fx == null:
		_build_weather_fx()
	var drops := clampf((rain - 0.4) / 0.6, 0.0, 1.0)
	_rain_fx.visible = drops > 0.02
	(_rain_fx.material as ShaderMaterial).set_shader_parameter("amount", drops)
	_heat_fx.visible = heat > 0.12
	(_heat_fx.material as ShaderMaterial).set_shader_parameter("strength", heat)


func set_night(night: float) -> void:
	if _vignette:
		(_vignette.material as ShaderMaterial).set_shader_parameter("strength", 0.22 + 0.3 * clampf(night, 0.0, 1.0))


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l
