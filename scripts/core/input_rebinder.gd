class_name InputRebinder
extends RefCounted
## Keyboard and mouse re-binding. Only the actions in ACTIONS can change; gamepad buttons are left
## alone. Bindings are saved with the settings ("bindings" section) and re-applied on start.
## InputHints shows the new key names in the prompts.

const ACTIONS := [
	["move_forward", "Move forward"], ["move_backward", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"],
	["sprint", "Sprint"], ["jump", "Jump"], ["interact", "Interact"], ["shout", "Whistle"], ["phone", "Phone"],
	["turf_map", "Turf map"], ["radio", "Car radio"], ["switch_weapon", "Switch weapon"], ["aim", "Aim"], ["fire", "Shoot"],
]

static var _defaults: Dictionary = {}   # action -> Array[InputEvent] (keyboard/mouse only), taken before any change


static func action_ids() -> Array:
	return ACTIONS.map(func(a): return a[0])


static func snapshot_defaults() -> void:
	if not _defaults.is_empty():
		return
	for id in action_ids():
		_defaults[id] = _kbm_events(id)


static func _kbm_events(action: String) -> Array:
	var out: Array = []
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventKey or e is InputEventMouseButton:
				out.append(e.duplicate())
	return out


static func _replace(action: String, events: Array) -> void:
	for e in _kbm_events(action):
		InputMap.action_erase_event(action, e)
	for e in events:
		InputMap.action_add_event(action, e)
	_refresh_hint(action)


static func _refresh_hint(action: String) -> void:
	var list := _kbm_events(action)
	if list.is_empty():
		InputHints.custom.erase(action)
	else:
		InputHints.custom[action] = describe(list[0])


static func describe(e: InputEvent) -> String:
	if e is InputEventKey:
		var code: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		return OS.get_keycode_string(code)
	if e is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get(e.button_index, "Mouse %d" % e.button_index)
	return "?"


## What the action is bound to now, for the menu button.
static func label(action: String) -> String:
	var list := _kbm_events(action)
	return " / ".join(list.map(func(e): return describe(e))) if not list.is_empty() else "(none)"


## Binds `event` (a key or mouse button) to `action`. If another action already uses it, the two swap
## so nothing is left unbound. Returns the saved form of every changed action.
static func bind(action: String, event: InputEvent) -> Dictionary:
	snapshot_defaults()
	var changed := {}
	var old_events := _kbm_events(action)
	for other in action_ids():
		if other == action:
			continue
		for e in _kbm_events(other):
			if _same(e, event):
				_replace(other, old_events)
				changed[other] = _to_saved(old_events)
	_replace(action, [event])
	changed[action] = _to_saved([event])
	return changed


static func reset_all() -> void:
	snapshot_defaults()
	for id in action_ids():
		_replace(id, _defaults[id])


static func apply(saved: Dictionary) -> void:
	snapshot_defaults()
	for action in saved:
		if not action_ids().has(action) or not saved[action] is Array:
			continue
		var events: Array = []
		for s in saved[action]:
			var e := _from_saved(s)
			if e:
				events.append(e)
		if not events.is_empty():
			_replace(action, events)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return describe(a) == describe(b)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


static func _to_saved(events: Array) -> Array:
	var out: Array = []
	for e in events:
		if e is InputEventKey:
			out.append({"k": int(e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode)})
		elif e is InputEventMouseButton:
			out.append({"m": int(e.button_index)})
	return out


static func _from_saved(s: Variant) -> InputEvent:
	if not s is Dictionary:
		return null
	if s.has("k"):
		var k := InputEventKey.new()
		k.physical_keycode = int(s.k) as Key
		return k
	if s.has("m"):
		var m := InputEventMouseButton.new()
		m.button_index = int(s.m) as MouseButton
		return m
	return null
