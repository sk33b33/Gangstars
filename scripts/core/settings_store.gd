class_name SettingsStore
extends RefCounted
## Player-facing settings, persisted to a ConfigFile. `apply(...)` pushes them into the
## engine and game objects. Unknown or bad values fall back to defaults.

signal changed

const DEFAULTS := {
	"audio/master": 0.9, "audio/sfx": 0.9, "audio/ambient": 0.7, "audio/ui": 0.8,
	"controls/mouse_sensitivity": 0.0025, "controls/stick_sensitivity": 2.6, "controls/invert_y": false,
	"controls/vibration": true,
	"video/fov": 70.0, "video/shadows": true, "video/msaa": 2, "video/fog": true,
	"video/render_scale": 1.0, "video/fullscreen": false, "video/vsync": true, "video/show_fps": false,
	"gameplay/weather": true, "gameplay/traffic": true,
}
const RANGES := {
	"audio/master": [0.0, 1.0], "audio/sfx": [0.0, 1.0], "audio/ambient": [0.0, 1.0], "audio/ui": [0.0, 1.0],
	"controls/mouse_sensitivity": [0.0005, 0.008], "controls/stick_sensitivity": [1.0, 6.0], "video/fov": [55.0, 95.0], "video/render_scale": [0.5, 1.0],
	"video/msaa": [0, 3],
}

var path := "user://settings.cfg"
var values: Dictionary = DEFAULTS.duplicate()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = _sanitize(key, value)
	changed.emit()


func _sanitize(key: String, value: Variant) -> Variant:
	var def: Variant = DEFAULTS[key]
	if def is bool:
		return bool(value)
	if def is int:
		var r: Array = RANGES.get(key, [-1000000, 1000000])
		return clampi(int(value), int(r[0]), int(r[1]))
	if def is float:
		var r2: Array = RANGES.get(key, [-1e9, 1e9])
		return clampf(float(value), float(r2[0]), float(r2[1]))
	return value


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key: String in DEFAULTS:
		var parts := key.split("/")
		if cfg.has_section_key(parts[0], parts[1]):
			values[key] = _sanitize(key, cfg.get_value(parts[0], parts[1]))


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	for key: String in values:
		var parts := key.split("/")
		cfg.set_value(parts[0], parts[1], values[key])
	return cfg.save(path)


## Applies everything that doesn't need game objects (audio buses, window).
func apply_engine() -> void:
	for pair in [["Master", "audio/master"], ["SFX", "audio/sfx"], ["Ambient", "audio/ambient"], ["UI", "audio/ui"]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, float(get_value(pair[1])))))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if get_value("video/fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("video/vsync") else DisplayServer.VSYNC_DISABLED)
