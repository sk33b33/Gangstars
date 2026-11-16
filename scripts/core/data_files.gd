class_name DataFiles
extends RefCounted
## Small helper for loading JSON data files with clear errors.


## Real-world mode: the game's content re-placed on the real Westridge lives in data/real/ (written
## by tools/world/relocate_to_real.py). With this on, a file there is read instead of its original.
static var real_mode := _initial_real_mode()


## Chosen before any scene loads: the --real / --old-world arguments, else the saved setting.
static func _initial_real_mode() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--old-world"):
		return false
	if args.has("--real"):
		return true
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		return bool(cfg.get_value("gameplay", "real_world", REAL_DEFAULT))
	return REAL_DEFAULT


## Which world a fresh install starts in.
const REAL_DEFAULT := true
const REAL_OVERLAY := "res://data/real/"


static func resolve(path: String) -> String:
	if real_mode and path.begins_with("res://data/") and not path.begins_with(REAL_OVERLAY):
		var over := REAL_OVERLAY + path.trim_prefix("res://data/")
		if FileAccess.file_exists(over):
			return over
	return path


static func load_json(path: String) -> Variant:
	path = resolve(path)
	if not FileAccess.file_exists(path):
		push_error("Data file missing: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


static func to_color(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


static func to_vec2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
