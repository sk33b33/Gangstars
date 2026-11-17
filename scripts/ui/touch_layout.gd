class_name TouchLayout
extends RefCounted
## Where the on-screen buttons of a touchscreen sit, which ones are there, and what can be added.
## Pure logic (no nodes): TouchControls draws and handles it, the settings save it (`touch/layout`).
## Positions are fractions of the screen, so a layout survives another phone or a rotated screen.
## Design: design/gdd/touch_controls.md.

## The MENU button is the way back to this editor and the settings: it can never be removed.
const MENU_ID := "pause"
## How far (in pixels) a button's edge must stay from the screen's edge.
const EDGE_MARGIN := 6.0
## Where a newly added button appears, as fractions of the screen (the player drags it from there).
const ADD_AT := Vector2(0.5, 0.3)

## Every button the game offers. id, action ("" = handled by TouchControls), label, name (for the Add list),
## hold, radius, and the default place: `at` pixels in from the edge `from` ("br" bottom right, "tr" top
## right, "bl" bottom left). `extra`: not on screen until the player adds it.
const CATALOG := [
	{"id": "interact", "action": "interact", "label": "TALK", "name": "Talk / interact", "hold": false, "r": 58.0, "at": [330.0, 150.0], "from": "br"},
	{"id": "sprint", "action": "sprint", "label": "RUN", "name": "Sprint (tap to switch on or off)", "hold": true, "toggle": true, "r": 46.0, "at": [470.0, 70.0], "from": "br"},
	{"id": "jump", "action": "jump", "label": "JUMP", "name": "Jump", "hold": false, "r": 42.0, "at": [470.0, 200.0], "from": "br"},
	{"id": "aim", "action": "aim", "label": "AIM", "name": "Aim (hold)", "hold": true, "r": 46.0, "at": [215.0, 330.0], "from": "br"},
	{"id": "lock", "action": "", "label": "LOCK", "name": "Auto-lock on / off", "hold": false, "toggle": true, "r": 46.0, "at": [90.0, 330.0], "from": "br"},
	{"id": "fire", "action": "fire", "label": "FIRE", "name": "Shoot (hold)", "hold": true, "r": 56.0, "at": [190.0, 345.0], "from": "bl"},
	{"id": "pause", "action": "pause", "label": "MENU", "name": "Menu", "hold": false, "r": 30.0, "at": [48.0, 115.0], "from": "tr"},
	{"id": "phone", "action": "phone", "label": "PHONE", "name": "Phone", "hold": false, "r": 30.0, "at": [48.0, 185.0], "from": "tr"},
	{"id": "turf_map", "action": "turf_map", "label": "MAP", "name": "Turf map", "hold": false, "r": 30.0, "at": [48.0, 255.0], "from": "tr"},
	{"id": "shout", "action": "shout", "label": "HEY", "name": "Whistle / shout", "hold": false, "r": 30.0, "at": [120.0, 255.0], "from": "tr"},
	{"id": "camera_mode", "action": "camera_mode", "label": "VIEW", "name": "Switch camera view", "hold": false, "r": 30.0, "at": [120.0, 115.0], "from": "tr"},
	{"id": "bag", "action": "bag", "label": "BAG", "name": "Bag", "hold": false, "r": 30.0, "at": [48.0, 325.0], "from": "tr"},
	{"id": "radio", "action": "radio", "label": "RADIO", "name": "Car radio", "hold": false, "r": 30.0, "at": [120.0, 185.0], "from": "tr"},
	{"id": "switch_weapon", "action": "switch_weapon", "label": "SWAP", "name": "Switch weapon", "hold": false, "r": 36.0, "at": [0.0, 0.0], "from": "br", "extra": true},
	{"id": "accelerate", "action": "accelerate", "label": "GAS", "name": "Accelerate (driving)", "hold": true, "r": 46.0, "at": [0.0, 0.0], "from": "br", "extra": true},
	{"id": "brake", "action": "brake", "label": "BRAKE", "name": "Brake (driving)", "hold": true, "r": 46.0, "at": [0.0, 0.0], "from": "br", "extra": true},
]

var positions := {}    # button id -> Vector2 (fractions of the screen) for buttons the player moved or added
var removed := {}      # button id -> true: default buttons the player took away
var added := {}        # button id -> true: extra buttons the player put on screen


static func entry(id: String) -> Dictionary:
	for b: Dictionary in CATALOG:
		if b.id == id:
			return b
	return {}


## The buttons now on screen, in catalog order (copies, so a caller may add keys).
func active() -> Array:
	var out: Array = []
	for b: Dictionary in CATALOG:
		if is_active(str(b.id)):
			out.append(b.duplicate())
	return out


func is_active(id: String) -> bool:
	var b := entry(id)
	if b.is_empty():
		return false
	return added.has(id) if b.get("extra", false) else not removed.has(id)


## The buttons that are not on screen: what the Add list offers.
func available() -> Array:
	var out: Array = []
	for b: Dictionary in CATALOG:
		if not is_active(str(b.id)):
			out.append(b.duplicate())
	return out


## Where a button's centre is, in pixels, on a screen of `size`.
func centre(b: Dictionary, size: Vector2) -> Vector2:
	var id := str(b.id)
	if positions.has(id):
		return clamp_to_screen((positions[id] as Vector2) * size, float(b.r), size)
	var at: Array = b.at
	match str(b.get("from", "br")):
		"tr":
			return Vector2(size.x - float(at[0]), float(at[1]))
		"bl":
			return Vector2(float(at[0]), size.y - float(at[1]))
	return Vector2(size.x - float(at[0]), size.y - float(at[1]))


## Keeps a button of radius `r` entirely on a screen of `size`.
static func clamp_to_screen(p: Vector2, r: float, size: Vector2) -> Vector2:
	var m := r + EDGE_MARGIN
	return Vector2(clampf(p.x, minf(m, size.x * 0.5), maxf(size.x - m, size.x * 0.5)), clampf(p.y, minf(m, size.y * 0.5), maxf(size.y - m, size.y * 0.5)))


## Moves a button so its centre is at `pixels` (kept on screen).
func move(id: String, pixels: Vector2, size: Vector2) -> void:
	var b := entry(id)
	if b.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	positions[id] = clamp_to_screen(pixels, float(b.r), size) / size


## False for the MENU button, which stays.
func can_remove(id: String) -> bool:
	return id != MENU_ID and is_active(id)


## Takes a button off the screen. Returns false (and changes nothing) when it cannot go.
func remove(id: String) -> bool:
	if not can_remove(id):
		return false
	if entry(id).get("extra", false):
		added.erase(id)
	else:
		removed[id] = true
	positions.erase(id)
	return true


## Puts a button on screen: a default one back where it was, an extra one at ADD_AT. Returns false when it is already there.
func add(id: String) -> bool:
	var b := entry(id)
	if b.is_empty() or is_active(id):
		return false
	if b.get("extra", false):
		added[id] = true
		positions[id] = ADD_AT
	else:
		removed.erase(id)
		positions.erase(id)
	return true


func reset() -> void:
	positions.clear()
	removed.clear()
	added.clear()


func is_default() -> bool:
	return positions.is_empty() and removed.is_empty() and added.is_empty()


## For the settings file: {"pos": {id: [x, y]}, "removed": [ids], "added": [ids]}.
func to_dict() -> Dictionary:
	var pos := {}
	for id: String in positions:
		pos[id] = [snappedf((positions[id] as Vector2).x, 0.0001), snappedf((positions[id] as Vector2).y, 0.0001)]
	return {"pos": pos, "removed": removed.keys(), "added": added.keys()}


## Loads a saved layout; anything unknown or malformed is ignored (a layout from another version never breaks the game).
func load_dict(d: Variant) -> void:
	reset()
	if not d is Dictionary:
		return
	for id in (d.get("removed", []) if d.get("removed", []) is Array else []):
		var b := entry(str(id))
		if not b.is_empty() and not b.get("extra", false) and str(id) != MENU_ID:
			removed[str(id)] = true
	for id in (d.get("added", []) if d.get("added", []) is Array else []):
		var b := entry(str(id))
		if not b.is_empty() and b.get("extra", false):
			added[str(id)] = true
	var pos: Variant = d.get("pos", {})
	if pos is Dictionary:
		for id in pos:
			var v: Variant = pos[id]
			if is_active(str(id)) and v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
				positions[str(id)] = Vector2(clampf(float(v[0]), 0.0, 1.0), clampf(float(v[1]), 0.0, 1.0))
