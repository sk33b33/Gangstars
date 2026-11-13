class_name InputHints
extends RefCounted
## Button names for on-screen prompts. They follow the device used last: the HUD calls
## `note_event` on every input event, and prompts switch between keyboard and gamepad names
## (Xbox-style labels; other pads map to the same positions).

static var gamepad := false
## Keyboard/mouse names after the player re-binds keys (InputRebinder): action -> label.
static var custom: Dictionary = {}

const KEYBOARD := {
	"interact": "E", "shout": "Q", "turf_map": "M", "sprint": "Shift", "jump": "Space",
	"pause": "Esc", "move": "WASD", "look": "Mouse", "drive": "W/S", "back": "Esc", "aim": "RMB", "fire": "LMB", "phone": "P", "radio": "R", "skip_tips": "Tab",
}
const PAD := {
	"interact": "A", "shout": "Y", "turf_map": "View", "sprint": "L3", "jump": "B",
	"pause": "Menu", "move": "Left stick", "look": "Right stick", "drive": "RT/LT", "back": "B", "aim": "LT", "fire": "RT", "phone": "D-pad up", "radio": "D-pad down", "skip_tips": "D-pad left",
}
## Stick movement below this doesn't count as switching to the gamepad (drift, resting thumbs).
const STICK_SWITCH := 0.5


## Returns true if the active device changed.
static func note_event(event: InputEvent) -> bool:
	var pad := gamepad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > STICK_SWITCH:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and event.relative.length() > 4.0:
		pad = false
	if pad == gamepad:
		return false
	gamepad = pad
	return true


static func key(action: String) -> String:
	if not gamepad and custom.has(action):
		return str(custom[action])
	return str((PAD if gamepad else KEYBOARD).get(action, action))


static func help_line() -> String:
	if gamepad:
		return "Left stick move · L3 sprint · A interact · LT aim · RT shoot · D-pad up phone · Y whistle · View turf map · Menu pause"
	var move := "WASD" if not custom.has("move_forward") else "%s%s%s%s" % [key("move_forward"), key("move_left"), key("move_backward"), key("move_right")]
	return "%s move · %s sprint · %s interact · %s aim · %s shoot · %s phone · %s whistle · %s turf map · F3 debug · F7 +1h · Esc mouse" % [
		move, key("sprint"), key("interact"), key("aim"), key("fire"), key("phone"), key("shout"), key("turf_map")]
