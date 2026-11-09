class_name Hud
extends CanvasLayer
## HUD: title/help, interaction prompt, feedback messages, and the debug text panel.
## Observes gameplay through signals; owns no gameplay rules.

const MESSAGE_TIME := 5.0
const HELP := "WASD move · Shift sprint · E interact · Q whistle · F3 debug · F5/F6 incidents · F7 +1h · Esc frees mouse"

var _title: Label
var _prompt: Label
var _message: Label
var _debug: Label
var _clock: Label
var _district := ""
var _message_timer := 0.0


func _ready() -> void:
	_title = _label(Vector2(16, 12), 18)
	_title.text = "CONCRETE KINGS\n" + HELP
	_clock = _label(Vector2(16, 70), 26)
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
	_title.text = "%s\n%s" % [text.to_upper(), HELP]


func set_clock(clock: SimClock) -> void:
	_clock.text = "%s  ·  Day %d%s" % [clock.label(), clock.day, "  ·  night" if clock.is_night() else ""]


func set_prompt(target: Interactable) -> void:
	_prompt.text = "[E]  %s" % target.prompt if target else ""


func show_message(text: String) -> void:
	if text.is_empty():
		return
	_message.text = text
	_message.modulate.a = 1.0
	_message_timer = MESSAGE_TIME


func set_debug_text(text: String) -> void:
	_debug.text = text


func set_debug_visible(v: bool) -> void:
	_debug.visible = v


func prompt_text() -> String:
	return _prompt.text


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		_message.modulate.a = clampf(_message_timer, 0.0, 1.0)


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l
